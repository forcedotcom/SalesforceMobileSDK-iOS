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

#import "CSFTokenRefresh.h"
#import "CSFAuthRefresh+Internal.h"

#import "CSFInput_Internal.h"
#import "CSFOAuthTokenRefreshInput.h"

#import "CSFOutput_Internal.h"
#import "CSFOAuthTokenRefreshOutput.h"

#import "CSFDefines.h"
#import "CSFAction+Internal.h"

#import <SalesforceSDKCore/SalesforceSDKCore.h>

static NSString * const kCSFTokenRefreshPath = @"/services/oauth2/token";
static NSTimeInterval const kCSFTokenRefreshTimeout = 60.0;

@interface CSFTokenRefresh ()

@property (nonatomic, copy, readwrite) CSFOAuthTokenRefreshInput *refreshInput;

@end

@implementation CSFTokenRefresh

- (instancetype)initWithNetwork:(CSFNetwork *)network {
    self = [super initWithNetwork:network];
    if (self) {
        self.refreshInput = [[CSFOAuthTokenRefreshInput alloc] init];
        self.refreshInput.redirectUri = network.account.credentials.redirectUri;
        self.refreshInput.instanceUrl = network.account.credentials.instanceUrl;
        self.refreshInput.clientId = network.account.credentials.clientId;
        self.refreshInput.refreshToken = network.account.credentials.refreshToken;
        _refreshTimeout = kCSFTokenRefreshTimeout;
    }
    return self;
}

- (void)refreshAuth {
    if (!self.refreshInput.redirectUri) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                             code:CSFNetworkURLCredentialsError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not contain a redirectUri" }];
        [self finishWithOutput:nil error:error];
        return;
    }

    if (!self.refreshInput.instanceUrl) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkURLCredentialsError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not contain an instanceUrl" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    if (!self.refreshInput.clientId) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkURLCredentialsError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 client_id set" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    if (!self.refreshInput.refreshToken) {
        NSError *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                    code:CSFNetworkURLCredentialsError
                                userInfo:@{ NSLocalizedDescriptionKey: @"Credentials do not have an OAuth2 refresh_token set" }];
        [self finishWithOutput:nil error:error];
        return;
    }
    
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@",
                                       self.refreshInput.instanceUrl.scheme,
                                       self.refreshInput.instanceUrl.host,
                                       kCSFTokenRefreshPath]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:self.refreshTimeout];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [CSFURLFormEncode([self.refreshInput JSONDictionary], &error) dataUsingEncoding:NSUTF8StringEncoding];
    
    if (error) {
        [self finishWithOutput:nil error:error];
        return;
    }
    
    NSURLSession *session = self.network.ephemeralSession;
    __weak CSFTokenRefresh *weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong CSFTokenRefresh *strongSelf = weakSelf;
        if (error) {
            [strongSelf finishWithOutput:nil error:error];
            return;
        }
        
        CSFOutput *refreshOutput = nil;
        if (data) {
            NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                [strongSelf finishWithOutput:nil error:error];
                return;
            }
            refreshOutput = [[CSFOAuthTokenRefreshOutput alloc] initWithJSON:jsonData context:nil];
        }

        [strongSelf finishWithOutput:refreshOutput error:nil];
    }];
    [task resume];
}

@end
