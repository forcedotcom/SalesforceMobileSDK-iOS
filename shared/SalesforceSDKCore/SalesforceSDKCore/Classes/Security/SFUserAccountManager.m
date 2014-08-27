/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFUserAccountManager+Internal.h"
#import "SFDirectoryManager.h"
#import "SFCommunityData.h"

#import <SalesforceSecurity/SFKeyStoreManager.h>
#import <SalesforceSecurity/SFKeyStoreKey.h>
#import <SalesforceSecurity/SFSDKCryptoUtils.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>

// Notifications
NSString * const SFUserAccountManagerDidChangeCurrentUserNotification   = @"SFUserAccountManagerDidChangeCurrentUserNotification";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

// The temporary user ID
NSString * const SFUserAccountManagerTemporaryUserAccountId = @"TEMP_USER_ID";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

// Persistence Keys
static NSString * const kUserAccountsMapCodingKey  = @"accountsMap";
static NSString * const kUserDefaultsLastUserIdKey = @"LastUserId";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";

// Oauth
static NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort default OAuth host
static NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";
static NSString * const kSFUserAccountOAuthRedirectUri = @"SFDCOAuthRedirectUri";

// Key for storing the user's configured login host (deprecated, use kSFUserAccountOAuthLoginHost)
static NSString * const kDeprecatedLoginHostPrefKey = @"login_host_pref";

// Key for the login host as defined in the app settings.
static NSString * const kAppSettingsLoginHost = @"primary_login_host_pref";

// Key for the custom login host value in the app settings.
static NSString * const kAppSettingsLoginHostCustomValue = @"custom_login_host_pref";

// Value for kAppSettingsLoginHost when a custom host is chosen.
static NSString * const kAppSettingsLoginHostIsCustom = @"CUSTOM";

// Name of the individual file containing the archived SFUserAccount class
static NSString * const kUserAccountPlistFileName = @"UserAccount.plist";

// Prefix of an org ID
static NSString * const kOrgPrefix = @"00D";

// Prefix of a user ID
static NSString * const kUserPrefix = @"005";

// Label for encryption key for user account persistence.
static NSString * const kUserAccountEncryptionKeyLabel = @"com.salesforce.userAccount.encryptionKey";

#pragma mark - SFLoginHostUpdateResult

@implementation SFLoginHostUpdateResult

- (id)initWithOrigHost:(NSString *)originalLoginHost
           updatedHost:(NSString *)updatedLoginHost
           hostChanged:(BOOL)loginHostChanged
{
    self = [super init];
    if (self) {
        _originalLoginHost = [originalLoginHost copy];
        _updatedLoginHost = [updatedLoginHost copy];
        _loginHostChanged = loginHostChanged;
    }
    
    return self;
}

@end

@implementation SFUserAccountManager

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFUserAccountManager *userAccountManager = nil;
    dispatch_once(&pred, ^{
		userAccountManager = [[self alloc] init];
	});
    return userAccountManager;
}

+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials {
    switch ([SFLogger logLevel]) {
        case SFLogLevelDebug:
            credentials.logLevel = kSFOAuthLogLevelDebug;
            break;
            
        case SFLogLevelInfo:
            credentials.logLevel = kSFOAuthLogLevelInfo;
            break;
            
        case SFLogLevelWarning:
            credentials.logLevel = kSFOAuthLogLevelWarning;
            break;
            
        case SFLogLevelError:
            credentials.logLevel = kSFOAuthLogLevelError;
            break;
    }
}

- (id)init {
	self = [super init];
	if (self) {
        _delegates = [[NSMutableOrderedSet alloc] init];
        NSString *bundleOAuthCompletionUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthRedirectUri];
        if (bundleOAuthCompletionUrl != nil) {
            self.oauthCompletionUrl = bundleOAuthCompletionUrl;
        }
        
        _userAccountMap = [[NSMutableDictionary alloc] init];
        
        [self loadAccounts:nil];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)makeUserIdSafe:(NSString*)aUserId {
    NSInteger userIdLen = [aUserId length];
    NSString *shortUserId = [aUserId substringToIndex:MIN(15,userIdLen)];
    return shortUserId;
}

#pragma mark - Login Host

