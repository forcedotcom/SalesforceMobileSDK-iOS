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
#import "SFSDKOAuthClientCache.h"
#import "SFSDKWebViewStateManager.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKWindowContainer.h"
#import "SFSDKIDPConstants.h"
#import "SFSDKAuthViewHandler.h"

// Notifications
NSString * const SFUserAccountManagerDidChangeUserNotification       = @"SFUserAccountManagerDidChangeUserNotification";
NSString * const SFUserAccountManagerDidChangeUserDataNotification   = @"SFUserAccountManagerDidChangeUserDataNotification";
NSString * const SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

//login & logout notifications
NSString * const kSFNotificationUserWillLogIn  = @"SFNotificationUserWillLogIn";
NSString * const kSFNotificationUserDidLogIn   = @"SFNotificationUserDidLogIn";
NSString * const kSFNotificationUserWillLogout = @"SFNotificationUserWillLogout";
NSString * const kSFNotificationUserDidLogout  = @"SFNotificationUserDidLogout";
NSString * const kSFNotificationOrgDidLogout   = @"SFNotificationOrgDidLogout";

//Auth Display Notification
NSString * const kSFNotificationUserWillShowAuthView = @"SFNotificationUserWillShowAuthView";
NSString * const kSFNotificationUserCanceledAuth = @"SFNotificationUserCanceledAuthentication";
//IDP-SP flow Notifications
NSString * const kSFNotificationUserWillSendIDPRequest      = @"SFNotificationUserWillSendIDPRequest";
NSString * const kSFNotificationUserWillSendIDPResponse     = @"kSFNotificationUserWillSendIDPResponse";
NSString * const kSFNotificationUserDidReceiveIDPRequest    = @"SFNotificationUserDidReceiveIDPRequest";
NSString * const kSFNotificationUserDidReceiveIDPResponse   = @"SFNotificationUserDidReceiveIDPResponse";
NSString * const kSFNotificationUserIDPInitDidLogIn       = @"SFNotificationUserIDPInitDidLogIn";

//keys used in notifications
NSString * const kSFNotificationUserInfoAccountKey      = @"account";
NSString * const kSFNotificationUserInfoCredentialsKey  = @"credentials";
NSString * const kSFNotificationUserInfoAuthTypeKey     = @"authType";
NSString * const kSFUserInfoAddlOptionsKey     = @"options";
NSString * const kSFNotificationUserInfoKey    = @"sfuserInfo";

NSString * const SFUserAccountManagerUserChangeKey      = @"change";
NSString * const SFUserAccountManagerUserChangeUserKey      = @"user";
// Persistence Keys
static NSString * const kUserDefaultsLastUserIdentityKey = @"LastUserIdentity";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";
static NSString * const kSFAppFeatureMultiUser   = @"MU";

static NSString * const kAlertErrorTitleKey = @"authAlertErrorTitle";
static NSString * const kAlertOkButtonKey = @"authAlertOkButton";
static NSString * const kAlertRetryButtonKey = @"authAlertRetryButton";
static NSString * const kAlertDismissButtonKey = @"authAlertDismissButton";
static NSString * const kAlertConnectionErrorFormatStringKey = @"authAlertConnectionErrorFormatString";
static NSString * const kAlertVersionMismatchErrorKey = @"authAlertVersionMismatchError";

static NSString *const kSFIncompatibleAuthError = @"Cannot use SFUserAccountManager Auth functions with useLegacyAuthenticationManager enabled";

static NSString *const kErroredClientKey = @"SFErroredOAuthClientKey";
static NSString * const kSFSPAppFeatureIDPLogin   = @"SP";
static NSString * const kSFIDPAppFeatureIDPLogin   = @"IP";
static NSString *const  kOptionsClientKey          = @"clientIdentifier";

@interface SFNotificationUserInfo()
- (instancetype) initWithUser:(SFUserAccount *)user;
@end

@implementation SFNotificationUserInfo : NSObject

- (instancetype) initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        _accountIdentity = user.accountIdentity;
        _communityId = user.credentials.communityId;
    }
    return self;
}

@end

@implementation SFUserAccountManager

