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
#import "SFSDKOAuthViewHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"
#import "SFLoginViewController.h"
#import "SFSDKLoginHostDelegate.h"
#import "SFSDKOAuthClientContext.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFIdentityCoordinator.h"
#import "SFSDKWindowManager.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKLoginHost.h"
#import "SFOAuthInfo.h"
#import "SFSDKResourceUtils.h"
#import "SFNetwork.h"
#import "SFSDKWebViewStateManager.h"
#import "SFSecurityLockout.h"
#import "SFSDKIDPAuthClient.h"
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
static NSString * const kSFRevokePath = @"/services/oauth2/revoke";

static id<SFSDKOAuthClientProvider> _clientProvider = nil;


@interface SFSDKOAuthClient()<SFOAuthCoordinatorDelegate,SFIdentityCoordinatorDelegate,SFSDKLoginHostDelegate,SFLoginViewControllerDelegate>{
    NSRecursiveLock *readWriteLock;
}

@property (nonatomic, copy)  SFSDKOAuthClientContext *context;
@property (nonatomic, copy)  SFSDKOAuthClientConfig *config;
@property (nonatomic, strong) SFIdentityData *idData;

@property (nonatomic, strong) UIAlertController *statusAlert;

@property (nonatomic, copy,nullable) SFOAuthBrowserFlowCallbackBlock authCoordinatorBrowserBlock;
@property (nonatomic, strong, nullable) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, strong, nullable) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;
@property (nonatomic, strong, nullable) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, strong, nullable) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, strong, nullable) SFAuthErrorHandlerList *authErrorHandlerList;
@property (nonatomic, strong, nullable) SFSDKOAuthViewHandler *authViewHandler;

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

+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error;

@end

@implementation SFSDKOAuthClient

- (instancetype) initWithConfig:(SFSDKOAuthClientConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        readWriteLock = [[NSRecursiveLock alloc] init];
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
    return self.idCoordinator.idData;
}

