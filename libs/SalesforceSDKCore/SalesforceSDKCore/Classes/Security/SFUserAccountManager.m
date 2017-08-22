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
#import "SFFileProtectionHelper.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFDefaultUserAccountPersister.h"
#import "SFOAuthCredentials+Internal.h"
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>
#import <SalesforceAnalytics/SFSDKDatasharingHelper.h>
#import "SFSDKOAuthClient.h"
#import "SFPushNotificationManager.h"

// Notifications
NSString * const SFUserAccountManagerDidChangeUserNotification   = @"SFUserAccountManagerDidChangeUserNotification";
NSString * const SFUserAccountManagerDidChangeUserDataNotification   = @"SFUserAccountManagerDidChangeUserDataNotification";
NSString * const SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

NSString * const SFUserAccountManagerWillLogoutNotification = @"SFUserAccountManagerWillLogoutNotification";
NSString * const SFUserAccountManagerLogoutNotification = @"SFUserAccountManagerLogoutNotification";
NSString * const SFUserAccountManagerLoggedInNotification = @"SFUserAccountManagerLoggedInNotification";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";
NSString * const SFUserAccountManagerUserChangeUserKey      = @"user";

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

// Persistence Keys
static NSString * const kUserDefaultsLastUserIdentityKey = @"LastUserIdentity";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";
static NSString * const kSFAppFeatureMultiUser   = @"MU";
static NSString * const kSFUserAccountOAuthRedirectUri = @"SFDCOAuthRedirectUri";
static NSString * const kDeprecatedLoginHostPrefKey = @"login_host_pref";

NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort
NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";


@implementation SFUserAccountManager

@synthesize currentUser = _currentUser;
@synthesize userAccountMap = _userAccountMap;
@synthesize accountPersister = _accountPersister;
@synthesize authClient = _authClient;

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFUserAccountManager *userAccountManager = nil;
    dispatch_once(&pred, ^{
		userAccountManager = [[self alloc] init];
	});
    static dispatch_once_t pred2;
    dispatch_once(&pred2, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidFinishUserInitNotification object:nil];
    });
    return userAccountManager;
}

- (id)init {
	self = [super init];
	if (self) {
        self.delegates = [NSHashTable weakObjectsHashTable];
        _accountPersister = [SFDefaultUserAccountPersister new];
        [self migrateUserDefaults];
        _accountsLock = [NSRecursiveLock new];
     }
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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

#pragma mark - persistent properties
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

#pragma  mark - login & logout

- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse {
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse %@",[appUrlResponse description]];
    self.authClient.advancedAuthConfiguration = self.advancedAuthConfiguration;
    self.authClient.delegate = self;
    self.authClient.safariViewDelegate = self;
    return [self.authClient handleURLAuthenticationResponse:appUrlResponse];
}

- (BOOL)authenticateWithCompletion:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock
                           failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    self.authClient.advancedAuthConfiguration = self.advancedAuthConfiguration;
    self.authClient.delegate = self;
    self.authClient.webViewDelegate = self;
    self.authClient.safariViewDelegate = self;
    return [self.authClient fetchCredentials:completionBlock failure:failureBlock];
}

- (BOOL)authenticateWithCredentials:(SFOAuthCredentials *)credentials
                         completion:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock
                            failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    self.authClient.advancedAuthConfiguration = self.advancedAuthConfiguration;
    self.authClient.delegate = self;
    self.authClient.webViewDelegate = self;
    self.authClient.safariViewDelegate = self;
    return [self.authClient refreshCredentials:credentials success:completionBlock failure:failureBlock];
}

- (BOOL)loginWithCompletion:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    return [self authenticateWithCompletion:completionBlock failure:failureBlock];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials completion:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    return [self authenticateWithCredentials:credentials completion:completionBlock failure:failureBlock];
}