@synthesize currentUser = _currentUser;
@synthesize userAccountMap = _userAccountMap;
@synthesize accountPersister = _accountPersister;
@synthesize loginViewControllerConfig = _loginViewControllerConfig;

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
        _errorManager = [[SFSDKAuthErrorManager alloc] init];
        __weak typeof (self) weakSelf = self;
        self.alertDisplayBlock = ^(SFSDKAlertMessage * message, SFSDKWindowContainer *window) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            strongSelf.alertView = [[SFSDKAlertView alloc] initWithMessage:message window:window];
            [strongSelf.alertView presentViewController:NO completion:nil];
        };
        [self populateErrorHandlers];
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
    if (isIdentityProvider) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFIDPAppFeatureIDPLogin];
    }else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFIDPAppFeatureIDPLogin];
    }
    self.authPreferences.isIdentityProvider = isIdentityProvider;
}

- (BOOL)idpEnabled {
    return self.authPreferences.idpEnabled;
}

- (SFOAuthAdvancedAuthConfiguration)advancedAuthConfiguration {
   return self.authPreferences.advancedAuthConfiguration;
}

- (void)setAdvancedAuthConfiguration:(SFOAuthAdvancedAuthConfiguration)advancedAuthConfiguration {
    self.authPreferences.advancedAuthConfiguration = advancedAuthConfiguration;
}


- (BOOL)useLegacyAuthenticationManager{
    return self.authPreferences.useLegacyAuthenticationManager;
}

- (void)setUseLegacyAuthenticationManager:(BOOL)enabled {
    self.authPreferences.useLegacyAuthenticationManager = enabled;
}

- (NSString *)appDisplayName {
    return self.authPreferences.appDisplayName;
}

- (void)setAppDisplayName:(NSString *)appDisplayName {
    self.authPreferences.appDisplayName = appDisplayName;
}

- (NSString *)idpAppURIScheme{
    return self.authPreferences.idpAppURIScheme;
}

- (void)setIdpAppURIScheme:(NSString *)idpAppURIScheme {
    if (idpAppURIScheme && [idpAppURIScheme trim].length > 0) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFSPAppFeatureIDPLogin];
    } else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFSPAppFeatureIDPLogin];
    }
    self.authPreferences.idpAppURIScheme = idpAppURIScheme;
}

- (SFSDKLoginViewControllerConfig *) loginViewControllerConfig {
    if (!_loginViewControllerConfig) {
        _loginViewControllerConfig = [[SFSDKLoginViewControllerConfig alloc] init];
    }
    return _loginViewControllerConfig;
}

- (void) setLoginViewControllerConfig:(SFSDKLoginViewControllerConfig *)config {
    if (_loginViewControllerConfig != config) {
        _loginViewControllerConfig = config;
    }
}

#pragma  mark - login & logout

- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse options:(nonnull NSDictionary *)options{
     NSAssert(self.useLegacyAuthenticationManager==false, kSFIncompatibleAuthError);
    [SFSDKCoreLogger d:[self class] format:@"handleAdvancedAuthenticationResponse %@",[appUrlResponse description]];
    BOOL result = [[SFSDKURLHandlerManager sharedInstance] canHandleRequest:appUrlResponse options:options];
    if (result) {
        result = [[SFSDKURLHandlerManager sharedInstance] processRequest:appUrlResponse  options:options];
    }
    return result;
}

- (BOOL)loginWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(self.useLegacyAuthenticationManager==false, kSFIncompatibleAuthError);
    SFOAuthCredentials *clientCredentials = [self newClientCredentials];
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:clientCredentials];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(self.useLegacyAuthenticationManager==false, kSFIncompatibleAuthError);
    NSAssert(credentials.refreshToken.length > 0, @"Refresh token required to refresh credentials.");
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:credentials];
}

- (BOOL)authenticateWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock credentials:(SFOAuthCredentials *)credentials{
    NSAssert(self.useLegacyAuthenticationManager==false, kSFIncompatibleAuthError);
    [SFSDKWebViewStateManager removeSession];
    SFSDKOAuthClient *client = [self fetchOAuthClient:credentials cached:NO completion:completionBlock failure:failureBlock];
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    return [client refreshCredentials];
}

