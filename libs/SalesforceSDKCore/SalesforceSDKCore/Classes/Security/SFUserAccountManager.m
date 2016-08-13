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
#import "SFUserAccountIdentity.h"
#import "SFUserAccountManagerUpgrade.h"
#import "SFDirectoryManager.h"
#import "SFCommunityData.h"
#import "SFManagedPreferences.h"
#import "SFUserAccount+Internal.h"
#import "SFIdentityData+Internal.h"

#import "SFKeyStoreManager.h"
#import "SFKeyStoreKey.h"
#import "SFSDKCryptoUtils.h"
#import "NSString+SFAdditions.h"
#import "SFSDKDatasharingHelper.h"
#import "SFFileProtectionHelper.h"

// Notifications
NSString * const SFUserAccountManagerDidChangeCurrentUserNotification   = @"SFUserAccountManagerDidChangeCurrentUserNotification";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

// The anonymous user support the application should add to its Info.plist file
static NSString * const kSFUserAccountSupportAnonymousUsage = @"SFDCSupportAnonymousUsage";
static NSString * const kSFUserAccountAutocreateAnonymousUser = @"SFDCAutocreateAnonymousUser";

// The anonymous user user id and org id
static NSString * const SFUserAccountManagerAnonymousUserAccountUserId = @"ANONYM_USER_ID"; // DO NOT EXCEED 15 characters
static NSString * const SFUserAccountManagerAnonymousUserAccountOrgId = @"ANONYM_ORG_ID"; // DO NOT EXCEED 15 characters

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

// Persistence Keys
static NSString * const kUserAccountsMapCodingKey  = @"accountsMap";
static NSString * const kUserDefaultsLastUserIdentityKey = @"LastUserIdentity";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";

// Oauth
static NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort default OAuth host
static NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";
static NSString * const kSFUserAccountOAuthRedirectUri = @"SFDCOAuthRedirectUri";

// Key for storing the user's configured login host (deprecated, use kSFUserAccountOAuthLoginHost)
static NSString * const kDeprecatedLoginHostPrefKey = @"login_host_pref";

// Name of the individual file containing the archived SFUserAccount class
static NSString * const kUserAccountPlistFileName = @"UserAccount.plist";

// Prefix of an org ID
static NSString * const kOrgPrefix = @"00D";

// Prefix of a user ID
static NSString * const kUserPrefix = @"005";

// Label for encryption key for user account persistence.
static NSString * const kUserAccountEncryptionKeyLabel = @"com.salesforce.userAccount.encryptionKey";

// Error domain and codes
static NSString * const SFUserAccountManagerErrorDomain = @"SFUserAccountManager";

static const NSUInteger SFUserAccountManagerCannotReadDecryptedArchive = 10001;
static const NSUInteger SFUserAccountManagerCannotReadPlainTextArchive = 10002;
static const NSUInteger SFUserAccountManagerCannotRetrieveUserData = 10003;

static const char * kSyncQueue = "com.salesforce.mobilesdk.sfuseraccountmanager.syncqueue";

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
    switch ([SFLogger sharedLogger].logLevel) {
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

        case SFLogLevelVerbose:
            credentials.logLevel = kSFOAuthLogLevelVerbose;
            break;
            
        default:
            break;
    }
}

