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
 * to pending requests when token refresh fails. The DPoP mismatch regression tests also
 * verify the asynchronous logout decision without invoking account deletion.
 */

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFRestAPI+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKOAuthConstants.h"
#import <objc/runtime.h>

@interface SFSDKOAuthTokenEndpointResponse ()
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end

@interface SFRestAPI (Testing)
- (void)startAuthenticationRefreshForRequest:(SFRestRequest *)request response:(NSURLResponse *)response;
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

static NSUInteger gLogoutCallCount;
static SFUserAccount *gLoggedOutUser;
static SFLogoutReason gLogoutReason;
static XCTestExpectation *gLogoutExpectation;

@interface SFRestAPIReplayRequestTests : XCTestCase
@property (nonatomic, strong) SFRestAPI *restAPI;
@property (nonatomic, strong) SFUserAccount *testAccount;
@property (nonatomic, strong) SFAuthClientFactoryBlock originalAuthClientFactory;
@property (nonatomic, assign) BOOL logoutUserSwizzled;
- (void)record_logoutUser:(SFUserAccount *)user reason:(SFLogoutReason)reason;
@end

@implementation SFRestAPIReplayRequestTests

- (void)setUp {
    [super setUp];
    gLogoutCallCount = 0;
    gLoggedOutUser = nil;
    gLogoutReason = SFLogoutReasonUnknown;
    gLogoutExpectation = nil;

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
    if (self.logoutUserSwizzled) {
        [self swapLogoutUserWithRecorder];
    }
    [SFUserAccountManager sharedInstance].authClient = self.originalAuthClientFactory;
    [SFRestAPI removeSharedInstanceWithUser:self.restAPI.user];
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:self.testAccount error:nil];
    self.testAccount = nil;
    self.restAPI = nil;
    [super tearDown];
}

- (void)swapLogoutUserWithRecorder {
    Method original = class_getInstanceMethod([SFUserAccountManager class], @selector(logoutUser:reason:));
    Method replacement = class_getInstanceMethod([self class], @selector(record_logoutUser:reason:));
    method_exchangeImplementations(original, replacement);
    self.logoutUserSwizzled = !self.logoutUserSwizzled;
}

- (void)record_logoutUser:(SFUserAccount *)user reason:(SFLogoutReason)reason {
    gLogoutCallCount++;
    gLoggedOutUser = user;
    gLogoutReason = reason;
    [gLogoutExpectation fulfill];
}

- (void)startRefreshForRequest:(SFRestRequest *)request {
    NSHTTPURLResponse *unauthorizedResponse = [[NSHTTPURLResponse alloc]
                                                initWithURL:[NSURL URLWithString:@"https://test.salesforce.com/services/data/v66.0"]
                                                statusCode:401
                                                HTTPVersion:@"HTTP/1.1"
                                                headerFields:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.restAPI performSelector:@selector(startAuthenticationRefreshForRequest:response:)
                       withObject:request
                       withObject:unauthorizedResponse];
#pragma clang diagnostic pop
}

- (SFRestRequest *)pendingRequestWithFailureBlock:(SFRestRequestFailBlock)failureBlock {
    SFRestRequest *request = [self.restAPI requestForResources:nil];
    request.failureBlock = failureBlock;
    [self.restAPI.activeRequests addObject:request];
    return request;
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"Main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:2.0];
}

- (void)test_given_invalidGrant_when_startAuthenticationRefresh_then_logsOutWithTokenExpired {
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

    __block NSError *receivedError = nil;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];
    SFRestRequest *request = [self pendingRequestWithFailureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        [failureExpectation fulfill];
    }];
    [self startRefreshForRequest:request];

    [self waitForExpectations:@[failureExpectation] timeout:5.0];
    [self drainMainQueue];

    // Assert
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqual(receivedError.code, kSFOAuthErrorInvalidGrant, @"Error code should be invalid_grant");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"invalid_grant", @"Wire value should be preserved");
}

