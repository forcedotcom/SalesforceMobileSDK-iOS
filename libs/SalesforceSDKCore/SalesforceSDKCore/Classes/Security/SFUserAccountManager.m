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
#import "SFSDKAppFeatureMarkers.h"
#import "SFDefaultUserAccountPersister.h"

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
static NSString * const kSFAppFeatureMultiUser   = @"MU";

// Instance class
static Class AccountPersisterClass = nil;

static id<SFUserAccountPersister> accountPersister;

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

        [self reload];
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

- (SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials {
    // Sort the identities
    SFUserAccount *account = nil;
    [accountsLock lock];
    NSArray *keys = [self.userAccountMap allKeys];
    for (SFUserAccountIdentity *identity in keys) {
        if ([identity matchesCredentials:credentials]) {
            account = (self.userAccountMap)[identity];
            break;
        }
    }
    [accountsLock unlock];
    return account;
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

-(SFOAuthCredentials *)oauthCredentials {

    NSString *oauthClientId = [self oauthClientId];
    NSString *identifier = [self uniqueUserAccountIdentifier];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:oauthClientId encrypted:YES];
    creds.redirectUri = self.oauthCompletionUrl;
    creds.domain = self.loginHost;
    creds.accessToken = nil;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;
    return creds;
}

- (SFUserAccount*)createUserAccount {

    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier] clientId:self.oauthClientId];
    SFOAuthCredentials *creds = newAcct.credentials;
    creds.accessToken = nil;
    creds.domain = self.loginHost;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self saveAccountForUser:newAcct error:nil];

    return newAcct;
}

- (SFUserAccount*)createUserAccountWithCredentials:(SFOAuthCredentials*)credentials {

    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    newAcct.credentials = credentials;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self saveAccountForUser:newAcct error:nil];

    return newAcct;
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
    BOOL success = YES;
    [accountsLock lock];

    NSError *internalError = nil;
    NSDictionary<SFUserAccountIdentity *,SFUserAccount *> *accounts = [accountPersister fetchAllAccounts:&internalError];
    [_userAccountMap removeAllObjects];
    _userAccountMap = [NSMutableDictionary  dictionaryWithDictionary:accounts];

    if (internalError)
        success = false;

    if (error && internalError)
        *error = internalError;

    [accountsLock unlock];
    return success;
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
    _currentUser = nil;
    [self.userAccountMap removeAllObjects];
    [accountsLock unlock];
}

- (BOOL)saveAccountForUser:(SFUserAccount*)userAccount error:(NSError **) error{
    BOOL success = NO;
    [accountsLock lock];
    NSUInteger oldCount = self.userAccountMap.count;

    //remove from cache
    if ([self.userAccountMap objectForKey:userAccount.accountIdentity]!=nil)
        [self.userAccountMap removeObjectForKey:userAccount.accountIdentity];

    success = [accountPersister saveAccountForUser:userAccount error:error];
    if (success) {
        [self.userAccountMap setObject:userAccount forKey:userAccount.accountIdentity];
        if (self.userAccountMap.count>1 && oldCount<self.userAccountMap.count ) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMultiUser];
        }

    }
    [accountsLock unlock];
    return success;
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    BOOL success = NO;
    [accountsLock lock];
    success = [accountPersister deleteAccountForUser:user error:error];

    if (success) {
        user.userDeleted = YES;
        [self.userAccountMap removeObjectForKey:user.accountIdentity];
        if ([self.userAccountMap count] < 2) {
            [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureMultiUser];
        }
        if ([user.accountIdentity isEqual:self->_currentUser.accountIdentity]) {
            _currentUser = nil;
            [self setCurrentUserIdentity:nil];
        }
    }

    [accountsLock unlock];
    return success;
}

