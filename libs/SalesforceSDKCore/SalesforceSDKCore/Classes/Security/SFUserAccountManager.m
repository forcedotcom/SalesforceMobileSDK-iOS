/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFManagedPreferences.h"
#import "SFUserAccount+Internal.h"
#import "SFIdentityData+Internal.h"

#import "SFKeyStoreManager.h"
#import "SFSDKCryptoUtils.h"
#import "NSString+SFAdditions.h"
#import "SFSDKDatasharingHelper.h"
#import "SFFileProtectionHelper.h"
#import "NSUserDefaults+SFAdditions.h"
#import "SalesforceSDKManager.h"

// Notifications
NSString * const SFUserAccountManagerDidChangeCurrentUserNotification   = @"SFUserAccountManagerDidChangeCurrentUserNotification";
NSString * const SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

// Persistence Keys
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
static const NSUInteger SFUserAccountManagerCannotRetrieveUserData = 10003;

static const char * kSyncQueue = "com.salesforce.mobilesdk.sfuseraccountmanager.syncqueue";

static NSString * const kSFAppFeatureMultiUser   = @"MU";

@implementation SFUserAccountManager

@synthesize currentUser = _currentUser;

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFUserAccountManager *userAccountManager = nil;
    dispatch_once(&pred, ^{
		userAccountManager = [[self alloc] init];
	});
    dispatch_once(&pred, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidFinishUserInitNotification object:nil];
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
        [self migrateUserDefaults];
        accountsLock = [NSRecursiveLock new];
        _userAccountMap = [NSMutableDictionary new];
        [self loadAccounts:nil];
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
        [[NSUserDefaults msdkUserDefaults] removeObjectForKey:kSFUserAccountOAuthLoginHost];
    } else {
        [[NSUserDefaults msdkUserDefaults] setObject:host forKey:kSFUserAccountOAuthLoginHost];
    }

    [[NSUserDefaults msdkUserDefaults] synchronize];

    // Only post the login host change notification if the host actually changed.
    if ((oldLoginHost || host) && ![host isEqualToString:oldLoginHost]) {
        NSDictionary *userInfoDict = @{ kSFLoginHostChangedNotificationOriginalHostKey: (oldLoginHost ?: [NSNull null]),
                                        kSFLoginHostChangedNotificationUpdatedHostKey: (host ?: [NSNull null]) };
        NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
        [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
    }
}

- (NSString *)loginHost {
    NSUserDefaults *defaults = [NSUserDefaults msdkUserDefaults];

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
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSArray *scopesArray = [defs objectForKey:kOAuthScopesKey] ?: [NSArray array];
    return [NSSet setWithArray:scopesArray];
}

- (void)setScopes:(NSSet *)newScopes
{
    NSArray *scopesArray = [newScopes allObjects];
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:scopesArray forKey:kOAuthScopesKey];
    [defs synchronize];
}

- (NSString *)oauthCompletionUrl
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSString *redirectUri = [defs objectForKey:kOAuthRedirectUriKey];
    return redirectUri;
}

- (void)setOauthCompletionUrl:(NSString *)newRedirectUri
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:newRedirectUri forKey:kOAuthRedirectUriKey];
    [defs synchronize];
}

- (NSString *)oauthClientId
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSString *clientId = [defs objectForKey:kOAuthClientIdKey];
    return clientId;
}

- (void)setOauthClientId:(NSString *)newClientId
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
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

#pragma mark - Anonymous User
- (BOOL)isCurrentUserAnonymous {
    return self.currentUser == nil;
}

#pragma mark Account management
- (NSArray *)allUserAccounts
{
    NSMutableArray *accounts = nil;
    [accountsLock lock];
    // Remove the temporary user id from the array
    if ([self.userAccountMap count] > 0) {
        accounts = [NSMutableArray array];
        for (SFUserAccountIdentity *key in [self.userAccountMap allKeys]) {
            [accounts addObject:(self.userAccountMap)[key]];
        }
    }
    [accountsLock unlock];
    return accounts;
}

