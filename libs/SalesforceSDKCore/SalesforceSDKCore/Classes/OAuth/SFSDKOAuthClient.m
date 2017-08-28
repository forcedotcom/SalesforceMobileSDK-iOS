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
#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"
#import "SFSDKOAuthClientContext.h"
#import "SFSDKAuthPreferences.h"
#import "SFSDKMutableOAuthClientContext.h"
#import "SFSDKOAuthClientConfig.h"
static SFSDKOAuthClient *_sharedInstance = nil;

static SFSDKOAuthClient *_idpInstance = nil;
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


@interface SFSDKOAuthClient()<SFOAuthCoordinatorDelegate,SFIdentityCoordinatorDelegate,SFSDKLoginHostDelegate,SFLoginViewControllerDelegate>
@property (nonatomic, strong) SFSDKOAuthClientContext *_Nullable context;


- (void)revokeRefreshToken:(SFOAuthCredentials *)user;
/**
 Sets up the default error handling chain.
 @return The SFAuthErrorHandlerList instance containing the chain of error handler filters.
 */
- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList;

/**
 Processes an auth error by sending it through the chain of error handlers.
 @param error The auth error object.
 */
- (void)processAuthError:(NSError *)error;

/**
 Displays an alert in the event of an unknown failure for OAuth or Identity requests, allowing the user
 to retry the process.
 @param tag The tag that identifies the process (OAuth or Identity).
 */
- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag;

/**
 Displays an alert if the Connected App version on the server does not match the credentials of the client
 app.
 */
- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error;

@end

@implementation SFSDKOAuthClient

- (instancetype) initWithConfig:(SFSDKOAuthClientConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
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

- (SFSDKWindowContainer *) authWindow{
   return [SFSDKWindowManager sharedManager].authWindow;
}

- (BOOL)isAuthenticating {
    return _isAuthenticating;
}

- (SFOAuthCredentials *)credentials {
    return self.context.credentials;
}

- (SFIdentityData *)idData {
    return self.context.idCoordinator.idData;
}

- (SFSDKOAuthViewHandler *)authViewHandler {

    if (!self.config.authViewHandler) {
        __weak typeof(self) weakSelf = self;

        if (self.config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationNone) {
            _config.authViewHandler = [[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClient *client, SFSDKOAuthClientViewHolder *viewHandler) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (strongSelf.config.authViewController == nil) {
                            strongSelf.config.authViewController = [SFLoginViewController sharedInstance];
                            strongSelf.config.authViewController.delegate = strongSelf;
                        }
                        [strongSelf.config.authViewController setOauthView:viewHandler.wkWebView];
                        strongSelf.authWindow.viewController = strongSelf.config.authViewController;
                        [strongSelf.authWindow enable];
                    } dismissBlock:^(SFSDKOAuthClient *client) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [SFLoginViewController sharedInstance].oauthView = nil;
                        [strongSelf dismissAuthViewControllerIfPresent];
                    }];
        } else {
            _config.authViewHandler =[[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClient *client, SFSDKOAuthClientViewHolder *viewHandler) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        strongSelf.authWindow.viewController = viewHandler.safariViewController;
                        [strongSelf.authWindow enable];
                    } dismissBlock:nil];
        }

    }
    return _config.authViewHandler;
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

- (void)retrieveIdentityDataWithCompletion:(SFIdentitySuccessCallbackBlock)successBlock
                     failure:(SFIdentityFailureCallbackBlock)failureBlock {

    self.config.identitySuccessCallbackBlock = successBlock;
    self.config.identityFailureCallbackBlock = failureBlock;
    [self.context.idCoordinator initiateIdentityDataRetrieval];
}

- (BOOL)cancelAuthentication {
    [self.context.coordinator.view removeFromSuperview];
    self.context.idCoordinator.idData = nil;
    [self.context.coordinator stopAuthentication];
    self.isAuthenticating = NO;
    return YES;
}

- (BOOL)refreshCredentials {

   if (self.isAuthenticating) {
        return NO;
    }
    self.isAuthenticating = YES;
    [self.context.coordinator authenticateWithCredentials:self.context.coordinator.credentials];
    return  YES;
}

