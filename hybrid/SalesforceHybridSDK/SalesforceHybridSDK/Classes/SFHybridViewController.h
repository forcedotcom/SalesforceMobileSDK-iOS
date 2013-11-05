/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
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
#import "CDVViewController.h"
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceOAuth/SFOAuthInfo.h>
#import "SFHybridViewConfig.h"

/**
 The designator used to signify a hybrid component in the user agent.
 */
extern NSString * const kSFMobileSDKHybridDesignator;

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
typedef void (^SFOAuthPluginAuthSuccessBlock)(SFOAuthInfo *, NSDictionary *);

/**
 Base view controller for Salesforce hybrid app components.
 */
@interface SFHybridViewController : CDVViewController
{
    
}

/**
 The Remote Access object consumer key.
 */
@property (nonatomic, readonly) NSString *remoteAccessConsumerKey;

/**
 The Remote Access object redirect URI
 */
@property (nonatomic, readonly) NSString *oauthRedirectURI;

/**
 The set of oauth scopes that should be requested for this app.
 */
@property (nonatomic, readonly) NSSet *oauthScopes;

/**
 The offline "home page" for the app.  Will be nil if no value has been
 found.
 */
@property (nonatomic, strong) NSURL *appHomeUrl;

/**
 Designated initializer.  Initializes the view controller with its hybrid view configuration.
 @param viewConfig The hybrid view configuration associated with this component.
 */
- (id)initWithConfig:(SFHybridViewConfig *)viewConfig;

/**
 Method used by the OAuth plugin to obtain the current login credentials, or authenticate if no
 credentials are configured.
 @param completionBlock The OAuth plugin completion block to call upon successful retrieval of
 the credentials.
 @param failureBlock The failure block to call in the event of an authentication failure.
 */
- (void)getAuthCredentialsWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock;

/**
 Used by the OAuth plugin to authenticate the user.
 @param completionBlock The block to call upon successsful authentication.
 @param failureBlock The block to call in the event of an auth failure.
 */
- (void)authenticateWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock;

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
+ (NSDictionary *)credentialsAsDictionary;

/**
 Prepend a user agent string to the current one, based on device, application, and SDK
 version information.
 We are building a user agent of the form:
   SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) appName/appVersion Hybrid [Current User Agent]
 @return The user agent string for SF hybrid apps.
 */
+ (NSString *)sfHybridViewUserAgentString;

@end
