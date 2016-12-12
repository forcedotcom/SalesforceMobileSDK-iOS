/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthTestFlowCoordinatorDelegate.h"
#import "SFOAuthInfo.h"

static NSString * const kWebNotSupportedExceptionName = @"com.salesforce.oauth.tests.WebNotSupported";
static NSString * const kWebNotSupportedReasonFormat  = @"%@ WKWebView transactions not supported in unit test framework.";

@implementation SFOAuthTestFlowCoordinatorDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isNetworkAvailable = YES;  // Network is available by default.
    }
    return self;
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    NSString *reason = [NSString stringWithFormat:kWebNotSupportedReasonFormat, NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:kWebNotSupportedExceptionName reason:reason userInfo:nil];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    NSString *reason = [NSString stringWithFormat:kWebNotSupportedReasonFormat, NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:kWebNotSupportedExceptionName reason:reason userInfo:nil];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    NSString *reason = [NSString stringWithFormat:kWebNotSupportedReasonFormat, NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:kWebNotSupportedExceptionName reason:reason userInfo:nil];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError*)errorOrNil {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    NSString *reason = [NSString stringWithFormat:kWebNotSupportedReasonFormat, NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:kWebNotSupportedExceptionName reason:reason userInfo:nil];
}

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.willBeginAuthenticationCalled = YES;
    self.authInfo = info;
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.didAuthenticateCalled = YES;
    self.authInfo = info;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.didFailWithErrorCalled = YES;
    self.didFailWithError = error;
    self.authInfo = info;
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator*)coordinator {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.isNetworkAvailableCalled = YES;
    return self.isNetworkAvailable;
}

@end
