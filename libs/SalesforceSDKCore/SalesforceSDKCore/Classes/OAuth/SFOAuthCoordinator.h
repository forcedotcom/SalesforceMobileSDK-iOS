/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "SFOAuthCredentials.h"

@class SFOAuthCoordinator;
@class SFOAuthInfo;

/** SFOAuth default network timeout in seconds.
 */
extern const NSTimeInterval kSFOAuthDefaultTimeout;

/** This constant defines the SFOAuth framework error domain.
 
 Domain indicating an error occurred during OAuth authentication.
 */
extern NSString * const kSFOAuthErrorDomain;

/** 
 @enum SFOAuthErrorDomain related error codes
 Constants used by SFOAuthCoordinator to indicate errors in the SFOAuth domain
 */
enum {
    kSFOAuthErrorUnknown = 666,
    kSFOAuthErrorTimeout,
    kSFOAuthErrorMalformed,
    kSFOAuthErrorAccessDenied,              // end user denied authorization
    kSFOAuthErrorInvalidClientId,
    kSFOAuthErrorInvalidClientCredentials,  // client secret invalid
    kSFOAuthErrorInvalidGrant,              // expired access/refresh token, or IP restricted, or invalid login hours
    kSFOAuthErrorInvalidRequest,
    kSFOAuthErrorInactiveUser,
    kSFOAuthErrorInactiveOrg,
    kSFOAuthErrorRateLimitExceeded,
    kSFOAuthErrorUnsupportedResponseType,
    kSFOAuthErrorWrongVersion,              // credentials do not match current Connected App version in the org
    kSFOAuthErrorBrowserLaunchFailed,
    kSFOAuthErrorUnknownAdvancedAuthConfig,
    kSFOAuthErrorInvalidMDMConfiguration,
    kSFOAuthErrorJWTInvalidGrant
};

/**
 Enumeration of advanced auth configuration.
 */
typedef NS_ENUM(NSUInteger, SFOAuthAdvancedAuthConfiguration) {
    /**
     Advanced authentication is not configured (default)
     */
    SFOAuthAdvancedAuthConfigurationNone = 0,
    
    /**
     Advanced authentication is allowed.  Coordinator will attempt to retrieve advanced auth
     configuration from the org, to determine whether to initiate advanced authentication.
     */
    SFOAuthAdvancedAuthConfigurationAllow,
    
    /**
     Advanced authentication is required.  Coordinator will initiate advanced authentication
     regardless of org settings.
     */
    SFOAuthAdvancedAuthConfigurationRequire
};

/**
 Enumeration of different advanced authentication stages.
 */
typedef NS_ENUM(NSUInteger, SFOAuthAdvancedAuthState) {
    /**
     No advanced authentication is currently under way.
     */
    SFOAuthAdvancedAuthStateNotStarted = 0,
    
    /**
     The advanced authentication flow has initiated a request through the external browser (Safari).
     */
    SFOAuthAdvancedAuthStateBrowserRequestInitiated,
    
    /**
     The advanced authentication flow has received a response from the external browser, and has
     initiated a token exchange request.
     */
    SFOAuthAdvancedAuthStateTokenRequestInitiated
};

/**
 Callback block used for the browser flow authentication.
 @see oauthCoordinator:willBeginBrowserAuthentication:
 */
typedef void (^SFOAuthBrowserFlowCallbackBlock)(BOOL);

/** Protocol for objects intending to be a delegate for an OAuth coordinator.
 
 Implement this protocol to receive updates from an `SFOAuthCoordinator` instance.
 Use these methods to update your interface and refresh your application once a session restarts.

 @see SFOAuthCoordinator
 */
@protocol SFOAuthCoordinatorDelegate <NSObject>

@optional

