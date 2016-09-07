/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "TestDataAction.h"

@interface CSFActionTest : XCTestCase

@property (nonatomic, strong) CSFNetwork *networkMock;

@end

@implementation CSFActionTest

- (void)setUp {
    [super setUp];

    self.networkMock = [TestDataAction mockNetworkWithAccount:nil];
}

- (void)testCancel {
    TestDataAction *testAction = nil;

    XCTestExpectation *normalCancelExpectation = [self expectationWithDescription:@"normal cancel block called"];
    testAction = [[TestDataAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, CSFNetworkErrorDomain);
        XCTAssertEqual(error.code, CSFNetworkCancelledError);
        [normalCancelExpectation fulfill];
    } testFilename:nil withExtension:nil];
    testAction.enqueuedNetwork = self.networkMock;
    [testAction cancel];
    
    XCTestExpectation *afterStartCancelExpectation = [self expectationWithDescription:@"after start cancel block called"];
    testAction = [[TestDataAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, CSFNetworkErrorDomain);
        XCTAssertEqual(error.code, CSFNetworkCancelledError);
        [afterStartCancelExpectation fulfill];
    } testFilename:nil withExtension:nil];
    testAction.enqueuedNetwork = self.networkMock;
    testAction.cancelled = YES;
    [testAction start];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}

- (void)testBadJSON {
    XCTestExpectation *responseBlockExpectation = [self expectationWithDescription:@"response block called"];

    TestDataAction *testAction = [[TestDataAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        XCTAssertNotNil(error);

        XCTAssertEqualObjects(error.domain, CSFNetworkErrorDomain);
        XCTAssertEqual(error.code, CSFNetworkJSONInvalidError);
        [responseBlockExpectation fulfill];
    } testString:@"What the heck, this isn't JSON?"];
    testAction.url = [NSURL URLWithString:@"http://example.com/foo/bar"];
    testAction.testResponseObject = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com/foo/bar"]
                                                                statusCode:200
                                                               HTTPVersion:@"1.1"
                                                              headerFields:nil];
    testAction.enqueuedNetwork = self.networkMock;
    [testAction start];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}

- (void)testBaseURL {
    CSFAction *action = [[CSFAction alloc] initWithResponseBlock:nil];
    XCTAssertNotNil(action);
    XCTAssertTrue([action.headersForAction[@"Accept-Encoding"] isEqualToString:@"gzip"]);
    
    action.baseURL = [NSURL URLWithString:@"http://example.com"];
    XCTAssertEqualObjects(action.baseURL.absoluteString, @"http://example.com/");

    action.verb = @"some/relative/path";
    XCTAssertEqualObjects(action.url.absoluteString, @"http://example.com/some/relative/path");

    action.verb = @"/some/relative/path";
    XCTAssertEqualObjects(action.url.absoluteString, @"http://example.com/some/relative/path");
    
    action.baseURL = [NSURL URLWithString:@"http://example.com/v1/root"];
    XCTAssertEqualObjects(action.baseURL.absoluteString, @"http://example.com/v1/root/");
    XCTAssertEqualObjects(action.url.absoluteString, @"http://example.com/v1/root/some/relative/path");
    
    action.url = [NSURL URLWithString:@"http://another.example.com/some/path/to/a/request"];
    XCTAssertEqualObjects(action.baseURL.absoluteString, @"http://another.example.com/");
    XCTAssertEqualObjects(action.url.absoluteString, @"http://another.example.com/some/path/to/a/request");
    XCTAssertEqualObjects(action.verb, @"/some/path/to/a/request");
}

@end
