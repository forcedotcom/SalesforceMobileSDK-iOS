/*
 SFSDKAuthPreferences.h
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
#include "SFOAuthCoordinator.h"
NS_ASSUME_NONNULL_BEGIN
@interface SFSDKAuthPreferences : NSObject

/**
 Advanced authentication configuration.  Default is SFOAuthAdvancedAuthConfigurationNone.  Leave the
 default value unless you need advanced authentication, as it requires an additional round trip to the
 service to retrieve org authentication configuration.
 */
@property (nonatomic, assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;

/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray * additionalOAuthParameterKeys;

/**
 A dictionary of additional parameters (key value pairs) to send during token refresh
 */
@property (nonatomic, strong) NSDictionary * additionalTokenRefreshParams;

/** The host that will be used for login.
 */
@property (nonatomic, strong, nullable) NSString *loginHost;

/** Should the login process start again if it fails (default: YES)
 */
@property (nonatomic, assign) BOOL retryLoginAfterFailure;

/** OAuth client ID to use for login.  Apps may customize
 by setting this property before login; otherwise, this
 value is determined by the SFDCOAuthClientIdPreference
 configured via the settings bundle.
 */
@property (nonatomic, copy, nullable) NSString *oauthClientId;

/** OAuth callback url to use for the OAuth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main
 bundle property SFDCOAuthRedirectUri
 */
@property (nonatomic, copy, nullable) NSString *oauthCompletionUrl;

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, copy, nullable) NSString *brandLoginPath;

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet<NSString*> *scopes;

/**  Use this property to enable an app to become and IdentityProvider for other apps
 *
 */
@property (nonatomic,assign) BOOL isIdentityProvider;

/** Check if the idp apps URI scheme  has been set.
 *
 */
@property (nonatomic,assign,readonly) BOOL idpEnabled;
/** Use this property to use SFAuthenticationManager for authentication
 *
 */
@property (nonatomic,assign) BOOL useLegacyAuthenticationManager;

/** Use this property to indicate the url scheme  for the Identity Provider app
 *
 */
@property (nonatomic, copy) NSString *idpAppURIScheme;

/** Use this property to indicate to provide a user-friendly name for your app. This name will be displayed
 *  in the user selection view of the identity provider app.
 *
 */
@property (nonatomic,copy) NSString *appDisplayName;

@end
NS_ASSUME_NONNULL_END
