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
#import "SFSDKAuthPreferences.h"
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>
#import <SalesforceAnalytics/SFSDKDatasharingHelper.h>
#import "SFSDKOAuthClient.h"
#import "SFPushNotificationManager.h"
#import "SFOAuthInfo.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFSecurityLockout.h"
#import "SFSDKSalesforceAnalyticsManager.h"
#import "SFIdentityCoordinator.h"
#import "SFSDKAuthPreferences.h"
#import "SFSDKOAuthClientConfig.h"
#import "NSURL+SFAdditions.h"
#import "SFSDKIDPAuthClient.h"
#import "SFSDKUserSelectionNavViewController.h"
#import "SFSDKURLHandlerManager.h"
// Notifications
NSString * const SFUserAccountManagerDidChangeUserNotification   = @"SFUserAccountManagerDidChangeUserNotification";
NSString * const SFUserAccountManagerDidChangeUserDataNotification   = @"SFUserAccountManagerDidChangeUserDataNotification";
NSString * const SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

NSString * const SFUserAccountManagerWillLogoutNotification = @"SFUserAccountManagerWillLogoutNotification";
NSString * const SFUserAccountManagerLogoutNotification = @"SFUserAccountManagerLogoutNotification";
NSString * const SFUserAccountManagerLoggedInNotification = @"SFUserAccountManagerLoggedInNotification";

NSString * const SFUserAccountManagerIDPInitiatedLoginNotification = @"SFUserAccountManagerIDPInitiatedLoginNotification";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";
NSString * const SFUserAccountManagerUserChangeUserKey      = @"user";
// Persistence Keys
static NSString * const kUserDefaultsLastUserIdentityKey = @"LastUserIdentity";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";
static NSString * const kSFAppFeatureMultiUser   = @"MU";

@implementation SFUserAccountManager

@synthesize currentUser = _currentUser;
@synthesize userAccountMap = _userAccountMap;
@synthesize accountPersister = _accountPersister;

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
        _authPreferences = [SFSDKAuthPreferences  new];
        _oauthClientInstances = [[SFSDKSafeMutableDictionary alloc] init];
     }
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - persistent properties

- (void)setLoginHost:(NSString*)host {
    self.authPreferences.loginHost = host;
}

- (NSString *)loginHost {
    return self.authPreferences.loginHost;
}

- (NSSet *)scopes
{
    return self.authPreferences.scopes;
}

- (void)setScopes:(NSSet *)newScopes
{
    self.authPreferences.scopes = newScopes;
}

- (NSString *)oauthCompletionUrl
{
    return self.authPreferences.oauthCompletionUrl;
}

- (void)setOauthCompletionUrl:(NSString *)newRedirectUri
{
    self.authPreferences.oauthCompletionUrl = newRedirectUri;
}

- (NSString *)oauthClientId
{
    return self.authPreferences.oauthClientId;
}

- (void)setOauthClientId:(NSString *)newClientId
{
    self.authPreferences.oauthClientId = newClientId;
}

- (BOOL)isIdentityProvider {
    return self.authPreferences.isIdentityProvider;
}

- (void)setIsIdentityProvider:(BOOL)isIdentityProvider{
    self.authPreferences.isIdentityProvider = isIdentityProvider;
}

- (BOOL)idpEnabled {
    return self.authPreferences.idpEnabled;
}

- (void)setIdpEnabled:(BOOL)idpEnabled {
    self.authPreferences.idpEnabled = idpEnabled;
}

- (NSString *)appDisplayName {
    return self.authPreferences.appDisplayName;
}

- (void)setAppDisplayName:(NSString *)appDisplayName {
    self.authPreferences.appDisplayName = appDisplayName;
}

- (NSString *)idpAppUrl{
    return self.authPreferences.idpAppUrl;
}

- (void)setIdpAppUrl:(NSString *)idpAppUrl {
    self.authPreferences.idpAppUrl = idpAppUrl;
}

#pragma  mark - login & logout

- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse options:(nonnull NSDictionary *)options{
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse %@",[appUrlResponse description]];
    
    BOOL result = [[SFSDKURLHandlerManager sharedInstance] canHandleRequest:appUrlResponse options:options];
    
    if (result) {
        result = [[SFSDKURLHandlerManager sharedInstance] processRequest:appUrlResponse  options:options];
    }
    return result;
}

