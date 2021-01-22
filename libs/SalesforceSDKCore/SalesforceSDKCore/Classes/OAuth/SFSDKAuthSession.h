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
@class SFOAuthCredentials;
@class SFSDKAuthRequest;
@class SFIdentityCoordinator;
@class SFOAuthCoordinator;
@class SFOAuthInfo;
@class SFUserAccount;

@interface SFSDKAuthSession : NSObject
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, strong) SFOAuthCredentials *credentials;
@property (nonatomic, strong) SFOAuthCoordinator *oauthCoordinator;
@property (nonatomic, strong) SFSDKAuthRequest *oauthRequest;
@property (nonatomic, strong, readonly) NSString *sceneId;
@property (nonatomic, copy, nullable) void (^authSuccessCallback)(SFOAuthInfo *, SFUserAccount *);
@property (nonatomic, copy, nullable) void (^authFailureCallback)(SFOAuthInfo *, NSError *);
@property (nonatomic, strong) SFIdentityCoordinator *identityCoordinator;
@property (nonatomic, assign) BOOL notifiesDelegatesOfFailure;
@property (nonatomic, strong, nullable)NSError *authError;
@property (nonatomic, strong) SFOAuthInfo *authInfo;
@property (nonatomic, copy, nullable) void (^authCoordinatorBrowserBlock)(BOOL);
//idp related
@property (nonatomic, strong, nullable) SFOAuthCredentials *spAppCredentials;

-(instancetype)initWith:(SFSDKAuthRequest *)request credentials:(nullable SFOAuthCredentials *)creds;
-(instancetype)initWith:(SFSDKAuthRequest *)request credentials:(nullable SFOAuthCredentials *)creds spAppCredentials:(nullable SFOAuthCredentials *)spAppCredentials;
@end

NS_ASSUME_NONNULL_END
