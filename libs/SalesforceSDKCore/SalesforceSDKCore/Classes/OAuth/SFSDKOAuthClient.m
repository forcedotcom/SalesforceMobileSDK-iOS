/*
 SFSDKOAuthClient.m
 SalesforceSDKCore

 Created by Raj Rao on 7/25/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKOAuthClient.h"
#import "SalesforceSDKCore.h"
#import "SFSDKOAuthViewHandler.h"
#import "SFUserAccount+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"

static SFSDKOAuthClient *_sharedInstance = nil;

// Auth error handler name constants
static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";

// Private constants
static NSInteger const kOAuthGenericAlertViewTag           = 444;
static NSInteger const kIdentityAlertViewTag               = 555;
static NSInteger const kConnectedAppVersionMismatchViewTag = 666;
static NSInteger const kAdvancedAuthDialogTag              = 777;

static NSString * const kAlertErrorTitleKey = @"authAlertErrorTitle";
static NSString * const kAlertOkButtonKey = @"authAlertOkButton";
static NSString * const kAlertRetryButtonKey = @"authAlertRetryButton";
static NSString * const kAlertDismissButtonKey = @"authAlertDismissButton";
static NSString * const kAlertConnectionErrorFormatStringKey = @"authAlertConnectionErrorFormatString";
static NSString * const kAlertVersionMismatchErrorKey = @"authAlertVersionMismatchError";

static id<SFSDKOAuthClientProvider> _clientProvider = nil;


@interface SFSDKOAuthClient()<SFOAuthCoordinatorDelegate,SFIdentityCoordinatorDelegate,SFSDKLoginHostDelegate,SFLoginViewControllerDelegate> {
    SFSDKOAuthViewHandler *_authViewHandler;
    SFSDKOAuthClientContext *_lastCodeRequest;
}

@property (nonatomic,strong) SFSDKSafeMutableDictionary *currentRequestContexts;
/**
 Making certain read-only properties privately read-write
 */
@property (nonatomic, readwrite) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;

- (SFSDKOAuthClientContext *)newRequestForCredentials:(SFOAuthCredentials *)credentials;

- (void)revokeRefreshToken:(SFOAuthCredentials *)user;
/**
 Sets up the default error handling chain.
 @return The SFAuthErrorHandlerList instance containing the chain of error handler filters.
 */
- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList;

/**
 Processes an auth error by sending it through the chain of error handlers.
 @param error The auth error object.
 @param context The SFSDKOAuthClientContext context associated with authentication.
 */
- (void)processAuthError:(NSError *)error context:(SFSDKOAuthClientContext *)context;

/**
 Displays an alert in the event of an unknown failure for OAuth or Identity requests, allowing the user
 to retry the process.
 @param tag The tag that identifies the process (OAuth or Identity).
 */
- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag context:(SFSDKOAuthClientContext *)context;

/**
 Displays an alert if the Connected App version on the server does not match the credentials of the client
 app.
 */
- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error context:(SFSDKOAuthClientContext *)context;

@end

@implementation SFSDKOAuthClientContext

@end

@implementation SFSDKOAuthClient

- (instancetype) init {
    self = [super init];
    if (self) {
        _currentRequestContexts = [SFSDKSafeMutableDictionary new];
        [self populateDefaultAuthErrorHandlerList];
    }
    return self;
}
+ (id<SFSDKOAuthClientProvider>) clientProvider {
    return _clientProvider;
}

+ (void)setClientProvider:(id<SFSDKOAuthClientProvider>) clientProvider  {
    if(_clientProvider!= clientProvider) {
        _clientProvider = clientProvider;
    }
}
- (void)setAuthViewHandler:(SFSDKOAuthViewHandler *)authViewHandler {
    if (authViewHandler!=_authViewHandler) {
        _authViewHandler = authViewHandler;
    }
}

- (SFSDKWindowContainer *) authWindow{
   return [SFSDKWindowManager sharedManager].authWindow;
}