- (BOOL)loginWithJwtToken:(NSString *)jwtToken completion:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    NSAssert(jwtToken.length > 0, @"JWT token value required.");
    SFOAuthCredentials *credentials = [self.authClient retrieveClientCredentials];
    credentials.jwt = jwtToken;
    return [self authenticateWithCredentials:credentials
                                  completion:completionBlock
                                     failure:failureBlock];
}

- (void)logout {
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logoutUser:(SFUserAccount *)user {
    // No-op, if the user is not valid.
    if (user == nil) {
        [SFSDKCoreLogger i:[self class] format:@"logoutUser: user is nil.  No action taken."];
        return;
    }
    
    BOOL loggingOutTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggingOut];
    if (!loggingOutTransitionSucceeded) {
        // SFUserAccount already logs the transition failure.
        return;
    }
    BOOL isCurrentUser = [user isEqual:self.currentUser];
    [SFSDKCoreLogger i:[self class] format:@"Logging out user '%@'.", user.userName];
    NSDictionary *userInfo = @{ @"account": user };
    [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerWillLogoutNotification
                                                        object:self
                                                      userInfo:userInfo];
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:willLogout:)]) {
            [delegate userAccountManager:weakSelf willLogout:user];
        }
    }];
    
    SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
    [[SFSDKOAuthClient sharedInstance] revokeCredentials:user.credentials];
    
    if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications:user];
    }
    [userAccountManager deleteAccountForUser:user error:nil];
    
    if (isCurrentUser) {
        userAccountManager.currentUser = nil;
    }
    userInfo = @{ @"account": user };
    NSNotification *logoutNotification = [NSNotification notificationWithName:SFUserAccountManagerLogoutNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:didLogout:)]) {
            [delegate userAccountManager:self didLogout:user];
        }
    }];
    // NB: There's no real action that can be taken if this login state transition fails.  At any rate,
    // it's an unlikely scenario.
    [user transitionToLoginState:SFUserAccountLoginStateNotLoggedIn];
}

- (void)logoutAllUsers {
    // Log out all other users, then the current user.
    NSArray *userAccounts = [[SFUserAccountManager sharedInstance] allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != [SFUserAccountManager sharedInstance].currentUser) {
            [self logoutUser:account];
        }
    }
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (id<SFSDKOAuthClient>)authClient {
     return _authClient == nil?[SFSDKOAuthClient sharedInstance]:_authClient;
}

- (void)setOAuthClient:(SFSDKOAuthClient *)authClient {
    if (_authClient != authClient) {
        _authClient = authClient;
    }
}

#pragma mark - SFSDKOAuthClientDelegate
- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context {
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:willLogin:)]) {
            [delegate userAccountManager:self willLogin:context.coordinator.credentials];
        }
    }];
}

- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error context:(SFSDKOAuthClientContext *)context {
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
            [delegate userAccountManager:self error:error info:context.authInfo];
        }
    }];
}

- (BOOL)authClientIsNetworkAvailable:(SFSDKOAuthClient *)client {
    __block BOOL result = YES;
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerIsNetworkAvailable:)]) {
            result = [delegate userAccountManagerIsNetworkAvailable:self];
        }
    }];
    return result;
}

- (void)authClientDidFinish:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context {
    
    // fire notification for user logged in
    SFUserAccount *currentAccount = [self accountForCredentials:context.coordinator.credentials];
    NSDictionary *userInfo = @{ @"account": currentAccount };
    
    NSNotification *loggedInNotification = [NSNotification notificationWithName:SFUserAccountManagerLoggedInNotification object:self  userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
    
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:didLogin:)]) {
            [delegate userAccountManager:self didLogin:currentAccount];
        }
    }];
    
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

-(NSMutableDictionary *)userAccountMap {
    if(!_userAccountMap || _userAccountMap.count < 1) {
        [self reload];
    }
    return _userAccountMap;
}

