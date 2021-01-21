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
@class UIViewController;
@protocol SFSDKLoginFlowSelectionView;
@protocol SFSDKUserSelectionView;

@interface SFSDKAuthRequest : NSObject

@property (nonatomic, assign) BOOL useBrowserAuth;
@property (nonatomic, strong) NSArray<NSString *> *additionalOAuthParameterKeys;
@property (nonatomic, strong) NSDictionary<NSString *,id> * additionalTokenRefreshParams;
@property (nonatomic, copy) NSString *loginHost;
@property (nonatomic, assign) BOOL retryLoginAfterFailure;
@property (nonatomic, copy) NSString *oauthClientId;
@property (nonatomic, copy) NSString *oauthCompletionUrl;
@property (nonatomic, nullable, copy) NSString *brandLoginPath;
@property (nonatomic, copy) NSSet<NSString*> *scopes;
@property (nonatomic,strong) SFSDKLoginViewControllerConfig *loginViewControllerConfig;
@property (nonatomic,strong) SFSDKAppLockViewConfig *appLockViewControllerConfig;
@property (nullable, nonatomic, strong) UIScene *scene;
@property (nonatomic, copy) NSString *jwtToken;
@property (nonatomic, copy, nullable) NSString *userAgentForAuth;

//IDP flow related properties (SPApp related properties)
@property (nonatomic, readonly, assign) BOOL idpEnabled;
@property (nonatomic, copy) NSString *idpAppURIScheme;
@property (nonatomic, copy, nullable) NSString *userHint;
@property (nonatomic, copy, nullable) UIViewController<SFSDKLoginFlowSelectionView> * (^spAppLoginFlowSelectionAction)(void);
@property (nonatomic, copy) NSString *appDisplayName;
@property (nonatomic, assign) BOOL idpInitiatedAuth;

//IDP flow related properties (IDP App related properties)
@property (nonatomic, copy, nullable) UIViewController<SFSDKUserSelectionView>* (^idpAppUserSelectionAction)(void);
@property (nonatomic, assign) BOOL authenticateRequestFromSPApp;

@end

NS_ASSUME_NONNULL_END