- (SFSDKOAuthViewHandler *)authViewHandler {

    if (!_authViewHandler) {
        __weak typeof(self) weakSelf = self;
        if (self.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationNone) {
            _authViewHandler = [[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClient *client, SFSDKOAuthClientViewHolder *viewHandler) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (strongSelf.authViewController == nil) {
                            strongSelf.authViewController = [SFLoginViewController sharedInstance];
                            strongSelf.authViewController.delegate = strongSelf;
                        }
                        [strongSelf.authViewController setOauthView:viewHandler.wkWebView];
                        strongSelf.authWindow.viewController = strongSelf.authViewController;
                        [strongSelf.authWindow enable];
                    } dismissBlock:^(SFSDKOAuthClient *client) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [SFLoginViewController sharedInstance].oauthView = nil;
                        [strongSelf dismissAuthViewControllerIfPresent];
                    }];
        } else {
            _authViewHandler =[[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClient *client, SFSDKOAuthClientViewHolder *viewHandler) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        strongSelf.authWindow.viewController = viewHandler.safariViewController;
                        [strongSelf.authWindow enable];
                    } dismissBlock:nil];
        }

    }
    return _authViewHandler;
}

-(void)dismissAuthViewControllerIfPresent {

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent];
        });
        return;
    }
   [self dismissAuthWindow];

}

-(void)dismissAuthWindow {
    [[SFSDKWindowManager sharedManager].authWindow disable];
}


- (SFSDKOAuthClientContext *_Nullable)cachedContextForCredentials:(SFOAuthCredentials *)credentials {
    SFSDKOAuthClientContext *request = [self.currentRequestContexts objectForKey:credentials.identifier];
    return  request;
}

- (void)clearContextForCredentials:(SFOAuthCredentials *) credentials {
    [self.currentRequestContexts removeObject:credentials.identifier];
}

- (BOOL)cancelAuthentication:(SFSDKOAuthClientContext *_Nonnull) request {
    [request.coordinator.view removeFromSuperview];
    request.idCoordinator.idData = nil;
    [self clearContextForCredentials:request.coordinator.credentials];
    [request.coordinator stopAuthentication];
    request.isAuthenticating = NO;
    return YES;
}

- (BOOL)fetchCredentials {
    return [self fetchCredentials:nil failure:nil];
}
- (BOOL)fetchCredentials:(SFSDKOAuthClientSuccessCallbackBlock)completionBlock
                 failure:(SFSDKOAuthClientFailureCallbackBlock)failureBlock {
    SFOAuthCredentials *credentials = [self retrieveClientCredentials];
    return [self refreshCredentials:credentials success:completionBlock failure:failureBlock];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *_Nullable)credentials
                   success:(SFSDKOAuthClientSuccessCallbackBlock _Nullable)completionBlock
                   failure:(SFSDKOAuthClientFailureCallbackBlock _Nullable)failureBlock{

    SFSDKOAuthClientContext *request = [self cachedContextForCredentials:credentials];

    if (request && request.isAuthenticating) {
        return NO;
    }

    if (!request)
        request = [self newRequestForCredentials:credentials];

    request.isAuthenticating = YES;
    request.coordinator.delegate = self;
    request.idCoordinator.delegate = self;
    request.successCallbackBlock = completionBlock;
    request.failureBlock = failureBlock;
    [request.coordinator authenticateWithCredentials:credentials];
    return  YES;
}

-(void)revokeCredentials:(SFOAuthCredentials *_Nullable)credentials {
    SFSDKOAuthClientContext *request = [self cachedContextForCredentials:credentials];
    if ([_delegate respondsToSelector:@selector(authClientWillRevokeCredentials:context:)]) {
        [_delegate authClientWillRevokeCredentials:self context:request];
    }
    [self revokeRefreshToken:credentials];

    if ([_delegate respondsToSelector:@selector(authClientDidRevokeCredentials:context:)]) {
        [_delegate authClientDidRevokeCredentials:self context:request];
    }
}

- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse {
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse"];
    [_lastCodeRequest.coordinator handleAdvancedAuthenticationResponse:appUrlResponse];
    _lastCodeRequest = nil;
    return YES;
}

#pragma mark - SFLoginViewControllerDelegate

- (void)loginViewController:(SFLoginViewController *)loginViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    [SFUserAccountManager sharedInstance].loginHost= newLoginHost.host;
    SFOAuthCredentials *credentials = [self retrieveClientCredentials];
    SFSDKOAuthClientContext *context = [self cachedContextForCredentials:credentials];
    if (context) {
        [self cancelAuthentication:context];

    }
    [self restartAuthentication:context];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    SFOAuthCredentials *credentials = fromUser.credentials;
    SFSDKOAuthClientContext *context = [self cachedContextForCredentials:credentials];
    [self clearAccountState:NO context:context];
}

#pragma mark - SFOAuthCoordinatorDelegate
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view {
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:willBeginAuthenticationWithView:"];
    if ([self.webViewDelegate respondsToSelector:@selector(authClientWillBeginAuthWithView:)]) {
        [self.webViewDelegate authClientWillBeginAuthWithView:self];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view {
    if ([self.webViewDelegate respondsToSelector:@selector(authClientDidStartAuthWebViewLoad:)]) {
        [self.webViewDelegate authClientDidStartAuthWebViewLoad:self];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError *)errorOrNil {
    if ([self.webViewDelegate respondsToSelector:@selector(authClientDidFinishAuthWebViewLoad:)]) {
        [self.webViewDelegate authClientDidFinishAuthWebViewLoad:self];
    }
}

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {

    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorWillBeginAuthentication"];
    SFSDKOAuthClientContext *request = [self cachedContextForCredentials:coordinator.credentials];

    if ([self.delegate respondsToSelector:@selector(authClientWillBeginAuthentication:context:)]) {
        [self.delegate authClientWillBeginAuthentication:self context:request];
    }

    if (info.authType == SFOAuthTypeRefresh) {
        if ([self.delegate respondsToSelector:@selector(authClientWillRefreshCredentials:context:)]) {
            [self.delegate authClientWillRefreshCredentials:self context:request];
        }
    }

}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidAuthenticate"];
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];
    SFSDKOAuthClientContext *currentRequest = [self cachedContextForCredentials:coordinator.credentials];
    currentRequest.authInfo = info;

    // Logging event for token refresh flow.
    SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] accountForCredentials:coordinator.credentials];
    if (info.authType == SFOAuthTypeRefresh) {
        [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:userAccount className:NSStringFromClass([self class]) attributes:nil];
    } else {

        // Logging events for add user and number of servers.
        NSArray *accounts = [SFUserAccountManager sharedInstance].allUserAccounts;
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

    [self dismissAuthWindow];
    [self loggedIn:NO request:currentRequest];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    SFSDKOAuthClientContext *currentRequest = [self cachedContextForCredentials:coordinator.credentials];
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, currentRequest.authInfo];
    currentRequest.authInfo = info;
    currentRequest.authError = error;
    [self processAuthError:error context:currentRequest];
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator *)coordinator {
    return YES;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self oauthCoordinator:coordinator willBeginBrowserAuthentication:callbackBlock];
        });
        return;
    }
    SFSDKOAuthClientContext *currentRequest = [self cachedContextForCredentials:coordinator.credentials];
    currentRequest.authCoordinatorBrowserBlock = callbackBlock;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];;
    NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowMessage"], coordinator.credentials.domain, appName];

    if (self.statusAlert) {
        self.statusAlert = nil;
    }
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowTitle"]
                     message:alertMessage
            firstButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"]
           secondButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertCancelButton"]
                         tag:kAdvancedAuthDialogTag
                         context:currentRequest
                         error: nil ];

}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayAlertMessage:(NSString *)message completion:(dispatch_block_t)completion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"] style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (completion) completion();
                                                          }];

    [alert addAction:defaultAction];
    __weak typeof(self) weakSelf = self;
    self.authWindow.viewController = [self blankViewController];
    [self.authWindow enable:NO withCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.authWindow.viewController presentViewController:strongSelf.statusAlert animated:NO completion:nil];
    }];

}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayConfirmationMessage:(NSString *)message completion:(void (^)(BOOL result))completion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"] style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (completion) completion(YES);
                                                          }];
    [alert addAction:defaultAction];

    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertCancelButton"] style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             if (completion) completion(NO);
                                                         }];
    [alert addAction:cancelAction];

    self.authWindow.viewController = [self blankViewController];
    __weak typeof (self) weakSelf = self;
    
    [self.authWindow enable:NO withCompletion:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        [strongSelf.authWindow.viewController presentViewController:alert animated:NO completion:nil];
    }];

}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didBeginAuthenticationWithView"];

    if ([self.webViewDelegate respondsToSelector:@selector(authClient:willDisplayAuthWebView:)]) {
        [self.webViewDelegate authClient:self willDisplayAuthWebView:view];
    }
    SFSDKOAuthClientViewHolder *viewHolder = [SFSDKOAuthClientViewHolder new];
    viewHolder.wkWebView = view;
    viewHolder.isAdvancedAuthFlow = NO;
    // Ensure this runs on the main thread.  Has to be sync, because the coordinator expects the auth view
    // to be added to a superview by the end of this method.
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.authViewHandler.authViewDisplayBlock(self, viewHolder);
        });
    } else {
        self.authViewHandler.authViewDisplayBlock(self, viewHolder);
    }

}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithSafariViewController:(SFSafariViewController *)svc {
    _lastCodeRequest = [self cachedContextForCredentials:coordinator.credentials];
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didBeginAuthenticationWithSafariViewController"];
    if ([self.safariViewDelegate respondsToSelector:@selector(authClient:willDisplayAuthSafariViewController:)]) {
        [self.safariViewDelegate authClient:self willDisplayAuthSafariViewController:svc];
    }
    SFSDKOAuthClientViewHolder *viewHolder = [SFSDKOAuthClientViewHolder new];
    viewHolder.safariViewController = svc;
    viewHolder.isAdvancedAuthFlow = YES;
    self.authViewHandler.authViewDisplayBlock(self, viewHolder);
}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {
    __block BOOL handledByDelegate = NO;
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidCancelBrowserAuthentication"];
    if ([self.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
        handledByDelegate = YES;
        [self.safariViewDelegate authClientDidCancelBrowserFlow:self];
    }
    // If no delegates implement authManagerDidCancelBrowserFlow, display Login Host List
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        hostListViewController.delegate = self;
        self.authWindow.viewController = hostListViewController;
        [self.authWindow enable];
    }

}
#pragma mark - SFSDKLoginHostDelegate
- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [hostListViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)hostListViewController:(SFSDKLoginHostListViewController *)hostListViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    [SFUserAccountManager sharedInstance].loginHost = newLoginHost.host;
    // NB: We only get here if there was no delegates for authManagerDidCancelBrowserFlow
    // Calling switchToNewUser to reset app state - which up to 5.1, used to be the
    // behavior implemented by SFSDKLoginHostListViewController's applyLoginHostAtIndex
    [[SFUserAccountManager sharedInstance] switchToNewUser];
}