- (BOOL)loginWithJwtToken:(NSString *)jwtToken completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(self.useLegacyAuthenticationManager == false, kSFIncompatibleAuthError);
    NSAssert(jwtToken.length > 0, @"JWT token value required.");
    SFOAuthCredentials *credentials = [self newClientCredentials];
    credentials.jwt = jwtToken;
    return [self authenticateWithCompletion:completionBlock failure:failureBlock credentials:credentials];
}

- (void)logout {
    NSAssert(self.useLegacyAuthenticationManager == false, kSFIncompatibleAuthError);
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logoutUser:(SFUserAccount *)user {
    NSAssert(self.useLegacyAuthenticationManager == false, kSFIncompatibleAuthError);

    // No-op, if the user is not valid.
    if (user == nil) {
        [SFSDKCoreLogger i:[self class] format:@"logoutUser: user is nil. No action taken."];
        return;
    }
    BOOL loggingOutTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggingOut];
    if (!loggingOutTransitionSucceeded) {

        // SFUserAccount already logs the transition failure.
        return;
    }
    
    // Before starting actual logout (which will tear down SFRestAPI), first unregister from push notifications if needed
    __weak typeof(self) weakSelf = self;
    [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotificationsWithCompletionBlock:user completionBlock:^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf postPushUnregistration:user];
    }];
}

- (void)postPushUnregistration:(SFUserAccount *)user {
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postPushUnregistration:user];
        });
        return;
    }

    [SFSDKCoreLogger d:[self class] format:@"Logging out user '%@'.", user.userName];
    
    //save for use with didLogout notification
    NSString *userId = user.credentials.userId;
    NSString *orgId = user.credentials.organizationId;
    NSString *communityId = user.credentials.communityId;
    
    NSDictionary *userInfo = @{ kSFNotificationUserInfoAccountKey : user };
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserWillLogout
                                                         object:self
                                                       userInfo:userInfo];

    SFSDKOAuthClient *client = [self fetchOAuthClient:user.credentials completion:nil failure:nil];
    [self deleteAccountForUser:user error:nil];
    [client cancelAuthentication:NO];
    [client revokeCredentials];
    [SFSecurityLockout clearPasscodeState:user];
    BOOL isCurrentUser = [user isEqual:self.currentUser];
    if (isCurrentUser) {
        self.currentUser = nil;
    }

    [SFSDKWebViewStateManager removeSession];
    
    //restore these id's inorder to enable post logout cleanup of components
    // TODO: Revisit the userInfo data structure of kSFNotificationUserDidLogout in 7.0.
    // Technically, an SFUserAccount should not continue to exist after logout.  The
    // identifying data here would be better organized into a standalone data structure.
    user.credentials.userId = userId;
    user.credentials.organizationId = orgId;
    user.credentials.communityId = communityId;
    
    NSNotification *logoutNotification = [NSNotification notificationWithName:kSFNotificationUserDidLogout object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];

    //post a notification if all users of the given org have logged out.
    if (![self orgHasLoggedInUsers:orgId]) {
        SFNotificationUserInfo *sfUserInfo = [[SFNotificationUserInfo alloc] initWithUser:user];
        
        NSDictionary *notificationUserInfo = @{ kSFNotificationUserInfoKey : sfUserInfo };
        NSNotification *orgLogoutNotification = [NSNotification notificationWithName:kSFNotificationOrgDidLogout object:self userInfo:notificationUserInfo];
        [[NSNotificationCenter defaultCenter] postNotification:orgLogoutNotification];
    }
    
    // NB: There's no real action that can be taken if this login state transition fails.  At any rate,
    // it's an unlikely scenario.
    [user transitionToLoginState:SFUserAccountLoginStateNotLoggedIn];
    [self disposeOAuthClient:client];
}

- (void)logoutAllUsers {
    NSAssert(self.useLegacyAuthenticationManager == false, kSFIncompatibleAuthError);

    // Log out all other users, then the current user.
    NSArray *userAccounts = [self allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != self.currentUser) {
            [self logoutUser:account];
        }
    }
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)dismissAuthViewControllerIfPresent
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent];
        });
        return;
    }
    UIViewController *presentedViewController = [SFSDKWindowManager sharedManager].authWindow.viewController.presentedViewController;
    
    if (presentedViewController) {
        [presentedViewController dismissViewControllerAnimated:NO completion:^{
            [[SFSDKWindowManager sharedManager].authWindow dismissWindow];
        }];
    } else {
        //hide the window if no controllers were found.
        [[SFSDKWindowManager sharedManager].authWindow dismissWindow];
    }
}

