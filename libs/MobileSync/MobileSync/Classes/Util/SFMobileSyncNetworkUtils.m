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

#import "SFMobileSyncNetworkUtils.h"
#import <SalesforceSDKCore/SFRestRequest.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>

// For user agent.
NSString * const kUserAgent = @"User-Agent";
NSString * const kMobileSync = @"MobileSync";

@implementation SFMobileSyncNetworkUtils

+ (void)sendRequestWithMobileSyncUserAgent:(SFRestRequest *)request failureBlock:(SFRestRequestFailBlock)failureBlock successBlock:(SFRestResponseBlock)successBlock {
    [SFSDKMobileSyncLogger d:[self class] format:@"sendRequestWithMobileSyncUserAgent:request:%@", request];
    [request setHeaderValue:[SFRestAPI userAgentString:kMobileSync] forHeaderName:kUserAgent];
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
    SFRestAPI *restApiInstance = (!user) ? [SFRestAPI sharedGlobalInstance] : [SFRestAPI sharedInstance];
    [restApiInstance sendRequest:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        [SFSDKMobileSyncLogger e:[self class] format:@"sendRequestWithMobileSyncUserAgent:error:%ld:%@", (long) e.code, e.domain];
        failureBlock(response, e, rawResponse);
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        [SFSDKMobileSyncLogger d:[self class] format:@"sendRequestWithMobileSyncUserAgent:response:%@", response];
        successBlock(response, rawResponse);
    }];
}

@end