- (void)setLoginHost:(NSString*)host {
    NSString *oldLoginHost = [self loginHost];
    
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kSFUserAccountOAuthLoginHost];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Update app settings, for apps that use it.
    [self updateAppSettingsLoginHost:host];
    
    // Only post the login host change notification if the host actually changed.
    if (![host isEqualToString:oldLoginHost]) {
        NSDictionary *userInfoDict = @{kSFLoginHostChangedNotificationOriginalHostKey: oldLoginHost, kSFLoginHostChangedNotificationUpdatedHostKey: host};
        NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
        [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
    }
}

- (NSString *)loginHost {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // First let's import any previously stored settings, if available
    NSString *host = [defaults stringForKey:kDeprecatedLoginHostPrefKey];
    if (host) {
        [defaults setObject:host forKey:kSFUserAccountOAuthLoginHost];
        [defaults removeObjectForKey:kDeprecatedLoginHostPrefKey];
        [defaults synchronize];
        return host;
    }
    
    // Fetch from the standard defaults or bundle
    NSString *loginHost = [defaults stringForKey:kSFUserAccountOAuthLoginHost];
    BOOL loginHostInitialized = (loginHost != nil);
    if (nil == loginHost || 0 == [loginHost length]) {
        loginHost = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthLoginHost];
        if (nil == loginHost || 0 == [loginHost length]) {
            loginHost = [self appSettingsLoginHost];
        }
    }
    
    // Finaly, default to something reasonnable
    if (nil == loginHost || 0 == [loginHost length]) {
        loginHost = kSFUserAccountOAuthLoginHostDefault;
    }
    
    // If the login host wasn't previously initialized, set it up.
    if (!loginHostInitialized) {
        [defaults setObject:loginHost forKey:kSFUserAccountOAuthLoginHost];
        [defaults synchronize];
        [self updateAppSettingsLoginHost:loginHost];
    }
    
    return loginHost;
}

- (void)updateAppSettingsLoginHost:(NSString *)newLoginHost {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    newLoginHost = [newLoginHost stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *newLoginHostLowercase = [newLoginHost lowercaseString];
    if (![newLoginHostLowercase isEqualToString:@"login.salesforce.com"]
            && ![newLoginHostLowercase isEqualToString:@"test.salesforce.com"]) {
        // Custom login host.
        [userDefaults setObject:kAppSettingsLoginHostIsCustom forKey:kAppSettingsLoginHost];
        [userDefaults setObject:newLoginHost forKey:kAppSettingsLoginHostCustomValue];
    } else {
        [userDefaults setObject:newLoginHost forKey:kAppSettingsLoginHost];
    }
    
    [userDefaults synchronize];
}

- (NSString *)appSettingsLoginHost {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // If the app settings host value is nil/empty, return default.
    NSString *appSettingsLoginHost = [defs objectForKey:kAppSettingsLoginHost];
    if (nil == appSettingsLoginHost || [appSettingsLoginHost length] == 0) {
        return nil;
    }
    
    // If a custom login host value was chosen and configured, return it.  If a custom value is
    // chosen but the value is *not* configured, reset the app settings login host to a sane
    // value and return that.
    if ([appSettingsLoginHost isEqualToString:kAppSettingsLoginHostIsCustom]) {  // User specified to use a custom host.
        NSString *customLoginHost = [defs objectForKey:kAppSettingsLoginHostCustomValue];
        if (nil != customLoginHost && [customLoginHost length] > 0) {
            // Custom value is set.  Return that.
            return customLoginHost;
        } else {
            // The custom host value is empty. Use the default.
            [defs setValue:kSFUserAccountOAuthLoginHostDefault forKey:kAppSettingsLoginHost];
            [defs synchronize];
            return kSFUserAccountOAuthLoginHostDefault;
        }
    }
    
    // If we got this far, we have a primary host value that exists, and isn't custom.  Return it.
    return appSettingsLoginHost;
}

- (SFLoginHostUpdateResult *)updateLoginHost
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
        
	NSString *previousLoginHost = self.loginHost;
	NSString *currentLoginHost = [self appSettingsLoginHost];
    SFLoginHostUpdateResult *result;
    if (currentLoginHost) {
        BOOL hostnameChanged = (nil != previousLoginHost && ![previousLoginHost isEqualToString:currentLoginHost]);
        if (hostnameChanged) {
            self.loginHost = currentLoginHost;
        }
        result = [[SFLoginHostUpdateResult alloc] initWithOrigHost:previousLoginHost updatedHost:currentLoginHost hostChanged:hostnameChanged];
    } else {
        result = [[SFLoginHostUpdateResult alloc] initWithOrigHost:previousLoginHost updatedHost:currentLoginHost hostChanged:NO];
    }
	return result;
}

