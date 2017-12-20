/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKAuthRequestCommand.h"
@interface SFSDKAuthRequestCommandTest : XCTestCase

@end

@implementation SFSDKAuthRequestCommandTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
}

- (void)testSFSDKAuthRequestCommand {
    SFSDKAuthRequestCommand *test = [[SFSDKAuthRequestCommand alloc]init];
    XCTAssertNotNil(test);
    NSString *testURL = @"atest://atest/v1.0/authrequest";
    XCTAssertTrue([test isAuthCommand:[NSURL URLWithString:testURL]]);
    
    XCTAssertTrue([test isAuthCommand:[NSURL URLWithString:testURL.uppercaseString]]);
    
}

- (void)testSFSDKAuthRequestCommandBadURL {
    SFSDKAuthRequestCommand *test = [[SFSDKAuthRequestCommand alloc]init];    XCTAssertNotNil(test);
    NSString *testURL = @"atest://atest/authrequest";
    NSURL *url = [NSURL URLWithString:testURL];
    XCTAssertNotNil(url);
    XCTAssertTrue(![test isAuthCommand:url]);
}


- (void)testSFSDKAuthRequestCommandWithParameters {
    
    NSString *spClientId = @"AClientID";
    NSString *spRedirectURI = @"anapp://some/oauth/callback";
    NSString *spState = @"AState";
    NSString *spChallengeCode = @"AChallenge";
    NSString *userHint = @"USER:ORG";
    NSString *spAppName = @"AnApp";
    NSString *spAppDesc = @"An Apps Description";
    NSString *spAppScopes = @"Scope1,Scope2";
    
    
    SFSDKAuthRequestCommand *test = [[SFSDKAuthRequestCommand alloc]init];
    XCTAssertNotNil(test);
    test.spClientId = spClientId;
    test.spAppName = spAppName;
    test.spCodeChallenge = spChallengeCode;
    test.spUserHint = userHint;
    test.spRedirectURI = spRedirectURI;
    test.spAppScopes = spAppScopes;
    test.spState = spState;
    test.spAppDescription = spAppDesc;
    test.scheme = @"app";
    
    XCTAssertNotNil([test requestURL]);
    XCTAssertTrue([test isAuthCommand:[test requestURL]]);
    
    SFSDKAuthRequestCommand *test2 = [[SFSDKAuthRequestCommand alloc]init];
    
    XCTAssertTrue([test2 isAuthCommand:[test requestURL]]);
    [test2 fromRequestURL:[test requestURL]];
    
    XCTAssertTrue([test2 isAuthCommand:[test2 requestURL]]);
    XCTAssertTrue([test2.spAppScopes isEqualToString:test.spAppScopes], @"App Scopes should match after decoding");
    
    XCTAssertTrue([test2.spRedirectURI isEqualToString:test.spRedirectURI], @"App RedirectURI should match after decoding");
    
    XCTAssertTrue([test2.spCodeChallenge isEqualToString:test.spCodeChallenge], @"Code Challenge should match after decoding");
    
    XCTAssertTrue([test2.spUserHint isEqualToString:test.spUserHint], @"App  userHint  should match after decoding");
    
    XCTAssertTrue([test2.spAppName isEqualToString:test.spAppName], @"App  Name   should match after decoding");
}
@end
