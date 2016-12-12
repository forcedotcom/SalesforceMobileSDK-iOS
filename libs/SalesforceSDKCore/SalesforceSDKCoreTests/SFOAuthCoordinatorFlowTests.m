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

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFOAuthCoordinator+Internal.h"
#import "SFOAuthTestFlow.h"
#import "SFOAuthTestFlowCoordinatorDelegate.h"

@interface SFOAuthCoordinatorFlowTests : XCTestCase

@property (nonatomic, strong) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong) SFOAuthTestFlow *oauthTestFlow;
@property (nonatomic, strong) SFOAuthTestFlowCoordinatorDelegate *testFlowDelegate;

@end

@implementation SFOAuthCoordinatorFlowTests

- (void)setUp {
    [super setUp];
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    [self setupCoordinatorFlow];
}

- (void)tearDown {
    [self tearDownCoordinatorFlow];
    [super tearDown];
}

- (void)testUserAgentFlowInitiated {
    [self.coordinator authenticate];
    SFSDKAsyncProcessListener *listener = [[SFSDKAsyncProcessListener alloc] initWithExpectedStatus:@YES
                                                                                  actualStatusBlock:^id{
                                                                                      return [NSNumber numberWithBool:self.testFlowDelegate.didAuthenticateCalled];
                                                                                  }
                                                                                            timeout:(self.oauthTestFlow.timeBeforeUserAgentCompletion + 0.5)];
    BOOL userAgentFlowSucceeded = [[listener waitForCompletion] boolValue];
    XCTAssertTrue(userAgentFlowSucceeded, @"User agent flow should have completed successfully.");
    XCTAssertTrue(self.oauthTestFlow.beginUserAgentFlowCalled, @"User agent flow should have been called in first authenticate.");
    XCTAssertFalse(self.oauthTestFlow.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in first authenticate.");
    XCTAssertEqual(self.oauthTestFlow.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
}

- (void)testRefreshFlowInitiated {
    self.coordinator.credentials.refreshToken = @"YeahIHaveATokenWoo!";
    [self.coordinator authenticate];
    SFSDKAsyncProcessListener *listener = [[SFSDKAsyncProcessListener alloc] initWithExpectedStatus:@YES
                                                                                  actualStatusBlock:^id{
                                                                                      return [NSNumber numberWithBool:self.testFlowDelegate.didAuthenticateCalled];
                                                                                  }
                                                                                            timeout:(self.oauthTestFlow.timeBeforeUserAgentCompletion + 0.5)];
    BOOL refreshFlowSucceeded = [[listener waitForCompletion] boolValue];
    XCTAssertTrue(refreshFlowSucceeded, @"Refresh flow should have completed successfully.");
    XCTAssertFalse(self.oauthTestFlow.beginUserAgentFlowCalled, @"User agent flow should not have been called with a refresh token.");
    XCTAssertTrue(self.oauthTestFlow.beginTokenEndpointFlowCalled, @"Token endpoint should have been called with a refresh token.");
    XCTAssertEqual(self.oauthTestFlow.tokenEndpointFlowType, SFOAuthTokenEndpointFlowRefresh, @"Token endpoint flow type should be refresh.");
}

- (void)testMultipleAuthenticationRequests {
    [self.coordinator authenticate];
    XCTAssertTrue(self.oauthTestFlow.beginUserAgentFlowCalled, @"User agent flow should have been called in first authenticate.");
    XCTAssertFalse(self.oauthTestFlow.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in first authenticate.");
    XCTAssertEqual(self.oauthTestFlow.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
    
    [self configureFlowAndDelegate];
    [self.coordinator authenticate];
    XCTAssertFalse(self.oauthTestFlow.beginUserAgentFlowCalled, @"User agent flow should not have been called in second authenticate.");
    XCTAssertFalse(self.oauthTestFlow.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in second authenticate.");
    XCTAssertEqual(self.oauthTestFlow.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
}

#pragma mark - Private methods

- (void)setupCoordinatorFlow {
    NSString *credsIdentifier = [NSString stringWithFormat:@"CredsIdentifier_%u", arc4random()];
    NSString *credsClientId = [NSString stringWithFormat:@"CredsClientId_%u", arc4random()];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:credsIdentifier clientId:credsClientId encrypted:YES];
    creds.redirectUri = [NSString stringWithFormat:@"sfdcUnitTest:///redirect_uri_%u", arc4random()];
    self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    [self configureFlowAndDelegate];
}

- (void)configureFlowAndDelegate {
    self.oauthTestFlow = [[SFOAuthTestFlow alloc] initWithCoordinator:self.coordinator];
    self.testFlowDelegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    self.coordinator.oauthCoordinatorFlow = self.oauthTestFlow;
    self.coordinator.delegate = self.testFlowDelegate;
}

- (void)tearDownCoordinatorFlow {
    [self.coordinator.credentials revoke];
    self.coordinator.delegate = nil;
    self.coordinator.oauthCoordinatorFlow = nil;
    self.testFlowDelegate = nil;
    self.oauthTestFlow = nil;
    self.coordinator = nil;
}

@end