/** Sent when authentication will begin.
 
 This method supplies the delegate with the WKWebView instance, which the user will use to input their OAuth credentials
 during the login process. At the time this method is called the WKWebView may not yet have any content loaded,
 therefore the WKWebView should not be displayed until willBeginAuthenticationWithView:
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The WKWebView instance that will be used to conduct the authentication workflow
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view;

/** Sent when the web will starts to load its content.
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The WKWebView instance that will be used to conduct the authentication workflow
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view;


/** Sent when the web will completed to load its content.
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The WKWebView instance that will be used to conduct the authentication workflow
 @param errorOrNil  Contains the error or `nil` if no error
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError*)errorOrNil;

/**
 Sent when authentication successfully completes. Note: This method is deprecated.  You should use
 the `oauthCoordinatorDidAuthenticate:authInfo:` method instead.
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator __attribute__((deprecated));

/**
 Sent before oauthcoordinator will begin any kind of authentication
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param info The SFOAuthInfo instance containing details about the type of authentication.
 */
- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info;

/**
 Sent when authentication successfully completes.
 
 @param coordinator The SFOAuthCoordinator instance processing this message.
 @param info Object containing info associated with this authentication attempt.
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info;

/**
 Sent if authentication fails due to an error. Note: This method is deprecated.  You should use the
 `oauthCoordinator:didFailWithError:authInfo` method instead.
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param error       The error message
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error __attribute__((deprecated));

/**
 Sent if authentication fails due to an error.
 
 @param coordinator The SFOAuthCoordinator instance processing this message.
 @param error       The error associated with the failure.
 @param info        Object containing info associated with the authentication attempt.
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info;

/**
 The delegate can implement this method to return a BOOL indicating whether the network is available.
 @param coordinator The SFOAuthCoordinator object to be queried (typically self).
 */
- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator*)coordinator;

/**
 Sent to notify the delegate that a browser authentication flow is about to begin.
 
 If the delegate implements this method, it is responsible for using the callbackBlock to let the coordinator know
 whether it should proceed with the browser flow or not.
 
 @param coordinator   The SFOAuthCoordinator instance processing this message.
 @param callbackBlock A callback block used to notify the coordinator if it should continue with the authentication flow.
 Pass in YES to proceed, NO to cancel the authentication flow.
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock;

/**
 Whether or not the coordinator retries browser authentication when the coordinator has not handled the browser response prior
 to application did become active event.
 
 @discussion
 Ideally the coordinator (via `-handleAdvancedAuthenticationResponse:`) should handle the browser response
 on your app delegate method `-application:openURL:sourceApplication:annotation:`.
 If your coordinator handles the browser response at any point after the application did become active notification is sent,
 this method should be implemented and return NO to disable the browser authentication auto-retry flow.
 
 The coordinator will auto retry authentication if this method is not implemented.
 */
- (BOOL)oauthCoordinatorRetryAuthenticationOnApplicationDidBecomeActive:(SFOAuthCoordinator *)coordinator;

@required

/** Sent after authentication has begun and the view parameter is displaying the first page of authentication content.
 
 The delegate will receive this message when the first page of the authentication flow is visible in the view parameter. 
 The receiver should display the view in the implementation of this method.
 
 @warning the view parameter must be added to a superview upon completion of this method or an assert will fail
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The WKWebView instance that will be used to conduct the authentication workflow
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view;

@end

/** The `SFOAuthCoordinator` class is the central class of the OAuth2 authentication process.
 
 This class manages a `WKWebView` instance and monitors it as it works its way
 through the various stages of the OAuth2 workflow. When authentication is complete,
 the coordinator instance extracts the necessary session information from the response
 and updates the `SFOAuthCredentials` object as necessary.
 
 @warning This class requires the following dependencies: 
 the Security framework and either the NSJSONSerialization iOS 5.0 SDK class 
 or the third party SBJsonParser class.
 */
@interface SFOAuthCoordinator : NSObject <WKNavigationDelegate> {
}

/** User credentials to use within the authentication process.
 
 @warning The behavior of this class is undefined if this property is set after `authenticate` has been called and 
 authentication has started.
 @warning This property must not be `nil` at the time the `authenticate` method is called or an exception will be raised.
 
 @see SFOAuthCredentials
 */