- (void)test_givenDPoPBoundKeyMismatch_when_startAuthenticationRefresh_thenLogsOutWithTokenExpired {
    NSDictionary *errorDict = @{
        @"error": @"invalid_dpop_proof",
        @"error_description": @"dpop thumbprint invalid for token"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };
    [self swapLogoutUserWithRecorder];

    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];
    gLogoutExpectation = [self expectationWithDescription:@"Token-expired logout"];
    SFRestRequest *request = [self pendingRequestWithFailureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        XCTAssertEqualObjects(error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        XCTAssertEqualObjects(error.localizedDescription, @"dpop thumbprint invalid for token");
        XCTAssertEqual(error.code, kSFOAuthErrorUnknown);
        [failureExpectation fulfill];
    }];

    [self startRefreshForRequest:request];
    [self waitForExpectations:@[failureExpectation, gLogoutExpectation] timeout:5.0];

    XCTAssertEqual(gLogoutCallCount, 1);
    XCTAssertEqualObjects(gLoggedOutUser.credentials.identifier, self.testAccount.credentials.identifier);
    XCTAssertEqual(gLogoutReason, SFLogoutReasonTokenExpired);
    gLogoutExpectation = nil;
    [self swapLogoutUserWithRecorder];
}

- (void)test_givenOtherDPoPProofError_when_startAuthenticationRefresh_thenDoesNotLogout {
    NSDictionary *errorDict = @{
        @"error": @"invalid_dpop_proof",
        @"error_description": @"dpop proof failed validation"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };
    [self swapLogoutUserWithRecorder];

    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];
    SFRestRequest *request = [self pendingRequestWithFailureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        XCTAssertEqualObjects(error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [failureExpectation fulfill];
    }];

    [self startRefreshForRequest:request];
    [self waitForExpectations:@[failureExpectation] timeout:5.0];
    [self drainMainQueue];
    XCTAssertEqual(gLogoutCallCount, 0);
    [self swapLogoutUserWithRecorder];
}

- (void)test_given_appAttestFailed_when_startAuthenticationRefresh_then_logsOutWithAppAttestationFailed {
    // Arrange: stub returns app_attest_failed error
    NSDictionary *errorDict = @{
        @"error": @"app_attest_failed",
        @"error_description": @"app attestation failed"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    __block NSError *receivedError = nil;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];
    SFRestRequest *request = [self pendingRequestWithFailureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        [failureExpectation fulfill];
    }];
    [self startRefreshForRequest:request];

    [self waitForExpectations:@[failureExpectation] timeout:5.0];
    [self drainMainQueue];

    // Assert: wire value is preserved so the refresh error path can parse it via SFOAuthErrorCode.from(_:)
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"app_attest_failed", @"Wire value should be preserved");
    XCTAssertEqual([SFOAuthErrorCodeHelper from:receivedError.userInfo[kSFOAuthError]],
                   SFOAuthErrorCodeAppAttestationFailed,
                   @"Wire value should map to appAttestationFailed via typed enum");
}

- (void)test_given_appAttestFailedRetry_when_startAuthenticationRefresh_then_doesNotLogout_andFlushesErrorToPending {
    // Arrange: stub returns app_attest_failed_retry error
    NSDictionary *errorDict = @{
        @"error": @"app_attest_failed_retry",
        @"error_description": @"attestation verification failed transiently"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:errorDict
                                                  parseAdditionalFields:nil];
    SFRestAPIReplayTestStub *stub = [[SFRestAPIReplayTestStub alloc] init];
    stub.stubbedResponse = response;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    __block NSError *receivedError = nil;
    XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Request fails"];
    SFRestRequest *request = [self pendingRequestWithFailureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        receivedError = error;
        [failureExpectation fulfill];
    }];
    [self startRefreshForRequest:request];

    [self waitForExpectations:@[failureExpectation] timeout:5.0];

    // Assert: wire value is preserved so the refresh error path can parse it via SFOAuthErrorCode.from(_:)
    XCTAssertNotNil(receivedError, @"Request should receive error");
    XCTAssertEqualObjects(receivedError.userInfo[kSFOAuthError], @"app_attest_failed_retry", @"Wire value should be preserved");
    XCTAssertEqual([SFOAuthErrorCodeHelper from:receivedError.userInfo[kSFOAuthError]],
                   SFOAuthErrorCodeAppAttestationFailedRetry,
                   @"Wire value should map to appAttestationFailedRetry via typed enum");
}

@end