- (id)init {
	self = [super init];
	if (self) {
        self.delegates = [NSHashTable weakObjectsHashTable];
        NSString *bundleOAuthCompletionUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthRedirectUri];
        if (bundleOAuthCompletionUrl != nil) {
            self.oauthCompletionUrl = bundleOAuthCompletionUrl;
        }
        _userAccountMap = [[NSMutableDictionary alloc] init];
        _temporaryUserIdentity = [[SFUserAccountIdentity alloc] initWithUserId:SFUserAccountManagerTemporaryUserAccountUserId orgId:SFUserAccountManagerTemporaryUserAccountOrgId];
        _anonymousUserIdentity = [[SFUserAccountIdentity alloc] initWithUserId:SFUserAccountManagerAnonymousUserAccountUserId orgId:SFUserAccountManagerAnonymousUserAccountOrgId];
        _syncQueue = dispatch_queue_create(kSyncQueue, NULL);
        [self loadAccounts:nil];
        [self setupAnonymousUser:self.supportsAnonymousUser autocreateAnonymousUser:self.autocreateAnonymousUser];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Login Host

- (void)setLoginHost:(NSString*)host {
    NSString *oldLoginHost = [self loginHost];
    
    if (nil == host) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSFUserAccountOAuthLoginHost];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:host forKey:kSFUserAccountOAuthLoginHost];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Only post the login host change notification if the host actually changed.
    if (![host isEqualToString:oldLoginHost]) {
        NSDictionary *userInfoDict;
        if (host) {
            userInfoDict = @{kSFLoginHostChangedNotificationOriginalHostKey: oldLoginHost, kSFLoginHostChangedNotificationUpdatedHostKey: host};
        } else {
            userInfoDict = @{kSFLoginHostChangedNotificationOriginalHostKey: oldLoginHost};
        }
        NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
        [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
    }
}

- (NSString *)loginHost {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // First let's import any previously stored settings, if available.
    NSString *host = [defaults stringForKey:kDeprecatedLoginHostPrefKey];
    if (host) {
        [defaults setObject:host forKey:kSFUserAccountOAuthLoginHost];
        [defaults removeObjectForKey:kDeprecatedLoginHostPrefKey];
        [defaults synchronize];
        return host;
    }

    // Fetch from the standard defaults or bundle.
    NSString *loginHost = [defaults stringForKey:kSFUserAccountOAuthLoginHost];
    if ([loginHost length] > 0) {
        return loginHost;
    }

    // Login host not initialized. Set it up.
    NSString *managedLoginHost = ([SFManagedPreferences sharedPreferences].loginHosts)[0];
    if (managedLoginHost.length > 0) {
        loginHost = managedLoginHost;
    } else {

        /*
         * Do not fall back to default login host if MDM only permits authorized hosts, even if there are no other hosts.
         */
        if (![SFManagedPreferences sharedPreferences].onlyShowAuthorizedHosts) {
            NSString *bundleLoginHost = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthLoginHost];
            if (bundleLoginHost.length > 0) {
                loginHost = bundleLoginHost;
            } else {
                loginHost = kSFUserAccountOAuthLoginHostDefault;
            }
        }
    }
    [defaults setObject:loginHost forKey:kSFUserAccountOAuthLoginHost];
    [defaults synchronize];
    return loginHost;
}

#pragma mark - Default Values

- (NSSet *)scopes
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *scopesArray = [defs objectForKey:kOAuthScopesKey] ?: [NSArray array];
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
            [self.delegates addObject:delegate];
        }
    }
}

- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            [self.delegates removeObject:delegate];
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SFUserAccountManagerDelegate>))block
{
    @synchronized(self) {
        for (id<SFUserAccountManagerDelegate> delegate in self.delegates) {
            if (block) block(delegate);
        }
    }
}

#pragma mark - Temporary User

- (SFUserAccount *)temporaryUser {
    SFUserAccount *tempAccount = (self.userAccountMap)[self.temporaryUserIdentity];
    if (tempAccount == nil) {
        tempAccount = [self createUserAccount];
    }
    return tempAccount;
}

#pragma mark - Anonymous User

+ (BOOL)isUserAnonymous:(SFUserAccount*)user {
    if (nil == user.accountIdentity) {
        return NO;
    }
    return [user.accountIdentity.userId isEqualToString:SFUserAccountManagerAnonymousUserAccountUserId] &&
        [user.accountIdentity.orgId isEqualToString:SFUserAccountManagerAnonymousUserAccountOrgId];
}