@property (nonatomic, strong) SFOAuthCredentials *credentials;

/** The delegate object for this coordinator. 

 The delegate is sent messages at different stages of the authentication process.
 
 @see SFOAuthCoordinatorDelegate
 */
@property (nonatomic, weak) id<SFOAuthCoordinatorDelegate> delegate;

/** A set of scopes for OAuth.
 See: 
 https://help.salesforce.com/apex/HTViewHelpDoc?language=en&id=remoteaccess_oauth_scopes.htm
 
 Generally you need not specify this unless you are using something other than the "api" scope.
 For instance, if you are accessing Visualforce pages as well as the REST API, you could use:
 [@"api", @"visualforce"]
 
 (You need not specify the "refresh_token" scope as this is always requested by this library.)
 
 If you do not set this property, the library does not add the "scope" parameter to the initial
 OAuth request, which implicitly sets the scope to include: "id", "api", and "refresh_token".
 */
@property (nonatomic, copy) NSSet *scopes;


/** Timeout interval for OAuth requests.
 
 This value controls how long requests will wait before timing out.
 */
@property (nonatomic, assign) NSTimeInterval timeout;

/**
 The configuration for advanced authentication.  Default is SFOAuthAdvancedAuthConfigurationNone.
 Keep the default value if you don't need advanced authentication options, as this requires an
 additional round trip to the service to get authentication configuration data.
 */
@property (nonatomic, assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;

/**
 The current state of any in-progress advanced authentication flow.
 */
@property (nonatomic, readonly) SFOAuthAdvancedAuthState advancedAuthState;

/** View in which the user will input OAuth credentials for the user-agent flow OAuth process.
 
 This is only guaranteed to be non-`nil` after one of the delegate methods returning a web view has been called.
 @see SFOAuthCoordinatorDelegate
 */
@property (nonatomic, readonly) WKWebView *view;

/**
 The user agent string that will be used for authentication.  While this property will persist throughout
 the lifetime of the coordinator object, the user agent configured for the system will be reset back to
 its original value in between authentication requests.
 */
@property (nonatomic, copy) NSString *userAgentForAuth;

/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray * additionalOAuthParameterKeys;
///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/** Initializes a new OAuth coordinator with the supplied credentials. This is the designated initializer.
 
 @warning Although it is permissible to pass `nil` for the credentials argument, the credentials propery
 must not be `nil` prior to calling the `authenticate` method or an exception will be raised.
 
 @param credentials An instance of `SFOAuthCredentials` identifying the user to be authenticated.
 @return The initialized authentication coordinator.
 
 @see SFOAuthCredentials
 */
- (id)initWithCredentials:(SFOAuthCredentials *)credentials;

///---------------------------------------------------------------------------------------
/// @name Authentication control
///---------------------------------------------------------------------------------------

/** Begins the authentication process.
 
 @exception NSInternalInconsistencyException If called when the `credentials` property is `nil`.
 */
- (void)authenticate;

/**
 * Sets the credentials property and begins the authentication process. Simply a convenience method for:
 *   `coordinator.credentials = theCredentials;`
 *   `[coordinator authenticate];`
 * @param credentials The OAuth credentials used for authentication.
 * @exception NSInternalInconsistencyException If called with a `nil` `credentials` argument.
 */
- (void)authenticateWithCredentials:(SFOAuthCredentials *)credentials;

/** Returns YES if the coordinator is in the process of authentication; otherwise NO.
 */
- (BOOL)isAuthenticating;

/** Stops the authentication process.
 */
- (void)stopAuthentication;

/** Revokes the authentication credentials.
 */
- (void)revokeAuthentication;

/**
 Handle an advanced authentication response from the external browser, continuing any
 in-progress adavanced authentication flow.
 @param appUrlResponse The URL response returned to the app from the external browser.
 @return YES if this is a valid URL response from advanced authentication that the coordinator
 should handle, NO otherwise.
 */
- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse;

@end
