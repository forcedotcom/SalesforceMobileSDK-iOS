/*
 SFSDKOAuthClient.h
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
#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator.h"
#import "SFSDKOAuthClientContext.h"

@class SFSDKOAuthClientContext;
@class SFSDKMutableOAuthClientContext;
@class SFSDKOAuthClient;
@class WKWebView;
@class SFIdentityCoordinator;
@class SFOAuthCredentials;
@class SFOAuthInfo;
@class SFLoginViewController;
@class SFSDKAuthViewHandler;
@class SFSDKWindowContainer;
@class SFSDKOAuthClientAdvanced;
@class SFSDKOAuthClientIDP;
@class SFAuthErrorHandlerList;
@class SFAuthErrorHandler;
@class SFSDKOAuthClientConfig;
@class SFIdentityData;
@class SFSDKAlertMessage;
@class SFSDKLoginViewControllerConfig;
NS_ASSUME_NONNULL_BEGIN

/** Delegate that will be used to notify of all the OAuth Client events.
 */
@protocol SFSDKOAuthClientDelegate <NSObject>

/**
 Alert Messaging. The consumer of OAuthClient controls the visual display of messages in a form suited best for the consumer.
 */
- (void)authClient:(SFSDKOAuthClient *_Nonnull)client displayMessage:(SFSDKAlertMessage *) message;

@optional
/**
 * Called when client will begin authentication.
 * @param client  initiating the request
 */
- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client;

/**
 * Called when client will begin authentication.
 * @param client making the call prior to refresh credentials
 */
- (void)authClientWillRefreshCredentials:(SFSDKOAuthClient *)client;

/**
 * Called when client will begin authentication.
 * @param client making the call prior to revoke credentials
 */
- (void)authClientWillRevokeCredentials:(SFSDKOAuthClient *)client;

/**
 * Called when client will begin authentication.
 * @param client making the call prior after the  revoke of credentials
 */
- (void)authClientDidRevokeCredentials:(SFSDKOAuthClient *)client;

/**
 * Called when client will begin authentication.
 * @param client making the call
 * @param error describes the error that occurred
 */
- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error;

/**
 * Called by the underlying mechanism allow for detection of network state
 * @param client making the call
 */
- (BOOL)authClientIsNetworkAvailable:(SFSDKOAuthClient *)client;

/**
 * Called when client did finish authentication.
 * @param client making the call
 */
- (void)authClientDidFinish:(SFSDKOAuthClient *)client;

/**
 Called when error occurs offline.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientContinueOfflineMode:(SFSDKOAuthClient *)client;

/**
 Called when a generic flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidChangeLoginHost:(SFSDKOAuthClient *)client loginHost:(NSString *)newLoginHost;

/**
 Called when a generic flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientRestartAuthentication:(SFSDKOAuthClient *)client;

/**
 Called when a generic flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidCancelGenericFlow:(SFSDKOAuthClient *)client;
@end

/** Delegate that will be used to notify of all the OAuth Client WebView Events.
 */
@protocol SFSDKOAuthClientWebViewDelegate <NSObject>

@optional
/**
 Called when the Oauth Client is starting the auth process with an auth view.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientWillBeginAuthWithView:(SFSDKOAuthClient *_Nonnull)client;

/**
 Called when the auth view starts its load.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidStartAuthWebViewLoad:(SFSDKOAuthClient *_Nonnull)client;

/**
 Called when the auth view load has finished.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidFinishAuthWebViewLoad:(SFSDKOAuthClient *_Nonnull)client;

/**
 Called when the OAuth Client is going to display the auth view.
 @param client The instance of SFSDKOAuthClient making the call.
 @param view The instance of the auth view to be displayed.
 */
- (void)authClient:(SFSDKOAuthClient *_Nonnull)client willDisplayAuthWebView:(WKWebView *_Nonnull)view;
@end

/** Delegate that will be used to notify of all the OAuth Client WebView Events.
 */
@protocol SFSDKOAuthClientSafariViewDelegate <NSObject>

@optional