- (BOOL)loginWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    SFOAuthCredentials *clientCredentials = [self newClientCredentials];
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:clientCredentials];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    
    NSAssert(credentials.refreshToken.length > 0, @"Refresh token required to refresh credentials.");
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:credentials];
}

- (BOOL)authenticateWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock credentials:(SFOAuthCredentials *)credentials{
    SFSDKOAuthClient *client = [self fetchOAuthClient:credentials completion:completionBlock failure:failureBlock];
    return [client refreshCredentials];
}

- (BOOL)loginWithJwtToken:(NSString *)jwtToken completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(jwtToken.length > 0, @"JWT token value required.");
    SFOAuthCredentials *credentials = [self newClientCredentials];
    credentials.jwt = jwtToken;
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:credentials];
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

    SFSDKOAuthClient *client = [self fetchOAuthClient:user.credentials completion:nil failure:nil];
    
    [self deleteAccountForUser:user error:nil];
    [client cancelAuthentication];
    [client revokeCredentials];

    if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications:user];
    }

    if (isCurrentUser) {
        self.currentUser = nil;
    }
   
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
    [self disposeOAuthClient:client];
    
}

- (void)logoutAllUsers {
    // Log out all other users, then the current user.
    NSArray *userAccounts = [self allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != self.currentUser) {
            [self logoutUser:account];
        }
    }
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
    [self.oauthClientInstances removeAllObjects];
}

#pragma mark - SFSDKOAuthClientDelegate
- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client{
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:willLogin:)]) {
            [delegate userAccountManager:self willLogin:client.credentials];
        }
    }];
}

- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error{
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
            [delegate userAccountManager:self error:error info:client.context.authInfo];
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

- (void)authClientDidFinish:(SFSDKOAuthClient *)client{
    [self loggedIn:NO client:client];
}

- (void)authClientContinueOfflineMode:(SFSDKOAuthClient *)client{
    [self retrievedIdentityData:client];
}

- (void)authClientDidChangeLoginHost:(SFSDKOAuthClient *)client loginHost:(NSString *)newLoginHost {
    self.loginHost = newLoginHost;
    SFOAuthCredentials *credentials = [self newClientCredentials];
    [self disposeOAuthClient:client];
    SFSDKOAuthClient *newClient = [self fetchOAuthClient:credentials
                                              completion:client.config.successCallbackBlock
                                                 failure:client.config.failureCallbackBlock];
    [newClient refreshCredentials];
}

- (void)authClientRestartAuthentication:(SFSDKOAuthClient *)client {
    [client restartAuthentication];
}

#pragma mark - SFSDKIDPAuthClientDelegate
- (void)authClient:(SFSDKOAuthClient *)client error:(NSError *)error {
    SFSDKIDPAuthClient *idpClient = (SFSDKIDPAuthClient *) [SFSDKOAuthClient idpAuthInstance:nil];
    [idpClient launchSPAppWithError:nil reason:@"User cancelled authentication"];
    [self disposeOAuthClient:idpClient];
}

- (void)authClient:(SFSDKOAuthClient *_Nonnull)client willSendResponseForIDPAuth:(NSURL *)response {
    [client dismissAuthViewControllerIfPresent];
}

#pragma mark - SFSDKUserSelectionNavViewControllerDelegate
- (void)createNewUser{
    SFOAuthCredentials *credentials = [self newClientCredentials];
    //[self disposeOAuthClient:client];
    SFSDKOAuthClient *newClient = [self fetchIDPAuthClient:credentials
                                              completion:nil
                                                 failure:nil];
    [newClient refreshCredentials];
}

- (void)selectedUser:(SFUserAccount *)user{
    // [[SFUserAccountManager sharedInstance] switchToNewUser];
    __weak typeof (self) weakSelf = self;
    SFSDKIDPAuthClient * idpClient = [self fetchIDPAuthClient:user.credentials completion:nil failure:nil];

    [idpClient retrieveIdentityDataWithCompletion:^(SFSDKOAuthClient *idClient) {
        SFSDKIDPAuthClient * idpClient = (SFSDKIDPAuthClient *) idClient;
        [[SFUserAccountManager sharedInstance] applyCredentials:user.credentials];
        [idpClient continueIDPFlow:user.credentials];
    } failure:^(SFSDKOAuthClient * idClient, NSError *error) {
        idClient.config.successCallbackBlock = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf selectedUser:account];
        };
        idClient.config.failureCallbackBlock = ^(SFOAuthInfo * authInfo, NSError *error) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            SFSDKIDPAuthClient * _tempClient = (SFSDKIDPAuthClient *) idClient;
            [_tempClient launchSPAppWithError:error reason:@"Failed refreshing credentials"];
            [strongSelf disposeOAuthClient:_tempClient];
        };
        [idClient refreshCredentials];
        
     }];
    [idpClient continueIDPFlow:user.credentials];
}

