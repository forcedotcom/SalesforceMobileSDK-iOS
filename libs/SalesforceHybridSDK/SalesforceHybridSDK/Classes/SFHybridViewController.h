/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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
#import <WebKit/WebKit.h>
#import <Cordova/CDVViewController.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFOAuthInfo.h>
#import "SFHybridViewConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 The property key used to designate the "home" URL of the app, to be used if the app is
 offline and supports HTML5 offline caching.
 */
extern NSString * const kAppHomeUrlPropKey;

//
// NSDictionary keys defining auth data properties.  See [SFHybridViewController credentialsAsDictionary].
//
extern NSString * const kAccessTokenCredentialsDictKey;
extern NSString * const kRefreshTokenCredentialsDictKey;
extern NSString * const kClientIdCredentialsDictKey;
extern NSString * const kUserIdCredentialsDictKey;
extern NSString * const kOrgIdCredentialsDictKey;
extern NSString * const kLoginUrlCredentialsDictKey;
extern NSString * const kInstanceUrlCredentialsDictKey;
extern NSString * const kUserAgentCredentialsDictKey;

/**
 Callback block definition for OAuth plugin auth success.
 */
typedef void (^SFOAuthPluginAuthSuccessBlock)(SFOAuthInfo *_Nullable, NSDictionary *);

/**
 Base view controller for Salesforce hybrid app components.
 */
@interface SFHybridViewController : CDVViewController <WKNavigationDelegate, UIWebViewDelegate>
{
    
}

/**
 Indicates if UIWebView is being used instead of WKWebView.
 */
@property (nonatomic, readonly, assign) BOOL useUIWebView;

/**
 The Remote Access object consumer key.
 */
@property (nonatomic, readonly) NSString *remoteAccessConsumerKey;

/**
 The Remote Access object redirect URI.
 */
@property (nonatomic, readonly) NSString *oauthRedirectURI;

/**
 The set of oauth scopes that should be requested for this app.
 */
@property (nonatomic, readonly) NSSet *oauthScopes;

/**
 The full config.
 */
@property (nonatomic, readonly) SFHybridViewConfig *hybridViewConfig;

/**
 The offline "home page" for the app.  Will be nil if no value has been
 found.
 */
@property (nonatomic, strong, nullable) NSURL *appHomeUrl;

/**
 Designated initializer. Initializes the view controller with its hybrid view configuration. Uses WKWebView by default.
 @param viewConfig The hybrid view configuration associated with this component.
 */
- (id) initWithConfig:(nullable SFHybridViewConfig *) viewConfig;

/**
 Designated initializer. Initializes the view controller with its hybrid view configuration and which view to use.
 @param viewConfig The hybrid view configuration associated with this component.
 @param useUIWebView YES - to use UIWebView, NO - to use WKWebView.
 */
- (id) initWithConfig:(nullable SFHybridViewConfig *) viewConfig useUIWebView:(BOOL) useUIWebView;

/**
 * Initializes a new Cordova view with the specified bounds and engine.
 */
- (UIView *)newCordovaViewWithFrameAndEngine:(CGRect)bounds webViewEngine:(NSString *)webViewEngine;

/**
 Used by the OAuth plugin to authenticate the user.
 @param completionBlock The block to call upon successsful authentication.
 @param failureBlock The block to call in the event of an auth failure.
 */
- (void)authenticateWithCompletionBlock:(nullable SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock;

/**
 Loads an error page, in the event of an otherwise unhandled error.
 @param errorCode A numberic error code associated with the error.
 @param errorDescription The error description associated with the failure.
 @param errorContext The context in which the error occurred.
 */
- (void)loadErrorPageWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext;

/**
 Convert the post-authentication credentials into a Dictionary, to return to
 the calling client code.
 @return Dictionary representation of oauth credentials.
 */
- (nullable NSDictionary *)credentialsAsDictionary;

/**
 @return The user agent string for SF hybrid apps.  @see [SalesforceSDKManager sharedManager].userAgentString @/see
 */
- (NSString *)sfHybridViewUserAgentString;

/**
 Determines whether an error that occurs during the web view load is fatal or not.  For example,
 redirects can sometimes generate an NSURLErrorCancelled error in the web view, which shouldn't
 otherwise halt the progress of the app.
 
 If this method returns YES, web view processing will stop, and the configured error page will be
 loaded with the details of the error.
 
 @param error The web view error to evaluate.
 @return YES if the error is fatal, NO otherwise.
 */
+ (BOOL)isFatalWebViewError:(NSError *)error;

/** 
 Configures the startPage property to be embedded in the context of its remote bootstrapping absolute URL. The default method configures the startPage property into a frontdoor.jsp absolute URL.
 
 Note: Do not override this method unless you know what you're doing. Improperly configuring the start page remote URL will cause your hybrid remote app to be unable to load. Your overriding method should set the startPage property to the remote URL to be loaded.
 */
- (void)configureRemoteStartPage;

/**
 Initiates a web state cleanup strategy prior to staging the web-based auth context from an
 OAuth authentication or refresh.
 
 Default behavior is to remove all of the web view cookies from .salesforce.com and .force.com
 domains.  Override this method if you wish to establish a different web state prior to the
 web-based auth context setup.
 */
- (void)webStateCleanupStrategy;

@end

NS_ASSUME_NONNULL_END
