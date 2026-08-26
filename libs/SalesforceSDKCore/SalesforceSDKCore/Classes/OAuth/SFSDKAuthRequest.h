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
@class SFSDKLoginViewControllerConfig;
@class UIViewController;
@protocol SFSDKLoginFlowSelectionView;
@protocol SFSDKUserSelectionView;

@interface SFSDKAuthRequest : NSObject

@property (nonatomic, assign) BOOL useBrowserAuth;

/// Per-call override for whether this authentication request should bind its
/// authorization code to DPoP (`dpop_jkt` on `/authorize`), independent of the
/// process-wide `SalesforceSDKManager.useDPoP` flag. `nil` (the default) means
/// "defer to the global flag" — normal logins never set this. A non-nil value
/// (e.g. set by a refresh-token migration) is threaded through to the
/// coordinator's `dpopOverride`.
@property (nonatomic, strong, nullable) NSNumber *useDPoP;

/// Indicates that browser auth was initiated by the "Login for Admin" action.
/// When YES, cancelling the browser session returns to the WebView login instead of showing the server picker.
@property (nonatomic, assign) BOOL loginAsAdmin;

/// Login-for-Admin override: the My Domain to authenticate against, set when
/// LFA is invoked from phase 2 of Welcome Discovery. Consulted only while
/// `loginAsAdmin == YES`; the request's `loginHost` is left unchanged so that
/// other settings actions (Reload, Clear Cache) and the post-cancel restart
/// continue to operate against the originally configured login host.
/// Cleared together with `loginAsAdmin` when the LFA browser session is cancelled.
@property (nonatomic, copy, nullable) NSString *loginAsAdminMyDomain;

/// Login-for-Admin override: the login_hint OAuth parameter to pass to the
/// browser session. Same scoping rules as `loginAsAdminMyDomain`.
@property (nonatomic, copy, nullable) NSString *loginAsAdminLoginHint;

@property (nonatomic, strong) NSArray<NSString *> *additionalOAuthParameterKeys;
@property (nonatomic, strong) NSDictionary<NSString *,id> * additionalTokenRefreshParams;
@property (nonatomic, copy) NSString *loginHost;
@property (nonatomic, assign) BOOL retryLoginAfterFailure;
@property (nonatomic, copy) NSString *oauthClientId;
@property (nonatomic, copy) NSString *oauthCompletionUrl;
@property (nonatomic, nullable, copy) NSString *brandLoginPath;
@property (nonatomic, copy) NSSet<NSString*> *scopes;
@property (nonatomic,strong) SFSDKLoginViewControllerConfig *loginViewControllerConfig;
@property (nullable, nonatomic, strong) UIScene *scene;
@property (nonatomic, copy) NSString *jwtToken;

//IDP flow related properties (SPApp related properties)
@property (nonatomic, readonly, assign) BOOL idpEnabled;
@property (nonatomic, copy) NSString *idpAppURIScheme;
@property (nonatomic, copy, nullable) NSString *userHint;
@property (nonatomic, copy, nullable) UIViewController<SFSDKLoginFlowSelectionView> * (^spAppLoginFlowSelectionAction)(void);
@property (nonatomic, copy) NSString *appDisplayName;
@property (nonatomic, assign) BOOL idpInitiatedAuth;
@property (nonatomic, copy, nullable) NSString *keychainGroup;
@property (nonatomic, copy, nullable) NSString *keychainReference;

//IDP flow related properties (IDP App related properties)
@property (nonatomic, copy, nullable) UIViewController<SFSDKUserSelectionView>* (^idpAppUserSelectionAction)(void);
@property (nonatomic, assign) BOOL authenticateRequestFromSPApp;

@end

NS_ASSUME_NONNULL_END