- (void)cancel {
    SFSDKIDPAuthClient * idpClient = [self fetchIDPAuthClient:[self newClientCredentials] completion:nil failure:nil];
    [idpClient launchSPAppWithError:nil reason:@"User cancelled authentication"];
    [idpClient cancelAuthentication];
    [self disposeOAuthClient:idpClient];
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

- (SFOAuthCredentials *)newClientCredentials{
    NSString *identifier = [self uniqueUserAccountIdentifier:self.oauthClientId];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:self.oauthClientId encrypted:YES];
    creds.redirectUri = self.oauthCompletionUrl;
    creds.domain = self.loginHost;
    creds.accessToken = nil;
    return creds;
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

- (NSString *)encodeUserIdentity:(SFUserAccountIdentity *)userIdentity {
    NSString *encodedString = [NSString stringWithFormat:@"%@:%@",userIdentity.userId,userIdentity.orgId];
    return encodedString;
}

- (SFUserAccountIdentity *)decodeUserIdentity:(NSString *)userIdentity {
    NSArray *listItems = [userIdentity componentsSeparatedByString:@":"];
    SFUserAccountIdentity *identity = [[SFUserAccountIdentity alloc] initWithUserId:listItems[0] orgId:listItems[1]];
    return identity;
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
                [SFSDKCoreLogger e:[self class] format:@"Cannot set the new user as currentUser. Add the account to the SFAccountManager before making this call."];
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

#pragma mark - private methods

- (BOOL)handleNativeAuthResponse:(NSURL *_Nonnull)appUrlResponse options:(NSDictionary *_Nullable)options {
    //should return the shared instance for advanced auth
    NSString *state = [appUrlResponse valueForParameterName:@"state"];
    NSString *key = [NSString stringWithFormat:@"%@-ADVANCED", state];
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:key];
    return [client handleURLAuthenticationResponse:appUrlResponse];

}

- (BOOL)handleIdpAuthError:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options {
    
    NSString *reason = [url valueForParameterName:@"errorReason"];
    if (reason) {
        reason = [reason stringByRemovingPercentEncoding];
    }else {
        reason = @"IDP Authentication failed";
    }
    
    NSString *param = [url valueForParameterName:@"state"];
    
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:param];
    SFOAuthCredentials *creds = nil;
    
    if (!client) {
        creds = [self newClientCredentials];
        client = [self fetchOAuthClient:creds completion:nil failure:nil];
        
    }
    __weak typeof (self) weakSelf = self;
    [client showAlertMessage:reason withCompletion:^{
        [weakSelf disposeOAuthClient:client];
    }];
    
    return YES;
}

- (BOOL)handleIdpInitiatedAuth:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options {
    
    SFOAuthCredentials *creds = [[SFUserAccountManager sharedInstance] newClientCredentials];
    NSString *key = [self clientKeyForCredentials:creds];
    __weak typeof (self) weakSelf = self;
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:creds  configBlock:^(SFSDKOAuthClientConfig  *config) {
        __strong typeof (self) strongSelf = weakSelf;
        config.loginHost = strongSelf.loginHost;
        config.isIdentityProvider = strongSelf.isIdentityProvider;
        config.scopes = strongSelf.scopes;
        config.oauthCompletionUrl = strongSelf.oauthCompletionUrl;
        config.oauthClientId = strongSelf.oauthClientId;
        config.idpAppUrl = strongSelf.idpAppUrl;
        config.appDisplayName = strongSelf.appDisplayName;
        
        config.isIDPEnabled = YES;
        config.isIDPInitiatedFlow = YES;
        config.scopes = strongSelf.scopes;
        config.loginHost = strongSelf.loginHost;
        config.oauthClientId = strongSelf.oauthClientId;
        config.delegate = strongSelf;
        config.safariViewDelegate = strongSelf;
        config.idpDelegate = strongSelf;
    }];
    [self.oauthClientInstances setObject:client forKey:key];
    //TODO : fix setting user hint
    NSString *userHint = [url valueForParameterName:@"user_hint"];
    client.context.userHint = userHint;
    return [client refreshCredentials];
}

