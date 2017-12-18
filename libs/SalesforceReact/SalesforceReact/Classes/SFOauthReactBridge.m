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

#import "SFOauthReactBridge.h"
#import <React/RCTUtils.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>

NSString * const kAccessTokenCredentialsDictKey = @"accessToken";
NSString * const kRefreshTokenCredentialsDictKey = @"refreshToken";
NSString * const kClientIdCredentialsDictKey = @"clientId";
NSString * const kUserIdCredentialsDictKey = @"userId";
NSString * const kOrgIdCredentialsDictKey = @"orgId";
NSString * const kLoginUrlCredentialsDictKey = @"loginUrl";
NSString * const kInstanceUrlCredentialsDictKey = @"instanceUrl";
NSString * const kUserAgentCredentialsDictKey = @"userAgent";
SFSDK_USE_DEPRECATED_BEGIN
@implementation SFOauthReactBridge

RCT_EXPORT_MODULE();

#pragma mark - Bridged methods

RCT_EXPORT_METHOD(getAuthCredentials:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    [SFSDKReactLogger d:[self class] format:@"getAuthCredentials: arguments: %@", args];
    [self getAuthCredentialsWithCallback:callback];
}

RCT_EXPORT_METHOD(logoutCurrentUser:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    __weak typeof(self) weakSelf = self;
    [SFSDKReactLogger d:[self class] format:@"logoutCurrentUser: arguments: %@", args];
    dispatch_async(dispatch_get_main_queue(), ^{
         __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf logout];
    });
}

RCT_EXPORT_METHOD(authenticate:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    __weak typeof(self) weakSelf = self;
    [SFSDKReactLogger d:[self class] format:@"authenticate: arguments: %@", args];
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf loginWithCompletion:^(SFOAuthInfo *authInfo,SFUserAccount *userAccount) {
            [SFUserAccountManager sharedInstance].currentUser  =  userAccount;
            [strongSelf sendAuthCredentials:callback];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [strongSelf sendNotAuthenticatedError:callback];
        }];
    });
}

- (void)sendAuthCredentials:(RCTResponseSenderBlock) callback
{
    SFOAuthCredentials *creds = [SFUserAccountManager sharedInstance].currentUser.credentials;
    if (nil != creds) {
        NSString *instanceUrl = creds.instanceUrl.absoluteString;
        NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
        NSString *uaString = [SalesforceSDKManager sharedManager].userAgentString(@"");
        NSDictionary* credentialsDict = @{kAccessTokenCredentialsDictKey: creds.accessToken,
                                          kRefreshTokenCredentialsDictKey: creds.refreshToken,
                                          kClientIdCredentialsDictKey: creds.clientId,
                                          kUserIdCredentialsDictKey: creds.userId,
                                          kOrgIdCredentialsDictKey: creds.organizationId,
                                          kLoginUrlCredentialsDictKey: loginUrl,
                                          kInstanceUrlCredentialsDictKey: instanceUrl,
                                          kUserAgentCredentialsDictKey: uaString};
        callback(@[[NSNull null], credentialsDict]);
    } else {
        [self sendNotAuthenticatedError:callback];
    }
}

- (void)sendNotAuthenticatedError:(RCTResponseSenderBlock) callback
{
    callback(@[RCTMakeError(@"Not authenticated", nil, nil)]);
}

- (void)getAuthCredentialsWithCallback:(RCTResponseSenderBlock) callback
{
    SFOAuthCredentials *creds = [SFUserAccountManager sharedInstance].currentUser.credentials;
    NSString *accessToken = creds.accessToken;
    
    // If access token is not present, send error so user can manually authenticate. Otherwise, send current credentials.
    if (accessToken) {
        [self sendAuthCredentials:callback];
    } else {
        [self sendNotAuthenticatedError:callback];
    }
}

- (void)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock {
    if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
        [[SFAuthenticationManager sharedManager] loginWithCompletion:completionBlock failure:failureBlock];
    } else {
        [[SFUserAccountManager sharedInstance] loginWithCompletion:completionBlock failure:failureBlock];
    }
    
}

- (void)logout {
    if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
        [[SFAuthenticationManager sharedManager] logout];
    } else {
        [[SFUserAccountManager sharedInstance] logout];
    }
}

@end
SFSDK_USE_DEPRECATED_END
