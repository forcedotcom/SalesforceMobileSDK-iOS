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
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertView.h"
#import "SFSDKWindowManager.h"
@interface SDSDKAlertMessageTest : XCTestCase

@end

@implementation SDSDKAlertMessageTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMessageCreate {
    
    NSString *alertTitle = @"Title";
    NSString *buttonOneTitle = @"ButtonOne";
    NSString *buttonTwoTitle = @"ButtonTwo";
    NSString *alertMessage = @"Message for the alert";
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder){
        builder.alertTitle = alertTitle;
        builder.actionOneTitle = buttonOneTitle;
        builder.actionTwoTitle = buttonTwoTitle;
        builder.alertMessage = alertMessage;
    }];
    XCTAssertNotNil(message);
    XCTAssertTrue([message.alertTitle isEqualToString:alertTitle]);
    XCTAssertTrue([message.actionOneTitle isEqualToString:buttonOneTitle]);
    XCTAssertTrue([message.actionTwoTitle isEqualToString:buttonTwoTitle]);
    XCTAssertTrue([message.alertMessage isEqualToString:alertMessage]);
}

- (void)testMessageCreateWithCompletionBlocks {
    NSString *alertTitle = @"Title";
    NSString *buttonOneTitle = @"ButtonOne";
    NSString *buttonTwoTitle = @"ButtonTwo";
    NSString *alertMessage = @"Message for the alert";
    XCTestExpectation *expectationOne = [self expectationWithDescription:@"messageActionOne"];
    XCTestExpectation *expectationTwo = [self expectationWithDescription:@"messageActionTwo"];
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder){
        builder.alertTitle = alertTitle;
        builder.actionOneTitle = buttonOneTitle;
        builder.actionTwoTitle = buttonTwoTitle;
        builder.alertMessage = alertMessage;
        builder.actionOneCompletion = ^{
            [expectationOne fulfill];
        };
        builder.actionTwoCompletion = ^{
            [expectationTwo fulfill];
        };
    }];
    XCTAssertNotNil(message);
    XCTAssertNotNil(message.actionOneCompletion);
    message.actionOneCompletion();
    XCTAssertNotNil(message.actionTwoCompletion);
    message.actionTwoCompletion();
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testAlertViewCreate {
    
    NSString *alertTitle = @"Title";
    NSString *buttonOneTitle = @"ButtonOne";
    NSString *buttonTwoTitle = @"ButtonTwo";
    NSString *alertMessage = @"Message for the alert";
    
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder){
        builder.alertTitle = alertTitle;
        builder.actionOneTitle = buttonOneTitle;
        builder.actionTwoTitle = buttonTwoTitle;
        builder.alertMessage = alertMessage;
        builder.actionOneCompletion = ^{
          
        };
        builder.actionTwoCompletion = ^{
           
        };
    }];
    
    SFSDKAlertView *view = [[SFSDKAlertView alloc] initWithMessage:message window:[SFSDKWindowManager sharedManager].authWindow];
    XCTAssertNotNil(view);
    XCTAssertNotNil(view.controller);
    XCTAssertNotNil(view.window);
    XCTAssertTrue(view.window == [SFSDKWindowManager sharedManager].authWindow);
}



@end