- (BOOL)supportsAnonymousUser {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountSupportAnonymousUsage] boolValue];
}

- (BOOL)autocreateAnonymousUser {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountAutocreateAnonymousUser] boolValue];
}

- (BOOL)isCurrentUserAnonymous {
    return [[self class] isUserAnonymous:self.currentUser];
}

- (SFUserAccount *)anonymousUser {
    if (nil == _anonymousUser) {
        for (SFUserAccountIdentity *identity in self.allUserIdentities) {
            if ([identity isEqual:self.anonymousUserIdentity]) {
                _anonymousUser = [self userAccountForUserIdentity:identity];
                break;
            }
        }
    }
    return _anonymousUser;
}

- (void)setupAnonymousUser:(BOOL)supportsAnonymousUser autocreateAnonymousUser:(BOOL)autocreateAnonymousUser {

    // If there is no current user but the application support anonymous user
    // and wants it to be created automatically, then create it now.
    if (supportsAnonymousUser && autocreateAnonymousUser && nil == self.anonymousUser) {
        [self log:SFLogLevelInfo msg:@"Creating anonymous user"];
        [self enableAnonymousAccount];
        if (nil == self.currentUser) {
            self.currentUser = self.anonymousUser;
        }
    }
}

- (void)enableAnonymousAccount {
    if (nil == self.anonymousUser) {
        self.anonymousUser = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier] clientId:self.oauthClientId];
        SFOAuthCredentials *creds = self.anonymousUser.credentials;
        creds.domain = self.loginHost;
        creds.redirectUri = self.oauthCompletionUrl;
        creds.clientId = self.oauthClientId;
        creds.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://does.not.matter.domain-does-not-exist/id/%@/%@", self.anonymousUserIdentity.orgId, self.anonymousUserIdentity.userId]];
        creds.communityUrl = [NSURL URLWithString:@"https://who-cares.domain-does-not-exist"];
        creds.instanceUrl = [NSURL URLWithString:@"https://who-cares.domain-does-not-exist"];
        creds.accessToken = [NSUUID UUID].UUIDString;
        [self addAccount:self.anonymousUser];
        [self saveAccounts:nil];
    }
}

- (void)disableAnonymousAccount {
    NSError *error;
    if (![self deleteAccountForUser:self.anonymousUser error:&error]) {
        [self log:SFLogLevelError format:@"Unable to delete the anonymous user: %@", [error localizedDescription]];
    }
    self.anonymousUser = nil;
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
    for (SFUserAccountIdentity *key in [self.userAccountMap allKeys]) {
        if ([key isEqual:self.temporaryUserIdentity]) {
            continue;
        }
        [accounts addObject:(self.userAccountMap)[key]];
    }
    
    return accounts;
}