- (NSArray *)allUserIdentities {
    // Sort the identities
    NSMutableArray *filteredKeys = nil;
    [accountsLock lock];
    NSArray *keys = [[self.userAccountMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
    filteredKeys = [NSMutableArray array];
    for (SFUserAccountIdentity *identity in keys) {
        [filteredKeys addObject:identity];
    }
    [accountsLock unlock];

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

-(SFOAuthCredentials *)currentCredentials {
    SFOAuthCredentials *creds = nil;

    if (self.currentUserIdentity != nil) {
         SFUserAccount *account = [self userAccountForUserIdentity:self.currentUserIdentity];
         creds = account.credentials;
    }else {
        SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
        creds = newAcct.credentials;
        creds.accessToken = nil;
        creds.domain = self.loginHost;
        creds.redirectUri = self.oauthCompletionUrl;
        creds.clientId = self.oauthClientId;
    }
    creds.domain = self.loginHost;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;
    return creds;
}

- (SFUserAccount*)createUserAccount {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    SFOAuthCredentials *creds = newAcct.credentials;
    creds.accessToken = nil;
    creds.domain = self.loginHost;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self updateAccount:newAcct];

    return newAcct;
}

- (SFUserAccount*)createUserAccountWithCredentials:(SFOAuthCredentials*)credentials {

    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    newAcct.credentials = credentials;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self updateAccount:newAcct];

    return newAcct;
}

+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user {
    NSString *directory = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:directory error:nil];
    return [directory stringByAppendingPathComponent:kUserAccountPlistFileName];
}

+ (NSString*)userAccountPlistFileForUserId:(SFUserAccountIdentity*)userAccountIdentity {
    NSString *directory = [[SFDirectoryManager sharedManager] directoryForOrg:userAccountIdentity.orgId user:userAccountIdentity.userId community:nil type:NSLibraryDirectory components:nil];
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

- (BOOL)loadAccounts:(NSError **) error {
    BOOL success = NO;
    [accountsLock lock];
    // Get the root directory, usually ~/Library/<appBundleId>/
    NSString *rootDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    NSFileManager *fm = [[NSFileManager alloc] init];
    if (![fm fileExistsAtPath:rootDirectory]) {
        // There is no root directory, that's fine, probably a fresh app install,
        // new user will be created later on.
        success = YES;
    } else {

        // Now iterate over the org and then user directories to load
        // each individual user account file.
        // ~/Library/<appBundleId>/<orgId>/<userId>/UserAccount.plist
        NSArray *rootContents = [fm contentsOfDirectoryAtPath:rootDirectory error:error];
        if (nil == rootContents) {
            if (error) {
                [self log:SFLogLevelDebug format:@"Unable to enumerate the content at %@: %@", rootDirectory, *error];
            }
            success = NO;
        } else {
            for (NSString *rootContent in rootContents) {

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
                    NSString *orgPath = [rootPath stringByAppendingPathComponent:orgContent];

                    // Now let's try to load the user account file in there
                    NSString *userAccountPath = [orgPath stringByAppendingPathComponent:kUserAccountPlistFileName];
                    if ([fm fileExistsAtPath:userAccountPath]) {
                        SFUserAccount *userAccount =  nil;
                        [self loadUserAccountFromFile:userAccountPath account:&userAccount error:nil];
                        if (userAccount) {
                            self.userAccountMap[userAccount.accountIdentity] = userAccount;
                        } else {
                            // Error logging will already have occurred.  Make sure account file data is removed.
                            [fm removeItemAtPath:userAccountPath error:nil];
                        }
                    } else {
                        [self log:SFLogLevelDebug format:@"There is no user account file in this user directory: %@", orgPath];
                    }
                }
                success = YES;
            }
        }
    }
    [accountsLock unlock];
    return success;
}
/** Loads a user account from a specified file
 @param filePath The file to load the user account from
 @param account On output, contains the user account or nil if an error occurred
 @param error On output, contains the error if the method returned NO
 @return YES if the method succeeded, NO otherwise
 */

