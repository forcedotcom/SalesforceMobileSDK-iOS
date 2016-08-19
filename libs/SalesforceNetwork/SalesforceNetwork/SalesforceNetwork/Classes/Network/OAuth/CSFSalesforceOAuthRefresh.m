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

#import "CSFSalesforceOAuthRefresh.h"
#import "CSFDefines.h"
#import "CSFAuthRefresh+Internal.h"
#import "CSFOAuthTokenRefreshOutput.h"
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "CSFInternalDefines.h"

@interface CSFSalesforceOAuthRefresh () <SFOAuthCoordinatorDelegate>

@property (nonatomic, strong) SFOAuthCoordinator *coordinator;

@end

@implementation CSFSalesforceOAuthRefresh

- (void)refreshAuth {
    SFOAuthCredentials *creds = self.network.account.credentials;
    if (!creds.instanceUrl) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                             code:CSFNetworkURLCredentialsError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not contain an instanceUrl" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    if (!creds.clientId) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                             code:CSFNetworkURLCredentialsError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 client_id set" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    if (!creds.refreshToken) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                             code:CSFNetworkURLCredentialsError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 refresh_token set" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    self.coordinator.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.coordinator authenticate];
    });
}

- (void)finishWithOutput:(CSFOutput *)refreshOutput error:(NSError *)error {
    if ([error.domain isEqualToString:kSFOAuthErrorDomain] && error.code == kSFOAuthErrorInvalidGrant) {
        NetworkInfo(@"invalid grant error received, triggering logout.");
        // make sure we call logoutUser on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SFAuthenticationManager sharedManager] logoutUser:self.network.account];
        });
    }
    
    [super finishWithOutput:refreshOutput error:error];
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    self.network.account.credentials = coordinator.credentials;
    CSFOAuthTokenRefreshOutput *output = [[CSFOAuthTokenRefreshOutput alloc] initWithCoordinator:coordinator];
    [self finishWithOutput:output error:nil];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    [self finishWithOutput:nil error:error];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {
    // Shouldn't happen (refreshAuth is guarded by the presence of a refresh token), but....
    NSString *errorString = [NSString stringWithFormat:@"%@: User Agent flow not supported for token refresh.", NSStringFromClass([self class])];
    NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkURLCredentialsError
                                     userInfo:@{ NSLocalizedDescriptionKey: errorString }];
    [coordinator stopAuthentication];
    [self finishWithOutput:nil error:error];
}

@end