- (NSArray *)allUserIdentities {
    // Sort the identities
    NSArray *keys = [[self.userAccountMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    // Remove the temporary user id from the array
    NSMutableArray *filteredKeys = [NSMutableArray array];
    for (SFUserAccountIdentity *identity in keys) {
        if ([identity isEqual:self.temporaryUserIdentity]) {
            continue;
        }
        [filteredKeys addObject:identity];
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

    // When creating a fresh user account, always use a default user ID
    // and org ID until the server tells us what the actual IDs are.
    creds.userId = self.temporaryUserIdentity.userId;
    creds.organizationId = self.temporaryUserIdentity.orgId;

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

- (void)migrateUserDefaults {
    //Migrate the defaults to the correct location
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    BOOL isGroupAccessEnabled = [SFSDKDatasharingHelper sharedInstance].appGroupEnabled;
    BOOL userIdentityShared = [sharedDefaults boolForKey:@"userIdentityShared"];
    BOOL communityIdShared = [sharedDefaults boolForKey:@"communityIdShared"];
    
    if (isGroupAccessEnabled && !userIdentityShared) {
        //Migrate user identity to shared location
        NSData *userData = [standardDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (userData) {
            [sharedDefaults setObject:userData forKey:kUserDefaultsLastUserIdentityKey];
        }
        [sharedDefaults setBool:YES forKey:@"userIdentityShared"];
    }
    if (!isGroupAccessEnabled && userIdentityShared) {
        //Migrate base app identifier key to non-shared location
        NSData *userData = [sharedDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (userData) {
            [standardDefaults setObject:userData forKey:kUserDefaultsLastUserIdentityKey];
        }
        
        [sharedDefaults setBool:NO forKey:@"userIdentityShared"];
    } else if (isGroupAccessEnabled && !communityIdShared) {
        //Migrate communityId to shared location
        NSString *activeCommunityId = [standardDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
        if (activeCommunityId) {
            [sharedDefaults setObject:activeCommunityId forKey:kUserDefaultsLastUserCommunityIdKey];
        }
        [sharedDefaults setBool:YES forKey:@"communityIdShared"];
    } else if (!isGroupAccessEnabled && communityIdShared) {
        //Migrate base app identifier key to non-shared location
        NSString *activeCommunityId = [sharedDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
        if (activeCommunityId) {
            [standardDefaults setObject:activeCommunityId forKey:kUserDefaultsLastUserCommunityIdKey];
        }
        [sharedDefaults setBool:NO forKey:@"communityIdShared"];
    }
    
    [standardDefaults synchronize];
    [sharedDefaults synchronize];
    
}

// called by init
- (BOOL)loadAccounts:(NSError**)error {
    [self migrateUserDefaults];
    
    // Make sure we start from a blank state
    [self clearAllAccountState];
    
    // Get the root directory, usually ~/Library/<appBundleId>/
    NSString *rootDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    NSFileManager *fm = [[NSFileManager alloc] init];
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
        if (error) {
            [self log:SFLogLevelDebug format:@"Unable to enumerate the content at %@: %@", rootDirectory, *error];
        }
        
        return NO;
    } else {
        for (NSString *rootContent in rootContents) {

            // Ignore content that don't represent an organization or an anonymous org
            if (![rootContent hasPrefix:kOrgPrefix] && ![rootContent isEqualToString:SFUserAccountManagerAnonymousUserAccountOrgId]) continue;
            NSString *rootPath = [rootDirectory stringByAppendingPathComponent:rootContent];

            // Fetch the content of the org directory
            NSArray *orgContents = [fm contentsOfDirectoryAtPath:rootPath error:error];
            if (nil == orgContents) {
                if (error) {
                    [self log:SFLogLevelDebug format:@"Unable to enumerate the content at %@: %@", rootPath, *error];
                }
                continue;
            }
            
            for (NSString *orgContent in orgContents) {

                // Ignore content that don't represent a user or an anonymous user
                if (![orgContent hasPrefix:kUserPrefix] && ![orgContent isEqualToString:SFUserAccountManagerAnonymousUserAccountUserId]) continue;
                NSString *orgPath = [rootPath stringByAppendingPathComponent:orgContent];
                
                // Now let's try to load the user account file in there
                NSString *userAccountPath = [orgPath stringByAppendingPathComponent:kUserAccountPlistFileName];
                if ([fm fileExistsAtPath:userAccountPath]) {
                    SFUserAccount *userAccount = [self loadUserAccountFromFile:userAccountPath];
                    if (userAccount) {
                        [self addAccount:userAccount];
                    } else {
                        // Error logging will already have occurred.  Make sure account file data is removed.
                        [fm removeItemAtPath:userAccountPath error:nil];
                    }
                } else {
                    [self log:SFLogLevelDebug format:@"There is no user account file in this user directory: %@", orgPath];
                }
            }
        }
    }
    
    // Convert any legacy active user data to the active user identity.
    [SFUserAccountManagerUpgrade updateToActiveUserIdentity:self];
    
    SFUserAccountIdentity *curUserIdentity = self.activeUserIdentity;
    
    // In case the most recently used account was removed, or the most recent account is the temporary account,
    // see if we can load another available account.
    if (nil == curUserIdentity || [curUserIdentity isEqual:self.temporaryUserIdentity]) {
        for (SFUserAccount *account in self.userAccountMap.allValues) {
            if (account.credentials.userId) {
                curUserIdentity = account.accountIdentity;
                break;
            }
        }
    }
    if (nil == curUserIdentity) {
        [self log:SFLogLevelInfo msg:@"Current active user identity is nil"];
    }
    
    self.previousCommunityId = self.activeCommunityId;

    if (curUserIdentity){
        SFUserAccount *account = [self userAccountForUserIdentity:curUserIdentity];
        account.communityId = self.previousCommunityId;
        self.currentUser = account;
    }else{
        self.currentUser = nil;
    }
    
    // update the client ID in case it's changed (via settings, etc)
    self.currentUser.credentials.clientId = self.oauthClientId;
    
    [self userChanged:SFUserAccountChangeCredentials];
    
    return YES;
}

- (SFUserAccount *)loadUserAccountFromFile:(NSString *)filePath {
    NSFileManager *manager = [[NSFileManager alloc] init];
    if (![manager fileExistsAtPath:filePath]) {
        [self log:SFLogLevelDebug format:@"No account data exists at '%@'", filePath];
        return nil;
    }

    // Try to load the user account assuming it is encrypted
    SFUserAccount *user = nil;
    if ([self loadUserAccountFromFile:filePath encrypted:YES account:&user error:nil]) {
        return user;
    } else {

        // Unable to retrieve the encrypted user, maybe it's still in the old plain text format?
        NSError *error = nil;
        if ([self loadUserAccountFromFile:filePath encrypted:NO account:&user error:&error]) {
        
            // Upgrade step.  The file is in the old plaintext format, and we'll
            // convert it to the encrypted format.
            BOOL encryptUserAccountSuccess = [self saveUserAccount:user toFile:filePath];
            if (!encryptUserAccountSuccess) {

                // Specific error messages will already be logged.  Make sure old user account file is removed.
                [manager removeItemAtPath:filePath error:nil];
                return nil;
            }
        } else {

            // Nope, unable to read it from the plain text format so let's remove that file
            [self log:SFLogLevelError format:@"Error deserializing the user account data: %@", [error description]];
            [manager removeItemAtPath:filePath error:nil];
        }
    }
    return user;
}

/** Loads a user account from a specified file
 @param filePath The file to load the user account from
 @param encrypted YES if the file contains the user account encrypted, NO otherwise
 @param account On output, contains the user account or nil if an error occurred
 @param error On output, contains the error if the method returned NO
 @return YES if the method succeeded, NO otherwise
 */
- (BOOL)loadUserAccountFromFile:(NSString *)filePath encrypted:(BOOL)encrypted account:(SFUserAccount**)account error:(NSError**)error {
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *reason = @"User account data could not be decrypted. Can't load account.";
    if (encrypted) {
        NSData *encryptedUserAccountData = [manager contentsAtPath:filePath];
        if (!encryptedUserAccountData) {
            NSString *reason = [NSString stringWithFormat:@"Could not retrieve user account data from '%@'", filePath];
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotRetrieveUserData
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
            }
            [self log:SFLogLevelDebug msg:reason];
            return NO;
        }
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
        NSData *decryptedArchiveData = [SFSDKCryptoUtils aes256DecryptData:encryptedUserAccountData withKey:encKey.key iv:encKey.initializationVector];
        if (!decryptedArchiveData) {
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotRetrieveUserData
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
            }
            [self log:SFLogLevelWarning msg:reason];
            return NO;
        }
        
        @try {
            SFUserAccount *decryptedAccount = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedArchiveData];
            
            // On iOS9, it won't throw an exception, but will return nil instead.
            if (decryptedAccount) {
                if (account) {
                    *account = decryptedAccount;
                }
                return YES;
            } else {
                if (error) {
                    *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                                 code:SFUserAccountManagerCannotReadDecryptedArchive
                                             userInfo:@{ NSLocalizedDescriptionKey : reason} ];
                }
                return NO;
            }
        }
        @catch (NSException *exception) {
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotReadDecryptedArchive
                                         userInfo:@{ NSLocalizedDescriptionKey : [exception reason]} ];
            }
            return NO;
        }
    } else {
        @try {
            SFUserAccount *plainTextUserAccount = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];

            // On iOS9, it won't throw an exception, but will return nil instead.
            if (plainTextUserAccount) {
                if (account) {
                    *account = plainTextUserAccount;
                }
                return YES;
            } else {
                if (error) {
                    *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                                 code:SFUserAccountManagerCannotReadPlainTextArchive
                                             userInfo:@{ NSLocalizedDescriptionKey : reason} ];
                }
                return NO;
            }
        }
        @catch (NSException *exception) {
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotReadPlainTextArchive
                                         userInfo:@{ NSLocalizedDescriptionKey : [exception reason]} ];
            }
            return NO;
        }
    }
}

