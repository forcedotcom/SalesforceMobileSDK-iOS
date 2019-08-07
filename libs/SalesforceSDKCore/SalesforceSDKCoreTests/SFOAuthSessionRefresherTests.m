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
#import "SFOAuthSessionRefresher+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"

@interface SFOAuthSessionRefresherTests : XCTestCase

@property (nonatomic, strong) SFOAuthSessionRefresher *oauthSessionRefresher;
@end

@implementation SFOAuthSessionRefresherTests

- (void)setUp {
    [super setUp];
    [self setupCoordinatorFlow];
}

- (void)tearDown {
    [self tearDownCoordinatorFlow];
    [super tearDown];
}

- (void)testBadInputData {
    __block NSError *inputError = nil;
    
    // Invalid Instance URL
    XCTestExpectation *invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Instance URL"];
    NSURL *origUrl = self.oauthSessionRefresher.credentials.instanceUrl;
    self.oauthSessionRefresher.credentials.instanceUrl = nil;
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Instance URL.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.instanceUrl = origUrl;
    }];
    
    // Invalid Client ID
    inputError = nil;
    invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Client ID"];
    NSString *origClientId = self.oauthSessionRefresher.credentials.clientId;
    self.oauthSessionRefresher.credentials.clientId = nil;
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Client ID.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.clientId = origClientId;
    }];
    
    // Invalid Refresh Token
    inputError = nil;
    invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Refresh Token"];
    NSString *origRefreshToken = self.oauthSessionRefresher.credentials.refreshToken;
    self.oauthSessionRefresher.credentials.refreshToken = nil;
    self.oauthSessionRefresher.credentials.instanceUrl = origUrl;  // Nil'ed out as side effect of nil refresh token in SFOAuthCredentials.
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Refresh Token.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.refreshToken = origRefreshToken;
    }];
}

- (void)testFailedRefresh {
    __block NSError *refreshFailsError = nil;
    XCTestExpectation *refreshAccessTokenExpectation = [self expectationWithDescription:@"Refresh Access Token fails"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [refreshAccessTokenExpectation fulfill];
    } error:^(NSError *refreshError) {
        refreshFailsError = refreshError;
        [refreshAccessTokenExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(refreshFailsError, @"Should have received an error refreshing the access token.");
    }];
}

#pragma mark - Private methods

- (void)setupCoordinatorFlow {
    NSString *credsIdentifier = [NSString stringWithFormat:@"CredsIdentifier_%u", arc4random()];
    NSString *credsClientId = [NSString stringWithFormat:@"CredsClientId_%u", arc4random()];
    NSString *credsAccessToken = [NSString stringWithFormat:@"CredsAccessToken_%u", arc4random()];
    NSString *credsRefreshToken = [NSString stringWithFormat:@"CredsRefreshToken_%u", arc4random()];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:credsIdentifier clientId:credsClientId encrypted:YES];
    creds.redirectUri = [NSString stringWithFormat:@"sfdcUnitTest:///redirect_uri_%u", arc4random()];
    creds.instanceUrl = [NSURL URLWithString:@"https://cs1.salesforce.com"];
    creds.accessToken = credsAccessToken;
    creds.refreshToken = credsRefreshToken;
    self.oauthSessionRefresher = [[SFOAuthSessionRefresher alloc] initWithCredentials:creds];
}

- (void)tearDownCoordinatorFlow {
    [self.oauthSessionRefresher.credentials revoke];
    self.oauthSessionRefresher = nil;
}

@end