- (SFSDKOAuthViewHandler *)authViewHandler {

    if (!_authViewHandler) {
        [readWriteLock lock];
        __weak typeof(self) weakSelf = self;
        if (self.config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire) {
            _authViewHandler =[[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClientViewHolder *viewHandler) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        strongSelf.authWindow.viewController = viewHandler.safariViewController;
                        [strongSelf.authWindow enable];
                    } dismissBlock:nil];
        } else {
            _authViewHandler = [[SFSDKOAuthViewHandler alloc]
                    initWithDisplayBlock:^(SFSDKOAuthClientViewHolder *viewHandler) {
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
       }
       [readWriteLock unlock];
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

- (void)retrieveIdentityDataWithCompletion:(SFIdentitySuccessCallbackBlock)successBlock
                     failure:(SFIdentityFailureCallbackBlock)failureBlock {
    [readWriteLock lock];
    self.config.identitySuccessCallbackBlock = successBlock;
    self.config.identityFailureCallbackBlock = failureBlock;
    self.idCoordinator.credentials = self.credentials;
    [self.idCoordinator initiateIdentityDataRetrieval];
    [readWriteLock unlock];
}

- (BOOL)cancelAuthentication {
    BOOL result = NO;
    [readWriteLock lock];
    if (self.isAuthenticating) {
        [self.coordinator.view removeFromSuperview];
        self.idCoordinator.idData = nil;
        [self.coordinator stopAuthentication];
        self.isAuthenticating = NO;
        result = YES;
    }
    [readWriteLock unlock];
    return result;
}

- (BOOL)refreshCredentials {
    return [self refreshCredentials:self.context.credentials];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials {
    [readWriteLock lock];
    if (self.isAuthenticating) {
        return NO;
    }
    self.isAuthenticating = YES;
    [self.coordinator authenticateWithCredentials:self.context.credentials];
    [readWriteLock unlock];
    return  YES;
}

-(void)revokeCredentials {
    [readWriteLock lock];
    SFSDKOAuthClientContext *request = self.context;
    if ([self.config.delegate respondsToSelector:@selector(authClientWillRevokeCredentials:)]) {
        [self.config.delegate authClientWillRevokeCredentials:self];
    }
    [self revokeRefreshToken:request.credentials];

    if ([self.config.delegate respondsToSelector:@selector(authClientDidRevokeCredentials:)]) {
        [self.config.delegate authClientDidRevokeCredentials:self];
    }
    [readWriteLock unlock];
}

- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse {
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse"];
    [self.coordinator handleAdvancedAuthenticationResponse:appUrlResponse];
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
    [readWriteLock lock];
    self.config.loginHost = newLoginHost.host;
    [readWriteLock unlock];
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
    SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [self.context mutableCopy];
    mutableOAuthClientContext.authInfo = info;
    mutableOAuthClientContext.authError = error;
    [readWriteLock lock];
    self.context = mutableOAuthClientContext;
    [readWriteLock unlock];
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
    [readWriteLock lock];
    self.authCoordinatorBrowserBlock = callbackBlock;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];;
    NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowMessage"], coordinator.credentials.domain, appName];

    if (self.statusAlert) {
        _statusAlert = nil;
    }
    [readWriteLock unlock];

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
            self.authViewHandler.authViewDisplayBlock(viewHolder);
        });
    } else {
        self.authViewHandler.authViewDisplayBlock(viewHolder);
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
    self.authViewHandler.authViewDisplayBlock(viewHolder);
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

        NSString *host = [NSString stringWithFormat:@"%@://%@%@?token=%@",
                        credentials.protocol, credentials.domain,
                        kSFRevokePath, credentials.refreshToken];
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
    [readWriteLock lock];
    if (clearAccountData) {
        [SFSecurityLockout clearPasscodeState];
    }
    [SFSDKWebViewStateManager removeSession];

    if (self.context) {
        if (self.coordinator.view) {
            [self.coordinator.view removeFromSuperview];
        }
        [self.coordinator stopAuthentication];
        self.idCoordinator.idData = nil;
        self.coordinator.credentials = nil;
    }
    [readWriteLock unlock];
}

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak typeof(self) weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];
     [readWriteLock lock];
    // Invalid credentials handler
    if (!_invalidCredentialsAuthErrorHandler) {
        _invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
            initWithName:kSFInvalidCredentialsAuthErrorHandler
               evalBlock:^BOOL(NSError *error,SFOAuthInfo *info) {
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if ([[strongSelf class] errorIsInvalidAuthCredentials:error]) {
                       [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
                       [strongSelf handleFailure:error];
                       return YES;
                   }
                   return NO;
               }];
    }
    [authHandlerList addAuthErrorHandler:_invalidCredentialsAuthErrorHandler];

    // Connected app version mismatch handler
    if (!_connectedAppVersionAuthErrorHandler) {
        _connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
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
    [authHandlerList addAuthErrorHandler:_connectedAppVersionAuthErrorHandler];

    // Network failure handler
    if (!_networkFailureAuthErrorHandler) {
        _networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
                initWithName:kSFNetworkFailureAuthErrorHandler
                evalBlock:^BOOL(NSError *error,SFOAuthInfo *info){
                        __strong typeof(self) strongSelf = weakSelf;
                       if ([[strongSelf class] errorIsNetworkFailure:error]) {
                           [SFSDKCoreLogger w:[weakSelf class] format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];

                           if (strongSelf.context.authInfo.authType != SFOAuthTypeRefresh) {
                               [SFSDKCoreLogger e:[weakSelf class] format:@"Network failure for non-Refresh OAuth flow (%@) is a fatal error.", strongSelf.context.authInfo.authTypeDescription];
                               return NO;  // Default error handler will show the error.
                           } else if (strongSelf.coordinator.credentials.accessToken == nil) {
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
    [authHandlerList addAuthErrorHandler:_networkFailureAuthErrorHandler];

    // Generic failure handler
    if (!_genericAuthErrorHandler) {
        _genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                initWithName:kSFGenericFailureAuthErrorHandler
                evalBlock:^BOOL(NSError *error,SFOAuthInfo *info) {
                       __strong typeof(self) strongSelf = weakSelf;
                       [strongSelf clearAccountState:NO];
                       [strongSelf showRetryAlertForAuthError:error alertTag:kOAuthGenericAlertViewTag];
                       return YES;
                   }];
    }
    [authHandlerList addAuthErrorHandler:_genericAuthErrorHandler];
    [readWriteLock unlock];
    return authHandlerList;
}

- (void)processAuthError:(NSError *)error
{
    NSInteger i = 0;
    BOOL errorHandled = NO;
    SFSDKOAuthClientContext *context = self.context;
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
    if (self.statusAlert) {
        self.statusAlert = nil;
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
                                                                 [strongSelf refreshCredentials];
                                                             } else if (tag == kIdentityAlertViewTag) {
                                                                 [strongSelf.idCoordinator initiateIdentityDataRetrieval];
                                                             } else if (tag == kConnectedAppVersionMismatchViewTag) {
                                                                 [weakSelf handleFailure:error];
                                                             } else if (tag == kAdvancedAuthDialogTag) {
                                                                 if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidProceedWithBrowserFlow:)]) {
                                                                     [strongSelf.config.safariViewDelegate authClientDidProceedWithBrowserFlow:self];
                                                                 }
                                                                 // Let the OAuth coordinator know whether to proceed or not.
                                                                 if (strongSelf.authCoordinatorBrowserBlock) {
                                                                     strongSelf.authCoordinatorBrowserBlock(YES);
                                                                 }
                                                             }
                                                         }];
        [self.statusAlert addAction:okAction];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:secondButtonTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
                                                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                 if(tag == kAdvancedAuthDialogTag) {
                                                                     if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
                                                                         [strongSelf.config.safariViewDelegate authClientDidCancelBrowserFlow:self];
                                                                     }

                                                                     // Let the OAuth coordinator know whether to proceed or not.
                                                                     if (self.authCoordinatorBrowserBlock) {
                                                                         self.authCoordinatorBrowserBlock(NO);
                                                                     }
                                                                 } else if (tag == kOAuthGenericAlertViewTag){
                                                                     // Let the delegate know about the cancellation
                                                                     if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelGenericFlow:)]) {
                                                                         [strongSelf.config.safariViewDelegate authClientDidCancelGenericFlow:self];
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

- (void)showAlertMessage:(NSString *)message withCompletion:(void (^)(void)) completionBlock{
    NSString *decodedMessage = [message  stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"IDP Authentication Failure"                                                     message:decodedMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    //We add buttons to the alert controller by creating UIAlertActions:
    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]; //You can use a block here to handle a press on this button
    [alertController addAction:actionOk];
    
    
    [self.authWindow.viewController presentViewController:alertController animated:YES completion:completionBlock];
}

- (void)showAlertMessage:(NSString *)message withSuccess:(void (^)(void)) successCompletionBlock failure:(void (^)(void)) cancelCompletionBlock{
    NSString *decodedMessage = [message  stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"IDP Authentication Failure"                                                     message:decodedMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if( successCompletionBlock )
            successCompletionBlock();
    }];
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if( cancelCompletionBlock )
            cancelCompletionBlock();
    }];
    [alertController addAction:actionOk];
    [alertController addAction:actionCancel];
    
    [self.authWindow.viewController presentViewController:alertController animated:YES completion:nil];
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
    [self.coordinator stopAuthentication];
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
    return [[SFSDKIDPAuthClient alloc] initWithConfig:config];

}

