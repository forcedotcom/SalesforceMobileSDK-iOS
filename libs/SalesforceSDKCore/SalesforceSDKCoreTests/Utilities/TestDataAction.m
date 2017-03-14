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

#import "TestDataAction.h"
#import <OCMock/OCMock.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>

@implementation TestDataAction

+ (SFUserAccount*)testUserAccount {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"the-identifier" clientId:@"the-client" encrypted:YES];
    credentials.accessToken = @"AccessToken";
    credentials.refreshToken = @"RefreshToken";
    credentials.instanceUrl = [NSURL URLWithString:@"http://example.org"];
    credentials.identityUrl = [NSURL URLWithString:@"https://example.org/id/orgID/userID"];
    
    SFUserAccount *account = [[SFUserAccount alloc] init];
    account.credentials = credentials;
    return account;
}

+ (NSURLSession*)mockURLSession {
    id session = OCMClassMock([NSURLSession class]);
    
    return session;
}

+ (CSFNetwork*)mockNetworkWithAccount:(SFUserAccount *)account {
    if (!account) {
        account = [self testUserAccount];
    }
    
    NSURLSession *session = [self mockURLSession];
    
    // Create a mock network for this user's network
    CSFNetwork *networkToMock = [[CSFNetwork alloc] init];
    CSFNetwork *network = OCMPartialMock(networkToMock);
    OCMStub([network userAgent]).andReturn(@"MyClient");
    OCMStub([network ephemeralSession]).andReturn(session);
    OCMStub([network account]).andReturn(account);
    OCMStub([network setSecurityToken:[OCMArg isKindOfClass:[NSString class]]]);
    return network;
}

- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock testFilename:(NSString*)filename withExtension:(NSString*)extension {
    self = [super initWithResponseBlock:responseBlock];
    if (self) {
        NSBundle *bundle = [NSBundle bundleForClass:self.class];
        NSURL *testURL = [bundle URLForResource:filename withExtension:extension];
        self.testResponseData = [NSData dataWithContentsOfURL:testURL];
    }
    return self;
}

- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock testString:(NSString*)testString {
    self = [super initWithResponseBlock:responseBlock];
    if (self) {
        self.testResponseData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

- (void)updateProgress {
}

- (NSURLSessionTask*)sessionTaskToProcessRequest:(NSURLRequest*)request session:(NSURLSession*)session {
    self.composedRequest = request;
    
    id task = OCMClassMock([NSURLSessionDataTask class]);
    [[[task expect] andDo:^(NSInvocation *invocation) {
        self.wasCancelled = YES;
    }] cancel];
    [[[task expect] andDo:^(NSInvocation *invocation) {
        self.wasResumed = YES;
        
        self.responseData = [NSMutableData dataWithData:self.testResponseData];
        [self completeOperationWithResponse:self.testResponseObject];
    }] resume];
    return task;
}

- (BOOL)isCancelled {
    if (_overriddenCancel) return YES;
    return [super isCancelled];
}

- (void)setCancelled:(BOOL)cancelled {
    _overriddenCancel = cancelled;
}

@end