- (BOOL)handleIdpRequest:(NSURL *_Nonnull)request options:(NSDictionary *_Nullable)options
{
    SFOAuthCredentials *idpAppsCredentials = [self newClientCredentials];
    NSString *sourceApplication = [options objectForKey:UIApplicationOpenURLOptionsSourceApplicationKey];
    NSString *userHint = [request valueForParameterName:@"user_hint"];
    SFOAuthCredentials *foundUserCredentials = nil;
    
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount.credentials.accessToken!=nil) {
            foundUserCredentials = userAccount.credentials;
        }
    }
    
    SFSDKIDPAuthClient  *authClient = nil;
    BOOL showSelection = NO;
    
    if (!foundUserCredentials) {
        //kick off login flow
        authClient = [self fetchIDPAuthClient:idpAppsCredentials completion:nil failure:nil];
    } else if (foundUserCredentials) {
        authClient = [self fetchIDPAuthClient:foundUserCredentials completion:nil failure:nil];
    }

    if (self.currentUser!=nil) {
        showSelection = YES;
    }
    authClient.config.callingAppState = [request valueForParameterName:@"state"];
    authClient.config.callingAppName = [request valueForParameterName:@"app_name"];
    authClient.config.callingAppIdentifier = sourceApplication;
    authClient.config.callingAppDescription =  [request valueForParameterName:@"app_desc"];
    
    if (showSelection) {
        UIViewController<SFSDKUserSelectionView> *controller  = authClient.idpUserSelectionBlock();
        controller.appName = authClient.config.callingAppName;
        controller.appDescription = authClient.config.callingAppDescription;
        controller.appIdentifier = authClient.config.callingAppIdentifier;
        controller.userSelectionDelegate = self;
        authClient.authWindow.viewController = controller;
        [authClient.authWindow enable];
    } else {
        [authClient refreshCredentials];
    }
    return YES;
}

- (BOOL)handleIdpResponse:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options{
  
    NSString *param = [url valueForParameterName:@"state"];
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:param];
    return [client handleURLAuthenticationResponse:url];
}

- (SFSDKOAuthClient *)fetchOAuthClient:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSString *key = [self clientKeyForCredentials:credentials];
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:key];
    if (!client) {
        __weak typeof(self) weakSelf = self;
        client = [SFSDKOAuthClient clientWithCredentials:credentials configBlock:^(SFSDKOAuthClientConfig *config) {
            __strong typeof(self) strongSelf = weakSelf;
            config.loginHost = strongSelf.loginHost;
            config.scopes = strongSelf.scopes;
            config.isIdentityProvider = strongSelf.isIdentityProvider;
            config.oauthCompletionUrl = strongSelf.oauthCompletionUrl;
            config.oauthClientId = strongSelf.oauthClientId;
            config.idpAppUrl = strongSelf.idpAppUrl;
            config.appDisplayName = strongSelf.appDisplayName;
            
            config.isIDPEnabled = strongSelf.idpEnabled;
            config.advancedAuthConfiguration = strongSelf.advancedAuthConfiguration;
            config.delegate = strongSelf;
            config.webViewDelegate = strongSelf;
            config.safariViewDelegate = strongSelf;
            config.successCallbackBlock = completionBlock;
            config.failureCallbackBlock = failureBlock;
        }];
        [self.oauthClientInstances setObject:client forKey:key];
     }
    return client;
}

