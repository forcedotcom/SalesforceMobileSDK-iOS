/*
 SFSDKAuthConfigUtilTests.m
 SalesforceSDKCoreTests
 
 Created by Bharath Hariharan on 2/9/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKAuthConfigUtil.h"
#import "TestSetupUtils.h"
#import "SFUserAccountManager.h"

static NSString * const kSFTestId = @"test_id";
static NSString * const kSFTestClientId = @"test_client_id";
static NSString * const kSFMyDomainEndpoint = @"images.cs4.my.salesforce.com";
static NSString * const kSFSandboxEndpoint = @"test.salesforce.com";

@interface SFSDKAuthConfigUtilTests : XCTestCase

@end

@implementation SFSDKAuthConfigUtilTests

- (void)testGetAuthConfig {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFMyDomainEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testGetAuthConfig"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(error, @"Error should be nil");
        XCTAssertNotNil(authConfig, @"Auth config should not be nil");
        XCTAssertNotNil(authConfig.authConfigDict, @"Auth config dictionary should not be nil");
        [expect fulfill];
    } oauthCredentials:credentials];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testBrowserBasedLoginEnabled {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFMyDomainEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testBrowserBasedLoginEnabled"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(error, @"Error should be nil");
        XCTAssertNotNil(authConfig, @"Auth config should not be nil");
        XCTAssertNotNil(authConfig.authConfigDict, @"Auth config dictionary should not be nil");
        XCTAssertTrue(authConfig.useNativeBrowserForAuth, @"Browser based login should be enabled");
        [expect fulfill];
    } oauthCredentials:credentials];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testGetNoAuthConfig {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFSandboxEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testGetNoAuthConfig"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(authConfig, @"Auth config should be nil");
        [expect fulfill];
    } oauthCredentials:credentials];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

@end