#pragma mark - Default Values

- (NSSet *)scopes
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *scopesArray = [defs objectForKey:kOAuthScopesKey];
    return [NSSet setWithArray:scopesArray];
}

- (void)setScopes:(NSSet *)newScopes
{
    NSArray *scopesArray = [newScopes allObjects];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:scopesArray forKey:kOAuthScopesKey];
    [defs synchronize];
}

- (NSString *)oauthCompletionUrl
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *redirectUri = [defs objectForKey:kOAuthRedirectUriKey];
    return redirectUri;
}

- (void)setOauthCompletionUrl:(NSString *)newRedirectUri
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:newRedirectUri forKey:kOAuthRedirectUriKey];
    [defs synchronize];
}

- (NSString *)oauthClientId
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *clientId = [defs objectForKey:kOAuthClientIdKey];
    return clientId;
}

- (void)setOauthClientId:(NSString *)newClientId
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:newClientId forKey:kOAuthClientIdKey];
    [defs synchronize];
}

#pragma mark - SFUserAccountDelegate management

- (void)addDelegate:(id<SFUserAccountManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [_delegates addObject:nonretainedDelegate];
        }
    }
}

- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [_delegates removeObject:nonretainedDelegate];
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SFUserAccountManagerDelegate>))block
{
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFUserAccountManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
    }
}

#pragma mark Account management

- (NSArray *)allUserAccounts
{
    // Only load accounts if they haven't yet been loaded.
    if ([self.userAccountMap count] == 0) {
        [self loadAccounts:nil];
    }
    if ([self.userAccountMap count] == 0) {
        return nil;
    }
    
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSString *userId in [self.userAccountMap allKeys]) {
        if ([userId isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
            continue;
        }
        [accounts addObject:(self.userAccountMap)[userId]];
    }
    
    return accounts;
}

- (NSArray*)allUserIds {
    // Sort the user id
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(localizedCompare:)];
    NSArray *keys = [[self.userAccountMap allKeys] sortedArrayUsingDescriptors:@[descriptor]];
    
    // Remove the temporary user id from the array
    NSMutableArray *filteredKeys = [NSMutableArray array];
    for (NSString *userId in keys) {
        if ([userId isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
            continue;
        }
        [filteredKeys addObject:userId];
    }
    return filteredKeys;
}

/** Returns all existing account names in the keychain
 */
- (NSSet*)allExistingAccountNames {
    NSMutableDictionary *tokenQuery = [[NSMutableDictionary alloc] init];
    tokenQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    tokenQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    tokenQuery[(__bridge id)kSecReturnAttributes] = (id)kCFBooleanTrue;
    
    CFArrayRef outArr = nil;
    OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)[NSDictionary dictionaryWithDictionary:tokenQuery], (CFTypeRef *)&outArr);
    if (noErr == result) {
        NSMutableSet *accounts = [NSMutableSet set];
        for (NSDictionary *info in (__bridge_transfer NSArray *)outArr) {
            NSString *accountName = info[(__bridge NSString*)kSecAttrAccount];
            if (accountName) {
                [accounts addObject:accountName];
            }
        }
        
        return accounts;
    } else {
        [self log:SFLogLevelDebug format:@"Error querying for all existing accounts in the keychain: %ld", result];
        return nil;
    }
}

/** Returns a unique user account identifier
 */
- (NSString*)uniqueUserAccountIdentifier {
    NSSet *existingAccountNames = [self allExistingAccountNames];
   
    // Make sure to build a unique identifier
    NSString *identifier = nil;
    while (nil == identifier || [existingAccountNames containsObject:identifier]) {
        u_int32_t randomNumber = arc4random();
        identifier = [NSString stringWithFormat:@"%@-%u", self.oauthClientId, randomNumber];
    }

    return identifier;
}