- (void)setAccountPersister:(id<SFUserAccountPersister>) persister {
    if(persister != _accountPersister) {
        [_accountsLock lock];
        _accountPersister = persister;
        [self reload];
        [_accountsLock unlock];
    }
}

#pragma mark Account management
- (NSArray *)allUserAccounts
{
    return [self.userAccountMap allValues];
}

- (NSArray *)allUserIdentities {
    // Sort the identities
    NSArray *keys = nil;
    [_accountsLock lock];
     keys = [[self.userAccountMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
    [_accountsLock unlock];
    return keys;
}

- (SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials {
    // Sort the identities
    SFUserAccount *account = nil;
    [_accountsLock lock];
    NSArray *keys = [self.userAccountMap allKeys];
    for (SFUserAccountIdentity *identity in keys) {
        if ([identity matchesCredentials:credentials]) {
            account = (self.userAccountMap)[identity];
            break;
        }
    }
    [_accountsLock unlock];
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
        [SFSDKCoreLogger d:[self class] format:@"Error querying for all existing accounts in the keychain: %ld", result];
        return nil;
    }
}

/** Returns a unique user account identifier
 */
- (NSString*)uniqueUserAccountIdentifier:(NSString *)clientId {
    NSSet *existingAccountNames = [self allExistingAccountNames];

    // Make sure to build a unique identifier
    NSString *identifier = nil;
    while (nil == identifier || [existingAccountNames containsObject:identifier]) {
        u_int32_t randomNumber = arc4random();
        identifier = [NSString stringWithFormat:@"%@-%u", clientId, randomNumber];
    }

    return identifier;
}

- (SFUserAccount*)createUserAccount:(SFOAuthCredentials *)credentials {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithCredentials:credentials];
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
    [_accountsLock lock];

    NSError *internalError = nil;
    NSDictionary<SFUserAccountIdentity *,SFUserAccount *> *accounts = [self.accountPersister fetchAllAccounts:&internalError];
    [_userAccountMap removeAllObjects];
    _userAccountMap = [NSMutableDictionary  dictionaryWithDictionary:accounts];

    if (internalError)
        success = NO;

    if (error && internalError)
        *error = internalError;

    [_accountsLock unlock];
    return success;
}

- (SFUserAccount *)userAccountForUserIdentity:(SFUserAccountIdentity *)userIdentity {

    SFUserAccount *result = nil;
    [_accountsLock lock];
    result = (self.userAccountMap)[userIdentity];
    [_accountsLock unlock];
    return result;
}

- (NSArray *)accountsForOrgId:(NSString *)orgId {
     NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountOrg = account.credentials.organizationId;
        if ([accountOrg isEqualToEntityId:orgId]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}

- (NSArray *)accountsForInstanceURL:(NSURL *)instanceURL {

    NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        if ([account.credentials.instanceUrl.host isEqualToString:instanceURL.host]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}
- (void)clearAllAccountState {
    [_accountsLock lock];
    _currentUser = nil;
    [self.userAccountMap removeAllObjects];
    [_accountsLock unlock];
}

- (BOOL)saveAccountForUser:(SFUserAccount*)userAccount error:(NSError **) error{
    BOOL success = NO;
    [_accountsLock lock];
    NSUInteger oldCount = self.userAccountMap.count;

    //remove from cache
    if ([self.userAccountMap objectForKey:userAccount.accountIdentity]!=nil)
        [self.userAccountMap removeObjectForKey:userAccount.accountIdentity];

    success = [self.accountPersister saveAccountForUser:userAccount error:error];
    if (success) {
        [self.userAccountMap setObject:userAccount forKey:userAccount.accountIdentity];
        if (self.userAccountMap.count>1 && oldCount<self.userAccountMap.count ) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMultiUser];
        }

    }
    [_accountsLock unlock];
    return success;
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    BOOL success = NO;
    [_accountsLock lock];
    success = [self.accountPersister deleteAccountForUser:user error:error];

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

    [_accountsLock unlock];
    return success;
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials {
    return [self applyCredentials:credentials withIdData:nil];
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(SFIdentityData *) identityData {
    return [self applyCredentials:credentials withIdData:identityData andNotification:YES];
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(SFIdentityData *) identityData andNotification:(BOOL) shouldSendNotification{
    
    SFUserAccount *currentAccount = [self accountForCredentials:credentials];
    SFUserAccountDataChange accountDataChange = SFUserAccountDataChangeUnknown;
    SFUserAccountChange userAccountChange = SFUserAccountChangeUnknown;

    if (currentAccount) {

        if (identityData)
            accountDataChange |= SFUserAccountDataChangeIdData;

        if ([credentials hasPropertyValueChangedForKey:@"accessToken"])
            accountDataChange |= SFUserAccountDataChangeAccessToken;

        if ([credentials hasPropertyValueChangedForKey:@"instanceUrl"])
            accountDataChange |= SFUserAccountDataChangeInstanceURL;

        if ([credentials hasPropertyValueChangedForKey:@"communityId"])
            accountDataChange |= SFUserAccountDataChangeCommunityId;

        if (accountDataChange!=SFUserAccountDataChangeUnknown)
            accountDataChange &= ~SFUserAccountDataChangeUnknown;

        currentAccount.credentials = credentials;
    }else {
        currentAccount = [[SFUserAccount alloc] initWithCredentials:credentials];

        //add the account to our list of possible accounts, but
        //don't set this as the current user account until somebody
        //asks us to login with this account.
        userAccountChange = SFUserAccountChangeNewUser;
    }
    [credentials resetCredentialsChangeSet];

    currentAccount.idData = identityData;
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
    }

    [self saveAccountForUser:currentAccount error:nil];

    if(shouldSendNotification) {
        if (accountDataChange != SFUserAccountChangeUnknown) {
            [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:currentAccount andChange:accountDataChange];
        } else if (userAccountChange!=SFUserAccountDataChangeUnknown) {
            [self notifyUserChange:SFUserAccountManagerDidChangeUserNotification withUser:currentAccount andChange:userAccountChange];
        }
    }
    return currentAccount;
}

- (SFUserAccount*) currentUser {
    if (!_currentUser) {
        [_accountsLock lock];
        NSData *resultData = nil;
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        resultData = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (resultData) {
            SFUserAccountIdentity *result = nil;
            @try {
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:resultData];
                result = [unarchiver decodeObjectForKey:kUserDefaultsLastUserIdentityKey];
                [unarchiver finishDecoding];
                if (result) {
                    _currentUser = [self userAccountForUserIdentity:result];
                } else {
                    [SFSDKCoreLogger e:[self class] format:@"Located current user Identity in NSUserDefaults but was not found in list of accounts managed by SFUserAccountManager."];
                }
            } @catch (NSException *exception) {
                [SFSDKCoreLogger d:[self class] format:@"Could not parse current user identity from user defaults. Setting to nil."];
            }
        }
        [_accountsLock unlock];
    }
    return _currentUser;
}

- (void)setCurrentUser:(SFUserAccount*)user {

    BOOL userChanged = NO;
    if (user != _currentUser) {
        [_accountsLock lock];
        if (!user) {
            //clear current user if  nil
            [self willChangeValueForKey:@"currentUser"];
            _currentUser = nil;
            [self setCurrentUserIdentity:nil];
            [self didChangeValueForKey:@"currentUser"];
            userChanged = YES;
        } else {
            //check if this is valid managed user
            SFUserAccount *userAccount = [self userAccountForUserIdentity:user.accountIdentity];
            if (userAccount) {
                [self willChangeValueForKey:@"currentUser"];
                _currentUser = user;
                [self setCurrentUserIdentity:user.accountIdentity];
                [self didChangeValueForKey:@"currentUser"];
                userChanged = YES;
            } else {
                [SFSDKCoreLogger e:[self class] format:@"Cannot set the currentUser as %@. Add the account to the SFAccountManager before making this call.", [user userName]];
            }
        }
        [_accountsLock unlock];
    }
    if (userChanged)
        [self notifyUserChange:SFUserAccountManagerDidChangeUserNotification withUser:_currentUser andChange:SFUserAccountChangeCurrentUser];
}

-(SFUserAccountIdentity *) currentUserIdentity {
    SFUserAccountIdentity *accountIdentity = nil;
    [_accountsLock lock];
    if (!_currentUser) {
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        accountIdentity = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        accountIdentity = _currentUser.accountIdentity;
    }
    [_accountsLock unlock];
    return accountIdentity;
}

- (void)setCurrentUserIdentity:(SFUserAccountIdentity*)userAccountIdentity {
    NSUserDefaults *standardDefaults = [NSUserDefaults msdkUserDefaults];
    [_accountsLock lock];
    if (userAccountIdentity) {
        NSMutableData *auiData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:auiData];
        [archiver encodeObject:userAccountIdentity forKey:kUserDefaultsLastUserIdentityKey];
        [archiver finishEncoding];
        [standardDefaults setObject:auiData forKey:kUserDefaultsLastUserIdentityKey];
    } else {  //clear current user if userAccountIdentity is nil
        [standardDefaults removeObjectForKey:kUserDefaultsLastUserIdentityKey];
    }
    [_accountsLock unlock];
    [standardDefaults synchronize];
}

- (void)applyIdData:(SFIdentityData *)idData forUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        user.idData = idData;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
    }
}

- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes forUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        user.idData.customAttributes = customAttributes;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
    }
}

- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions forUser:(SFUserAccount *)user {
     if (user) {
        [_accountsLock lock];
        user.idData.customPermissions = customPermissions;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
     }
}

- (void)setObjectForUserCustomData:(NSObject <NSCoding> *)object forKey:(NSString *)key andUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        [user setCustomDataObject:object forKey:key];
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
    }
}

- (NSString *)currentCommunityId {
    NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
    return [userDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

#pragma mark -
#pragma mark Switching Users

- (void)switchToNewUser {
    [self switchToUser:nil];
}

- (void)switchToUser:(SFUserAccount *)newCurrentUser {
    if ([self.currentUser.accountIdentity isEqual:newCurrentUser.accountIdentity]) {
        [SFSDKCoreLogger w:[self class] format:@"%@ new user identity is the same as the current user (%@/%@).  No action taken.", NSStringFromSelector(_cmd), newCurrentUser.credentials.organizationId, newCurrentUser.credentials.userId];
    } else {
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
}


#pragma mark - User Change Notifications
- (void)userChanged:(SFUserAccount *)user change:(SFUserAccountDataChange)change {
    [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:change];
}

- (void)notifyUserDataChange:(NSString *)notificationName withUser:(SFUserAccount *)user andChange:(SFUserAccountDataChange)change {
    if (user) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:user
                                                          userInfo:@{
                                                                SFUserAccountManagerUserChangeKey: @(change)
                                                          }];
    }

}

- (void)notifyUserChange:(NSString *)notificationName withUser:(SFUserAccount *)user andChange:(SFUserAccountChange)change {
    if (user) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:self
                                                          userInfo:@{
                                                                  SFUserAccountManagerUserChangeKey: @(change),                                                                  SFUserAccountManagerUserChangeUserKey: user
                                                          }];
    }else {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:self
                                                          userInfo:@{
                                                                  SFUserAccountManagerUserChangeKey: @(change)
                                                          }];

    }
}

- (void)reload {
    [_accountsLock lock];

    if(!_accountPersister)
        _accountPersister = [SFDefaultUserAccountPersister new];

    if (!_userAccountMap)
        _userAccountMap = [NSMutableDictionary new];
    else
        [_userAccountMap removeAllObjects];

    [self loadAccounts:nil];
    [_accountsLock unlock];
}

@end