-(void)revokeCredentials {
    SFSDKOAuthClientContext *request = self.context;
    if ([self.config.delegate respondsToSelector:@selector(authClientWillRevokeCredentials:)]) {
        [self.config.delegate authClientWillRevokeCredentials:self];
    }
    [self revokeRefreshToken:request.coordinator.credentials];

    if ([self.config.delegate respondsToSelector:@selector(authClientDidRevokeCredentials:)]) {
        [self.config.delegate authClientDidRevokeCredentials:self];
    }
}

- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse {
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse"];
    [self.context.coordinator handleAdvancedAuthenticationResponse:appUrlResponse];
    return YES;
}

#pragma mark - SFLoginViewControllerDelegate

- (void)loginViewController:(SFLoginViewController *)loginViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {

    if ([self.config.delegate respondsToSelector:@selector(authClientDidChangeLoginHost:loginHost:)]) {
        [self.config.delegate authClientDidChangeLoginHost:self loginHost:newLoginHost.host];
    }
}

#pragma mark - SFSDKLoginHostDelegate
- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [hostListViewController dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)hostListViewController:(SFSDKLoginHostListViewController *)hostListViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    [SFSDKAuthPreferences sharedPreferences].loginHost = newLoginHost.host;
    if ([self.config.delegate respondsToSelector:@selector(authClientDidChangeLoginHost:loginHost:)]) {
        [self.config.delegate authClientDidChangeLoginHost:self loginHost:newLoginHost.host];
    }
}

