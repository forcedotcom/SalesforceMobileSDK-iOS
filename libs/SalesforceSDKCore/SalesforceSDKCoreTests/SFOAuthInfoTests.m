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

@interface SFOAuthInfoTests : XCTestCase

@end

@implementation SFOAuthInfoTests

- (void)testAuthTypeDescription {
    // Test SFOAuthTypeUnknown
    SFOAuthInfo *unknownInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUnknown];
    XCTAssertEqualObjects(unknownInfo.authTypeDescription, @"SFOAuthTypeUnknown", @"Unknown auth type should return correct description");
    XCTAssertEqual(unknownInfo.authType, SFOAuthTypeUnknown, @"Auth type should be Unknown");
    
    // Test SFOAuthTypeUserAgent
    SFOAuthInfo *userAgentInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    XCTAssertEqualObjects(userAgentInfo.authTypeDescription, @"SFOAuthTypeUserAgent", @"UserAgent auth type should return correct description");
    XCTAssertEqual(userAgentInfo.authType, SFOAuthTypeUserAgent, @"Auth type should be UserAgent");
    
    // Test SFOAuthTypeWebServer
    SFOAuthInfo *webServerInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeWebServer];
    XCTAssertEqualObjects(webServerInfo.authTypeDescription, @"SFOAuthTypeWebServer", @"WebServer auth type should return correct description");
    XCTAssertEqual(webServerInfo.authType, SFOAuthTypeWebServer, @"Auth type should be WebServer");
    
    // Test SFOAuthTypeRefresh
    SFOAuthInfo *refreshInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    XCTAssertEqualObjects(refreshInfo.authTypeDescription, @"SFOAuthTypeRefresh", @"Refresh auth type should return correct description");
    XCTAssertEqual(refreshInfo.authType, SFOAuthTypeRefresh, @"Auth type should be Refresh");
    
    // Test SFOAuthTypeAdvancedBrowser
    SFOAuthInfo *advancedBrowserInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
    XCTAssertEqualObjects(advancedBrowserInfo.authTypeDescription, @"SFOAuthTypeAdvancedBrowser", @"AdvancedBrowser auth type should return correct description");
    XCTAssertEqual(advancedBrowserInfo.authType, SFOAuthTypeAdvancedBrowser, @"Auth type should be AdvancedBrowser");
    
    // Test SFOAuthTypeJwtTokenExchange
    SFOAuthInfo *jwtInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeJwtTokenExchange];
    XCTAssertEqualObjects(jwtInfo.authTypeDescription, @"SFOAuthTypeJwtTokenExchange", @"JwtTokenExchange auth type should return correct description");
    XCTAssertEqual(jwtInfo.authType, SFOAuthTypeJwtTokenExchange, @"Auth type should be JwtTokenExchange");
    
    // Test SFOAuthTypeIDP
    SFOAuthInfo *idpInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeIDP];
    XCTAssertEqualObjects(idpInfo.authTypeDescription, @"SFOAuthTypeIDP", @"IDP auth type should return correct description");
    XCTAssertEqual(idpInfo.authType, SFOAuthTypeIDP, @"Auth type should be IDP");
    
    // Test SFOAuthTypeNative
    SFOAuthInfo *nativeInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeNative];
    XCTAssertEqualObjects(nativeInfo.authTypeDescription, @"SFOAuthTypeNative", @"Native auth type should return correct description");
    XCTAssertEqual(nativeInfo.authType, SFOAuthTypeNative, @"Auth type should be Native");
    
    // Test SFOAuthTypeRefreshTokenMigration
    SFOAuthInfo *migrationInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefreshTokenMigration];
    XCTAssertEqualObjects(migrationInfo.authTypeDescription, @"SFOAuthTypeRefreshTokenMigration", @"RefreshTokenMigration auth type should return correct description");
    XCTAssertEqual(migrationInfo.authType, SFOAuthTypeRefreshTokenMigration, @"Auth type should be RefreshTokenMigration");
}

- (void)testDescription {
    // Test that description includes authTypeDescription
    SFOAuthInfo *info = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    NSString *description = [info description];
    
    XCTAssertNotNil(description, @"Description should not be nil");
    XCTAssertTrue([description containsString:@"SFOAuthInfo"], @"Description should contain class name");
    XCTAssertTrue([description containsString:@"authType="], @"Description should contain authType label");
    XCTAssertTrue([description containsString:@"SFOAuthTypeRefresh"], @"Description should contain auth type description");
}

@end