- (SFUserAccount*)createUserAccount {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    SFOAuthCredentials *creds = newAcct.credentials;
    creds.accessToken = nil;
    creds.domain = self.loginHost;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;

    //when creating a fresh user account, always use a default user ID 
    // until the server tells us what the actual user ID is
    creds.userId = SFUserAccountManagerTemporaryUserAccountId;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self addAccount:newAcct];

    return newAcct;
}

- (SFUserAccount*)createUserAccountWithCredentials:(SFOAuthCredentials*)credentials {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    newAcct.credentials = credentials;
    
    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self addAccount:newAcct];
    
    return newAcct;
}

+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user {
    NSString *directory = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:directory error:nil];
    return [directory stringByAppendingPathComponent:kUserAccountPlistFileName];
}

// called by init
- (BOOL)loadAccounts:(NSError**)error {
    // Make sure we start from a blank state
    [self clearAllAccountState];
    
    // Get the root directory, usually ~/Library/<appBundleId>/
    NSString *rootDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:rootDirectory]) {
        // There is no root directory, that's fine, probably a fresh app install,
        // new user will be created later on.
        return YES;
    }
    
    // Now iterate over the org and then user directories to load
    // each individual user account file.
    // ~/Library/<appBundleId>/<orgId>/<userId>/UserAccount.plist
    NSArray *rootContents = [fm contentsOfDirectoryAtPath:rootDirectory error:error];
    if (nil == rootContents) {
        [self log:SFLogLevelDebug format:@"Unable to enumerate the content at %@: %@", rootDirectory, error];
        return NO;
    } else {
        for (NSString *rootContent in rootContents) {
            // Ignore content that don't represent an organization
            if (![rootContent hasPrefix:kOrgPrefix]) continue;

            NSString *rootPath = [rootDirectory stringByAppendingPathComponent:rootContent];
            
            // Fetch the content of the org directory
            NSArray *orgContents = [fm contentsOfDirectoryAtPath:rootPath error:error];
            if (nil == orgContents) {
                [self log:SFLogLevelDebug format:@"Unable to enumerate the content at %@: %@", rootPath, error];
                continue;
            }
            
            for (NSString *orgContent in orgContents) {
                // Ignore content that don't represent a user
                if (![orgContent hasPrefix:kUserPrefix]) continue;

                NSString *orgPath = [rootPath stringByAppendingPathComponent:orgContent];
                
                // Now let's try to load the user account file in there
                NSString *userAccountPath = [orgPath stringByAppendingPathComponent:kUserAccountPlistFileName];
                if ([fm fileExistsAtPath:userAccountPath]) {
                    SFUserAccount *userAccount = [self loadUserAccountFromFile:userAccountPath];
                    if (userAccount) {
                        [self addAccount:userAccount];
                    } else {
                        // Error logging will already have occurred.  Make sure account file data is removed.
                        [[NSFileManager defaultManager] removeItemAtPath:userAccountPath error:nil];
                    }
                } else {
                    [self log:SFLogLevelDebug format:@"There is no user account file in this user directory: %@", orgPath];
                }
            }
        }
    }
    
    NSString *curUserId = [self activeUserId];
    
    // In case the most recently used account was removed, or the most recent account is the temporary account,
    // see if we can load another available account.
    if (nil == curUserId || [curUserId isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
        for (SFUserAccount *account in self.userAccountMap.allValues) {
            if (account.credentials.userId) {
                curUserId = account.credentials.userId;
                break;
            }
        }
    }
    if (nil == curUserId) {
        [self log:SFLogLevelInfo msg:@"Current active user id is nil"];
    }
    
    self.previousCommunityId = [self activeCommunityId];
    
    SFUserAccount *account = [self userAccountForUserId:curUserId];
    account.communityId = nil;
    [self setCurrentUser:account];
    
    // update the client ID in case it's changed (via settings, etc)
    [[[self currentUser] credentials] setClientId:self.oauthClientId];
    
    [self userChanged:SFUserAccountChangeCredentials];
    
    return YES;
}

