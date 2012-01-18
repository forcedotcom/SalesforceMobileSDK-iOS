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
#import "SFOAuthCredentials.h"


@class SFOAuthCoordinator;

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
    kSFOAuthErrorUnsupportedResponseType
};

/** Protocol for objects intending to be a delegate for an OAuth coordinator.
 
 Implement this protocol to receive updates from an `SFOAuthCoordinator` instance.
 Use these methods to update your interface and refresh your application once a session restarts.

 @see SFOAuthCoordinator
 */
@protocol SFOAuthCoordinatorDelegate <NSObject>

@optional

/** Sent when authentication will begin.
 
 This method supplies the delegate with the UIWebView instance, which the user will use to input their OAuth credentials 
 during the login process. At the time this method is called the UIWebView may not yet have any content loaded, 
 therefore the UIWebView should not be displayed until willBeginAuthenticationWithView:
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The UIWebView instance that will be used to conduct the authentication workflow
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view;

/** Sent when the web will starts to load its content.
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The UIWebView instance that will be used to conduct the authentication workflow
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(UIWebView *)view;

/** Sent when the web will completed to load its content.
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The UIWebView instance that will be used to conduct the authentication workflow
 @param errorOrNil  Contains the error or nil if no error
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(UIWebView *)view error:(NSError*)errorOrNil;

@required

/** Sent after authentication has begun and the view parameter is displaying the first page of authentication content.
 
 The delegate will receive this message when the first page of the authentication flow is visible in the view parameter. 
 The receiver should display the view in the implementation of this method.
 
 @warning the view parameter must be added to a superview upon completion of this method or an assert will fail
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param view        The UIWebView instance that will be used to conduct the authentication workflow
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view;

/** Sent when authentication successfully completes.
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator;

/** Sent if authentication fails due to an error.
 
 @param coordinator The SFOAuthCoordinator instance processing this message
 @param error       The error message
 
 @see SFOAuthCoordinator
 */
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error;

@end

/** The `SFOAuthCoordinator` class is the central class of the OAuth2 authentication process.
 
 This class manages a `UIWebView` instance and monitors it as it works its way
 through the various stages of the OAuth2 workflow. When authentication is complete,
 the coordinator instance extracts the necessary session information from the response
 and updates the `SFOAuthCredentials` object as necessary.
 
 @warning This class requires the following dependencies: 
 the Security framework and either the NSJSONSerialization iOS 5.0 SDK class 
 or the third party SBJsonParser class.
 */
@interface SFOAuthCoordinator : NSObject <UIWebViewDelegate> {
}

/** User credentials to use within the authentication process.
 
 @warning The behavior of this class is undefined if this property is set after `authenticate` has been called and 
 authentication has started.
 
 @see SFOAuthCredentials
 */
@property (nonatomic, retain) SFOAuthCredentials *credentials;

/** The delegate object for this coordinator. 

 The delegate is sent messages at different stages of the authentication process.
 
 @see SFOAuthCoordinatorDelegate
 */
@property (nonatomic, assign) id<SFOAuthCoordinatorDelegate> delegate;

/** Timeout interval for OAuth requests.
 
 This value controls how long requests will wait before timing out.
 */
@property (nonatomic, assign) NSTimeInterval timeout;

/** View in which the user will input OAuth credentials for the user-agent flow OAuth process.
 
 This is only guaranteed to be non-nil after one of the delegate methods returning a web view has been called.
 @see SFOAuthCoordinatorDelegate
 */
@property (nonatomic, readonly) UIWebView *view;


/** A set of scopes for OAuth.
 See: 
 https://help.salesforce.com/apex/HTViewHelpDoc?language=en&id=remoteaccess_oauth_scopes.htm
 

 Generally you need not specify this unless you are using something other than "api".
 For instances, if you are accessing Visualforce pages as well as the REST API, you could use:
 [@"api",@"Visualforce"]
 
 (You need not specify "refresh_token" -- that is always requested by this library.)

 If you do not set this property, the library does not add the "scope" parameter to the
 initial OAuth request.
 */
@property (nonatomic, copy) NSSet *scopes;


///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/** Initializes a new OAuth coordinator with the supplied credentials.
 
 @warning The value of `credentials` must not be nil.
 
 @param credentials An instance of `SFOAuthCredentials` identifying the user to be authenticated.
 @return The initialized authentication coordinator.
 
 @see SFOAuthCredentials
 */
- (id)initWithCredentials:(SFOAuthCredentials *)credentials;

///---------------------------------------------------------------------------------------
/// @name Authentication control
///---------------------------------------------------------------------------------------

/** Begins the authentication process.
 */
- (void)authenticate;

/** Returns YES if the coordinator is in the process of authentication; otherwise NO.
 */
- (BOOL)isAuthenticating;

/** Stops the authentication process.
 */
- (void)stopAuthentication;

/** Revokes the authentication credentials.
 */
- (void)revokeAuthentication;

@end
