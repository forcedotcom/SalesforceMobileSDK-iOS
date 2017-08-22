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
@class SFSDKOAuthClient;
@class WKWebView;
@class SFIdentityCoordinator;
@class SFOAuthCredentials;
@class SFOAuthInfo;
@class SFUserAccount;
@class SFLoginViewController;
@class SFSDKOAuthViewHandler;
@class SFSDKWindowContainer;
@class SFSDKOAuthClientAdvanced;
@class SFSDKOAuthClientIDP;
@class SFAuthErrorHandlerList;
@class SFAuthErrorHandler;

NS_ASSUME_NONNULL_BEGIN
/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFSDKOAuthClientSuccessCallbackBlock)(SFOAuthInfo *, SFUserAccount *_Nullable);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFSDKOAuthClientFailureCallbackBlock)(SFOAuthInfo *, NSError *_Nullable);

/** Object representing state of a current authentication context. Provides a means to isolate individual authentication
 * requests
 */
@interface SFSDKOAuthClientContext : NSObject
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, copy, nullable) SFSDKOAuthClientSuccessCallbackBlock successCallbackBlock;
@property (nonatomic, copy, nullable) SFSDKOAuthClientFailureCallbackBlock  failureBlock;
@property (nonatomic, strong, nullable) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong, nullable) SFIdentityCoordinator *idCoordinator;
@property (nonatomic, strong, nullable) SFOAuthInfo *authInfo;
@property (nonatomic, strong, nullable) NSError *authError;
@property (nonatomic, copy) SFOAuthBrowserFlowCallbackBlock authCoordinatorBrowserBlock;
@end

/** Delegate that will be used to notify of all the OAuth Client events.
 */
@protocol SFSDKOAuthClientDelegate <NSObject>

@optional
/**
 * Called when client will begin authentication.
 * @param client  initiating the request
 * @param context of the authentication
 */
- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context;

/**
 * Called when client will begin authentication.
 * @param client making the call prior to refresh credentials
 * @param context of the authentication
 */
- (void)authClientWillRefreshCredentials:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context;

/**
 * Called when client will begin authentication.
 * @param client making the call prior to revoke credentials
 * @param context of the authentication
 */
- (void)authClientWillRevokeCredentials:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context;

/**
 * Called when client will begin authentication.
 * @param client making the call prior after the  revoke of credentials
 * @param context of the authentication
 */
- (void)authClientDidRevokeCredentials:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context;

/**
 * Called when client will begin authentication.
 * @param client making the call
 * @param error describes the error that occurred
 * @param context of the call
 */
- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error context:(SFSDKOAuthClientContext *)context;

/**
 * Called by the underlying mechanism allow for detection of network state
 * @param client making the call
 */
- (BOOL)authClientIsNetworkAvailable:(SFSDKOAuthClient *)client;

/**
 * Called when client did finish authentication.
 * @param client making the call
 * @param context of the call
 */
- (void)authClientDidFinish:(SFSDKOAuthClient *)client context:(SFSDKOAuthClientContext *)context;
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

/**
 Called when a browser flow authentication is proceeded.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidProceedWithBrowserFlow:(SFSDKOAuthClient *)client;

/**
 Called when a browser flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidCancelBrowserFlow:(SFSDKOAuthClient *)client;

/**
 Called when the auth client is going to present the safari view controller.
 @param client The instance of SFSDKOAuthClient making the call.
 @param svc The instance of the safari view controller to be presented.
 */
- (void)authClient:(SFSDKOAuthClient *)client willDisplayAuthSafariViewController:(SFSafariViewController *_Nonnull)svc;

/**
 Called when a generic flow authentication is cancelled.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidCancelGenericFlow:(SFSDKOAuthClient *)client;

@end

@protocol SFSDKOAuthClientProvider
/**
 * @return Provide a sharedInstance
 */
+ (SFSDKOAuthClient *)sharedInstance;
/**
 * @return Provide a newInstance
 */
+ (SFSDKOAuthClient *)newInstance;

@end

@protocol SFSDKOAuthClient <NSObject>

/**
 The view controller used to present the authentication dialog.
 */
@property (nonatomic, strong, nullable) SFLoginViewController *authViewController;

/**
 * The authViewHandler used to present the auth workflow.
 */
@property (nonatomic, strong) SFSDKOAuthViewHandler * _Nullable authViewHandler;

/**
 * The advancedAuthConfiguration for the client
 */
