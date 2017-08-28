/*
 SFSDKOAuthClientContext.m
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
#import "SFSDKOAuthClientContext.h"
#import "SFIdentityData.h"
#import "SFSDKOAuthClient.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"
#import "SFSDKOAuthViewHandler.h"

@interface SFSDKOAuthClientContext()

@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, weak,readwrite,nullable) SFOAuthCredentials *credentials;
@property (nonatomic, weak,readwrite,nullable) id<SFSDKOAuthClientSafariViewDelegate> safariViewDelegate;
@property (nonatomic, weak,readwrite,nullable) id<SFSDKOAuthClientWebViewDelegate> webViewDelegate;
@property (nonatomic, weak,readwrite,nullable) id<SFSDKOAuthClientDelegate> delegate;

@property (nonatomic, copy, readwrite,nullable) SFAuthenticationSuccessCallbackBlock successCallbackBlock;
@property (nonatomic, copy, readwrite,nullable) SFAuthenticationFailureCallbackBlock  failureCallbackBlock;
@property (nonatomic, copy, readwrite,nullable) SFIdentitySuccessCallbackBlock identitySuccessCallbackBlock;
@property (nonatomic, copy, readwrite,nullable) SFIdentityFailureCallbackBlock  identityFailureCallbackBlock;
@property (nonatomic, copy,readwrite,nullable)  SFOAuthBrowserFlowCallbackBlock authCoordinatorBrowserBlock;

@property (nonatomic, strong, readwrite,nullable) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong, readwrite,nullable) SFIdentityCoordinator *idCoordinator;
@property (nonatomic, strong, readwrite,nullable) SFOAuthInfo *authInfo;
@property (nonatomic, strong, readwrite,nullable) NSError *authError;

@property (nonatomic,assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;
@property (nonatomic, strong, readwrite,nullable) NSArray *additionalOAuthParameterKeys;
@property (nonatomic, strong, readwrite,nullable) NSDictionary *additionalTokenRefreshParams;
@property (nonatomic, readwrite,nullable) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, readwrite,nullable) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;
@property (nonatomic, readwrite,nullable) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, readwrite,nullable) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, strong, readwrite,nullable) SFAuthErrorHandlerList *authErrorHandlerList;
@property (nonatomic, strong,readwrite,nullable) UIAlertController *statusAlert;
@end

@implementation SFSDKOAuthClientContext

@end
