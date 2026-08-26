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
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"

static NSString * const kSFTestId = @"test_id";
static NSString * const kSFTestClientId = @"test_client_id";
static NSString * const kSFMyDomainEndpoint = @"mobilesdk.my.salesforce.com";
static NSString * const kSFAlternateMyDomainEndpoint = @"powerofus.salesforce.com";
static NSString * const kSFAlternateMyDomainLoginURL = @"powerofus.salesforce.com/s/login";
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
    } loginDomain:credentials.domain];
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
    } loginDomain:credentials.domain];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testGetSSOUrls {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFMyDomainEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testGetSSOUrls"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(error, @"Error should be nil");
        XCTAssertNotNil(authConfig, @"Auth config should not be nil");
        XCTAssertNotNil(authConfig.authConfigDict, @"Auth config dictionary should not be nil");
        XCTAssertNotNil(authConfig.ssoUrls, @"SSO URLs should not be nil");
        XCTAssertEqual(authConfig.ssoUrls.count, 1, @"SSO URLs should have 1 valid entries");
        [expect fulfill];
    } loginDomain:credentials.domain];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testGetLoginPageUrl {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFAlternateMyDomainEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testGetLoginPageUrl"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(error, @"Error should be nil");
        XCTAssertNotNil(authConfig, @"Auth config should not be nil");
        XCTAssertNotNil(authConfig.authConfigDict, @"Auth config dictionary should not be nil");
        XCTAssertNotNil(authConfig.loginPageUrl, @"Login page URL should not be nil");
        XCTAssertTrue([authConfig.loginPageUrl containsString:kSFAlternateMyDomainLoginURL], @"Login page URL should contain correct URL");
        [expect fulfill];
    } loginDomain:credentials.domain];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testGetNoAuthConfig {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kSFTestId clientId:kSFTestClientId encrypted:YES];
    [credentials setDomain:kSFSandboxEndpoint];
    XCTestExpectation *expect = [self expectationWithDescription:@"testGetNoAuthConfig"];
    [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
        XCTAssertNil(authConfig, @"Auth config should be nil");
        [expect fulfill];
    } loginDomain:credentials.domain];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

// MARK: - isProductionLoginHost tests (no network)

- (void)testIsProductionLoginHost_production {
    XCTAssertTrue([SFSDKAuthConfigUtil isProductionLoginHost:@"login.salesforce.com"]);
}

- (void)testIsProductionLoginHost_internalPool {
    XCTAssertTrue([SFSDKAuthConfigUtil isProductionLoginHost:@"login.test1.pc-rnd.salesforce.com"]);
}

- (void)testIsProductionLoginHost_sandbox_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isProductionLoginHost:@"test.salesforce.com"]);
}

- (void)testIsProductionLoginHost_myDomain_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isProductionLoginHost:@"acme.my.salesforce.com"]);
}

- (void)testIsProductionLoginHost_internalMyDomain_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isProductionLoginHost:@"mobilesdksdb32.test1.my.pc-rnd.salesforce.com"]);
}

- (void)testIsProductionLoginHost_loginPrefixMyDomain_isFalse {
    // login-acme.my.salesforce.com: has .my. so it's My Domain, not production pool
    XCTAssertFalse([SFSDKAuthConfigUtil isProductionLoginHost:@"login-acme.my.salesforce.com"]);
}

// MARK: - isMyDomainHost tests (no network)

- (void)testIsMyDomainHost_standardMyDomain {
    XCTAssertTrue([SFSDKAuthConfigUtil isMyDomainHost:@"acme.my.salesforce.com"]);
}

- (void)testIsMyDomainHost_sandboxMyDomain {
    XCTAssertTrue([SFSDKAuthConfigUtil isMyDomainHost:@"acme.sandbox.my.salesforce.com"]);
}

- (void)testIsMyDomainHost_internalMyDomain {
    XCTAssertTrue([SFSDKAuthConfigUtil isMyDomainHost:@"mobilesdksdb32.test1.my.pc-rnd.salesforce.com"]);
}

- (void)testIsMyDomainHost_production_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isMyDomainHost:@"login.salesforce.com"]);
}

- (void)testIsMyDomainHost_sandbox_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isMyDomainHost:@"test.salesforce.com"]);
}

// MARK: - isPoolLoginHost tests (no network)

- (void)testIsPoolLoginHost_production {
    XCTAssertTrue([SFSDKAuthConfigUtil isPoolLoginHost:@"login.salesforce.com"]);
}

- (void)testIsPoolLoginHost_internalProduction {
    XCTAssertTrue([SFSDKAuthConfigUtil isPoolLoginHost:@"login.test1.pc-rnd.salesforce.com"]);
}

- (void)testIsPoolLoginHost_sandbox {
    XCTAssertTrue([SFSDKAuthConfigUtil isPoolLoginHost:@"test.salesforce.com"]);
}

- (void)testIsPoolLoginHost_myDomain_isFalse {
    XCTAssertFalse([SFSDKAuthConfigUtil isPoolLoginHost:@"acme.my.salesforce.com"]);
}

@end
