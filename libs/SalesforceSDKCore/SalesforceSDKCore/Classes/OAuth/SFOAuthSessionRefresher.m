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


#import "SalesforceSDKConstants.h"

// TODO: Remove when the class is internal in Mobile SDK 15.0
SFSDK_USE_DEPRECATED_BEGIN

#import "SFOAuthSessionRefresher+Internal.h"
#import "SFUserAccountManager.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthInfo.h"
#import "SFSDKOAuth2.h"
#import "SFSDKAppFeatureMarkers.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

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
    
    __weak typeof(self) weakSelf = self;
    [SFSDKAppAttestation attestationIfEnabledFor:self.credentials.domain consumerKey:self.credentials.clientId completionHandler:^(NSString * _Nullable attestation) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf executeRefreshWithAttestation:attestation];
    }];
}

- (void)executeRefreshWithAttestation:(NSString * _Nullable)attestation {
    SFSDKOAuthTokenEndpointRequest *request = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    request.additionalOAuthParameterKeys = [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys;
    request.additionalTokenRefreshParams = [SFUserAccountManager sharedInstance].additionalTokenRefreshParams;
    request.clientID = [self.credentials getClientIdForRefresh];
    request.refreshToken = self.credentials.refreshToken;
    request.redirectURI = self.credentials.redirectUri;
    request.serverURL = [self.credentials overrideDomainIfNeeded];
    request.credentialsIdentifier = self.credentials.identifier;
    request.tokenType = self.credentials.tokenType;
    request.attestation = attestation;

    __weak typeof(self) weakSelf = self;
    id<SFSDKOAuthProtocol> authClient = [SFUserAccountManager sharedInstance].authClient();
    [authClient accessTokenForRefresh:request completion:^(SFSDKOAuthTokenEndpointResponse * response) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (response.hasError) {
            [strongSelf completeWithError:response.error.error];
        } else {
            NSString *oldRefreshToken = strongSelf.credentials.refreshToken;
            [strongSelf.credentials updateCredentials:[response asDictionary]];
            if (response.additionalOAuthFields)
                strongSelf.credentials.additionalOAuthFields = response.additionalOAuthFields;

            // Detect Refresh Token Rotation: server sent a new, different refresh token
            if (strongSelf.credentials.refreshToken.length > 0
                && ![strongSelf.credentials.refreshToken isEqualToString:oldRefreshToken]) {
                SFUserAccount *account = [[SFUserAccountManager sharedInstance]
                                           accountForCredentials:strongSelf.credentials];
                if (account) {
                    strongSelf.credentials.lastTokenRotationDate = [NSDate date];
                    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureRTR forUser:account];
                }
            }

            [strongSelf completeWithSuccess];
        }
    }];
}

#pragma mark - Private methods
- (void)completeWithSuccess {
    [SFSDKCoreLogger i:[self class] format:@"%@ Session was successfully refreshed.", NSStringFromSelector(_cmd)];
    if (self.completionBlock) {
        SFUserAccount *account = [[SFUserAccountManager sharedInstance] accountForCredentials:self.credentials];
        NSMutableDictionary *userInfo = [NSMutableDictionary new];
        if (account) {
            [userInfo setValue:account forKey:kSFNotificationUserInfoAccountKey];
        } else {
            [SFSDKCoreLogger e:[self class] format:@"%@ No account for credentials", NSStringFromSelector(_cmd)];
        }
        SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
        [userInfo setValue:authInfo forKey:kSFNotificationUserInfoAuthTypeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidRefreshToken
                                                            object:[SFUserAccountManager sharedInstance]
                                                          userInfo:userInfo];
        self.completionBlock(self.credentials);
    }
}

- (void)completeWithError:(NSError *)error {
    [SFSDKCoreLogger e:[self class] format:@"%@ Refresh failed with error: %@", NSStringFromSelector(_cmd), error];

    if (self.errorBlock) {
        self.errorBlock(error);
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

- (void)oauthCoordinatorDidBeginNativeAuthentication:(nonnull SFOAuthCoordinator *)coordinator {
    
    // Do nothing - doesn't apply to the refresh flow.
}

@end

SFSDK_USE_DEPRECATED_END