- (BOOL)saveAccounts:(NSError**)error {
    __weak __typeof(self) weakSelf = self;
    __block BOOL accountsSaved = YES;
    dispatch_sync(_syncQueue, ^{
        NSDictionary *userAccountMap = [weakSelf.userAccountMap copy];
        
        for (SFUserAccountIdentity *userIdentity in userAccountMap) {
            // Don't save the temporary user id
            if ([userIdentity isEqual:weakSelf.temporaryUserIdentity]) {
                continue;
            }
            
            // Grab the user account...
            SFUserAccount *user = userAccountMap[userIdentity];
            
            // And it's persistent file path
            NSString *userAccountPath = [[weakSelf class] userAccountPlistFileForUser:user];
            
            // Make sure to remove any existing file
            NSFileManager *fm = [[NSFileManager alloc] init];
            if ([fm fileExistsAtPath:userAccountPath]) {
                if (![fm removeItemAtPath:userAccountPath error:error]) {
                    NSError*const err = error ? *error : nil;
                    [weakSelf log:SFLogLevelDebug format:@"failed to remove old user account %@: %@", userAccountPath, err];
                    accountsSaved = NO;
                    return;
                }
            }
            
            // And now save its content
            if (![weakSelf saveUserAccount:user toFile:userAccountPath]) {
                [weakSelf log:SFLogLevelDebug format:@"failed to archive user account: %@", userAccountPath];
                accountsSaved = NO;
                return ;
            }
        }
    });
    return accountsSaved;
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
    NSFileManager *manager = [[NSFileManager alloc] init];
    if ([manager fileExistsAtPath:filePath]) {
        NSError *removeAccountFileError = nil;
        if (![manager removeItemAtPath:filePath error:&removeAccountFileError]) {
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
    BOOL saveFileSuccess = [manager createFileAtPath:filePath contents:encryptedArchiveData attributes:@{ NSFileProtectionKey : [SFFileProtectionHelper fileProtectionForPath:filePath] }];
    if (!saveFileSuccess) {
        [self log:SFLogLevelDebug format:@"Could not create user account data file at path '%@'", filePath];
        return NO;
    }
    
    return YES;
}

- (SFUserAccount *)userAccountForUserIdentity:(SFUserAccountIdentity *)userIdentity {
    SFUserAccount *result = (self.userAccountMap)[userIdentity];
	return result;
}

- (NSArray *)accountsForOrgId:(NSString *)orgId {
    NSMutableArray *array = [NSMutableArray array];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountOrg = account.credentials.organizationId;
        if ([accountOrg isEqualToEntityId:orgId]) {
            [array addObject:account];
        }
    }
    return array;
}

- (NSArray *)accountsForInstanceURL:(NSURL *)instanceURL {
    NSMutableArray *responseArray = [NSMutableArray array];
    
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        if ([account.credentials.instanceUrl.host isEqualToString:instanceURL.host]) {
            [responseArray addObject:account];
        }
    }
    
    return responseArray;
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    if (nil != user) {
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSString *userDirectory = [[SFDirectoryManager sharedManager] directoryForUser:user
                                                                                 scope:SFUserAccountScopeUser
                                                                                  type:NSLibraryDirectory
                                                                            components:nil];
        if ([manager fileExistsAtPath:userDirectory]) {
            NSError *folderRemovalError = nil;
            BOOL removeUserFolderSucceeded = [manager removeItemAtPath:userDirectory error:&folderRemovalError];
            if (!removeUserFolderSucceeded) {
                [self log:SFLogLevelDebug
                   format:@"Error removing the user folder for '%@': %@", user.userName, [folderRemovalError localizedDescription]];
                if (error) {
                    *error = folderRemovalError;
                }
                return removeUserFolderSucceeded;
            }
        } else {
            [self log:SFLogLevelDebug format:@"User folder for user '%@' does not exist on the filesystem.  Continuing.", user.userName];
        }
        user.userDeleted = YES;
        [self.userAccountMap removeObjectForKey:user.accountIdentity];
    }
    return YES;
}