@property (nonatomic, assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;

/**
 * Set a delegate to listen for all SafariViewController based auth  events
 */
@property (nonatomic, weak,nullable) id<SFSDKOAuthClientSafariViewDelegate> safariViewDelegate;

/**
 * Set a delegate to listen for all WKWebview based auth events
 */
@property (nonatomic, weak,nullable) id<SFSDKOAuthClientWebViewDelegate> webViewDelegate;

/**
 * Factory implementation. Set this factory to change the implementation of auth client provider
 */
@property (class, nonatomic, strong) id<SFSDKOAuthClientProvider> clientProvider;


@property (nonatomic, weak,nullable) id<SFSDKOAuthClientDelegate> delegate;
/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray *_Nullable additionalOAuthParameterKeys;

/**
 The auth handler for invalid credentials.
 */
@property (nonatomic, readonly) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;

/**
 The auth handler for Connected App version errors.
 */
@property (nonatomic, readonly) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;

/**
 The auth handler for failures due to network connectivity.
 */
@property (nonatomic, readonly) SFAuthErrorHandler *networkFailureAuthErrorHandler;

/**
 The generic auth handler for any unhandled errors.
 */
@property (nonatomic, readonly) SFAuthErrorHandler *genericAuthErrorHandler;

/**
 The list of auth error handler filters to pass each authentication error through.  You can add or
 remove items from this list to change the flow of auth error handling.
 */
@property (nonatomic, strong) SFAuthErrorHandlerList *authErrorHandlerList;

/**
 A dictionary of additional parameters (key value pairs) to send during token refresh
 */
@property (nonatomic, strong) NSDictionary * _Nullable additionalTokenRefreshParams;

/**
 Alert view for displaying auth-related status messages.
 */
@property (nonatomic, strong, nullable) UIAlertController *statusAlert;

/**
 * An Auth window in which the auth flow will be presented
 */
- (SFSDKWindowContainer *)authWindow;

/**
 * Get the configured client credentials
 */
- (SFOAuthCredentials *)retrieveClientCredentials;

/**
 * Retrieve cached context
 * @param credentials to use retrieve cached context
 */
- (SFSDKOAuthClientContext *_Nullable)cachedContextForCredentials:(SFOAuthCredentials *)credentials;

/**
 * Clear cached context
 *  @param credentials for which context will be removed
 */
- (void)clearContextForCredentials:(SFOAuthCredentials *)credentials;

/**
 * Cancel authentication for a given authentication context
 * @param context to cancel authentication request.
 */
- (BOOL)cancelAuthentication:(SFSDKOAuthClientContext *)context;

/**
 * Fetch credentials using configured credentials.
 * @param completionBlock to invoke when done
 * @param failureBlock to invoke when a failure occurs.
 */
- (BOOL)fetchCredentials:(SFSDKOAuthClientSuccessCallbackBlock _Nullable) completionBlock
                 failure:(SFSDKOAuthClientFailureCallbackBlock _Nullable) failureBlock;

/**
 * Refresh credentials request.
 * @param credentials to use for refresh flow.
 * @param completionBlock to invoke when done
 * @param failureBlock to invoke when a failure occurs.
 */
- (BOOL)refreshCredentials:(SFOAuthCredentials *_Nullable)credentials success:(SFSDKOAuthClientSuccessCallbackBlock _Nullable)completionBlock failure:(SFSDKOAuthClientFailureCallbackBlock _Nullable)failureBlock;

/**
 * Revoke credentials request.
 * @param credentials to revoke.
 */
- (void)revokeCredentials:(SFOAuthCredentials *_Nullable)credentials;

/**
 * Restart Authentication for a given context.
 * @param context to use.
 */
- (void)restartAuthentication:(SFSDKOAuthClientContext *) context;

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

@end


@interface SFSDKOAuthClient : NSObject<SFSDKOAuthClient,SFSDKOAuthClientProvider>

@property (nonatomic, strong, nullable) SFLoginViewController *authViewController;
@property (nonatomic, strong) SFSDKOAuthViewHandler * _Nullable authViewHandler;
@property (nonatomic, assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;
@property (nonatomic, weak, nullable) id<SFSDKOAuthClientSafariViewDelegate> safariViewDelegate;
@property (nonatomic, weak, nullable) id<SFSDKOAuthClientWebViewDelegate> webViewDelegate;
@property (class, nonatomic, strong) id<SFSDKOAuthClientProvider> clientProvider;
@property (nonatomic, weak,nullable) id<SFSDKOAuthClientDelegate> delegate;
@property (nonatomic, strong) NSArray *_Nullable additionalOAuthParameterKeys;
@property (nonatomic, readonly) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, readonly) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;
@property (nonatomic, readonly) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, readonly) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, strong) SFAuthErrorHandlerList *authErrorHandlerList;
@property (nonatomic, strong) NSDictionary * _Nullable additionalTokenRefreshParams;
@property (nonatomic, strong, nullable) UIAlertController *statusAlert;

@end

NS_ASSUME_NONNULL_END
