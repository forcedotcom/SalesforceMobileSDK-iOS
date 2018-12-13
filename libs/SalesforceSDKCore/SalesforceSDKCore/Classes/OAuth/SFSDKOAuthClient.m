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
#import "SFSDKAuthViewHandler.h"
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
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKLoginViewControllerConfig.h"
#import "SFSDKNavigationController.h"
// Auth error handler name constants
static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";
static NSString * const kSFRevokePath = @"/services/oauth2/revoke";

static Class<SFSDKOAuthClientProvider> _clientProvider = nil;

@interface SFSDKOAuthClient()<SFOAuthCoordinatorDelegate,SFIdentityCoordinatorDelegate,SFSDKLoginHostDelegate,SFLoginViewControllerDelegate>{
    NSRecursiveLock *readWriteLock;
}

@property (nonatomic, copy)  SFSDKOAuthClientContext *context;
@property (nonatomic, copy)  SFSDKOAuthClientConfig *config;
@property (nonatomic, strong) SFIdentityData *idData;

@property (nonatomic, copy,nullable) SFOAuthBrowserFlowCallbackBlock authCoordinatorBrowserBlock;
- (void)revokeRefreshToken:(SFOAuthCredentials *)user;

@end

@implementation SFSDKOAuthClient

- (instancetype) initWithConfig:(SFSDKOAuthClientConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        readWriteLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

+ (Class<SFSDKOAuthClientProvider>) clientProvider {
    return _clientProvider;
}

+ (void)setClientProvider:(Class<SFSDKOAuthClientProvider>) clientProvider  {
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

- (SFSDKAuthViewHandler *)authViewHandler {

    if (!self.config.authViewHandler) {
        [readWriteLock lock];
        __weak typeof(self) weakSelf = self;
        self.config.authViewHandler = [[SFSDKAuthViewHandler alloc]
                                       initWithDisplayBlock:^(SFSDKAuthViewHolder *viewHandler) {
                                           __strong typeof(weakSelf) strongSelf = weakSelf;
                                           [strongSelf presentLoginView:viewHandler];
                                       } dismissBlock:^() {
                                           __strong typeof(weakSelf) strongSelf = weakSelf;
                                           [strongSelf dismissAuthWindow];
                                       }];
       [readWriteLock unlock];
    }
    return self.config.authViewHandler;
}

-(void)dismissAuthViewControllerIfPresent {

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent];
        });
        return;
    }
    self.authViewHandler.authViewDismissBlock();

}

-(void)dismissAuthWindow {

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

- (void)retrieveIdentityDataWithCompletion:(SFIdentitySuccessCallbackBlock)successBlock
                     failure:(SFIdentityFailureCallbackBlock)failureBlock {
    [readWriteLock lock];
    self.config.identitySuccessCallbackBlock = successBlock;
    self.config.identityFailureCallbackBlock = failureBlock;
    self.idCoordinator.credentials = self.credentials;
    [self.idCoordinator initiateIdentityDataRetrieval];
    [readWriteLock unlock];
}

- (BOOL)cancelAuthentication:(BOOL)authenticationCanceledByUser {
    __block BOOL result = NO;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = [self cancelAuthentication:authenticationCanceledByUser];
        });
        return result;
    }
    
    [readWriteLock lock];
    if (self.isAuthenticating) {
        [self.coordinator.view removeFromSuperview];
        self.idCoordinator.idData = nil;
        [self.coordinator stopAuthentication];
        self.isAuthenticating = NO;
        result = YES;
    }
    
    if (authenticationCanceledByUser) {
        if ([self.config.delegate respondsToSelector:@selector(authClientDidCancelGenericFlow:)]) {
            [self.config.delegate authClientDidCancelGenericFlow:self];
        }
    }
    [readWriteLock unlock];
    return result;
}

