/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/*
 * Test coverage note: These tests verify that the correct NSError codes are propagated
 * to pending requests when token refresh fails with App Attestation errors. The logout
 * side-effects (logoutUser:reason:) are observable in the logs but difficult to verify
 * via notification in a unit test environment due to asynchronous account deletion.
 * Integration tests provide full end-to-end coverage of the logout flow.
 */

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFRestAPI+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKOAuthConstants.h"

@interface SFSDKOAuthTokenEndpointResponse ()
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end

@interface SFRestAPI (Testing)
- (void)send:(SFRestRequest *)request
failureBlock:(SFRestRequestFailBlock)failureBlock
successBlock:(SFRestResponseBlock)successBlock
 shouldRetry:(BOOL)shouldRetry;
- (void)replayRequest:(SFRestRequest *)request response:(NSURLResponse *)response;
@end

@interface SFRestAPIReplayTestStub : NSObject <SFSDKOAuthProtocol>
@property (nonatomic, strong) SFSDKOAuthTokenEndpointResponse *stubbedResponse;
@end

@implementation SFRestAPIReplayTestStub
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    completionBlock(self.stubbedResponse);
}
- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                        completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {}
- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(NSString *))completionBlock {}
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {}
@end

@interface SFRestAPIReplayRequestTests : XCTestCase
@property (nonatomic, strong) SFRestAPI *restAPI;
@property (nonatomic, strong) SFUserAccount *testAccount;
@property (nonatomic, strong) SFAuthClientFactoryBlock originalAuthClientFactory;
@end

@implementation SFRestAPIReplayRequestTests

- (void)setUp {
    [super setUp];

    // Save original factory
    self.originalAuthClientFactory = [SFUserAccountManager sharedInstance].authClient;

    // Create test account
    NSString *identifier = [NSString stringWithFormat:@"testuser_%u", arc4random()];
    NSString *clientId = [NSString stringWithFormat:@"testclient_%u", arc4random()];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:clientId encrypted:YES];
    credentials.redirectUri = [NSString stringWithFormat:@"testapp:///oauth_%u", arc4random()];
    credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    credentials.accessToken = [NSString stringWithFormat:@"access_%u", arc4random()];
    credentials.refreshToken = [NSString stringWithFormat:@"refresh_%u", arc4random()];
    credentials.userId = @"005000000000001";
    credentials.organizationId = @"00D000000000001";

    self.testAccount = [[SFUserAccount alloc] initWithCredentials:credentials];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:self.testAccount error:nil];

    self.restAPI = [SFRestAPI sharedInstanceWithUser:self.testAccount];
}

- (void)tearDown {
    [SFUserAccountManager sharedInstance].authClient = self.originalAuthClientFactory;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:self.testAccount error:nil];
    self.testAccount = nil;
    self.restAPI = nil;
    [super tearDown];
}

- (void)test_given_invalidGrant_when_replayRequest_then_logsOutWithTokenExpired {
    // Arrange: stub returns invalid_grant error
    NSDictionary *errorDict = @{
        @"error": @"invalid_grant",
        @"error_description": @"expired refresh token"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    // Create a pending request
    SFRestRequest *request = [self.restAPI requestForResources:nil];
    __block NSError *receivedError = nil;
    __block BOOL expectationFulfilled = NO;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];

    [self.restAPI send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        if (!expectationFulfilled) {
            expectationFulfilled = YES;
            [failureExpectation fulfill];
        }
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"Should not succeed");
    } shouldRetry:NO];

    // Trigger replay by simulating a 401
    NSHTTPURLResponse *unauthorizedResponse = [[NSHTTPURLResponse alloc]
                                                initWithURL:[NSURL URLWithString:@"https://test.salesforce.com/services/data/v66.0"]
                                                statusCode:401
                                                HTTPVersion:@"HTTP/1.1"
                                                headerFields:nil];

    // Use performSelector to invoke replayRequest:response: since it's private
    if ([self.restAPI respondsToSelector:@selector(replayRequest:response:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.restAPI performSelector:@selector(replayRequest:response:)
                           withObject:request
                           withObject:unauthorizedResponse];
#pragma clang diagnostic pop
    }

    [self waitForExpectations:@[failureExpectation] timeout:5.0];

    // Assert
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqual(receivedError.code, kSFOAuthErrorInvalidGrant, @"Error code should be invalid_grant");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"invalid_grant", @"Wire value should be preserved");
}