+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error {
    return [SFSDKAuthErrorManager errorIsInvalidAuthCredentials:error];
}

#pragma mark - SFSDKOAuthClientDelegate
- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client{
    
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: client.credentials,
                                kSFNotificationUserInfoAuthTypeKey: client.context.authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillLogIn
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error{
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    [options setObject:client forKey:kErroredClientKey];
    
    __block BOOL errorWasHandledByDelegate = NO;
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
            BOOL returnVal = [delegate userAccountManager:self error:error info:client.context.authInfo];
            errorWasHandledByDelegate |= returnVal;
        }
    }];
    
    if (!errorWasHandledByDelegate) {
       BOOL errorWasHandledBySDK =  [self.errorManager processAuthError:error authInfo:client.context.authInfo options:options];
        if (!errorWasHandledBySDK) {
            [SFSDKCoreLogger e:[self class] format:@"Unhandled Error during authentication. Handle the error using   [SFUserAccountManagerDelegate userAccountManager:error:info:] and return true. %@", error.localizedDescription];
        }
    }
    [self disposeOAuthClient:client];
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
    [self loggedIn:NO client:client notifyDelegatesOfFailure:YES];
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
    newClient.config.loginHost = newLoginHost;
    [newClient refreshCredentials];
}

- (void)authClientRestartAuthentication:(SFSDKOAuthClient *)client {
    [client restartAuthentication];
}

- (void)authClient:(SFSDKOAuthClient *)client displayMessage:(SFSDKAlertMessage *)message {
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
       weakSelf.alertDisplayBlock(message,client.authWindow);
    });
    
}

#pragma mark - SFSDKOAuthClientWebViewDelegate
- (void)authClient:(SFSDKOAuthClient *_Nonnull)client willDisplayAuthWebView:(WKWebView *_Nonnull)view {
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: client.credentials,
                                kSFNotificationUserInfoAuthTypeKey: client.context.authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillShowAuthView
                                                        object:self userInfo:userInfo];
}

#pragma mark - SFSDKOAuthClientSafariViewDelegate
- (void)authClient:(SFSDKOAuthClient *)client willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock {
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: client.credentials,
                                kSFNotificationUserInfoAuthTypeKey: client.context.authInfo };
    if (client.config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationAllow) {
        //Rekey the client in cache. Need to do, since advanced auth configuration was realized
        //from org/domain setting.
        NSString *newKey = [SFSDKOAuthClientCache keyFromCredentials:client.credentials type:SFOAuthClientKeyTypeAdvanced];
        [[SFSDKOAuthClientCache sharedInstance] removeClient:client];
        [[SFSDKOAuthClientCache sharedInstance] addClient:client forKey:newKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillShowAuthView object:self  userInfo:userInfo];
}

- (BOOL)authClientDidCancelBrowserFlow:(SFSDKOAuthClient *)client {
    BOOL result = NO;
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: client.credentials,
                                kSFNotificationUserInfoAuthTypeKey: client.context.authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserCanceledAuth
                                                        object:self userInfo:userInfo];
    if (self.authCancelledByUserHandlerBlock) {
        [client cancelAuthentication:YES];
        result = YES;
        self.authCancelledByUserHandlerBlock();
    }
    return result;
}

#pragma mark - SFSDKIDPAuthClientDelegate
- (void)authClient:(SFSDKOAuthClient *)client error:(NSError *)error {
    SFSDKIDPAuthClient *idpClient = (SFSDKIDPAuthClient *) [SFSDKOAuthClient idpAuthInstance:nil];
    [idpClient launchSPAppWithError:error reason:nil];
    [self disposeOAuthClient:idpClient];
}