- (BOOL)refreshCredentials {
    return [self refreshCredentials:self.context.credentials];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials {
    if (![NSThread isMainThread]) {
         __block BOOL result = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            result =  [self refreshCredentials:credentials];
        });
        return result;
    }
    [readWriteLock lock];
    
    if (self.config.loginHost)
        credentials.domain = self.config.loginHost;
    
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

- (void)loginViewController:(SFLoginViewController *)loginViewController didSelectBackButton:(SFSDKLoginHost *)newLoginHost {

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
    [self notifyDelegateOfFailure:error];
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator *)coordinator {
    BOOL result = YES;
    if ([self.config.delegate respondsToSelector:@selector(authClientIsNetworkAvailable:)]) {
        result = [self.config.delegate authClientIsNetworkAvailable:self];
    }
    return result;
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
    [readWriteLock unlock];
    
    if ([self.config.safariViewDelegate respondsToSelector:@selector(authClient:willBeginBrowserAuthentication:)]) {
        [self.config.safariViewDelegate authClient:self willBeginBrowserAuthentication:callbackBlock];
    }
    
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowMessage"], coordinator.credentials.domain, appName];
    
     __weak typeof(self) weakSelf = self;
    
    
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.actionTwoTitle = [SFSDKResourceUtils localizedString:@"authAlertCancelButton"];
        builder.alertTitle = [SFSDKResourceUtils localizedString:@"authAlertBrowserFlowTitle"];
        builder.alertMessage = alertMessage;
        builder.actionOneCompletion = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidProceedWithBrowserFlow:)]) {
                [strongSelf.config.safariViewDelegate authClientDidProceedWithBrowserFlow:strongSelf];
            }
            // Let the OAuth coordinator know whether to proceed or not.
            if (strongSelf.authCoordinatorBrowserBlock) {
                strongSelf.authCoordinatorBrowserBlock(YES);
            }
        };
        builder.actionTwoCompletion = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            BOOL handledByDelegate = NO;
            // Let the OAuth coordinator know whether to proceed or not.
            if ([strongSelf.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
                handledByDelegate = [strongSelf.config.safariViewDelegate authClientDidCancelBrowserFlow:strongSelf];
            }
            
            if (strongSelf.authCoordinatorBrowserBlock) {
                strongSelf.authCoordinatorBrowserBlock(NO);
            }
            // If no delegates implement authManagerDidCancelBrowserFlow, display Login Host List
            if (!handledByDelegate) {
                SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
                hostListViewController.delegate = strongSelf;
               
                [strongSelf.authWindow presentWindowAnimated:NO withCompletion:^{
                    [strongSelf.authWindow.viewController presentViewController:hostListViewController animated:NO completion:nil];
                }];
            }
            
        };
    }];
    [self.config.delegate authClient:self displayMessage:messageObject];
    
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayAlertMessage:(NSString *)message completion:(dispatch_block_t)completion {
    
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.alertTitle = @"";
        builder.actionOneCompletion = completion;
    }];
    
    [self.config.delegate authClient:self displayMessage:messageObject];
    
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayConfirmationMessage:(NSString *)message completion:(void (^)(BOOL result))completion {
    
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.actionTwoTitle = [SFSDKResourceUtils localizedString:@"authAlertCancelButton"];
        builder.alertTitle = @"";
        builder.alertMessage = message;
        builder.actionOneCompletion = ^{
            if (completion) completion(YES);
        };
        builder.actionTwoCompletion = ^{
            if (completion) completion(NO);
        };
    }];
    
    [self.config.delegate authClient:self displayMessage:messageObject];
    
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didBeginAuthenticationWithView"];

    if ([self.config.webViewDelegate respondsToSelector:@selector(authClient:willDisplayAuthWebView:)]) {
        [self.config.webViewDelegate authClient:self willDisplayAuthWebView:view];
    }
    SFLoginViewController *loginViewController = [self createLoginViewControllerInstance];
    loginViewController.oauthView = view;
    SFSDKAuthViewHolder *viewHolder = [SFSDKAuthViewHolder new];
    viewHolder.loginController = loginViewController;
    viewHolder.isAdvancedAuthFlow = NO;
    self.config.authViewController  = loginViewController;
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
    SFSDKAuthViewHolder *viewHolder = [SFSDKAuthViewHolder new];
    viewHolder.safariViewController = svc;
    viewHolder.isAdvancedAuthFlow = YES;
    self.authViewHandler.authViewDisplayBlock(viewHolder);
}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {
    __block BOOL handledByDelegate = NO;
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidCancelBrowserAuthentication"];
    if ([self.config.safariViewDelegate respondsToSelector:@selector(authClientDidCancelBrowserFlow:)]) {
        handledByDelegate = [self.config.safariViewDelegate authClientDidCancelBrowserFlow:self];
    }
    // If no delegates implement authManagerDidCancelBrowserFlow, display Login Host List
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        hostListViewController.delegate = self;
        __weak typeof (self) weakSelf = self;
        [self.authWindow presentWindowAnimated:NO withCompletion:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf.authWindow.viewController presentViewController:hostListViewController animated:NO completion:nil];
        }];
        
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
        [SFSDKCoreLogger e:[self class] format:@"Error retrieving idData:%@", error];
        __weak typeof (self) weakSelf = self;
        SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertRetryButton"];
            builder.actionTwoTitle = [SFSDKResourceUtils localizedString:@"authAlertDismissButton"];
            builder.alertTitle = [SFSDKResourceUtils localizedString:@"authAlertErrorTitle"];
            builder.alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertConnectionErrorFormatString"], [error localizedDescription]];
            
            builder.actionOneCompletion = ^{
                 [strongSelf.idCoordinator initiateIdentityDataRetrieval];
            };
        }];
        
        [self.config.delegate authClient:self displayMessage:message];
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
        SFNetwork *network = [[SFNetwork alloc] initWithEphemeralSession];
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

