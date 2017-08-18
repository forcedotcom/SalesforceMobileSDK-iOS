/*
 InstrumentationEventBuilderTests.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/5/16.
 
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceAnalytics/SFSDKInstrumentationEventBuilder.h>
#import "AnalyticsTestUtil.h"

static NSString * const kTestEventName = @"TEST_EVENT_NAME_%lf";
static NSString * const kTestSenderId = @"TEST_SENDER_ID";
static NSString * const kTestSessionId = @"TEST_SESSION_ID";

@interface InstrumentationEventBuilderTests : XCTestCase

@property (nonatomic, readwrite, strong) NSString *storeDirectory;
@property (nonatomic, readwrite, strong) SFSDKAnalyticsManager *analyticsManager;

@end

@implementation InstrumentationEventBuilderTests

- (void) setUp {
    [super setUp];
    SFSDKDeviceAppAttributes *deviceAppAttributes = [[SFSDKDeviceAppAttributes alloc] initWithAppVersion:@"TEST_APP_VERSION" appName:@"TEST_APP_NAME" osVersion:@"TEST_OS_VERSION" osName:@"TEST_OS_NAME" nativeAppType:@"TEST_NATIVE_APP_TYPE" mobileSdkVersion:@"TEST_MOBILE_SDK_VERSION" deviceModel:@"TEST_DEVICE_MODEL" deviceId:@"TEST_DEVICE_ID" clientId:@"TEST_CLIENT_ID"];
    self.storeDirectory = [AnalyticsTestUtil buildTestStoreDirectory];
    self.analyticsManager = [[SFSDKAnalyticsManager alloc] initWithStoreDirectory:self.storeDirectory dataEncryptorBlock:nil dataDecryptorBlock:nil deviceAttributes:deviceAppAttributes];
}

- (void) tearDown {
    [self.analyticsManager reset];
    [super tearDown];
}

- (void)testEventCopyAndEquality {
    SFSDKInstrumentationEvent *event = [self standardTestEvent];
    SFSDKInstrumentationEvent *eventCopy = [event copy];
    XCTAssertEqualObjects(event, eventCopy, @"Events should still be equivalent.");
    XCTAssertNotEqual(event, eventCopy, @"Copy should make a different event instance.");
}

/**
 * Test for missing mandatory field 'name'.
 */
- (void) testMissingName {
    SFSDKInstrumentationEvent *event = [SFSDKInstrumentationEventBuilder buildEventWithBuilderBlock:^(SFSDKInstrumentationEventBuilder *builder) {
        double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
        builder.startTime = curTime;
        builder.page = [[NSDictionary alloc] init];
        builder.sessionId = kTestSessionId;
        builder.senderId = kTestSenderId;
        builder.schemaType = SchemaTypeError;
        builder.eventType = EventTypeSystem;
        builder.errorType = ErrorTypeWarn;
    } analyticsManager:self.analyticsManager];
    XCTAssertEqualObjects(event, nil, @"Event should be nil due to missing mandatory field 'name'");
}

/**
 * Test for missing mandatory field 'page'.
 */
- (void) testMissingPage {
    SFSDKInstrumentationEvent *event = [SFSDKInstrumentationEventBuilder buildEventWithBuilderBlock:^(SFSDKInstrumentationEventBuilder *builder) {
        double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
        NSString *eventName = [NSString stringWithFormat:kTestEventName, curTime];
        builder.name = eventName;
        builder.startTime = curTime;
        builder.sessionId = kTestSessionId;
        builder.senderId = kTestSenderId;
        builder.schemaType = SchemaTypeError;
        builder.eventType = EventTypeSystem;
        builder.errorType = ErrorTypeWarn;
    } analyticsManager:self.analyticsManager];
    XCTAssertEqualObjects(event, nil, @"Event should be nil due to missing mandatory field 'page'");
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

/**
 * Test for missing mandatory field 'device app attributes'.
 */
- (void) testMissingDeviceAppAttributes {
    [self.analyticsManager reset];
    self.analyticsManager = [[SFSDKAnalyticsManager alloc] initWithStoreDirectory:self.storeDirectory dataEncryptorBlock:nil dataDecryptorBlock:nil deviceAttributes:nil];
    SFSDKInstrumentationEvent *event = [SFSDKInstrumentationEventBuilder buildEventWithBuilderBlock:^(SFSDKInstrumentationEventBuilder *builder) {
        double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
        NSString *eventName = [NSString stringWithFormat:kTestEventName, curTime];
        builder.name = eventName;
        builder.page = [[NSDictionary alloc] init];
        builder.startTime = curTime;
        builder.sessionId = kTestSessionId;
        builder.senderId = kTestSenderId;
        builder.schemaType = SchemaTypeError;
        builder.eventType = EventTypeSystem;
        builder.errorType = ErrorTypeWarn;
    } analyticsManager:self.analyticsManager];
    XCTAssertEqualObjects(event, nil, @"Event should be nil due to missing mandatory field 'device app attributes'");
    [self.analyticsManager reset];
}

#pragma clang diagnostic pop

/**
 * Test for auto population of mandatory field 'start time'.
 */
- (void) testAutoPopulateStartTime {
    SFSDKInstrumentationEvent *event = [SFSDKInstrumentationEventBuilder buildEventWithBuilderBlock:^(SFSDKInstrumentationEventBuilder *builder) {
        double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
        NSString *eventName = [NSString stringWithFormat:kTestEventName, curTime];
        builder.name = eventName;
        builder.page = [[NSDictionary alloc] init];
        builder.sessionId = kTestSessionId;
        builder.senderId = kTestSenderId;
        builder.schemaType = SchemaTypeError;
        builder.eventType = EventTypeSystem;
        builder.errorType = ErrorTypeWarn;
    } analyticsManager:self.analyticsManager];
    XCTAssertTrue(event.startTime > 0, @"Start time should have been auto populated");
}

/**
 * Test for auto population of mandatory field 'event ID'.
 */
- (void) testAutoPopulateEventId {
    SFSDKInstrumentationEvent *event = [self standardTestEvent];
    XCTAssertTrue(event.eventId != nil, @"Event ID should have been auto populated");
}

/**
 * Test for auto population of mandatory field 'sequence ID'.
 */
- (void) testAutoPopulateSequenceId {
    SFSDKInstrumentationEvent *event = [self standardTestEvent];
    NSInteger sequenceId = event.sequenceId;
    XCTAssertTrue(sequenceId > 0, @"Sequence ID should have been auto populated");
    NSInteger globalSequenceId = self.analyticsManager.globalSequenceId;
    XCTAssertEqual(0, globalSequenceId - sequenceId);
}

#pragma mark - Helper methods

- (SFSDKInstrumentationEvent *)standardTestEvent {
    return [SFSDKInstrumentationEventBuilder buildEventWithBuilderBlock:^(SFSDKInstrumentationEventBuilder *builder) {
        double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
        NSString *eventName = [NSString stringWithFormat:kTestEventName, curTime];
        builder.name = eventName;
        builder.page = [[NSDictionary alloc] init];
        builder.startTime = curTime;
        builder.sessionId = kTestSessionId;
        builder.senderId = kTestSenderId;
        builder.schemaType = SchemaTypeError;
        builder.eventType = EventTypeSystem;
        builder.errorType = ErrorTypeWarn;
    } analyticsManager:self.analyticsManager];
}

@end