- (void)authClient:(SFSDKOAuthClient *)client willSendResponseForIDPAuth:(NSDictionary *)options {
    [client dismissAuthViewControllerIfPresent];
    SFUserAccount *account = [[SFUserAccountManager sharedInstance] accountForCredentials:client.credentials];
    NSDictionary *userInfo = @{kSFNotificationUserInfoAccountKey:account,kSFUserInfoAddlOptionsKey:options};
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserWillSendIDPResponse
                                                         object:self
                                                       userInfo:userInfo
     ];
}

- (void)authClient:(SFSDKIDPAuthClient *)client willSendRequestForIDPAuth:(NSDictionary *)options {
    NSDictionary *userInfo = @{kSFUserInfoAddlOptionsKey:options};
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserWillSendIDPRequest
                                                         object:self
                                                         userInfo:userInfo
     ];
}

- (void)authClientDisplayIDPLoginFlowSelection:(SFSDKIDPAuthClient *)client  {
    UIViewController<SFSDKLoginFlowSelectionView> *controller  = client.idpLoginFlowSelectionBlock();
    controller.selectionFlowDelegate = self;
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    [options setObject:key forKey:kOptionsClientKey];
    controller.appOptions = options;
    [client.authWindow presentWindowAnimated:NO withCompletion:^{
        [client.authWindow.viewController presentViewController:controller animated:YES completion:^{
            [[SFSDKOAuthClientCache sharedInstance] addClient:client];
        }];
    }];
}