- (void)notifyDelegateOfFailure:(NSError *)error {
    __weak typeof(self) weakSelf = self;
    if ([self.config.delegate respondsToSelector:@selector(authClientDidFail:error:)]) {
        [self.config.delegate authClientDidFail:weakSelf error:error];
    }
}

- (void)restartAuthentication {
    if (!self.isAuthenticating) {
        [SFSDKCoreLogger w:[self class] format:@"%@: Authentication manager is not currently authenticating.  No action taken.", NSStringFromSelector(_cmd)];
        return;
    }
    [SFSDKCoreLogger i:[self class] format:@"%@: Restarting in-progress authentication process.", NSStringFromSelector(_cmd)];
    [self.coordinator stopAuthentication];
    [self refreshCredentials];
}

- (SFLoginViewController *) createLoginViewControllerInstance {
    SFLoginViewController *controller = nil;
    if (self.config.loginViewControllerConfig.loginViewControllerCreationBlock) {
        controller = self.config.loginViewControllerConfig.loginViewControllerCreationBlock();
    } else {
        controller = [[SFLoginViewController alloc] initWithNibName:nil bundle:nil];
    }
    [controller setConfig:self.config.loginViewControllerConfig];
    [controller setDelegate:self];
    return controller;
}

#pragma mark - SFSDKOAuthClientProvider
+ (SFSDKOAuthClient *)idpAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKOAuthClient * instance = nil;
    if (self.clientProvider) {
        instance = [self.clientProvider idpAuthInstance:config];
    } else {
        instance = [[SFSDKIDPAuthClient alloc] initWithConfig:config];
    }
    SFSDKMutableOAuthClientContext *context = [[SFSDKMutableOAuthClientContext alloc] initWithAuthType:SFOAuthTypeIDP];
    instance.context = context;
    return instance;
}

