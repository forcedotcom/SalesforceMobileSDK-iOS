//
//  SFOAuthCoordinatorFlowTests.m
//  SalesforceOAuth
//
//  Created by Kevin Hawkins on 12/18/14.
//  Copyright (c) 2014 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <SalesforceSDKCommon/SFSDKAsyncProcessListener.h>

#import "SFOAuthCoordinator+Internal.h"
#import "SFOAuthFlowAndDelegate.h"

@interface SFOAuthCoordinatorFlowTests : XCTestCase

@property (nonatomic, strong) SFOAuthCoordinator *coordinator;
@property (nonatomic, strong) SFOAuthFlowAndDelegate *flowAndDelegate;

@end

@implementation SFOAuthCoordinatorFlowTests

- (void)setUp {
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
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
                                                                                      return [NSNumber numberWithBool:self.flowAndDelegate.didAuthenticateCalled];
                                                                                  }
                                                                                            timeout:(self.flowAndDelegate.timeBeforeUserAgentCompletion + 0.5)];
    BOOL userAgentFlowSucceeded = [[listener waitForCompletion] boolValue];
    XCTAssertTrue(userAgentFlowSucceeded, @"User agent flow should have completed successfully.");
    XCTAssertTrue(self.flowAndDelegate.beginUserAgentFlowCalled, @"User agent flow should have been called in first authenticate.");
    XCTAssertFalse(self.flowAndDelegate.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in first authenticate.");
    XCTAssertEqual(self.flowAndDelegate.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
}

- (void)testRefreshFlowInitiated {
    self.coordinator.credentials.refreshToken = @"YeahIHaveATokenWoo!";
    [self.coordinator authenticate];
    SFSDKAsyncProcessListener *listener = [[SFSDKAsyncProcessListener alloc] initWithExpectedStatus:@YES
                                                                                  actualStatusBlock:^id{
                                                                                      return [NSNumber numberWithBool:self.flowAndDelegate.didAuthenticateCalled];
                                                                                  }
                                                                                            timeout:(self.flowAndDelegate.timeBeforeUserAgentCompletion + 0.5)];
    BOOL refreshFlowSucceeded = [[listener waitForCompletion] boolValue];
    XCTAssertTrue(refreshFlowSucceeded, @"Refresh flow should have completed successfully.");
    XCTAssertFalse(self.flowAndDelegate.beginUserAgentFlowCalled, @"User agent flow should not have been called with a refresh token.");
    XCTAssertTrue(self.flowAndDelegate.beginTokenEndpointFlowCalled, @"Token endpoint should have been called with a refresh token.");
    XCTAssertEqual(self.flowAndDelegate.tokenEndpointFlowType, SFOAuthTokenEndpointFlowRefresh, @"Token endpoint flow type should be refresh.");
}

- (void)testMultipleAuthenticationRequests {
    [self.coordinator authenticate];
    XCTAssertTrue(self.flowAndDelegate.beginUserAgentFlowCalled, @"User agent flow should have been called in first authenticate.");
    XCTAssertFalse(self.flowAndDelegate.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in first authenticate.");
    XCTAssertEqual(self.flowAndDelegate.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
    
    [self configureFlowAndDelegate];
    [self.coordinator authenticate];
    XCTAssertFalse(self.flowAndDelegate.beginUserAgentFlowCalled, @"User agent flow should not have been called in second authenticate.");
    XCTAssertFalse(self.flowAndDelegate.beginTokenEndpointFlowCalled, @"Token endpoint should not have been called in second authenticate.");
    XCTAssertEqual(self.flowAndDelegate.tokenEndpointFlowType, SFOAuthTokenEndpointFlowNone, @"Should be no token endpoint flow type configured.");
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
    self.flowAndDelegate = [[SFOAuthFlowAndDelegate alloc] initWithCoordinator:self.coordinator];
    self.coordinator.oauthCoordinatorFlow = self.flowAndDelegate;
    self.coordinator.delegate = self.flowAndDelegate;
}

- (void)tearDownCoordinatorFlow {
    [self.coordinator.credentials revoke];
    self.coordinator.delegate = nil;
    self.coordinator.oauthCoordinatorFlow = nil;
    self.flowAndDelegate = nil;
    self.coordinator = nil;
}

@end