- (SFUserAccount *)loadUserAccountFromFile:(NSString *)filePath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [self log:SFLogLevelDebug format:@"No account data exists at '%@'", filePath];
        return nil;
    }
    
    @try {
        SFUserAccount *plainTextUserAccount = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        
        // Upgrade step.  If we got this far, the file is in the old plaintext format, and we'll
        // convert it to the encrypted format before returning the object.
        BOOL encryptUserAccountSuccess = [self saveUserAccount:plainTextUserAccount toFile:filePath];
        if (!encryptUserAccountSuccess) {
            // Specific error messages will already be logged.  Make sure old user account file is removed.
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            return nil;
        }
    }
    @finally {
        NSData *encryptedUserAccountData = [[NSFileManager defaultManager] contentsAtPath:filePath];
        if (!encryptedUserAccountData) {
            [self log:SFLogLevelDebug format:@"Could not retrieve user account data from '%@'", filePath];
            return nil;
        }
        
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
        NSData *decryptedArchiveData = [SFSDKCryptoUtils aes256DecryptData:encryptedUserAccountData withKey:encKey.key iv:encKey.initializationVector];
        if (!decryptedArchiveData) {
            [self log:SFLogLevelDebug msg:@"User account data could not be decrypted.  Can't load account."];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            return nil;
        }
        
        @try {
            SFUserAccount *decryptedAccount = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedArchiveData];
            return decryptedAccount;
        }
        @catch (NSException *exception) {
            [self log:SFLogLevelDebug format:@"Error deserializing the user account data: %@", [exception reason]];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            return nil;
        }
    }
}

- (BOOL)saveAccounts:(NSError**)error {
    for (NSString *userId in self.userAccountMap) {
        // Don't save the temporary user id
        if ([userId isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
            continue;
        }
        
        // Grab the user account...
        SFUserAccount *user = self.userAccountMap[userId];
        
        // And it's persistent file path
        NSString *userAccountPath = [[self class] userAccountPlistFileForUser:user];
        
        // Make sure to remove any existing file
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:userAccountPath]) {
            if (![fm removeItemAtPath:userAccountPath error:error]) {
                [self log:SFLogLevelDebug format:@"failed to remove old user account %@: %@", userAccountPath, error];
                return NO;
            }
        }
        
        // And now save its content
        if (![self saveUserAccount:user toFile:userAccountPath]) {
            [self log:SFLogLevelDebug format:@"failed to archive user account: %@", userAccountPath];
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)saveUserAccount:(SFUserAccount *)userAccount toFile:(NSString *)filePath {
    if (!userAccount) {
        [self log:SFLogLevelDebug msg:@"Cannot save empty user account."];
        return NO;
    }
    if ([filePath length] == 0) {
        [self log:SFLogLevelDebug msg:@"File path cannot be empty.  Can't save account."];
        return NO;
    }
    
    // Remove any existing file.
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *removeAccountFileError = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&removeAccountFileError]) {
            [self log:SFLogLevelDebug format:@"Failed to remove old user account data at path '%@': %@", filePath, [removeAccountFileError localizedDescription]];
            return NO;
        }
    }
    
    // Serialize the user account data.
    NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:userAccount];
    if (!archiveData) {
        [self log:SFLogLevelDebug msg:@"Could not archive user account data to save it."];
        return NO;
    }
    
    // Encrypt it.
    SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
    NSData *encryptedArchiveData = [SFSDKCryptoUtils aes256EncryptData:archiveData withKey:encKey.key iv:encKey.initializationVector];
    if (!encryptedArchiveData) {
        [self log:SFLogLevelDebug msg:@"User account data could not be encrypted.  Can't save account."];
        return NO;
    }
    
    // Save it.
    BOOL saveFileSuccess = [[NSFileManager defaultManager] createFileAtPath:filePath contents:encryptedArchiveData attributes:@{ NSFileProtectionKey : NSFileProtectionComplete }];
    if (!saveFileSuccess) {
        [self log:SFLogLevelDebug format:@"Could not create user account data file at path '%@'", filePath];
        return NO;
    }
    
    return YES;
}

- (SFUserAccount *)temporaryUser {
    SFUserAccount *tempAccount = (self.userAccountMap)[SFUserAccountManagerTemporaryUserAccountId];
    if (tempAccount == nil) {
        tempAccount = [self createUserAccount];
    }
    return tempAccount;
}