#pragma mark - SFIdentityCoordinatorDelegate
- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator {
    SFSDKOAuthClientContext *request = [self cachedContextForCredentials:coordinator.credentials];
    [self retrievedIdentityData:request];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error {
    SFSDKOAuthClientContext *currentRequest = [self cachedContextForCredentials:coordinator.credentials];
    if (error.code == kSFIdentityErrorMissingParameters) {

        // No retry, as missing parameters are fatal
        [SFSDKCoreLogger e:[self class] format:@"Missing parameters attempting to retrieve identity data.  Error domain: %@, code: %ld, description: %@", [error domain], [error code], [error localizedDescription]];
        SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] accountForCredentials:coordinator.credentials];
        [self revokeRefreshToken:userAccount.credentials];
        [self handleFailureWithContext:currentRequest];
    } else {
        [SFSDKCoreLogger e:[self class] format:@"Error retrieving idData:"];
        [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag context:currentRequest];
    }
}


#pragma mark - private methods
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials
{
    SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] accountForCredentials:credentials];
    if (credentials.refreshToken != nil) {
        [SFSDKCoreLogger i:[self class] format:@"Revoking credentials on the server for '%@'.",userAccount.userName];
         NSMutableString *host = [NSMutableString stringWithFormat:@"%@://", credentials.protocol];
        [host appendString:credentials.domain];
        [host appendString:@"/services/oauth2/revoke?token="];
        [host appendString:credentials.refreshToken];
        NSURL *url = [NSURL URLWithString:host];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setHTTPShouldHandleCookies:NO];
        SFNetwork *network = [[SFNetwork alloc] init];
        [network sendRequest:request dataResponseBlock:nil];
    }
    [credentials revoke];
}