- (BOOL)loadUserAccountFromFile:(NSString *)filePath account:(SFUserAccount**)account error:(NSError**)error {

    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *reason = @"User account data could not be decrypted. Can't load account.";
    NSData *encryptedUserAccountData = [manager contentsAtPath:filePath];
    if (!encryptedUserAccountData) {
        reason = [NSString stringWithFormat:@"Could not retrieve user account data from '%@'", filePath];
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

    SFUserAccount *result = nil;
    [accountsLock lock];
    result = (self.userAccountMap)[userIdentity];
    [accountsLock unlock];
    return result;
}

- (NSArray *)accountsForOrgId:(NSString *)orgId {
     NSMutableArray *responseArray = [NSMutableArray array];
    [accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountOrg = account.credentials.organizationId;
        if ([accountOrg isEqualToEntityId:orgId]) {
            [responseArray addObject:account];
        }
    }
    [accountsLock unlock];
    return responseArray;
}

- (NSArray *)accountsForInstanceURL:(NSURL *)instanceURL {

    NSMutableArray *responseArray = [NSMutableArray array];
    [accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        if ([account.credentials.instanceUrl.host isEqualToString:instanceURL.host]) {
            [responseArray addObject:account];
        }
    }
    [accountsLock unlock];
    return responseArray;
}
- (void)clearAllAccountState {
    [accountsLock lock];
    [self.userAccountMap removeAllObjects];
    [accountsLock unlock];
}

- (void)updateAccount:(SFUserAccount*)acct {
    [accountsLock lock];
    NSUInteger oldCount = self.userAccountMap.count;
    NSString *userAccountPlist = [SFUserAccountManager userAccountPlistFileForUser:acct];
    if ([self.userAccountMap objectForKey:acct.accountIdentity]!=nil)
        [self.userAccountMap removeObjectForKey:acct.accountIdentity];

    BOOL success = [self saveUserAccount:acct toFile:userAccountPlist];
    if (success) {
        [self.userAccountMap setObject:acct forKey:acct.accountIdentity];
        if (self.userAccountMap.count>1 && oldCount<self.userAccountMap.count ) {
            [[SalesforceSDKManager sharedManager] registerAppFeature:kSFAppFeatureMultiUser];
        }

    }
    [accountsLock unlock];
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    BOOL success = NO;
    [accountsLock lock];
    if (nil != user) {
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSString *userDirectory = [[SFDirectoryManager sharedManager] directoryForUser:user
                                                                                 scope:SFUserAccountScopeUser
                                                                                  type:NSLibraryDirectory
                                                                            components:nil];
        if ([manager fileExistsAtPath:userDirectory]) {
            NSError *folderRemovalError = nil;
            success= [manager removeItemAtPath:userDirectory error:&folderRemovalError];
            if (!success) {
                [self log:SFLogLevelDebug
                         format:@"Error removing the user folder for '%@': %@", user.userName, [folderRemovalError localizedDescription]];
                if (folderRemovalError && error) {
                    *error = folderRemovalError;
                }
            }
        } else {
            NSString *reason = [NSString stringWithFormat:@"User folder for user '%@' does not exist on the filesystem", user.userName];
            NSError *ferror = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                                  code:SFUserAccountManagerCannotReadDecryptedArchive
                                              userInfo:@{NSLocalizedDescriptionKey: reason}];
            [self log:SFLogLevelDebug format:@"User folder for user '%@' does not exist on the filesystem.", user.userName];
            if(error)
                *error = ferror;
            success = NO;
        }
        if (success) {
            user.userDeleted = YES;
            [self.userAccountMap removeObjectForKey:user.accountIdentity];
            success = YES;
            if ([self.userAccountMap count] < 2) {
                [[SalesforceSDKManager sharedManager] unregisterAppFeature:kSFAppFeatureMultiUser];
            }
            if([user.accountIdentity isEqual:self->_currentUser.accountIdentity]) {
                _currentUser = nil;
                [self setCurrentUserIdentity:nil];
            }
        }
    }
    [accountsLock unlock];
    return success;
}