#pragma mark - SFOAuthCoordinatorDelegate
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view {
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:willBeginAuthenticationWithView:"];
    if ([self.config.webViewDelegate respondsToSelector:@selector(authClientWillBeginAuthWithView:)]) {
        [self.config.webViewDelegate authClientWillBeginAuthWithView:self];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view {
    if ([self.config.webViewDelegate respondsToSelector:@selector(authClientDidStartAuthWebViewLoad:)]) {
        [self.config.webViewDelegate authClientDidStartAuthWebViewLoad:self];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError *)errorOrNil {
    if ([self.config.webViewDelegate respondsToSelector:@selector(authClientDidFinishAuthWebViewLoad:)]) {
        [self.config.webViewDelegate authClientDidFinishAuthWebViewLoad:self];
    }
}

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {

    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorWillBeginAuthentication"];
    if ([self.config.delegate respondsToSelector:@selector(authClientWillBeginAuthentication:)]) {
        [self.config.delegate authClientWillBeginAuthentication:self];
    }

    if (info.authType == SFOAuthTypeRefresh) {
        if ([self.config.delegate respondsToSelector:@selector(authClientWillRefreshCredentials:)]) {
            [self.config.delegate authClientWillRefreshCredentials:self];
        }
    }

}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidAuthenticate"];
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];

    if ([self.config.delegate respondsToSelector:@selector(authClientDidFinish:)]) {
        [self.config.delegate authClientDidFinish:self];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {

    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, self.context.authInfo];
    SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [SFSDKMutableOAuthClientContext mutableContext:self.context];
    mutableOAuthClientContext.authInfo = info;
    mutableOAuthClientContext.authError = error;
    self.context = mutableOAuthClientContext;
    [self processAuthError:error];
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
   // SFSDKMutableOAuthClientContext *currentRequest = [SFSDKMutableOAuthClientContext mutableContext:context];
    self.config.authCoordinatorBrowserBlock = callbackBlock;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];;
    NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowMessage"], coordinator.credentials.domain, appName];

    if (self.context.statusAlert) {
        SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [SFSDKMutableOAuthClientContext mutableContext:self.context];
        mutableOAuthClientContext.statusAlert = nil;
        self.context = mutableOAuthClientContext;
    }

    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowTitle"]
                     message:alertMessage
            firstButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"]
           secondButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertCancelButton"]
                         tag:kAdvancedAuthDialogTag
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
        [strongSelf.authWindow.viewController presentViewController:strongSelf.context.statusAlert animated:NO completion:nil];
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

    if ([self.config.webViewDelegate respondsToSelector:@selector(authClient:willDisplayAuthWebView:)]) {
        [self.config.webViewDelegate authClient:self willDisplayAuthWebView:view];
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
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didBeginAuthenticationWithSafariViewController"];
    if ([self.config.safariViewDelegate respondsToSelector:@selector(authClient:willDisplayAuthSafariViewController:)]) {
        [self.config.safariViewDelegate authClient:self willDisplayAuthSafariViewController:svc];
    }
    SFSDKOAuthClientViewHolder *viewHolder = [SFSDKOAuthClientViewHolder new];
    viewHolder.safariViewController = svc;
    viewHolder.isAdvancedAuthFlow = YES;
    self.authViewHandler.authViewDisplayBlock(self, viewHolder);
}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {
    __block BOOL handledByDelegate = NO;
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidCancelBrowserAuthentication"];
    if ([self.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
        handledByDelegate = YES;
        [self.config.safariViewDelegate authClientDidCancelBrowserFlow:self];
    }
    // If no delegates implement authManagerDidCancelBrowserFlow, display Login Host List
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        hostListViewController.delegate = self;
        self.authWindow.viewController = hostListViewController;
        [self.authWindow enable];
    }

}


#pragma mark - SFIdentityCoordinatorDelegate
- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator {
    if (self.config.identitySuccessCallbackBlock)
        self.config.identitySuccessCallbackBlock(self);
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error {
    if (error.code == kSFIdentityErrorMissingParameters) {
        // No retry, as missing parameters are fatal
        [SFSDKCoreLogger e:[self class] format:@"Missing parameters attempting to retrieve identity data.  Error domain: %@, code: %ld, description: %@", [error domain], [error code], [error localizedDescription]];
        if (self.config.identityFailureCallbackBlock)
            self.config.identityFailureCallbackBlock(self,error);
    } else {
        [SFSDKCoreLogger e:[self class] format:@"Error retrieving idData:"];
        [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag];
    }
}


#pragma mark - private methods
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials
{
    if (credentials.refreshToken != nil) {
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

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self clearAccountState:clearAccountData];
        });
        return;
    }

    if (clearAccountData) {
        [SFSecurityLockout clearPasscodeState];
    }
    [SFSDKWebViewStateManager removeSession];

    if (self.context) {
        if (self.context.coordinator.view) {
            [self.context.coordinator.view removeFromSuperview];
        }
        [self.context.coordinator stopAuthentication];
        self.context.idCoordinator.idData = nil;
        self.context.coordinator.credentials = nil;
    }
}

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak typeof(self) weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];

    // Invalid credentials handler
    if (!_config.invalidCredentialsAuthErrorHandler) {
    _config.invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFInvalidCredentialsAuthErrorHandler
               evalBlock:^BOOL(NSError *error,SFOAuthInfo *info) {
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if ([[strongSelf class] errorIsInvalidAuthCredentials:error]) {
                       [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
                       [self handleFailure:error];
                       return YES;
                   }
                   return NO;
               }];
    }
    [authHandlerList addAuthErrorHandler:self.config.invalidCredentialsAuthErrorHandler];

    // Connected app version mismatch handler
    if (!_config.connectedAppVersionAuthErrorHandler) {
        _config.connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
                initWithName:kSFConnectedAppVersionAuthErrorHandler
                evalBlock:^BOOL(NSError *error,SFOAuthInfo *info) {
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       if (error.code == kSFOAuthErrorWrongVersion) {
                           [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
                           [strongSelf showAlertForConnectedAppVersionMismatchError:error];
                           return YES;
                       }
                       return NO;
                   }];
    }
    [authHandlerList addAuthErrorHandler:self.config.connectedAppVersionAuthErrorHandler];

    // Network failure handler
    if (!_config.networkFailureAuthErrorHandler) {
        _config.networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
                initWithName:kSFNetworkFailureAuthErrorHandler
                evalBlock:^BOOL(NSError *error,SFOAuthInfo *info){
                        __strong typeof(self) strongSelf = weakSelf;
                       if ([[strongSelf class] errorIsNetworkFailure:error]) {
                           [SFSDKCoreLogger w:[weakSelf class] format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];

                           if (strongSelf.context.authInfo.authType != SFOAuthTypeRefresh) {
                               [SFSDKCoreLogger e:[weakSelf class] format:@"Network failure for non-Refresh OAuth flow (%@) is a fatal error.", strongSelf.context.authInfo.authTypeDescription];
                               return NO;  // Default error handler will show the error.
                           } else if (strongSelf.context.coordinator.credentials.accessToken == nil) {
                               [SFSDKCoreLogger w:[strongSelf class] format:@"Network unreachable for access token refresh, and no access token is configured.  Cannot continue."];
                               return NO;
                           } else {
                               [SFSDKCoreLogger i:[strongSelf class] format:@"Network failure for OAuth Refresh flow (existing credentials)  Try to continue."];
                               [strongSelf.config.delegate authClientContinueOfflineMode:strongSelf];
                               return YES;
                           }
                       }
                       return NO;
                   }];
    }
    [authHandlerList addAuthErrorHandler:_config.networkFailureAuthErrorHandler];

    // Generic failure handler
    if (!_config.genericAuthErrorHandler) {
        _config.genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                initWithName:kSFGenericFailureAuthErrorHandler
                evalBlock:^BOOL(NSError *error,SFOAuthInfo *info) {
                       __strong typeof(self) strongSelf = weakSelf;
                       [strongSelf clearAccountState:NO];
                       [strongSelf showRetryAlertForAuthError:error alertTag:kOAuthGenericAlertViewTag];
                       return YES;
                   }];
    }
    [authHandlerList addAuthErrorHandler:_config.genericAuthErrorHandler];
    return authHandlerList;
}