- (void)authClient:(SFSDKOAuthClient *)client willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock;
/**
 Called when a browser flow authentication is proceeded.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidProceedWithBrowserFlow:(SFSDKOAuthClient *)client;

/**
 Called when a browser flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (BOOL)authClientDidCancelBrowserFlow:(SFSDKOAuthClient *)client;

/**
 Called when the auth client is going to present the safari view controller.
 @param client The instance of SFSDKOAuthClient making the call.
 @param svc The instance of the safari view controller to be presented.
 */
- (void)authClient:(SFSDKOAuthClient *)client willDisplayAuthSafariViewController:(SFSafariViewController *_Nonnull)svc;

@end

@protocol SFSDKOAuthClientProvider

/**
 * @return Provide an instance of SFSDKOAuthClient for idp Authentication
 */
+ (SFSDKOAuthClient *)idpAuthInstance:(SFSDKOAuthClientConfig *_Nullable)config;

/**
 * @return Provide an instance of SFSDKOAuthClient for native browser Authentication
 */
+ (SFSDKOAuthClient *)nativeBrowserAuthInstance:(SFSDKOAuthClientConfig *_Nullable)config;

/**
 * @return Provide a newInstance
 */
+ (SFSDKOAuthClient *)webviewAuthInstance:(SFSDKOAuthClientConfig *_Nullable)config;
@end

@protocol SFSDKOAuthClient <NSObject>

/**
 * Indicates the status of Authentication
 */
@property (nonatomic, assign) BOOL isAuthenticating;

/**
 * Credentials used to create this client
 */
@property (nonatomic, readonly) SFOAuthCredentials *credentials;

/**
 * Identity data that is populated during authentication.
 */
@property (nonatomic, readonly) SFIdentityData *idData;

/**
 * The context for this client
 */
@property (nonatomic, readonly, strong, nullable) SFSDKOAuthClientContext * context;

/**
 * The Client Config that was configured
 */
@property (nonatomic, readonly,nullable) SFSDKOAuthClientConfig *config;

/**
 * An Auth window in which the auth flow will be presented
 */
- (SFSDKWindowContainer *)authWindow;

/**
 * An Auth window in which the auth flow will be presented
 */

- (void)retrieveIdentityDataWithCompletion:(SFIdentitySuccessCallbackBlock) successBlock failure:(SFIdentityFailureCallbackBlock)failureBlock;
/**
 * Cancel authentication for a given authentication context
 */
- (BOOL)cancelAuthentication:(BOOL)authenticationCanceledByUser;


/**
 * Refresh credentials request.
 */
- (BOOL)refreshCredentials;

/**
 * Revoke credentials request.
 */
- (void)revokeCredentials;

/**
 * Restart Authentication for a given context.
 */
- (void)restartAuthentication;

/**
 * Dismiss the AuthViewController if presented
 */
- (void)dismissAuthViewControllerIfPresent;

/**
 * Dismiss the Auth Window
 */
- (void)dismissAuthWindow;

/**
 * Restart Authentication for a given context.
 * @param appUrlResponse to digest.
 */
- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse;

/**
 * @return Provide an instance
 */
+ (SFSDKOAuthClient *)clientWithCredentials:(SFOAuthCredentials *_Nullable)credentials configBlock:(void(^)(SFSDKOAuthClientConfig *))configBlock;

+ (Class<SFSDKOAuthClientProvider>) clientProvider;

+ (void)setClientProvider:(Class<SFSDKOAuthClientProvider>)className;

@end

@interface SFSDKOAuthClient : NSObject<SFSDKOAuthClient, SFSDKOAuthClientProvider>
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, readonly) SFSDKOAuthClientContext *context;
@property (nonatomic, readonly,nullable) SFSDKOAuthClientConfig *config;
@property (nonatomic, readonly) SFOAuthCredentials *credentials;
@property (nonatomic, readonly) SFIdentityData *idData;
@property (nonatomic, strong) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong) SFIdentityCoordinator *idCoordinator;
- (instancetype)initWithConfig:(SFSDKOAuthClientConfig *_Nullable)config;
- (void)notifyDelegateOfFailure:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
