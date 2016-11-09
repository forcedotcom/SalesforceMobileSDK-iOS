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

#import "SFOAuthTestFlow.h"
#import "SFOAuthOrgAuthConfiguration.h"
#import "SFOAuthInfo.h"

@interface SFOAuthTestFlow ()

@property (nonatomic, weak) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong) SFOAuthOrgAuthConfiguration *retrieveOrgConf;
@property (nonatomic, strong) NSError *retrieveOrgConfError;

@end

@implementation SFOAuthTestFlow

@synthesize coordinator = _coordinator;

- (id)initWithCoordinator:(SFOAuthCoordinator *)coordinator {
    self = [super init];
    if (self) {
        self.coordinator = coordinator;
        self.timeBeforeUserAgentCompletion = 1.0;  // 1s default before user agent flow "completes".
        self.timeBeforeRefreshTokenCompletion = 1.0;
        self.userAgentFlowIsSuccessful = YES;
        self.refreshTokenFlowIsSuccessful = YES;
    }
    return self;
}

- (void)setRetrieveOrgAuthConfigurationData:(SFOAuthOrgAuthConfiguration *)config error:(NSError *)error {
    self.retrieveOrgConf = config;
    self.retrieveOrgConfError = error;
}

#pragma mark - Private methods

- (NSURL *)userAgentSuccessUrl {
    NSString *successFormatString = @"%@#access_token=%@&issued_at=%@&instance_url=%@&id=%@";
    NSString *successUrl = [NSString stringWithFormat:successFormatString,
                            self.coordinator.credentials.redirectUri,
                            @"some_access_token_val",
                            @(1418945872705),
                            [@"https://na1.salesforce.com" stringByURLEncoding],
                            [@"https://login.salesforce.com/id/some_org_id/some_user_id" stringByURLEncoding]
                            ];
    return [NSURL URLWithString:successUrl];
}

- (NSURL *)userAgentErrorUrl {
    NSString *errorFormatString = @"%@#error=%@&error_description=%@";
    NSString *errorUrl = [NSString stringWithFormat:errorFormatString,
                          self.coordinator.credentials.redirectUri,
                          @"user_agent_flow_error_from_unit_test",
                          [@"User agent flow error from unit test" stringByURLEncoding]
                          ];
    return [NSURL URLWithString:errorUrl];
}

- (NSMutableData *)refreshTokenSuccessData{
    NSString *successFormatString = @"{\"id\":\"%@\",\"issued_at\":\"%@\",\"instance_url\":\"%@\",\"access_token\":\"%@\"}";
    NSString *successDataString = [NSString stringWithFormat:successFormatString,
                            self.coordinator.credentials.redirectUri,
                            [@"https://login.salesforce.com/id/some_org_id/some_user_id" stringByURLEncoding],
                            @(1418945872705),
                            [@"https://na1.salesforce.com" stringByURLEncoding],
                            @"some_access_token"];
     NSData *data = [successDataString dataUsingEncoding:NSUTF8StringEncoding];
    return [data mutableCopy];
}

- (NSMutableData *)refreshTokenErrorData {
    NSString *errorFormatString = @"{\"error\":\"%@\",\"error_description\":\"%@\"}";
    NSString *errorDataString = [NSString stringWithFormat:errorFormatString,
                          self.coordinator.credentials.redirectUri,
                          @"refresh_token_flow_error_from_unit_test",
                          [@"Refresh token flow error from unit test" stringByURLEncoding]
                          ];
    NSData *data = [errorDataString dataUsingEncoding:NSUTF8StringEncoding];
    return [data mutableCopy];
}

#pragma mark - SFOAuthCoordinatorFlow

- (void)beginUserAgentFlow {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.beginUserAgentFlowCalled = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeBeforeUserAgentCompletion * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.userAgentFlowIsSuccessful) {
        [self.coordinator handleUserAgentResponse:[self userAgentSuccessUrl]];
        } else {
            [self.coordinator handleUserAgentResponse:[self userAgentErrorUrl]];
        }
    });
}

- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.beginTokenEndpointFlowCalled = YES;
    self.tokenEndpointFlowType = flowType;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeBeforeRefreshTokenCompletion * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.refreshTokenFlowIsSuccessful) {
            [self.coordinator handleTokenEndpointResponse:[self refreshTokenSuccessData]];
        } else {
            [self.coordinator handleTokenEndpointResponse:[self refreshTokenErrorData]];
        }
    });
}

- (void)beginJwtTokenExchangeFlow {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.beginJwtTokenExchangeFlowCalled = YES;
}

- (void)beginNativeBrowserFlow {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.beginNativeBrowserFlowCalled = YES;
}

- (void)retrieveOrgAuthConfiguration:(void (^)(SFOAuthOrgAuthConfiguration *orgAuthConfig, NSError *error))retrievedAuthConfigBlock {
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    if (retrievedAuthConfigBlock) {
        retrievedAuthConfigBlock(self.retrieveOrgConf, self.retrieveOrgConfError);
    }
}

- (void)handleTokenEndpointResponse:(NSMutableData *) data{
    [self log:SFLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    self.handleTokenEndpointResponseCalled = YES;
}

@end