- (NSString *)currentCommunityId {
    NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
    return [userDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials {

    SFUserAccountChange change = SFUserAccountChangeCredentials;
    SFUserAccount *currentAccount = [self accountForCredentials:credentials];

    if (currentAccount) {
        currentAccount.credentials = credentials;
    }else {
        currentAccount = [self createUserAccountWithCredentials:credentials];
        change |= SFUserAccountChangeNewUser;
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
                currentAccount.communities = [currentAccount.communities arrayByAddingObject:communityData];
            } else {
                currentAccount.communities = @[communityData];
            }
        }
        [self setCurrentCommunityId:currentAccount.communityId];
    }

    [self saveAccountForUser:currentAccount error:nil];
    [self userChanged:change];
    return currentAccount;
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
                if(result)
                   _currentUser = [self userAccountForUserIdentity:result];
                else
                    [self log:SFLogLevelError msg:@"Located current user Identity in NSUserDefaults but was not found in list of accounts managed by SFUserAccountManager."];
            }
            @catch (NSException *exception) {
                [self log:SFLogLevelWarning msg:@"Could not parse current user identity from user defaults.  Setting to nil."];
            }
        }else {
            [self log:SFLogLevelWarning msg:@"Could not parse locate user identity object from user defaults.  Setting to nil."];
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
          [self log:SFLogLevelError format:@"Cannot set the currentUser as %@. Add the account to the SFAccountManager before making this call.",[user userName]];
        }
    }

    [accountsLock unlock];

    if (userChanged)
        [self userChanged:SFUserAccountChangeUnknown];
}

-(SFUserAccountIdentity *) currentUserIdentity {
    SFUserAccountIdentity *accountIdentity = nil;
    [accountsLock lock];
    if (_currentUser == nil) {
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        accountIdentity = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        accountIdentity = _currentUser.accountIdentity;
    }
    [accountsLock unlock];
    return accountIdentity;
}

- (void)setCurrentUserIdentity:(SFUserAccountIdentity*)userAccountIdentity {
    NSUserDefaults *standardDefaults = [NSUserDefaults msdkUserDefaults];
    [accountsLock lock];
    if (userAccountIdentity!=nil) {  //clear current user if userAccountIdentity is nil
        NSMutableData *auiData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:auiData];
        [archiver encodeObject:userAccountIdentity forKey:kUserDefaultsLastUserIdentityKey];
        [archiver finishEncoding];
        [standardDefaults setObject:auiData forKey:kUserDefaultsLastUserIdentityKey];
    } else {
        [standardDefaults removeObjectForKey:kUserDefaultsLastUserIdentityKey];
    }
    [accountsLock unlock];
    [standardDefaults synchronize];
}


- (void)applyIdData:(SFIdentityData *)idData {
   [self applyIdData:idData forUser:self.currentUser];
}

- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes {
   [self applyIdDataCustomAttributes:customAttributes forUser:self.currentUser];
}

- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions {
   [self applyIdDataCustomPermissions:customPermissions forUser:self.currentUser];
}

- (void)setObjectForCurrentUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key {
   [self setObjectForUserCustomData:object forKey:key andUser:self.currentUser];
}

- (void)applyIdData:(SFIdentityData *)idData forUser:(SFUserAccount *)user {
    [accountsLock lock];
    user.idData = idData;
    [self saveAccountForUser:user error:nil];
    [accountsLock unlock];
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes forUser:(SFUserAccount *)user {
    [accountsLock lock];
    user.idData.customAttributes = customAttributes;
    [self saveAccountForUser:user error:nil];
    [accountsLock unlock];
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions forUser:(SFUserAccount *)user {
    [accountsLock lock];
    user.idData.customPermissions = customPermissions;
    [self saveAccountForUser:user error:nil];
    [accountsLock unlock];
    [self userChanged:SFUserAccountChangeIdData];
}

- (void)setObjectForUserCustomData:(NSObject <NSCoding> *)object forKey:(NSString *)key andUser:(SFUserAccount *)user {
    [accountsLock lock];
    [user setCustomDataObject:object forKey:key];
    [self saveAccountForUser:user error:nil];
    [accountsLock unlock];
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

+ (void)setAccountPersisterClass:(nullable Class) persisterClass {
    AccountPersisterClass  = persisterClass;
}

- (id <SFUserAccountPersister>)accountPersister {
    return accountPersister;
}

- (void)reload {
    [accountsLock lock];

    if (AccountPersisterClass)
        accountPersister = [AccountPersisterClass new];
    else
        accountPersister = [SFDefaultUserAccountPersister new];

    if (_userAccountMap==nil)
        _userAccountMap= [NSMutableDictionary new];
    else
        [_userAccountMap removeAllObjects];

    NSString *bundleOAuthCompletionUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthRedirectUri];
    if (bundleOAuthCompletionUrl != nil) {
        self.oauthCompletionUrl = bundleOAuthCompletionUrl;
    }
    [self loadAccounts:nil];
    [accountsLock unlock];
}


@end
