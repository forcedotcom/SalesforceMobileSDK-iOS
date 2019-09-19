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

#import "SFOAuthSessionRefresher+Internal.h"
#import "SFUserAccountManager.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthInfo.h"
#import "SFSDKOAuth2.h"

@interface SFOAuthSessionRefresher()

@end
           
@implementation SFOAuthSessionRefresher

- (instancetype)initWithCredentials:(SFOAuthCredentials *)credentials {
    self = [super init];
    if (self) {
        self.credentials = credentials;
    }
    return self;
}

- (instancetype)init {
    return [self initWithCredentials:nil];
}

- (void)dealloc {
}

- (void)refreshSessionWithCompletion:(void (^)(SFOAuthCredentials *))completionBlock error:(void (^)(NSError *))errorBlock {
    self.completionBlock = completionBlock;
    self.errorBlock = errorBlock;
    if (self.credentials.instanceUrl == nil) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not contain an instanceUrl" }];
        [self completeWithError:error];
        return;
    }
    
    if (self.credentials.clientId.length == 0) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 client_id set" }];
        [self completeWithError:error];
        return;
    }
    
    if (self.credentials.refreshToken.length == 0) {
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                             code:SFOAuthSessionRefreshErrorCodeInvalidCredentials
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 refresh_token set" }];
        [self completeWithError:error];
        return;
    }
    
    SFSDKOAuthTokenEndpointRequest *request = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    request.additionalOAuthParameterKeys = [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys;
    request.additionalTokenRefreshParams = [SFUserAccountManager sharedInstance].additionalTokenRefreshParams;
    request.clientID = self.credentials.clientId;
    request.refreshToken = self.credentials.refreshToken;
    request.redirectURI = self.credentials.redirectUri;
    request.serverURL = [self.credentials overrideDomainIfNeeded];
    __weak typeof(self) weakSelf = self;
    id<SFSDKOAuthProtocol> authClient = [SFUserAccountManager sharedInstance].authClient();
    [authClient accessTokenForRefresh:request completion:^(SFSDKOAuthTokenEndpointResponse * response) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (response.hasError) {
            [strongSelf completeWithError:response.error.error];
        } else {
            [strongSelf.credentials updateCredentials:[response asDictionary]];
            if (response.additionalOAuthFields)
                strongSelf.credentials.additionalOAuthFields = response.additionalOAuthFields;
            [strongSelf completeWithSuccess];
        }
    }];
}

#pragma mark - Private methods
- (void)completeWithSuccess {
    [SFSDKCoreLogger i:[self class] format:@"%@ Session was successfully refreshed.", NSStringFromSelector(_cmd)];
    if (self.completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SFUserAccount *account = [[SFUserAccountManager sharedInstance] accountForCredentials:self.credentials];
            NSDictionary *userInfo = @{ kSFNotificationUserInfoAccountKey : account };
            [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidRefreshToken
                                                                object:self
                                                              userInfo:userInfo];
            self.completionBlock(self.credentials);
        });
    }
}

- (void)completeWithError:(NSError *)error {
    [SFSDKCoreLogger e:[self class] format:@"%@ Refresh failed with error: %@", NSStringFromSelector(_cmd), error];

    if (self.errorBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.errorBlock(error);
        });
    }
}
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithSession:(ASWebAuthenticationSession *)session {

    // Do nothing - doesn't apply to the refresh flow.
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {

    // Do nothing - doesn't apply to the refresh flow.
}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {

    // Do nothing - doesn't apply to the refresh flow.
}

@end