- (void)clearAllAccountState {
    [self.userAccountMap removeAllObjects];
}

- (void)addAccount:(SFUserAccount*)acct {
    SFUserAccountIdentity *idKey = acct.accountIdentity;
    (self.userAccountMap)[idKey] = acct;
}

- (SFUserAccountIdentity *)activeUserIdentity {
    NSData *resultData = nil;
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled) {
        NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
        resultData = [sharedDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        resultData = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsLastUserIdentityKey];
    }
    
    if (resultData == nil)
        return nil;
    
    SFUserAccountIdentity *result = nil;
    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:resultData];
        result = [unarchiver decodeObjectForKey:kUserDefaultsLastUserIdentityKey];
        [unarchiver finishDecoding];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelWarning msg:@"Could not parse active user identity from user defaults.  Setting to nil."];
        result = nil;
    }
    
    return result;
}

+ (void)setActiveUserIdentity:(SFUserAccountIdentity *)activeUserIdentity {
    NSUserDefaults *standardDefaults;
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled) {
        standardDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    } else {
        standardDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    if (activeUserIdentity == nil) {
        [standardDefaults removeObjectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        NSMutableData *auiData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:auiData];
        [archiver encodeObject:activeUserIdentity forKey:kUserDefaultsLastUserIdentityKey];
        [archiver finishEncoding];
        [standardDefaults setObject:auiData forKey:kUserDefaultsLastUserIdentityKey];
    }
    [standardDefaults synchronize];
}