- (void)loggedIn:(BOOL)fromOffline request:(SFSDKOAuthClientContext *) currentRequest
{
    if (!fromOffline) {
        [currentRequest.idCoordinator initiateIdentityDataRetrieval];
    } else {
        [self retrievedIdentityData:currentRequest];
    }
}

- (void)retrievedIdentityData:(SFSDKOAuthClientContext *)currentRequest
{
    // NB: This method is assumed to run after identity data has been refreshed from the service, or otherwise
    // already exists.
    NSAssert(currentRequest.idCoordinator.idData != nil, @"Identity data should not be nil/empty at this point.");
    __weak typeof(self) weakSelf = self;
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [weakSelf finalizeAuthCompletion:currentRequest];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [weakSelf handleFailureWithContext:currentRequest];
    }];

    // Check to see if a passcode needs to be created or updated, based on passcode policy data from the
    // identity service.
    [SFSecurityLockout setPasscodeLength:currentRequest.idCoordinator.idData.mobileAppPinLength
                             lockoutTime:(currentRequest.idCoordinator.idData.mobileAppScreenLockTimeout * 60)];
}


- (void)finalizeAuthCompletion:(SFSDKOAuthClientContext *)currentRequest
{
    // Apply the credentials that will ensure there is a user and that this
    // current user as the proper credentials.
    SFUserAccount *user = [[SFUserAccountManager sharedInstance] applyCredentials:currentRequest.coordinator.credentials withIdData:currentRequest.idCoordinator.idData];
    currentRequest.isAuthenticating = NO;
    BOOL loginStateTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    if (!loginStateTransitionSucceeded) {
        // We're in an unlikely, but nevertheless bad, state.  Fail this authentication.
        [SFSDKCoreLogger e:[self class] format:@"%@: Unable to transition user to a logged in state.  Login failed.", NSStringFromSelector(_cmd)];
        [self handleFailureWithContext:currentRequest];
    } else {
        // Notify the session is ready
        [self willChangeValueForKey:@"haveValidSession"];
        [self didChangeValueForKey:@"haveValidSession"];
        NSDictionary *userInfo = nil;
        if (user) {
            userInfo = @{ @"account" : user };
        }
        [self initAnalyticsManager];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSFAuthenticationManagerFinishedNotification  object:self
                                                          userInfo:userInfo];
        if ( currentRequest.successCallbackBlock)
            currentRequest.successCallbackBlock(currentRequest.authInfo,user);

        if ([_delegate respondsToSelector:@selector(authClientDidFinish:context:)]) {
            [_delegate authClientDidFinish:self context:currentRequest];
        }
    }
    [self clearContextForCredentials:currentRequest.coordinator.credentials];

}

- (void)initAnalyticsManager
{
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:user];
    [analyticsManager updateLoggingPrefs];
}