+ (SFSDKOAuthClient *)nativeBrowserAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKOAuthClient *instance = nil;
    if (self.clientProvider) {
        instance = [self.clientProvider nativeBrowserAuthInstance:config];
    }  else {
        instance = [[self alloc] initWithConfig:config];
    }
    SFSDKMutableOAuthClientContext *context = [[SFSDKMutableOAuthClientContext alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
    instance.context = context;
    return instance;
}

+ (SFSDKOAuthClient *)webviewAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKOAuthClient *instance = nil;
    if (self.clientProvider) {
        instance =  [self.clientProvider webviewAuthInstance:config];
    } else {
        instance = [[self alloc] initWithConfig:config];
    }
    SFSDKMutableOAuthClientContext *context = [[SFSDKMutableOAuthClientContext alloc] initWithAuthType:SFOAuthTypeUserAgent];
    instance.context = context;
    return instance;
}

+ (SFSDKOAuthClient *)webviewAuthInstanceWithRefresh:(SFSDKOAuthClientConfig *)config {
    SFSDKOAuthClient *instance = nil;
    if (self.clientProvider) {
        instance =  [self.clientProvider webviewAuthInstance:config];
    } else {
        instance = [[self alloc] initWithConfig:config];
    }
    SFSDKMutableOAuthClientContext *context = [[SFSDKMutableOAuthClientContext alloc] initWithAuthType:SFOAuthTypeRefresh];
    instance.context = context;
    return instance;
}

+ (SFSDKOAuthClient *)clientWithCredentials:(SFOAuthCredentials *)credentials configBlock:(void(^)(SFSDKOAuthClientConfig *))configBlock {
    SFSDKOAuthClientConfig *config = [[SFSDKOAuthClientConfig alloc] init];
    configBlock(config);
    SFSDKOAuthClient *instance = nil;
    if (config.idpEnabled || config.isIdentityProvider) {
        instance = [self idpAuthInstance:config];
    } else if (config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire) {
        instance = [self nativeBrowserAuthInstance:config];
    } else if (credentials.refreshToken != nil) {
        instance = [self webviewAuthInstanceWithRefresh:config];
    } else {
        instance = [self webviewAuthInstance:config];
    }
    SFSDKMutableOAuthClientContext *context = [instance.context mutableCopy];
    context.credentials = credentials;
    instance.context = context;
    instance.coordinator  = [[SFOAuthCoordinator alloc] init];
    instance.coordinator.advancedAuthConfiguration = config.advancedAuthConfiguration;
    instance.coordinator.scopes = config.scopes;
    instance.coordinator.brandLoginPath = config.brandLoginPath;
    instance.coordinator.additionalOAuthParameterKeys = config.additionalOAuthParameterKeys;
    instance.coordinator.additionalTokenRefreshParams = config.additionalTokenRefreshParams;
    instance.idCoordinator  = [[SFIdentityCoordinator alloc] init];
    instance.coordinator.delegate = instance;
    instance.idCoordinator.delegate = instance;
    return instance;
}

- (void)presentLoginView:(SFSDKAuthViewHolder *)viewHandler {
    [self.authWindow presentWindow];
    UIViewController *controllerToPresent = nil;
    
    if (viewHandler.isAdvancedAuthFlow) {
        controllerToPresent = viewHandler.safariViewController;
    } else {
        SFSDKNavigationController *navController = [[SFSDKNavigationController  alloc]  initWithRootViewController:viewHandler.loginController];
        controllerToPresent = navController;
    }
    
    __weak typeof(self) weakSelf = self;
    void (^presentViewBlock)(void) = ^void() {
        [weakSelf.authWindow.viewController presentViewController:controllerToPresent animated:NO completion:^{
            if (!viewHandler.isAdvancedAuthFlow) {
                NSAssert((nil != [viewHandler.loginController.oauthView superview]), @"No superview for oauth web view invoke [super viewDidLayoutSubviews] in the SFLoginViewController subclass");
            }
        }];
    };
    
    //dismiss if already presented and then present
    if ([self.authWindow.viewController presentedViewController]) {
        [self.authWindow.viewController.presentedViewController dismissViewControllerAnimated:NO completion:^{
            presentViewBlock();
        }];
    }else {
        presentViewBlock();
    }
}
@end