- (void)setActiveUserIdentity:(SFUserAccountIdentity *)activeUserIdentity {
    [SFUserAccountManager setActiveUserIdentity:activeUserIdentity];
}

- (NSString *)activeCommunityId {
    NSUserDefaults *userDefaults;
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    } else {
        userDefaults =  [NSUserDefaults standardUserDefaults];
    }
    return [userDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

- (void)setActiveCommunityId:(NSString *)activeCommunityId {
    NSUserDefaults *userDefaults;
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    } else {
        userDefaults =  [NSUserDefaults standardUserDefaults];
    }
    
    if (activeCommunityId == nil) {
        [userDefaults removeObjectForKey:kUserDefaultsLastUserCommunityIdKey];
    } else {
        [userDefaults setObject:activeCommunityId forKey:kUserDefaultsLastUserCommunityIdKey];
    }
    [userDefaults synchronize];
}

- (void)setActiveUser:(SFUserAccount *)user {
    if (nil == user) {
        self.activeCommunityId = nil;
        self.activeUserIdentity = nil;
    } else {
        SFUserAccountIdentity *userIdentity = user.accountIdentity;
        self.activeUserIdentity = userIdentity;
        self.activeCommunityId = user.communityId;
    }
}

- (void)replaceOldUser:(SFUserAccountIdentity *)oldUserIdentity withUser:(SFUserAccount *)newUser {
    [self.userAccountMap removeObjectForKey:oldUserIdentity];
    SFUserAccountIdentity *newIdentity = newUser.accountIdentity;
    (self.userAccountMap)[newIdentity] = newUser;
    
    SFUserAccountIdentity *defUserIdentity = self.activeUserIdentity;
    if (!defUserIdentity || [defUserIdentity isEqual:oldUserIdentity]) {
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
- (SFUserAccountIdentity *)currentUserIdentity {
    return self.currentUser.accountIdentity;
}

- (NSString *)currentCommunityId {
    return self.currentUser.communityId;
}

- (void)applyCredentials:(SFOAuthCredentials*)credentials {
    SFUserAccountChange change = SFUserAccountChangeCredentials;
    SFUserAccount * newAccount = self.currentUser;
    // If the user is nil, create a new one with the specified credentials
    // otherwise update the current user credentials.
    if (nil == newAccount) {
        newAccount = [self createUserAccountWithCredentials:credentials];
        change |= SFUserAccountChangeNewUser;
    } else {
        if ([newAccount.accountIdentity matchesCredentials:credentials]) {
            newAccount.credentials = credentials;
        } else {
            [self log:SFLogLevelWarning format:@"Attempted to apply credentials to incorrect user"];
            return;
        }
    }
    
    // If the user has logged using a community-base URL, then let's create the community data
    // related to this community using the information we have from oauth.
    newAccount.communityId = credentials.communityId;
    if (newAccount.communityId) {
        SFCommunityData *communityData = [[SFCommunityData alloc] init];
        communityData.entityId = credentials.communityId;
        communityData.siteUrl = credentials.communityUrl;
        if (![newAccount communityWithId:credentials.communityId]) {
            if (newAccount.communities) {
                newAccount.communities = [self.currentUser.communities arrayByAddingObject:communityData];
            } else {
                newAccount.communities = @[communityData];
            }
        }
        [self setActiveCommunityId:newAccount.communityId];
    }
    
    // If our default user identity is currently the temporary user identity,
    // we need to update it with the latest known good user identity.
    if ([self.activeUserIdentity isEqual:self.temporaryUserIdentity]) {
        [self log:SFLogLevelDebug format:@"Replacing temp user identity with %@", newAccount];
        [self replaceOldUser:self.temporaryUserIdentity withUser:newAccount];
    }
    self.currentUser = newAccount;
    [self userChanged:change];
}

- (void)applyIdData:(SFIdentityData *)idData {
    self.currentUser.idData = idData;
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes {
    self.currentUser.idData.customAttributes = customAttributes;
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions {
    self.currentUser.idData.customPermissions = customPermissions;
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)setObjectForCurrentUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    [self.currentUser setCustomDataObject:object forKey:key];
}

#pragma mark -
#pragma mark Switching Users

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

#pragma mark -
#pragma mark User Change Notifications
- (BOOL)hasCommunityChanged {
    // If the last changed communityID exists and is inequal or
    // if there was no previous communityID and now there is
    if ((self.lastChangedCommunityId && ![self.lastChangedCommunityId isEqualToString:self.currentUser.communityId])
        || (!self.lastChangedCommunityId && self.currentUser.communityId)) {
        return YES;
    } else {
        return NO;
    }
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

    if ([self hasCommunityChanged])
    {
        self.lastChangedCommunityId = self.currentUser.communityId;
        change |= SFUserAccountChangeCommunityId;
        change &= ~SFUserAccountChangeUnknown; // clear the unknown bit
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidChangeCurrentUserNotification
														object:self
                                                      userInfo:@{ SFUserAccountManagerUserChangeKey : @(change) }];
}

@end