- (SFSDKOAuthClientContext *)newRequestForCredentials:(SFOAuthCredentials *)credentials {
    SFSDKOAuthClientContext *request = [[SFSDKOAuthClientContext alloc] init];
    request.coordinator  = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    request.coordinator.advancedAuthConfiguration = self.advancedAuthConfiguration;
    request.coordinator.scopes = [SFUserAccountManager sharedInstance].scopes;
    request.idCoordinator  = [[SFIdentityCoordinator alloc] initWithCredentials:credentials];
    [self.currentRequestContexts setObject:request forKey:credentials.identifier];

    return request;
}

- (SFOAuthCredentials *)retrieveClientCredentials {
    NSString *identifier = [[SFUserAccountManager sharedInstance] uniqueUserAccountIdentifier:[SFUserAccountManager sharedInstance].oauthClientId];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:[SFUserAccountManager sharedInstance].oauthClientId encrypted:YES];
    creds.redirectUri = [SFUserAccountManager sharedInstance].oauthCompletionUrl;
    creds.domain = [SFUserAccountManager sharedInstance].loginHost;
    creds.accessToken = nil;
    creds.clientId = [SFUserAccountManager sharedInstance].oauthClientId;

    return creds;
}

- (void)loggedIn:(BOOL)fromOffline context:(SFSDKOAuthClientContext *)context
{
    if (!fromOffline) {
        [context.idCoordinator initiateIdentityDataRetrieval];
    } else {
        [self retrievedIdentityData:context];
    }

    NSNotification *loggedInNotification = [NSNotification notificationWithName:kSFUserLoggedInNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
}

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData context:(SFSDKOAuthClientContext *)context {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self clearAccountState:clearAccountData context:context];
        });
        return;
    }

    if (clearAccountData) {
        [SFSecurityLockout clearPasscodeState];
    }
    [SFSDKWebViewStateManager removeSession];

    if (context) {
        if (context.coordinator.view) {
            [context.coordinator.view removeFromSuperview];
        }
        [context.coordinator stopAuthentication];
        context.idCoordinator.idData = nil;
        context.coordinator.credentials = nil;
    }
}

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak typeof(self) weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];

    // Invalid credentials handler
    self.invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFInvalidCredentialsAuthErrorHandler
               contextEvalBlock:^BOOL(NSError *error, SFSDKOAuthClientContext *context) {
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if ([[strongSelf class] errorIsInvalidAuthCredentials:error]) {
                       [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
                       context.authError = error;
                       [self handleFailureWithContext:context];
                       return YES;
                   }
                   return NO;
               }];
    [authHandlerList addAuthErrorHandler:self.invalidCredentialsAuthErrorHandler];

    // Connected app version mismatch handler

    self.connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFConnectedAppVersionAuthErrorHandler
            contextEvalBlock:^BOOL(NSError *error, SFSDKOAuthClientContext *context) {
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if (error.code == kSFOAuthErrorWrongVersion) {
                       [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
                       [strongSelf showAlertForConnectedAppVersionMismatchError:error context:context];
                       return YES;
                   }
                   return NO;
               }];
    [authHandlerList addAuthErrorHandler:self.connectedAppVersionAuthErrorHandler];

    // Network failure handler

    self.networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFNetworkFailureAuthErrorHandler
            contextEvalBlock:^BOOL(NSError *error, SFSDKOAuthClientContext *context) {
                   if ([[weakSelf class] errorIsNetworkFailure:error]) {
                       [SFSDKCoreLogger w:[weakSelf class] format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];

                       if (context.authInfo.authType != SFOAuthTypeRefresh) {
                           [SFSDKCoreLogger e:[weakSelf class] format:@"Network failure for non-Refresh OAuth flow (%@) is a fatal error.", context.authInfo.authTypeDescription];
                           return NO;  // Default error handler will show the error.
                       } else if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken == nil) {
                           [SFSDKCoreLogger w:[weakSelf class] format:@"Network unreachable for access token refresh, and no access token is configured.  Cannot continue."];
                           return NO;
                       } else {
                           [SFSDKCoreLogger i:[weakSelf class] format:@"Network failure for OAuth Refresh flow (existing credentials)  Try to continue."];
                           [weakSelf loggedIn:YES context:context];
                           return YES;
                       }
                   }
                   return NO;
               }];
    [authHandlerList addAuthErrorHandler:self.networkFailureAuthErrorHandler];

    // Generic failure handler
    self.genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFGenericFailureAuthErrorHandler
            contextEvalBlock:^BOOL(NSError *error, SFSDKOAuthClientContext *context) {
                   [weakSelf clearAccountState:NO context:context];
                   [weakSelf showRetryAlertForAuthError:error alertTag:kOAuthGenericAlertViewTag context:context];
                   return YES;
               }];
    [authHandlerList addAuthErrorHandler:self.genericAuthErrorHandler];
    return authHandlerList;
}