- (SFUserAccount*)userAccountForUserId:(NSString*)userId {
    NSString *safeUserId = [self makeUserIdSafe:userId];
    SFUserAccount *result = (self.userAccountMap)[safeUserId];
	return result;
}

- (NSArray *)accountsForOrgId:(NSString *)orgId {
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountOrg = account.credentials.organizationId;
        if ([accountOrg isEqualToString:orgId]) {
            [array addObject:account];
        }
    }
    return array;
}

- (NSArray *)accountsForInstanceURL:(NSString *)instanceURL {
    NSMutableArray *responseArray = [NSMutableArray array];
    
    for (NSString *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        if ([account.credentials.instanceUrl.host isEqualToString:instanceURL]) {
            [responseArray addObject:account];
        }
    }
    
    return responseArray;
}

- (BOOL)deleteAccountForUserId:(NSString*)userId error:(NSError **)error {
    NSString *safeUserId = [self makeUserIdSafe:userId];
    SFUserAccount *acct = [self userAccountForUserId:safeUserId];
    if (nil != acct) {
        NSString *userDirectory = [[SFDirectoryManager sharedManager] directoryForUser:acct
                                                                                 scope:SFUserAccountScopeUser
                                                                                  type:NSLibraryDirectory
                                                                            components:nil];
        if ([[NSFileManager defaultManager] fileExistsAtPath:userDirectory]) {
            NSError *folderRemovalError = nil;
            BOOL removeUserFolderSucceeded = [[NSFileManager defaultManager] removeItemAtPath:userDirectory error:&folderRemovalError];
            if (!removeUserFolderSucceeded) {
                [self log:SFLogLevelDebug
                   format:@"Error removing the user folder for '%@': %@", acct.userName, [folderRemovalError localizedDescription]];
                if (error) {
                    *error = folderRemovalError;
                }
                return removeUserFolderSucceeded;
            }
        } else {
            [self log:SFLogLevelDebug format:@"User folder for user '%@' does not exist on the filesystem.  Continuing.", acct.userName];
        }
        [self.userAccountMap removeObjectForKey:safeUserId];
    }
    return YES;
}

- (void)clearAllAccountState {
    [self.userAccountMap removeAllObjects];
}

- (void)addAccount:(SFUserAccount*)acct {
    NSString *safeUserId = [self makeUserIdSafe:acct.credentials.userId];
    (self.userAccountMap)[safeUserId] = acct;
}

- (NSString *)activeUserId {
    NSString *result = [[NSUserDefaults standardUserDefaults] stringForKey:kUserDefaultsLastUserIdKey];
    return result;
}

- (NSString *)activeCommunityId {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

- (void)setActiveUser:(SFUserAccount *)user {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults]; 
    if (nil == user) {
        [defs removeObjectForKey:kUserDefaultsLastUserIdKey];
        [defs removeObjectForKey:kUserDefaultsLastUserCommunityIdKey];
    } else {
        NSString *safeUserId = [self makeUserIdSafe:user.credentials.userId];
        [defs setValue:safeUserId forKey:kUserDefaultsLastUserIdKey];
        NSString *communityId = user.communityId;
        if (communityId) {
            [defs setObject:communityId forKey:kUserDefaultsLastUserCommunityIdKey];
        } else {
            [defs removeObjectForKey:kUserDefaultsLastUserCommunityIdKey];
        }
    }
    [defs synchronize];
}

- (void)replaceOldUser:(NSString*)oldUserId withUser:(SFUserAccount*)newUser {
    NSString *newUserId = [self makeUserIdSafe:newUser.credentials.userId];

    [self.userAccountMap removeObjectForKey:oldUserId];
    (self.userAccountMap)[newUserId] = newUser;
    
    NSString *defUserId = [self activeUserId];
    if (!defUserId || [defUserId isEqualToString:oldUserId]) {
        [self setActiveUser:newUser];
    }
}