+ (SFSDKOAuthClient *)nativeBrowserAuthInstance:(SFSDKOAuthClientConfig *)config {
    if (self.clientProvider) {
        return [self.clientProvider nativeBrowserAuthInstance:config];
    }

   return [[self alloc] initWithConfig:config];

}

+ (SFSDKOAuthClient *)webviewAuthInstance:(SFSDKOAuthClientConfig *)config {
    if (self.clientProvider) {
        return [self.clientProvider webviewAuthInstance:config];
    }
    return [[self alloc] initWithConfig:config];
}

+ (SFSDKOAuthClient *)clientWithCredentials:(SFOAuthCredentials *)credentials configBlock:(void(^)(SFSDKOAuthClientConfig *))configBlock {

    SFSDKOAuthClientConfig *config = [[SFSDKOAuthClientConfig alloc] init];
    SFSDKMutableOAuthClientContext *context = [[SFSDKMutableOAuthClientContext alloc] init];
    configBlock(config);
    SFSDKOAuthClient *instance = nil;
    
    if (config.idpEnabled || config.isIdentityProvider)
        instance = [self idpAuthInstance:config];
    else if (config.advancedAuthConfiguration==SFOAuthAdvancedAuthConfigurationRequire)
         instance = [self nativeBrowserAuthInstance:config];
    else
        instance = [self webviewAuthInstance:config];

    context.credentials = credentials;
    instance.context = context;
    instance.coordinator  = [[SFOAuthCoordinator alloc] init];
    instance.coordinator.advancedAuthConfiguration = config.advancedAuthConfiguration;
    instance.coordinator.scopes = config.scopes;
    instance.idCoordinator  = [[SFIdentityCoordinator alloc] init];
    instance.coordinator.delegate = instance;
    instance.idCoordinator.delegate = instance;
    
    return instance;
}
@end