- (void)processAuthError:(NSError *)error context:(SFSDKOAuthClientContext *)context
{
    NSInteger i = 0;
    BOOL errorHandled = NO;
    NSArray *authHandlerArray = self.authErrorHandlerList.authHandlerArray;
    while (i < [authHandlerArray count] && !errorHandled) {
        SFAuthErrorHandler *currentHandler = (self.authErrorHandlerList.authHandlerArray)[i];
        errorHandled = currentHandler.evalBlock(error, context.authInfo);
        i++;
    }

    if (!errorHandled) {
        // No error handlers could handle the error.  Pass through to the error blocks.
        if (context.authInfo.authType == SFOAuthTypeUserAgent)
            self.authViewHandler.authViewDismissBlock(self);
        //[self execFailureBlocks];
        context.authError = error;
        [self handleFailureWithContext:context];
    }
}

- (void)handleFailureWithContext:(SFSDKOAuthClientContext *)context{
   [self handleFailure:context.authError context:context];
}

- (void)handleFailure:(NSError *)error  context:(SFSDKOAuthClientContext *)context{
    if( context.failureBlock ) {
        context.failureBlock(context.authInfo,error);
    }
    __weak typeof(self) weakSelf = self;
    if ([self.delegate respondsToSelector:@selector(authClientDidFail:error:context:)]) {
        [self.delegate authClientDidFail:weakSelf error:error context:context];
    }
    [self cancelAuthentication:context];
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag context:(SFSDKOAuthClientContext *)context
{
    if (self.statusAlert) {
        self.statusAlert = nil;
    }
    [SFSDKCoreLogger e:[self class] format:@"Error during authentication: %@", error];
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertRetryButtonKey]
           secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:tag
                     context:context
                       error:error];
}

- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error context:(SFSDKOAuthClientContext *)context
{
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertOkButtonKey]
           secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:kConnectedAppVersionMismatchViewTag
                     context:context
                       error:error];
}