- (SFSDKIDPAuthClient *)fetchIDPAuthClient:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    
    SFSDKIDPAuthClient *client = (SFSDKIDPAuthClient *) [self.oauthClientInstances objectForKey:[NSString stringWithFormat:@"%@-%@",credentials.identifier, @"IDP"]];
    if (!client) {
        __weak typeof(self) weakSelf = self;
        client = (SFSDKIDPAuthClient *) [SFSDKOAuthClient clientWithCredentials:credentials configBlock:^(SFSDKOAuthClientConfig *config) {
            __strong typeof(self) strongSelf = weakSelf;
            //TODO : Ensure retrieve host & scope from SP App's request
            config.loginHost = strongSelf.loginHost;
            config.scopes = strongSelf.scopes;
            config.oauthCompletionUrl = strongSelf.oauthCompletionUrl;
            config.oauthClientId = strongSelf.oauthClientId;
            config.appDisplayName = strongSelf.appDisplayName;
            config.isIdentityProvider = strongSelf.isIdentityProvider;
            config.isIDPEnabled  = YES;
            config.advancedAuthConfiguration = strongSelf.advancedAuthConfiguration;
            config.idpDelegate = strongSelf;
            config.delegate = strongSelf;
            config.webViewDelegate = strongSelf;
            config.safariViewDelegate = strongSelf;
            config.successCallbackBlock = completionBlock;
            config.failureCallbackBlock = failureBlock;
            config.idpUserSelectionBlock = strongSelf.idpUserSelectionAction;
            config.idpLoginFlowSelectionBlock = strongSelf.idpLoginFlowSelectionAction;
        }];
        NSString *key = [self clientKeyForClient:client];
        [self.oauthClientInstances setObject:client forKey:key];
    }
    return client;
}


- (void)disposeOAuthClient:(SFSDKOAuthClient *)client {
    NSString *key= [self clientKeyForCredentials:client.credentials];
    [self.oauthClientInstances removeObject:key];
}

- (NSString *)clientKeyForCredentials:(SFOAuthCredentials *)credentials {
    
    NSString *instanceType = @"BASIC";
    
    if (self.authPreferences.idpEnabled)
        instanceType = @"IDP";
    
    if (self.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire)
        instanceType = @"ADVANCED";
    
    return [NSString stringWithFormat:@"%@-%@", credentials.identifier,instanceType];
}

- (NSString *)clientKeyForClient:(SFSDKOAuthClient *)client {
    
    NSString *instanceType = @"BASIC";
    
    if (client.config.isIDPEnabled)
        instanceType = @"IDP";
    
    if (client.config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire)
        instanceType = @"ADVANCED";
    
    return [NSString stringWithFormat:@"%@-%@", client.credentials.identifier,instanceType];
}

- (void)loggedIn:(BOOL)fromOffline client:(SFSDKOAuthClient* )client
{
    if (!fromOffline) {
        __weak typeof(self) weakSelf = self;
        [client retrieveIdentityDataWithCompletion:^(SFSDKOAuthClient *client) {
            [weakSelf retrievedIdentityData:client];
        } failure:^(SFSDKOAuthClient *client, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [client revokeCredentials];
            [strongSelf handleFailure:error client:client];
        }];
    } else {
        [self retrievedIdentityData:client];
    }
}

- (void)retrievedIdentityData:(SFSDKOAuthClient *)client
{
    // NB: This method is assumed to run after identity data has been refreshed from the service, or otherwise
    // already exists.
    NSAssert(client.idData != nil, @"Identity data should not be nil/empty at this point.");
    __weak typeof(self) weakSelf = self;
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [weakSelf finalizeAuthCompletion:client];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [weakSelf handleFailure:client.context.authError client:client];
    }];
    // Check to see if a passcode needs to be created or updated, based on passcode policy data from the
    // identity service.
    [SFSecurityLockout setPasscodeLength:client.idData.mobileAppPinLength
                             lockoutTime:(client.idData.mobileAppScreenLockTimeout * 60)];
}


- (void)handleFailure:(NSError *)error  client:(SFSDKOAuthClient *)client{
    if( client.config.failureCallbackBlock ) {
        client.config.failureCallbackBlock(client.context.authInfo,error);
    }
    __weak typeof(self) weakSelf = self;
    
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
            [delegate userAccountManager:weakSelf error:error info:client.context.authInfo];
        }
    }];
    
    [client cancelAuthentication];
}


