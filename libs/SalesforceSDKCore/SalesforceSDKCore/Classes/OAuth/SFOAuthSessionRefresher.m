/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthSessionRefresher+Internal.h"
#import "SFOAuthCredentials.h"

@implementation SFOAuthSessionRefresher

- (instancetype)initWithCredentials:(SFOAuthCredentials *)credentials {
    self = [super init];
    if (self) {
        self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
        self.coordinator.delegate = self;
    }
    return self;
}

- (instancetype)init {
    return [self initWithCredentials:nil];
}

- (void)dealloc {
    if (self.coordinator.isAuthenticating) {
        [self.coordinator stopAuthentication];
    }
    self.coordinator.delegate = nil;
}

- (void)refreshSessionWithCompletion:(void (^)(SFOAuthCredentials *))completionBlock error:(void (^)(NSError *))errorBlock {
    self.completionBlock = completionBlock;
    self.errorBlock = errorBlock;
    if (self.coordinator.credentials.instanceUrl == nil) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not contain an instanceUrl" }];
        [self completeWithError:error];
        return;
    }
    
    if (self.coordinator.credentials.clientId.length == 0) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 client_id set" }];
        [self completeWithError:error];
        return;
    }
    
    if (self.coordinator.credentials.refreshToken.length == 0) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 refresh_token set" }];
        [self completeWithError:error];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coordinator authenticate];
    });
}

#pragma mark - Private methods

- (void)completeWithSuccess:(SFOAuthCredentials *)credentials {
    [self log:SFLogLevelInfo format:@"%@ Session was successfully refreshed.", NSStringFromSelector(_cmd)];
    if (self.completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(credentials);
        });
    }
}

- (void)completeWithError:(NSError *)error {
    [self log:SFLogLevelError format:@"%@ Refresh failed with error: %@", NSStringFromSelector(_cmd), error];
    if (self.errorBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.errorBlock(error);
        });
    }
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [self completeWithSuccess:coordinator.credentials];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    [self completeWithError:error];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {
    // Shouldn't happen (refreshSessionWithCompletion:error: is guarded by the presence of a refresh token), but....
    NSString *errorString = [NSString stringWithFormat:@"%@: User Agent flow not supported for token refresh.", NSStringFromClass([self class])];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                         code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                     userInfo:@{ NSLocalizedDescriptionKey: errorString }];
    [coordinator stopAuthentication];
    [self completeWithError:error];
}

@end