#pragma mark - SFSDKLoginFlowSelectionViewControllerDelegate
-(void)loginFlowSelectionIDPSelected:(UIViewController *)controller options:(NSDictionary *)appOptions {
    NSString *key = [appOptions objectForKey:kOptionsClientKey];
    SFSDKIDPAuthClient *client = (SFSDKIDPAuthClient *)[[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    if(!client) {
        SFOAuthCredentials *credentials = [self newClientCredentials];
        client = [self fetchIDPAuthClient:credentials completion:nil failure:nil];
    }
    client.config.loginHost = self.loginHost;
    [client initiateIDPFlowInSPApp];
}

-(void)loginFlowSelectionLocalLoginSelected:(UIViewController *)controller options:(NSDictionary *)appOptions  {
    NSString *key = [appOptions objectForKey:kOptionsClientKey];
    SFSDKIDPAuthClient *client = (SFSDKIDPAuthClient *)[[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    if(!client) {
        SFOAuthCredentials *credentials = [self newClientCredentials];
        client = [self fetchIDPAuthClient:credentials completion:nil failure:nil];
    }
    [client initiateLocalLoginInSPApp];
}

#pragma mark - SFSDKUserSelectionViewDelegate
- (void)createNewUser:(NSDictionary *)spAppOptions{
    // bootstrap idp apps credentials
    SFOAuthCredentials *credentials = [self newClientCredentials];
    SFSDKIDPAuthClient *newClient = [self fetchIDPAuthClient:credentials
                                                  completion:nil
                                                     failure:nil];
    if (spAppOptions[kSFLoginHostParam]) {
        newClient.config.loginHost = spAppOptions[kSFLoginHostParam];
    }
    
    [newClient setCallingAppOptionsInContext:spAppOptions];
    [newClient beginIDPFlowForNewUser];
}

- (void)selectedUser:(SFUserAccount *)user spAppContext:(NSDictionary *)spAppOptions{
    __weak typeof (self) weakSelf = self;
    SFSDKIDPAuthClient * idpClient = [self fetchIDPAuthClient:user.credentials completion:nil failure:nil];
    [idpClient setCallingAppOptionsInContext:spAppOptions];
    
    [idpClient retrieveIdentityDataWithCompletion:^(SFSDKOAuthClient *idClient) {
        SFSDKIDPAuthClient *tempClient = (SFSDKIDPAuthClient *) idClient;
        [[SFUserAccountManager sharedInstance] applyCredentials:tempClient.credentials withIdData:tempClient.idData];
        [tempClient continueIDPFlow:tempClient.context.credentials];
    } failure:^(SFSDKOAuthClient * idClient, NSError *error) {
        SFSDKIDPAuthClient *tempClient = (SFSDKIDPAuthClient *) idClient;
        tempClient.config.successCallbackBlock = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf selectedUser:account spAppContext:spAppOptions];
        };
        tempClient.config.failureCallbackBlock = ^(SFOAuthInfo * authInfo, NSError *error) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            SFSDKIDPAuthClient * _tempClient = (SFSDKIDPAuthClient *) idClient;
            [_tempClient launchSPAppWithError:error reason:@"Failed refreshing credentials"];
            [strongSelf disposeOAuthClient:_tempClient];
        };
        [tempClient beginIDPFlowForNewUser];
        
    }];
}

- (void)cancel:(NSDictionary *)spAppOptions{
    SFSDKIDPAuthClient * idpClient = [self fetchIDPAuthClient:[self newClientCredentials] completion:nil failure:nil];
    [idpClient setCallingAppOptionsInContext:spAppOptions];
    [idpClient launchSPAppWithError:nil reason:@"User cancelled authentication"];
    [idpClient cancelAuthentication:YES];
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

- (NSArray *)userAccountsForDomain:(NSString *)domain {
    NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountDomain = account.credentials.domain;
        if ([[accountDomain lowercaseString] isEqualToString:[domain lowercaseString]]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}

- (BOOL)orgHasLoggedInUsers:(NSString *)orgId {
    NSArray *accounts = [self accountsForOrgId:orgId];
    return accounts && (accounts.count > 0);
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
    [[SFSDKOAuthClientCache sharedInstance] removeAllClients];
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
                [SFSDKCoreLogger e:[self class] message:@"Cannot set the currentUser. Add the account to the SFAccountManager before making this call."];
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
- (void)populateErrorHandlers
{
    __weak typeof (self) weakSelf = self;
    
    self.errorManager.invalidAuthCredentialsErrorHandlerBlock  = ^(NSError *error, SFOAuthInfo *authInfo,NSDictionary *options) {
         SFSDKOAuthClient *client = [options objectForKey:kErroredClientKey];
         __strong typeof (weakSelf) strongSelf = weakSelf;
        [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
         [strongSelf handleFailure:error client:client notifyDelegates:NO];
    };
    
    self.errorManager.networkErrorHandlerBlock = ^(NSError *error, SFOAuthInfo *authInfo,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        SFSDKOAuthClient *client = [options objectForKey:kErroredClientKey];
         //delegates if existed should have been already called
        [strongSelf loggedIn:YES client:client notifyDelegatesOfFailure:NO];
    };
    
    self.errorManager.hostConnectionErrorHandlerBlock  = ^(NSError *error, SFOAuthInfo *authInfo,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        SFSDKOAuthClient *client = [options objectForKey:kErroredClientKey];
        NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]];
        NSString *okButton = [SFSDKResourceUtils localizedString:kAlertOkButtonKey];
        [strongSelf showErrorAlertWithMessage:alertMessage buttonTitle:okButton andCompletion:^() {
            [client cancelAuthentication:YES];
            [strongSelf disposeOAuthClient:client];
            [weakSelf notifyUserCancelledOrDismissedAuth:client.credentials andAuthInfo:client.context.authInfo];
            SFSDKLoginHost *host = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:0];
            strongSelf.loginHost = host.host;
            [strongSelf switchToNewUser];
        }];
    };
    
    self.errorManager.genericErrorHandlerBlock = ^(NSError *error, SFOAuthInfo *authInfo,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;

        NSString *message =[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]];
        NSString *retryButton = [SFSDKResourceUtils localizedString:kAlertOkButtonKey];
        [strongSelf showErrorAlertWithMessage:message buttonTitle:retryButton   andCompletion:^() {
            SFSDKOAuthClient *client = [options objectForKey:kErroredClientKey];
            [strongSelf disposeOAuthClient:client];
            SFOAuthCredentials *credentials = [strongSelf newClientCredentials];
            [strongSelf dismissAuthViewControllerIfPresent];
            SFSDKOAuthClient *newClient = [strongSelf fetchOAuthClient:credentials completion:client.config.successCallbackBlock failure:client.config.failureCallbackBlock];
            [newClient refreshCredentials];
        }];
    };
    
    self.errorManager.connectedAppVersionMismatchErrorHandlerBlock = ^(NSError *  error, SFOAuthInfo *authInfo,NSDictionary *options) {
         __strong typeof (weakSelf) strongSelf = weakSelf;
        SFSDKOAuthClient *client = [options objectForKey:kErroredClientKey];
        [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
        [strongSelf showAlertForConnectedAppVersionMismatchError:error client:client];
    };
}

- (void)showErrorAlertWithMessage:(NSString *)alertMessage buttonTitle:(NSString *)buttonTitle andCompletion:(void(^)(void))completionBlock {
    __weak typeof (self) weakSelf = self;
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.alertTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.alertMessage = alertMessage;
        builder.actionOneTitle = buttonTitle;
        builder.actionOneCompletion = ^{
            completionBlock();
        };
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.alertDisplayBlock(message, SFSDKWindowManager.sharedManager.authWindow);
    });
}

- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error client:(SFSDKOAuthClient *)client
{
     __weak typeof (self) weakSelf = self;
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        builder.alertTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.alertMessage = [SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey];
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.actionTwoTitle = [SFSDKResourceUtils localizedString:kAlertDismissButtonKey];
        builder.actionOneCompletion = ^{
            [strongSelf handleFailure:error client:client notifyDelegates:NO];
        };
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
         weakSelf.alertDisplayBlock(message, SFSDKWindowManager.sharedManager.authWindow);
    });
}

- (SFSDKOAuthClient *)fetchOAuthClient:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    return [self fetchOAuthClient:credentials cached:YES completion:completionBlock failure:failureBlock];
}

- (SFSDKOAuthClient *)fetchOAuthClient:(SFOAuthCredentials *)credentials cached:(BOOL)cachedClient completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    
    NSString *key = [SFSDKOAuthClientCache keyFromCredentials:credentials];
    SFSDKOAuthClient *client = [[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    if (!cachedClient || !client) {
        __weak typeof(self) weakSelf = self;
        client = [SFSDKOAuthClient clientWithCredentials:credentials configBlock:^(SFSDKOAuthClientConfig *config) {
            __strong typeof(self) strongSelf = weakSelf;
            config.loginHost = strongSelf.loginHost;
            config.brandLoginPath = strongSelf.brandLoginPath;
            config.additionalTokenRefreshParams = strongSelf.additionalTokenRefreshParams;
            config.additionalOAuthParameterKeys = strongSelf.additionalOAuthParameterKeys;
            config.scopes = strongSelf.scopes;
            config.isIdentityProvider = strongSelf.isIdentityProvider;
            config.oauthCompletionUrl = strongSelf.oauthCompletionUrl;
            config.oauthClientId = strongSelf.oauthClientId;
            config.idpAppURIScheme = strongSelf.idpAppURIScheme;
            config.appDisplayName = strongSelf.appDisplayName;
            config.advancedAuthConfiguration = strongSelf.advancedAuthConfiguration;
            config.delegate = strongSelf;
            config.webViewDelegate = strongSelf;
            config.safariViewDelegate = strongSelf;
            config.idpDelegate = strongSelf;
            config.successCallbackBlock = completionBlock;
            config.failureCallbackBlock = failureBlock;
            config.idpLoginFlowSelectionBlock = strongSelf.idpLoginFlowSelectionAction;
            config.idpUserSelectionBlock = strongSelf.idpUserSelectionAction;
            config.authViewHandler = strongSelf.authViewHandler;
            config.loginViewControllerConfig = strongSelf.loginViewControllerConfig;
        }];
        [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    }
    return client;
}

- (SFSDKIDPAuthClient *)fetchIDPAuthClient:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(self.idpEnabled || self.isIdentityProvider, @"SDK must be enabled to be an identity provider or enabled for idp flow");
    SFSDKIDPAuthClient *idpAuthClient = (SFSDKIDPAuthClient *) [self fetchOAuthClient:credentials completion:completionBlock failure:failureBlock];
    return idpAuthClient;
}

- (void)disposeOAuthClient:(SFSDKOAuthClient *)client {
    [[SFSDKOAuthClientCache sharedInstance] removeClient:client];
}

- (void)loggedIn:(BOOL)fromOffline client:(SFSDKOAuthClient* )client notifyDelegatesOfFailure:(BOOL)shouldNotify
{
    if (!fromOffline) {
        __weak typeof(self) weakSelf = self;
        [client retrieveIdentityDataWithCompletion:^(SFSDKOAuthClient *client) {
            [weakSelf retrievedIdentityData:client];
        } failure:^(SFSDKOAuthClient *client, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [client revokeCredentials];
            [strongSelf handleFailure:error client:client notifyDelegates:shouldNotify];
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
    [client dismissAuthViewControllerIfPresent];
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [weakSelf finalizeAuthCompletion:client];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [weakSelf handleFailure:client.context.authError client:client notifyDelegates:YES];
    }];
    // Check to see if a passcode needs to be created or updated, based on passcode policy data from the
    // identity service.
    [SFSecurityLockout setPasscodeLength:client.idData.mobileAppPinLength
                             lockoutTime:(client.idData.mobileAppScreenLockTimeout * 60)];
}


- (void)handleFailure:(NSError *)error  client:(SFSDKOAuthClient *)client notifyDelegates:(BOOL)notifyDelegates {
    
    if( client.config.failureCallbackBlock ) {
        client.config.failureCallbackBlock(client.context.authInfo,error);
    }
  
    if (notifyDelegates) {
         __weak typeof(self) weakSelf = self;
        [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
                [delegate userAccountManager:weakSelf error:error info:client.context.authInfo];
            }
        }];
    }
    
    [client cancelAuthentication:NO];
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
        [self handleFailure:error client:client notifyDelegates:YES];
    } else {
        // Notify the session is ready
        [self willChangeValueForKey:@"haveValidSession"];
        [self didChangeValueForKey:@"haveValidSession"];
        [self initAnalyticsManager];
        if (client.config.successCallbackBlock)
            client.config.successCallbackBlock(client.context.authInfo,userAccount);
        
        [self handleAnalyticsAddUserEvent:client account:userAccount];
    }
    //async call, ignore if theres a failure. If success save the user photo locally.
    [self retrieveUserPhotoIfNeeded:userAccount];
    
    if (self.authPreferences.isIdentityProvider &&
       ([client.context.callingAppOptions count] >0)) {
        SFSDKIDPAuthClient *idpClient = (SFSDKIDPAuthClient *)client;
        
        //if not current user has been set in the app yet then set this user as current.
        if (self.currentUser==nil)
            self.currentUser = userAccount;
        
        [idpClient continueIDPFlow:userAccount.credentials];
    } else {
        NSDictionary *userInfo = @{kSFNotificationUserInfoAccountKey: userAccount,
                                   kSFNotificationUserInfoAuthTypeKey: client.context.authInfo};
        if (client.config.isIDPInitiatedFlow) {
            NSNotification *loggedInNotification = [NSNotification notificationWithName:kSFNotificationUserIDPInitDidLogIn object:self  userInfo:userInfo];
            [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
        } else {
         [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidLogIn
                                                                object:self
                                                              userInfo:userInfo];
        }
       [self disposeOAuthClient:client];
    }
}

- (void)retrieveUserPhotoIfNeeded:(SFUserAccount *)account{
    if (account.idData.pictureUrl) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:account.idData.pictureUrl];
        [request setHTTPMethod:@"GET"];
        [request setValue:[NSString stringWithFormat:kHttpAuthHeaderFormatString, account.credentials.accessToken] forHTTPHeaderField:kHttpHeaderAuthorization];
        SFNetwork *network = [[SFNetwork alloc] initWithEphemeralSession];
        [network sendRequest:request  dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error){
            if (error) {
                [SFSDKCoreLogger w:[self class] format:@"Error while trying to retrieve user photo: %@ %@", (long) error.code, error.localizedDescription];
                return;
            } else {
                account.photo = [UIImage imageWithData:data];
            }
        }];
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
    [SFSDKWebViewStateManager removeSession];
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

- (void)notifyUserCancelledOrDismissedAuth:(SFOAuthCredentials *)credentials andAuthInfo:(SFOAuthInfo *)info
 {
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey:credentials,
                                kSFNotificationUserInfoAuthTypeKey: info };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserCanceledAuth
                                                        object:self userInfo:userInfo];
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
