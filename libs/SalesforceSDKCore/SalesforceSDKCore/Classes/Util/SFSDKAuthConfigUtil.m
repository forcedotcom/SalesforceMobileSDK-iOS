/*
 SFSDKAuthConfigUtil.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 2/4/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKAuthConfigUtil.h"
#import "SFNetwork.h"
#import <SalesforceSDKCommon/SFJsonUtils.h>

static NSString * const kSFOAuthEndPointAuthConfiguration = @"/.well-known/auth-configuration";
static NSString * const kSandboxLoginURL = @"test.salesforce.com";
static NSString * const kProductionLoginURL = @"login.salesforce.com";
static NSString * const kWelcomeLoginURL = @"welcome.salesforce.com";

@implementation SFSDKAuthConfigUtil

+ (void)getMyDomainAuthConfig:(MyDomainAuthConfigBlock)authConfigBlock loginDomain:(NSString *)loginDomain {
    NSString *orgConfigUrl = [NSString stringWithFormat:@"https://%@%@", loginDomain, kSFOAuthEndPointAuthConfiguration];
    if ([loginDomain isEqualToString:kSandboxLoginURL] || [loginDomain isEqualToString:kProductionLoginURL] || [loginDomain isEqualToString:kWelcomeLoginURL]) {
        [SFSDKCoreLogger d:[self class] format:@"%@ Skipping auth config retrieval for login pool URL", NSStringFromSelector(_cmd)];
        authConfigBlock(nil, nil);
        return;
    }
    [SFSDKCoreLogger i:[self class] format:@"%@ Checking if advanced authentication configured. Retrieving auth configuration from %@", NSStringFromSelector(_cmd), orgConfigUrl];
    NSMutableURLRequest *orgConfigRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:orgConfigUrl]];
    SFNetwork *network = [SFNetwork sharedEphemeralInstance];
    __weak __typeof(self) weakSelf = self;
    [network sendRequest:orgConfigRequest dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            [SFSDKCoreLogger w:[strongSelf class] format:@"Org config request failed with error: Error Code: %ld, Description: %@", (long) error.code, error.localizedDescription];
            authConfigBlock(nil, error);
            return;
        }
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

        // 2xx indicates success.
        if (statusCode >= 200 && statusCode <= 299) {

            // Checks if the server returned any data.
            if (data == nil) {
                [SFSDKCoreLogger w:[strongSelf class] format:@"No org auth config data returned from %@", orgConfigUrl];
                authConfigBlock(nil, nil);
                return;
            }

            // Attempts to parse the data returned by the server.
            NSDictionary *configDict = [SFJsonUtils objectFromJSONData:data];
            if (configDict == nil) {
                NSError *jsonParseError = [SFJsonUtils lastError];
                [SFSDKCoreLogger e:[strongSelf class] format:@"Could not parse org auth config response from %@: %@", orgConfigUrl, [jsonParseError localizedDescription]];
                authConfigBlock(nil, jsonParseError);
                return;
            }

            // Passes the retrieved auth config back.
            [SFSDKCoreLogger i:[strongSelf class] format:@"Successfully retrieved org auth config data from %@", orgConfigUrl];
            SFOAuthOrgAuthConfiguration *orgAuthConfig = [[SFOAuthOrgAuthConfiguration alloc] initWithConfigDict:configDict];
            authConfigBlock(orgAuthConfig, nil);
        } else {
            [SFSDKCoreLogger w:[strongSelf class] format:@"Org config request failed with error: Status Code: %ld", statusCode];
            authConfigBlock(nil, nil);
        }
    }];
}

@end