- (void)processAuthError:(NSError *)error
{
    NSInteger i = 0;
    BOOL errorHandled = NO;
    SFSDKOAuthClientContext *context = self.context;
    NSArray *authHandlerArray = self.config.authErrorHandlerList.authHandlerArray;
    while (i < [authHandlerArray count] && !errorHandled) {
        SFAuthErrorHandler *currentHandler = (self.config.authErrorHandlerList.authHandlerArray)[i];
        errorHandled = currentHandler.evalBlock(error, context.authInfo);
        i++;
    }

    if (!errorHandled) {
        // No error handlers could handle the error.  Pass through to the error blocks.
        if (context.authInfo.authType == SFOAuthTypeUserAgent)
            self.authViewHandler.authViewDismissBlock(self);
        [self handleFailure:error];
    }
}


- (void)handleFailure:(NSError *)error{

    if (self.config.failureCallbackBlock) {
        self.config.failureCallbackBlock(self.context.authInfo,error);
    }
    __weak typeof(self) weakSelf = self;
    if ([self.config.delegate respondsToSelector:@selector(authClientDidFail:error:)]) {
        [self.config.delegate authClientDidFail:weakSelf error:error];
    }
    [self cancelAuthentication];
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (self.context.statusAlert) {
        SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [SFSDKMutableOAuthClientContext mutableContext:self.context];
        mutableOAuthClientContext.statusAlert = nil;
        self.context = mutableOAuthClientContext;
    }
    [SFSDKCoreLogger e:[self class] format:@"Error during authentication: %@", error];
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertRetryButtonKey]
           secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:tag
                       error:error];
}

- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error
{
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertOkButtonKey]
           secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:kConnectedAppVersionMismatchViewTag
                       error:error];
}