- (void)showAlertWithTitle:(nullable NSString *)title message:(nullable NSString *)message firstButtonTitle:(nullable NSString *)firstButtonTitle secondButtonTitle:(nullable NSString *)secondButtonTitle tag:(NSInteger)tag context:(SFSDKOAuthClientContext *)context error:(NSError *)error
{
    if (nil == self.statusAlert) {
        __weak typeof(self) weakSelf = self;
        self.statusAlert = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:firstButtonTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             __strong typeof(weakSelf) strongSelf = weakSelf;
                                                             if (tag == kOAuthGenericAlertViewTag) {
                                                                 [strongSelf dismissAuthViewControllerIfPresent];
                                                                 [strongSelf fetchCredentials];
                                                             } else if (tag == kIdentityAlertViewTag) {
                                                                 [context.idCoordinator initiateIdentityDataRetrieval];
                                                             } else if (tag == kConnectedAppVersionMismatchViewTag) {
                                                                 [weakSelf handleFailure:error context:context];
                                                             } else if (tag == kAdvancedAuthDialogTag) {
                                                                 if ([strongSelf.safariViewDelegate respondsToSelector:@selector(authClientDidProceedWithBrowserFlow:)]) {
                                                                     [strongSelf.safariViewDelegate authClientDidProceedWithBrowserFlow:self];
                                                                 }
                                                                 // Let the OAuth coordinator know whether to proceed or not.
                                                                 if (context.authCoordinatorBrowserBlock) {
                                                                     context.authCoordinatorBrowserBlock(YES);
                                                                 }
                                                             }
                                                         }];
        [self.statusAlert addAction:okAction];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:secondButtonTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
                                                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                 if(tag == kAdvancedAuthDialogTag) {
                                                                     if ([strongSelf.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
                                                                         [strongSelf.safariViewDelegate authClientDidCancelBrowserFlow:self];
                                                                     }

                                                                     // Let the OAuth coordinator know whether to proceed or not.
                                                                     if (context.authCoordinatorBrowserBlock) {
                                                                         context.authCoordinatorBrowserBlock(NO);
                                                                     }
                                                                 } else if (tag == kOAuthGenericAlertViewTag){
                                                                     // Let the delegate know about the cancellation
                                                                     if ([strongSelf.safariViewDelegate respondsToSelector:@selector(authClientDidCancelGenericFlow:)]) {
                                                                         [strongSelf.safariViewDelegate authClientDidCancelGenericFlow:self];
                                                                     }
                                                                 }
                                                             }];

        [self.statusAlert addAction:cancelAction];
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            strongSelf.authWindow.viewController = [self blankViewController];
            [strongSelf.authWindow enable:YES withCompletion:^{
                [strongSelf.authWindow.viewController presentViewController:weakSelf.statusAlert animated:NO completion:nil];
            }];
        });

    }
}

-(UIViewController *) blankViewController {
    UIViewController *blankViewController = [[UIViewController alloc] init];
    [[blankViewController view] setBackgroundColor:[UIColor clearColor]];
    return blankViewController;
}

- (void)restartAuthentication:(SFSDKOAuthClientContext *) context {
    if (!context.isAuthenticating) {
        [SFSDKCoreLogger w:[self class] format:@"%@: Authentication manager is not currently authenticating.  No action taken.", NSStringFromSelector(_cmd)];
        return;
    }
    [SFSDKCoreLogger i:[self class] format:@"%@: Restarting in-progress authentication process.", NSStringFromSelector(_cmd)];
    [context.coordinator stopAuthentication];
    [self fetchCredentials];
}

#pragma mark - private class members
+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error
{
    BOOL errorIsInvalidCreds = NO;
    if (error.domain == kSFOAuthErrorDomain) {
        if (error.code == kSFOAuthErrorInvalidGrant) {
            errorIsInvalidCreds = YES;
        }
    }
    return errorIsInvalidCreds;
}

/**
 * Evaluates an NSError object to see if it represents a network failure during
 * an attempted connection.
 * @param error The NSError to evaluate.
 * @return YES if the error represents a network failure, NO otherwise.
 */
+ (BOOL)errorIsNetworkFailure:(NSError *)error
{
    BOOL isNetworkFailure = NO;

    if (error == nil || error.domain == nil)
        return isNetworkFailure;

    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorTimedOut:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorNotConnectedToInternet:
            case NSURLErrorInternationalRoamingOff:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    } else if ([error.domain isEqualToString:kSFOAuthErrorDomain]) {
        switch (error.code) {
            case kSFOAuthErrorTimeout:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    }

    return isNetworkFailure;
}


#pragma mark - SFSDKOAuthClientProvider

+ (SFSDKOAuthClient *)sharedInstance {
    if (self.clientProvider) {
        return [self.clientProvider sharedInstance];
    }

    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;

}

+ (SFSDKOAuthClient *)newInstance {
    if (self.clientProvider) {
        return [self.clientProvider newInstance];
    }
    return [[self alloc] init];;
}

@end