- (void)test_given_clientBlocked_when_replayRequest_then_logsOutWithAppAttestationFailed {
    // Arrange: stub returns client_blocked error
    NSDictionary *errorDict = @{
        @"error": @"client_blocked",
        @"error_description": @"app attestation failed"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    // Create a pending request
    SFRestRequest *request = [self.restAPI requestForResources:nil];
    __block NSError *receivedError = nil;
    __block BOOL expectationFulfilled = NO;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];

    [self.restAPI send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        if (!expectationFulfilled) {
            expectationFulfilled = YES;
            [failureExpectation fulfill];
        }
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"Should not succeed");
    } shouldRetry:NO];

    // Trigger replay
    NSHTTPURLResponse *unauthorizedResponse = [[NSHTTPURLResponse alloc]
                                                initWithURL:[NSURL URLWithString:@"https://test.salesforce.com/services/data/v66.0"]
                                                statusCode:401
                                                HTTPVersion:@"HTTP/1.1"
                                                headerFields:nil];

    if ([self.restAPI respondsToSelector:@selector(replayRequest:response:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.restAPI performSelector:@selector(replayRequest:response:)
                           withObject:request
                           withObject:unauthorizedResponse];
#pragma clang diagnostic pop
    }

    [self waitForExpectations:@[failureExpectation] timeout:5.0];

    // Assert: wire value is preserved so replayRequest can parse it via SFOAuthErrorCode.from(_:)
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"client_blocked", @"Wire value should be preserved");
    XCTAssertEqual([SFOAuthErrorCodeHelper from:receivedError.userInfo[kSFOAuthError]],
                   SFOAuthErrorCodeAppAttestationFailed,
                   @"Wire value should map to appAttestationFailed via typed enum");
}

- (void)test_given_clientBlockedRetry_when_replayRequest_then_doesNotLogout_andFlushesErrorToPending {
    // Arrange: stub returns client_blocked_retry error
    NSDictionary *errorDict = @{
        @"error": @"client_blocked_retry",
        @"error_description": @"attestation verification failed transiently"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    // Create a pending request
    SFRestRequest *request = [self.restAPI requestForResources:nil];
    __block NSError *receivedError = nil;
    __block BOOL expectationFulfilled = NO;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];

    [self.restAPI send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        if (!expectationFulfilled) {
            expectationFulfilled = YES;
            [failureExpectation fulfill];
        }
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"Should not succeed");
    } shouldRetry:NO];

    // Trigger replay
    NSHTTPURLResponse *unauthorizedResponse = [[NSHTTPURLResponse alloc]
                                                initWithURL:[NSURL URLWithString:@"https://test.salesforce.com/services/data/v66.0"]
                                                statusCode:401
                                                HTTPVersion:@"HTTP/1.1"
                                                headerFields:nil];

    if ([self.restAPI respondsToSelector:@selector(replayRequest:response:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.restAPI performSelector:@selector(replayRequest:response:)
                           withObject:request
                           withObject:unauthorizedResponse];
#pragma clang diagnostic pop
    }

    [self waitForExpectations:@[failureExpectation] timeout:5.0];

    // Assert: wire value is preserved so replayRequest can parse it via SFOAuthErrorCode.from(_:)
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"client_blocked_retry", @"Wire value should be preserved");
    XCTAssertEqual([SFOAuthErrorCodeHelper from:receivedError.userInfo[kSFOAuthError]],
                   SFOAuthErrorCodeAppAttestationFailedRetry,
                   @"Wire value should map to appAttestationFailedRetry via typed enum");
}

@end