- (void)finalizeAuthCompletion:(SFSDKOAuthClient *)client
{
    // Apply the credentials that will ensure there is a user and that this
    // current user as the proper credentials.
    SFUserAccount *userAccount = [self applyCredentials:client.credentials withIdData:client.idData];
    client.isAuthenticating = NO;
    BOOL loginStateTransitionSucceeded = [userAccount transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    if (!loginStateTransitionSucceeded) {
        // We're in an unlikely, but nevertheless bad, state.  Fail this authentication.
        [SFSDKCoreLogger e:[self class] format:@"%@: Unable to transition user to a logged in state.  Login failed.", NSStringFromSelector(_cmd)];
        NSString *reason = [NSString stringWithFormat:@"Unable to transition user to a logged in state.  Login failed "];
        [SFSDKCoreLogger w:[self class] format:reason];
        NSError *error = [NSError errorWithDomain:@"SFUserAccountManager"
                                             code:1005
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        [self handleFailure:error client:client];
    } else {
        // Notify the session is ready
        [self willChangeValueForKey:@"haveValidSession"];
        [self didChangeValueForKey:@"haveValidSession"];
        [self initAnalyticsManager];
        if (client.config.successCallbackBlock)
            client.config.successCallbackBlock(client.context.authInfo,userAccount);
        
        [self handleAnalyticsAddUserEvent:client account:userAccount];
    }
    
    if (!self.authPreferences.idpEnabled && [client isKindOfClass:[SFSDKIDPAuthClient class]]) {
        SFSDKIDPAuthClient *idpClient = (SFSDKIDPAuthClient *)client;
        if (self.currentUser==nil)
            self.currentUser = userAccount;
        [idpClient continueIDPFlow:userAccount.credentials];
    } else {
        NSDictionary *userInfo = @{ @"account": userAccount };
        if (client.config.isIDPInitiatedFlow) {
            NSNotification *loggedInNotification = [NSNotification notificationWithName:SFUserAccountManagerIDPInitiatedLoginNotification object:self  userInfo:userInfo];
            [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
        } else {
            NSNotification *loggedInNotification = [NSNotification notificationWithName:SFUserAccountManagerLoggedInNotification object:self  userInfo:userInfo];
            [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
        }
        
        [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(userAccountManager:didLogin:)]) {
                [delegate userAccountManager:self didLogin:userAccount];
            }
        }];
        [client dismissAuthViewControllerIfPresent];
    }
}

- (void) handleAnalyticsAddUserEvent:(SFSDKOAuthClient *)client account:(SFUserAccount *) userAccount {
    if (client.context.authInfo.authType == SFOAuthTypeRefresh) {
        [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:userAccount className:NSStringFromClass([self class]) attributes:nil];
    } else {
        
        // Logging events for add user and number of servers.
        NSArray *accounts = self.allUserAccounts;
        NSMutableDictionary *userAttributes = [[NSMutableDictionary alloc] init];
        userAttributes[@"numUsers"] = [NSNumber numberWithInteger:(accounts ? accounts.count : 0)];
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:userAccount  className:NSStringFromClass([self class]) attributes:userAttributes];
        NSInteger numHosts = [SFSDKLoginHostStorage sharedInstance].numberOfLoginHosts;
        NSMutableArray<NSString *> *hosts = [[NSMutableArray alloc] init];
        for (int i = 0; i < numHosts; i++) {
            SFSDKLoginHost *host = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:i];
            if (host) {
                [hosts addObject:host.host];
            }
        }
        NSMutableDictionary *serverAttributes = [[NSMutableDictionary alloc] init];
        serverAttributes[@"numLoginServers"] = [NSNumber numberWithInteger:numHosts];
        serverAttributes[@"loginServers"] = hosts;
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:nil className:NSStringFromClass([self class]) attributes:serverAttributes];
    }
}

- (void)initAnalyticsManager
{
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:self.currentUser];
    [analyticsManager updateLoggingPrefs];
}

#pragma mark Switching Users

- (void)switchToNewUser {
    [self switchToUser:nil];
}

- (void)switchToUser:(SFUserAccount *)newCurrentUser {
    if ([self.currentUser.accountIdentity isEqual:newCurrentUser.accountIdentity]) {
        [SFSDKCoreLogger w:[self class] format:@"%@ new user identity is the same as the current user.  No action taken.", NSStringFromSelector(_cmd)];
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
