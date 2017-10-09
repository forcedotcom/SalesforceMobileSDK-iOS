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
#import "SFSDKAuthErrorCommand.h"
@interface SFSDKAuthErrorCommandTest : XCTestCase

@end

@implementation SFSDKAuthErrorCommandTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
}

- (void)testSFSDKAuthErrorCommand {
    SFSDKAuthErrorCommand *test = [[SFSDKAuthErrorCommand alloc]init];
    XCTAssertNotNil(test);
    NSString *testURL = @"atest://atest/v1.0/error";
    XCTAssertTrue([test isAuthCommand:[NSURL URLWithString:testURL]]);
    
    XCTAssertTrue([test isAuthCommand:[NSURL URLWithString:testURL.uppercaseString]]);
    
}

- (void)testSFSDKAuthErrorCommandBadURL {
    SFSDKAuthErrorCommand *test = [[SFSDKAuthErrorCommand alloc]init];
    XCTAssertNotNil(test);
    NSString *testURL = @"atest://atest/error";
    XCTAssertTrue(![test isAuthCommand:[NSURL URLWithString:testURL]]);
}


- (void)testSFSDKAuthErrorCommandWithParameters {
    
    NSString *errorCode = @"999";
    NSString *errorDesc = @"Aces%20High";
    NSString *errorReason = @"No%20Reason";
    
    SFSDKAuthErrorCommand *test = [[SFSDKAuthErrorCommand alloc]init];
    XCTAssertNotNil(test);
    
    NSString *testURLString = [NSString stringWithFormat:@"atest://atest/v1.0/error?errorCode=%@&errorDescription=%@&errorReason=%@",errorCode,errorDesc,errorReason];
    NSURL *testURL = [NSURL URLWithString:testURLString];
    
    XCTAssertNotNil(testURL);
    [test fromRequestURL:testURL];
    
    XCTAssertTrue(test.errorCode!=nil, @"Error Code should not be nil");
    XCTAssertTrue(test.errorDescription!=nil, @"Error Description should not be nil");
    XCTAssertTrue([test.errorCode isEqualToString:errorCode], @"Error Code should not have changed");
    
    XCTAssertTrue([test.errorDescription isEqualToString:[errorDesc stringByRemovingPercentEncoding]], @"Error Desc should not have changed");
   
    XCTAssertTrue([test.errorReason isEqualToString:[errorReason stringByRemovingPercentEncoding]], @"Error Reason should not have changed");
}


@end
