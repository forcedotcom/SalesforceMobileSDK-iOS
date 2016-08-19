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

#import "SFOAuthCoordinator.h"

@class SFOAuthInfo;
@class SFOAuthOrgAuthConfiguration;

typedef NS_ENUM(NSUInteger, SFOAuthTokenEndpointFlow) {
    SFOAuthTokenEndpointFlowNone = 0,
    SFOAuthTokenEndpointFlowRefresh,
    SFOAuthTokenEndpointFlowIPBypass,
    SFOAuthTokenEndpointFlowAdvancedBrowser
};

@protocol SFOAuthCoordinatorFlow <NSObject>

@required

- (void)beginUserAgentFlow;
- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType;
- (void)handleTokenEndpointResponse:(NSMutableData *)data;
- (void)beginNativeBrowserFlow;
- (void)retrieveOrgAuthConfiguration:(void (^)(SFOAuthOrgAuthConfiguration*, NSError*))retrievedAuthConfigBlock;

@end

@interface SFOAuthCoordinator () <SFOAuthCoordinatorFlow>

@property (nonatomic, weak) id<SFOAuthCoordinatorFlow> oauthCoordinatorFlow;
@property (assign) BOOL authenticating;
@property (nonatomic, strong, readonly) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) BOOL initialRequestLoaded;
@property (nonatomic, copy) NSString *approvalCode;
@property (nonatomic, strong) NSTimer *refreshFlowConnectionTimer;
@property (nonatomic, strong) NSThread *refreshTimerThread;
@property (nonatomic, strong) WKWebView *view;
@property (nonatomic, strong) NSString *codeVerifier;
@property (nonatomic, strong) SFOAuthInfo *authInfo;
@property (nonatomic, readwrite) SFOAuthAdvancedAuthState advancedAuthState;
@property (nonatomic, copy) NSString *origWebUserAgent;

- (void)startRefreshFlowConnectionTimer;
- (void)stopRefreshFlowConnectionTimer;
- (void)refreshFlowConnectionTimerFired:(NSTimer *)rfcTimer;
- (void)invalidateRefreshTimer;
- (void)cleanupRefreshTimer;
- (void)handleUserAgentResponse:(NSURL *)requestUrl;

/**
 Notify our delegate that we could not log in, and clear authenticating flag
 */
- (void)notifyDelegateOfFailure:(NSError*)error authInfo:(SFOAuthInfo *)info;
/**
 Notify our delegate that login succeeded, and clear authenticating flag
 */
- (void)notifyDelegateOfSuccess:(SFOAuthInfo *)authInfo;

+ (NSDictionary *)parseQueryString:(NSString *)query;
+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description;
+ (NSDate *)timestampStringToDate:(NSString *)timestamp;

@end


