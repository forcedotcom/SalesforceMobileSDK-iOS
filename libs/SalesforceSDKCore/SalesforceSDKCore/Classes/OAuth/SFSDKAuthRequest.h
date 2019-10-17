/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

NS_ASSUME_NONNULL_BEGIN
@class SFSDKAppLockViewConfig;
@class SFSDKLoginViewControllerConfig;

@interface SFSDKAuthRequest : NSObject

/**
 Indicates if the app is configured to require browser based authentication.
 */
@property (nonatomic, assign) BOOL useBrowserAuth NS_SWIFT_NAME(usesAdvancedAuthentication);
/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray<NSString *> *additionalOAuthParameterKeys;

/**
 A dictionary of additional parameters (key value pairs) to send during token refresh
 */
@property (nonatomic, strong) NSDictionary<NSString *,id> * additionalTokenRefreshParams  NS_SWIFT_NAME(additionalTokenRefreshParameters);

/** The host that will be used for login.
 */
@property (nonatomic, copy) NSString *loginHost;

/** Should the login process start again if it fails (default: YES)
 */
@property (nonatomic, assign) BOOL retryLoginAfterFailure NS_SWIFT_NAME(retriesLoginAfterFailure);

/** OAuth client ID to use for login.  Apps may customize
 by setting this property before login; otherwise, this
 value is determined by the SFDCOAuthClientIdPreference
 configured via the settings bundle.
 */
@property (nonatomic, copy) NSString *oauthClientId NS_SWIFT_NAME(oauthClientID);

/** OAuth callback url to use for the OAuth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main
 bundle property SFDCOAuthRedirectUri
 default: @"sfdc:///axm/detect/oauth/done")
 */
@property (nonatomic, copy) NSString *oauthCompletionUrl NS_SWIFT_NAME(oauthCompletionURL);

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, nullable, copy) NSString *brandLoginPath;

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet<NSString*> *scopes;

/** Use this property to indicate to provide LoginViewController customizations for themes,navbar and settigs icon.
 *
 */
@property (nonatomic,strong) SFSDKLoginViewControllerConfig *loginViewControllerConfig;

/** Use this property to indicate to provide PasscodeViewController customizations for themes,navbar, icons and settings.
 *
 */
@property (nonatomic,strong) SFSDKAppLockViewConfig *appLockViewControllerConfig;

@property (nonatomic, copy) NSString *jwtToken;

@property (nonatomic, copy, nullable) NSString *userAgentForAuth;

@end

NS_ASSUME_NONNULL_END
