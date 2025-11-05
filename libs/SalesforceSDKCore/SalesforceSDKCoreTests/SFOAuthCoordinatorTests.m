/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAuthSession.h"
#import "SFSDKAuthRequest.h"

@interface SFOAuthCoordinatorTests : XCTestCase

@end

@implementation SFOAuthCoordinatorTests

- (void)testMigrateRefreshTokenSetup {
    // Create test credentials
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testIdentifier" clientId:@"testClientId" encrypted:NO];
    credentials.redirectUri = @"testapp://callback";
    credentials.domain = @"test.salesforce.com";
    credentials.accessToken = @"testAccessToken";
    credentials.refreshToken = @"testRefreshToken";
    credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    
    // Create a test user account (not fully logged in to avoid actual API calls)
    SFUserAccount *userAccount = [[SFUserAccount alloc] initWithCredentials:credentials];
    
    // Create auth request and session
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"newClientId";
    authRequest.oauthCompletionUrl = @"newapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    
    // Track whether callbacks are invoked
    __block BOOL failureCallbackInvoked = NO;
    __block SFOAuthInfo *capturedAuthInfo = nil;
    __block NSError *capturedError = nil;
    
    authSession.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallbackInvoked = YES;
        capturedAuthInfo = authInfo;
        capturedError = error;
    };
    
    // Create coordinator
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:authSession];
    coordinator.credentials = credentials;
    
    // Verify initial state
    XCTAssertNotNil(coordinator.credentials);
    XCTAssertEqualObjects(coordinator.credentials.clientId, @"testClientId");
    
    // Call migrateRefreshToken - this will attempt to make a REST API call
    // which will fail because the user is not properly logged in
    [coordinator migrateRefreshToken:userAccount];
    
    // Wait a bit for the async failure callback
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for failure callback"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2.0];
    
    // Verify that the auth info was set to the correct type
    // This happens synchronously before the REST call
    XCTAssertNotNil(coordinator.authInfo, @"Auth info should be set");
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeRefreshTokenMigration, @"Auth type should be refresh token migration");
    
    // Verify initialRequestLoaded was set to false
    XCTAssertFalse(coordinator.initialRequestLoaded, @"Initial request loaded should be false");
    
    // Verify the failure callback was invoked (because the user isn't logged in properly)
    XCTAssertTrue(failureCallbackInvoked, @"Failure callback should be invoked when REST API fails");
    XCTAssertNotNil(capturedError, @"Should have captured an error");
    XCTAssertEqual(capturedAuthInfo.authType, SFOAuthTypeRefreshTokenMigration, @"AuthInfo type should be refresh token migration");
}

@end