- (void)setCurrentUser:(SFUserAccount*)user {
    [self setActiveUser:user];
    if (![_currentUser isEqual:user]) {
        
        [self willChangeValueForKey:@"currentUser"];
        _currentUser = user;
        [self didChangeValueForKey:@"currentUser"];
    }
    
    // It's important to call this method even if the isEqual
    // statement above returns YES, because the user account
    // object can still be the same but some internal
    // properties might have changed (eg the communityId).
    [self userChanged:SFUserAccountChangeUnknown];
}

// property accessor
- (NSString *)currentUserId {
    NSString *uid = self.currentUser.credentials.userId;
    if ([uid length]) {
        return [self makeUserIdSafe:uid];
    }
    return nil;
}

- (NSString *)currentCommunityId {
    return self.currentUser.communityId;
}

- (void)applyCredentials:(SFOAuthCredentials*)credentials {
    SFUserAccountChange change = SFUserAccountChangeCredentials;
    
    // If the user is nil, create a new one with the specified credentials
    // otherwise update the current user credentials.
    if (nil == self.currentUser) {
        self.currentUser = [self createUserAccountWithCredentials:credentials];
        change |= SFUserAccountChangeNewUser;
    } else {
        self.currentUser.credentials = credentials;
    }
    
    // If the user has logged using a community-base URL, then let's create the community data
    // related to this community using the information we have from oauth.
    self.currentUser.communityId = credentials.communityId;
    if (self.currentUser.communityId) {
        SFCommunityData *communityData = [[SFCommunityData alloc] init];
        communityData.entityId = credentials.communityId;
        communityData.siteUrl = credentials.communityUrl;
        self.currentUser.communities = @[ communityData ];
    } else {
        self.currentUser.communities = nil;
    }
    
    //if our default user id is currently the temporary user id,
    //we need to update it with the latest known good user id
    if ([[self activeUserId] isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
        [self log:SFLogLevelDebug format:@"Replacing temp user ID with %@",self.currentUser];
        [self replaceOldUser:SFUserAccountManagerTemporaryUserAccountId withUser:self.currentUser];
    }
    
    [self userChanged:change];
}

- (void)setObjectForCurrentUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    [self.currentUser setCustomDataObject:object forKey:key];
}

- (void)switchToNewUser {
    [self switchToUser:nil];
}

- (void)switchToUser:(SFUserAccount *)newCurrentUser {
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:willSwitchFromUser:toUser:)]) {
            [delegate userAccountManager:self willSwitchFromUser:self.currentUser toUser:newCurrentUser];
        }
    }];
    
    // "Local" new user, since we don't want to send back the temporary user to the delegates if we're
    // creating a new user.  We'll send back the original value (nil) in that case.
    SFUserAccount *tempNewCurrentUser = newCurrentUser;
    
    // If newCurrentUser is nil, we're switching to a "new" (unconfigured) user.
    if (tempNewCurrentUser == nil) {
        tempNewCurrentUser = [self createUserAccount];
    }
    
    SFUserAccount *origCurrentUser = self.currentUser;
    self.currentUser = tempNewCurrentUser;
    
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:didSwitchFromUser:toUser:)]) {
            [delegate userAccountManager:self didSwitchFromUser:origCurrentUser toUser:newCurrentUser];
        }
    }];
}

- (void)userChanged:(SFUserAccountChange)change {
    if (![self.lastChangedOrgId isEqualToString:self.currentUser.credentials.organizationId]) {
        self.lastChangedOrgId = self.currentUser.credentials.organizationId;
        change |= SFUserAccountChangeOrgId;
        change &= ~SFUserAccountChangeUnknown; // clear the unknown bit
    }

    if (![self.lastChangedUserId isEqualToString:self.currentUser.credentials.userId]) {
        self.lastChangedUserId = self.currentUser.credentials.userId;
        change |= SFUserAccountChangeUserId;
        change &= ~SFUserAccountChangeUnknown; // clear the unknown bit
    }

    if (![self.lastChangedCommunityId isEqualToString:self.currentUser.communityId]) {
        self.lastChangedCommunityId = self.currentUser.communityId;
        change |= SFUserAccountChangeCommunityId;
        change &= ~SFUserAccountChangeUnknown; // clear the unknown bit
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidChangeCurrentUserNotification
														object:self
                                                      userInfo:@{ SFUserAccountManagerUserChangeKey : @(change) }];
}

@end