- (void)showAlertWithTitle:(nullable NSString *)title message:(nullable NSString *)message firstButtonTitle:(nullable NSString *)firstButtonTitle secondButtonTitle:(nullable NSString *)secondButtonTitle tag:(NSInteger)tag  error:(NSError *)error
{
    if (nil == self.context.statusAlert) {
        SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [SFSDKMutableOAuthClientContext mutableContext:self.context];
        __weak typeof(self) weakSelf = self;
        mutableOAuthClientContext.statusAlert = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
        self.context = mutableOAuthClientContext;
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:firstButtonTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             __strong typeof(weakSelf) strongSelf = weakSelf;
                                                             if (tag == kOAuthGenericAlertViewTag) {
                                                                 [strongSelf dismissAuthViewControllerIfPresent];
                                                                 [strongSelf refreshCredentials];
                                                             } else if (tag == kIdentityAlertViewTag) {
                                                                 [strongSelf.context.idCoordinator initiateIdentityDataRetrieval];
                                                             } else if (tag == kConnectedAppVersionMismatchViewTag) {
                                                                 [weakSelf handleFailure:error];
                                                             } else if (tag == kAdvancedAuthDialogTag) {
                                                                 if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidProceedWithBrowserFlow:)]) {
                                                                     [strongSelf.config.safariViewDelegate authClientDidProceedWithBrowserFlow:self];
                                                                 }
                                                                 // Let the OAuth coordinator know whether to proceed or not.
                                                                 if (strongSelf.config.authCoordinatorBrowserBlock) {
                                                                     strongSelf.config.authCoordinatorBrowserBlock(YES);
                                                                 }
                                                             }
                                                         }];
        [self.context.statusAlert addAction:okAction];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:secondButtonTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
                                                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                 if(tag == kAdvancedAuthDialogTag) {
                                                                     if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
                                                                         [strongSelf.config.safariViewDelegate authClientDidCancelBrowserFlow:self];
                                                                     }

                                                                     // Let the OAuth coordinator know whether to proceed or not.
                                                                     if (self.config.authCoordinatorBrowserBlock) {
                                                                         self.config.authCoordinatorBrowserBlock(NO);
                                                                     }
                                                                 } else if (tag == kOAuthGenericAlertViewTag){
                                                                     // Let the delegate know about the cancellation
                                                                     if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelGenericFlow:)]) {
                                                                         [strongSelf.config.safariViewDelegate authClientDidCancelGenericFlow:self];
                                                                     }
                                                                 }
                                                             }];

        [self.context.statusAlert addAction:cancelAction];
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            strongSelf.authWindow.viewController = [self blankViewController];
            [strongSelf.authWindow enable:YES withCompletion:^{
                [strongSelf.authWindow.viewController presentViewController:weakSelf.context.statusAlert animated:NO completion:nil];
            }];
        });

    }
}

-(UIViewController *) blankViewController {
    UIViewController *blankViewController = [[UIViewController alloc] init];
    [[blankViewController view] setBackgroundColor:[UIColor clearColor]];
    return blankViewController;
}

- (void)restartAuthentication{
    if (!self.isAuthenticating) {
        [SFSDKCoreLogger w:[self class] format:@"%@: Authentication manager is not currently authenticating.  No action taken.", NSStringFromSelector(_cmd)];
        return;
    }
    [SFSDKCoreLogger i:[self class] format:@"%@: Restarting in-progress authentication process.", NSStringFromSelector(_cmd)];
    [self.context.coordinator stopAuthentication];
    [self refreshCredentials];
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
+ (SFSDKOAuthClient *)idpAuthInstance:(SFSDKOAuthClientConfig *)config {
    if (self.clientProvider) {
        return [self.clientProvider idpAuthInstance:config];
    }

    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        _idpInstance = [[self alloc] init];
    });
    return _idpInstance;

}

+ (SFSDKOAuthClient *)nativeBrowserAuthInstance:(SFSDKOAuthClientConfig *)config {
    if (self.clientProvider) {
        return [self.clientProvider nativeBrowserAuthInstance:config];
    }

    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        _sharedInstance = [[self alloc] initWithConfig:config];
    });
    return _sharedInstance;

}

+ (SFSDKOAuthClient *)webviewAuthInstance:(SFSDKOAuthClientConfig *)config {
    if (self.clientProvider) {
        return [self.clientProvider webviewAuthInstance:config];
    }
    return [[self alloc] initWithConfig:config];
}

+ (SFSDKOAuthClient *)clientWithContextBlock:(void(^)(SFSDKOAuthClientConfig *,SFSDKMutableOAuthClientContext *))contextBlock {
    SFSDKMutableOAuthClientContext *context = [SFSDKMutableOAuthClientContext new];
    SFSDKOAuthClientConfig *config = [SFSDKOAuthClientConfig new];
    contextBlock(config,context);
    
    SFSDKOAuthClient *instance = nil;
    if (config.advancedAuthConfiguration==SFOAuthAdvancedAuthConfigurationNone)
        instance = [self webviewAuthInstance:config];
    else
        instance = [self nativeBrowserAuthInstance:config];
    
    context.coordinator  = [[SFOAuthCoordinator alloc] initWithCredentials:context.credentials];
    context.coordinator.advancedAuthConfiguration = config.advancedAuthConfiguration;
    context.coordinator.scopes = [SFSDKAuthPreferences sharedPreferences].scopes;
    context.idCoordinator  = [[SFIdentityCoordinator alloc] initWithCredentials:context.credentials];
    context.coordinator.delegate = instance;
    context.idCoordinator.delegate = instance;
    instance.context = context;
    
    return instance;
}
@end
