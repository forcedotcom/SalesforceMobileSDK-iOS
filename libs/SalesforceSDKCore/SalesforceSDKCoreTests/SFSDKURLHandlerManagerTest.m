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
#import "SFSDKURLHandlerManager.h"
#import "SFSDKAuthRequestCommand.h"
#import "SFSDKAuthResponseCommand.h"
#import "SFSDKIDPErrorHandler.h"
#import "SFSDKAuthErrorCommand.h"
#import "SFSDKAdvancedAuthURLHandler.h"
#import "SFSDKIDPRequestHandler.h"
#import "SFSDKIDPResponseHandler.h"

@interface SFSDKURLHandlerManagerTest : XCTestCase

@end

@implementation SFSDKURLHandlerManagerTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testHandlerManagerNotHandledUrl {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    XCTAssertNotNil(manager);
    NSURL *url = [NSURL URLWithString:@"http://test/test"];
    BOOL result = [manager canHandleRequest:url options:nil];
    XCTAssertFalse(result);
    
}

- (void)testHandlerManagerForAdvancedAuth {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    XCTAssertNotNil(manager);
    NSURL *url = [NSURL URLWithString:@"myapp://test/test/code=666"];
    BOOL result = [manager canHandleRequest:url options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid advanced auth request");
}

- (void)testHandlerManagerForAdvancedAuthWithHandler {
    NSURL *url = [NSURL URLWithString:@"myapp://test/test/code=666"];
    SFSDKAdvancedAuthURLHandler *handler = [[SFSDKAdvancedAuthURLHandler alloc]init];
    BOOL result = [handler canHandleRequest:url options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid advanced auth request");
}

- (void)testHandlerManagerForAuthError {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    XCTAssertNotNil(manager);
    NSURL *url = [NSURL URLWithString:@"myapp://test/test/code="];
    BOOL result = [manager canHandleRequest:url options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid advanced auth request");
}



- (void)testHandlerManagerForIDPRequest {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
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
    test.scheme = @"someapp";
    BOOL result = [manager canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid id p auth request");
}

- (void)testHandlerManagerForIDPRequestWithHandler {
    
    SFSDKIDPRequestHandler *handler = [[SFSDKIDPRequestHandler alloc] init];
    
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
    test.scheme = @"someapp";
    BOOL result = [handler canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKIDPRequestHandler should be able to consume a valid id p auth request");
}


- (void)testHandlerManagerForIDPRequestError {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    
    SFSDKAuthRequestCommand *test = [[SFSDKAuthRequestCommand alloc]init];
    XCTAssertNotNil(test);
    
    test.spClientId = @"%@$&7&";
    test.spAppName = @"===&&";
    test.spCodeChallenge = @"";
    test.spUserHint = @"&%20%36^^***";
    test.spRedirectURI = @"";
    test.spAppScopes = @"";
    test.spState = @"";
    test.spAppDescription = @"";
    
    test.scheme = @"someapp";
    BOOL result = [manager canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid id p auth request");
}

- (void)testHandlerManagerForIDPResponse {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    
    SFSDKAuthResponseCommand *test = [[SFSDKAuthResponseCommand alloc]init];
    XCTAssertNotNil(test);
    test.state = @"astate";
    test.authCode = @"authCode";
    test.scheme = @"anapp";

    BOOL result = [manager canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid id p auth response");
}


- (void)testHandlerManagerForIDPResponseWithHandler {
    SFSDKIDPResponseHandler *handler = [[SFSDKIDPResponseHandler alloc] init];
    
    SFSDKAuthResponseCommand *test = [[SFSDKAuthResponseCommand alloc]init];
    XCTAssertNotNil(test);
    test.state = @"astate";
    test.authCode = @"authCode";
    test.scheme = @"anapp";
    BOOL result = [handler canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFIDPResponseHandler should be able to consume a valid id p auth response");
}

- (void)testHandlerManagerForIDPError {
    SFSDKURLHandlerManager *manager = [SFSDKURLHandlerManager sharedInstance];
    
    NSString *errorCode = @"999";
    NSString *errorDesc = @"Aces%20High";
    NSString *errorReason = @"No%20Reason";
    
    SFSDKAuthErrorCommand *test = [[SFSDKAuthErrorCommand alloc]init];
    XCTAssertNotNil(test);
    test.errorReason = errorReason;
    test.errorCode = errorCode;
    test.errorDescription = errorDesc;
    test.scheme = @"anapp";
    BOOL result = [manager canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKURLHandlerManager should be able to consume a valid id p auth error");
}

- (void)testHandlerManagerForIDPRequestErrorWithHandler {
    SFSDKIDPErrorHandler *handler = [[SFSDKIDPErrorHandler alloc]init];
    NSString *errorCode = @"999";
    NSString *errorDesc = @"Aces%20High";
    NSString *errorReason = @"No%20Reason";
    
    SFSDKAuthErrorCommand *test = [[SFSDKAuthErrorCommand alloc]init];
    XCTAssertNotNil(test);
    test.errorReason = errorReason;
    test.errorCode = errorCode;
    test.errorDescription = errorDesc;
    test.scheme = @"anapp";
    BOOL result = [handler canHandleRequest:[test requestURL] options:nil];
    XCTAssertTrue(result, @"SFSDKAuthErrorCommand should be able to consume a valid id p auth error");
}
@end