- (NSString *)currentCommunityId {
    NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
    return [userDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

- (void)applyCredentials:(SFOAuthCredentials*)credentials {
    SFUserAccountChange change = SFUserAccountChangeCredentials;
    SFUserAccount * currentAccount = self.currentUser;
    // If the user is nil, create a new one with the specified credentials
    // otherwise update the current user credentials.
    if (nil == currentAccount) {
        currentAccount = [self createUserAccountWithCredentials:credentials];
        [self setCurrentUser:currentAccount];
        change |= SFUserAccountChangeNewUser;
    } else if ([currentAccount.accountIdentity matchesCredentials:credentials]) {
        currentAccount.credentials = credentials;
        [self setCurrentUser:currentAccount];
    } else {
        //has credentials changed for another account that we know off?
        NSArray *identities = [self allUserIdentities];
        for(SFUserAccountIdentity *id in identities) {
            if([id matchesCredentials:credentials]) {
                currentAccount = [self userAccountForUserIdentity:id];
                currentAccount.credentials = credentials;
                [self setCurrentUser:currentAccount];
                change |= SFUserAccountChangeNewUser;
                break;
            }
        }

    }

    // If the user has logged using a community-base URL, then let's create the community data
    // related to this community using the information we have from oauth.
    currentAccount.communityId = credentials.communityId;
    if (currentAccount.communityId) {
        SFCommunityData *communityData = [[SFCommunityData alloc] init];
        communityData.entityId = credentials.communityId;
        communityData.siteUrl = credentials.communityUrl;
        if (![currentAccount communityWithId:credentials.communityId]) {
            if (currentAccount.communities) {
                currentAccount.communities = [self.currentUser.communities arrayByAddingObject:communityData];
            } else {
                currentAccount.communities = @[communityData];
            }
        }
        [self setCurrentCommunityId:currentAccount.communityId];
    }

    [self userChanged:change];
}

- (SFUserAccount*) currentUser {

    if (_currentUser == nil) {
        [accountsLock lock];
        NSData *resultData = nil;
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        resultData = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (resultData != nil) {
             SFUserAccountIdentity *result = nil;
            @try {
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:resultData];
                result = [unarchiver decodeObjectForKey:kUserDefaultsLastUserIdentityKey];
                [unarchiver finishDecoding];
                if(!result)
                   _currentUser = [self userAccountForUserIdentity:result];
            }
            @catch (NSException *exception) {
                [self log:SFLogLevelWarning msg:@"Could not parse current user identity from user defaults.  Setting to nil."];
            }
        }else {
            [self log:SFLogLevelWarning msg:@"Located current user identity from user defaults but was not found in the list of managed accounts"];
        }
        [accountsLock unlock];

    }
    return _currentUser;
}

- (void)setCurrentUser:(SFUserAccount*)user {

    BOOL userChanged = NO;
    [accountsLock lock];
    if (nil==user) { //clear current user if  nil
        _currentUser = nil;
        [self setCurrentUserIdentity:nil];
        userChanged = YES;
    } else {
        //check if this is valid managed user
        SFUserAccount *userAccount = [self userAccountForUserIdentity:user.accountIdentity];
        if (nil!=userAccount) {
          [self willChangeValueForKey:@"currentUser"];
               _currentUser = user;
              [self setCurrentUserIdentity:user.accountIdentity];
          userChanged = YES;
          [self didChangeValueForKey:@"currentUser"];
        } else {
          [self log:SFLogLevelError format:@"Cannot set currentUser for a user %@, that does not exist. An account should be added to Account manager prior to making this call.",[user userName]];
          userChanged = NO;
        }
      }
    [accountsLock unlock];
     if ( userChanged )
        [self userChanged:SFUserAccountChangeUnknown];
}

-(SFUserAccountIdentity *) currentUserIdentity {
    SFUserAccountIdentity *accountIdentity = nil;
    if (_currentUser == nil) {
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        accountIdentity = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        accountIdentity = _currentUser.accountIdentity;
    }
    return accountIdentity;
}

- (void)setCurrentUserIdentity:(SFUserAccountIdentity*)userAccountIdentity {
    NSUserDefaults *standardDefaults = [NSUserDefaults msdkUserDefaults];
    if (userAccountIdentity!=nil) {  //clear current user if userAccountIdentity is nil
        NSMutableData *auiData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:auiData];
        [archiver encodeObject:userAccountIdentity forKey:kUserDefaultsLastUserIdentityKey];
        [archiver finishEncoding];
        [standardDefaults setObject:auiData forKey:kUserDefaultsLastUserIdentityKey];
    } else {
        [standardDefaults removeObjectForKey:kUserDefaultsLastUserIdentityKey];
    }

    [standardDefaults synchronize];

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

    SFUserAccount *prevUser = self.currentUser;
    [self setCurrentUser:newCurrentUser];

    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:didSwitchFromUser:toUser:)]) {
            [delegate userAccountManager:self didSwitchFromUser:prevUser toUser:newCurrentUser];
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
