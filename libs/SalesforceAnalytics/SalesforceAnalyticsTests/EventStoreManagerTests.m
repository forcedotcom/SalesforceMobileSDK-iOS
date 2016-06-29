/*
 EventStoreManagerTests.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/15/16.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceAnalytics/InstrumentationEventBuilder.h>
#import "AnalyticsTestUtil.h"

static NSString * const kTestEventName = @"TEST_EVENT_NAME_%lf";
static NSString * const kTestSenderId = @"TEST_SENDER_ID";

@interface EventStoreManagerTests : XCTestCase

@property (nonatomic, readwrite, strong) NSString *storeDirectory;
@property (nonatomic, readwrite, strong) AnalyticsManager *analyticsManager;
@property (nonatomic, readwrite, strong) EventStoreManager *storeManager;

@end

@implementation EventStoreManagerTests

- (void)setUp {
    [super setUp];
    DeviceAppAttributes *deviceAppAttributes = [[DeviceAppAttributes alloc] init:@"TEST_APP_VERSION" appName:@"TEST_APP_NAME" osVersion:@"TEST_OS_VERSION" osName:@"TEST_OS_NAME" nativeAppType:@"TEST_NATIVE_APP_TYPE" mobileSdkVersion:@"TEST_MOBILE_SDK_VERSION" deviceModel:@"TEST_DEVICE_MODEL" deviceId:@"TEST_DEVICE_ID" clientId:@"TEST_CLIENT_ID"];
    self.storeDirectory = [AnalyticsTestUtil buildTestStoreDirectory];
    self.analyticsManager = [[AnalyticsManager alloc] init:self.storeDirectory dataEncryptorBlock:nil dataDecryptorBlock:nil deviceAttributes:deviceAppAttributes];
    self.storeManager = [[EventStoreManager alloc] init:self.storeDirectory dataEncryptorBlock:nil dataDecryptorBlock:nil];
}

- (void)tearDown {
    [self.storeManager deleteAllEvents];
    [self.analyticsManager reset];
    [super tearDown];
}

/**
 * Test for storing one event and retrieving it.
 */
- (void) testStoreOneEvent {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(1, events.count, @"Number of events stored should be 1");
    XCTAssertEqualObjects(event, [events firstObject], @"Stored event should be the same as generated event");
}

/**
 * Test for storing many events and retrieving them.
 */
- (void) testStoreMultipleEvents {
    InstrumentationEvent *event1 = [self createTestEvent];
    XCTAssertTrue(event1 != nil, @"Generated event stored should not be nil");
    InstrumentationEvent *event2 = [self createTestEvent];
    XCTAssertTrue(event2 != nil, @"Generated event stored should not be nil");
    NSMutableArray<InstrumentationEvent *> *genEvents = [[NSMutableArray alloc] init];
    [genEvents addObject:event1];
    [genEvents addObject:event2];
    [self.storeManager storeEvents:genEvents];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(2, events.count, @"Number of events stored should be 2");
    XCTAssertTrue([event1 isEqual:[events firstObject]], @"Stored event should be the same as generated event");
    XCTAssertTrue([event2 isEqual:[events objectAtIndex:1]], @"Stored event should be the same as generated event");
}

/**
 * Test for fetching one event by specifying event ID.
 */
- (void) testFetchOneEvent {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    NSString *eventId = event.eventId;
    [self.storeManager storeEvent:event];
    InstrumentationEvent *storedEvent = [self.storeManager fetchEvent:eventId];
    XCTAssertTrue(storedEvent != nil, @"Event stored should not be nil");
    XCTAssertEqualObjects(event, storedEvent, @"Stored event should be the same as generated event");
}

/**
 * Test for fetching all stored events.
 */
- (void) testFetchAllEvents {
    InstrumentationEvent *event1 = [self createTestEvent];
    XCTAssertTrue(event1 != nil, @"Generated event stored should not be nil");
    [self.storeManager storeEvent:event1];
    InstrumentationEvent *event2 = [self createTestEvent];
    XCTAssertTrue(event2 != nil, @"Generated event stored should not be nil");
    [self.storeManager storeEvent:event2];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(2, events.count, @"Number of events stored should be 2");
    XCTAssertTrue([event1 isEqual:[events firstObject]], @"Stored event should be the same as generated event");
    XCTAssertTrue([event2 isEqual:[events objectAtIndex:1]], @"Stored event should be the same as generated event");
}

/**
 * Test for deleting one event by specifying event ID.
 */
- (void) testDeleteOneEvent {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    NSString *eventId = event.eventId;
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *eventsBeforeDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsBeforeDel != nil, @"List of events should not be nil");
    XCTAssertEqual(1, eventsBeforeDel.count, @"Number of events stored should be 1");
    XCTAssertEqualObjects(event, [eventsBeforeDel firstObject], @"Stored event should be the same as generated event");
    [self.storeManager deleteEvent:eventId];
    NSArray<InstrumentationEvent *> *eventsAfterDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsAfterDel != nil, @"List of events should not be nil");
    XCTAssertEqual(0, eventsAfterDel.count, @"Number of events stored should be 0");
}

/**
 * Test for deleting multiple events by specifying event IDs.
 */
- (void) testDeleteMultipleEvents {
    InstrumentationEvent *event1 = [self createTestEvent];
    XCTAssertTrue(event1 != nil, @"Generated event stored should not be nil");
    NSString *eventId1 = event1.eventId;
    InstrumentationEvent *event2 = [self createTestEvent];
    XCTAssertTrue(event2 != nil, @"Generated event stored should not be nil");
    NSString *eventId2 = event2.eventId;
    NSMutableArray<InstrumentationEvent *> *genEvents = [[NSMutableArray alloc] init];
    [genEvents addObject:event1];
    [genEvents addObject:event2];
    [self.storeManager storeEvents:genEvents];
    NSArray<InstrumentationEvent *> *eventsBeforeDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsBeforeDel != nil, @"List of events should not be nil");
    XCTAssertEqual(2, eventsBeforeDel.count, @"Number of events stored should be 2");
    XCTAssertTrue([event1 isEqual:[eventsBeforeDel firstObject]], @"Stored event should be the same as generated event");
    XCTAssertTrue([event2 isEqual:[eventsBeforeDel objectAtIndex:1]], @"Stored event should be the same as generated event");
    NSMutableArray<NSString *> *eventIds = [[NSMutableArray alloc] init];
    [eventIds addObject:eventId1];
    [eventIds addObject:eventId2];
    [self.storeManager deleteEvents:eventIds];
    NSArray<InstrumentationEvent *> *eventsAfterDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsAfterDel != nil, @"List of events should not be nil");
    XCTAssertEqual(0, eventsAfterDel.count, @"Number of events stored should be 0");
}

/**
 * Test for deleting all events stored.
 */
- (void) testDeleteAllEvents {
    InstrumentationEvent *event1 = [self createTestEvent];
    XCTAssertTrue(event1 != nil, @"Generated event stored should not be nil");
    InstrumentationEvent *event2 = [self createTestEvent];
    XCTAssertTrue(event2 != nil, @"Generated event stored should not be nil");
    NSMutableArray<InstrumentationEvent *> *genEvents = [[NSMutableArray alloc] init];
    [genEvents addObject:event1];
    [genEvents addObject:event2];
    [self.storeManager storeEvents:genEvents];
    NSArray<InstrumentationEvent *> *eventsBeforeDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsBeforeDel != nil, @"List of events should not be nil");
    XCTAssertEqual(2, eventsBeforeDel.count, @"Number of events stored should be 2");
    XCTAssertTrue([event1 isEqual:[eventsBeforeDel firstObject]], @"Stored event should be the same as generated event");
    XCTAssertTrue([event2 isEqual:[eventsBeforeDel objectAtIndex:1]], @"Stored event should be the same as generated event");
    [self.storeManager deleteAllEvents];
    NSArray<InstrumentationEvent *> *eventsAfterDel = [self.storeManager fetchAllEvents];
    XCTAssertTrue(eventsAfterDel != nil, @"List of events should not be nil");
    XCTAssertEqual(0, eventsAfterDel.count, @"Number of events stored should be 0");
}

/**
 * Test for disabling logging.
 */
- (void) testDisablingLogging {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    self.storeManager.isLoggingEnabled = NO;
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(0, events.count, @"Number of events stored should be 0");
}

/**
 * Test for enabling logging.
 */
- (void) testEnablingLogging {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    self.storeManager.isLoggingEnabled = NO;
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(0, events.count, @"Number of events stored should be 0");
    self.storeManager.isLoggingEnabled = YES;
    [self.storeManager storeEvent:event];
    events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(1, events.count, @"Number of events stored should be 1");
    XCTAssertEqualObjects(event, [events firstObject], @"Stored event should be the same as generated event");
}

/**
 * Test for event limit exceeded.
 */
- (void) testEventLimitExceeded {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    self.storeManager.maxEvents = 0;
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(0, events.count, @"Number of events stored should be 0");
}

/**
 * Test for event limit not exceeded.
 */
- (void) testEventLimitNotExceeded {
    InstrumentationEvent *event = [self createTestEvent];
    XCTAssertTrue(event != nil, @"Generated event stored should not be nil");
    self.storeManager.maxEvents = 0;
    [self.storeManager storeEvent:event];
    NSArray<InstrumentationEvent *> *events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(0, events.count, @"Number of events stored should be 0");
    self.storeManager.maxEvents = 1;
    [self.storeManager storeEvent:event];
    events = [self.storeManager fetchAllEvents];
    XCTAssertTrue(events != nil, @"List of events should not be nil");
    XCTAssertEqual(1, events.count, @"Number of events stored should be 1");
    XCTAssertEqualObjects(event, [events firstObject], @"Stored event should be the same as generated event");
}

- (InstrumentationEvent *) createTestEvent {
    InstrumentationEventBuilder *builder = [InstrumentationEventBuilder getInstance:self.analyticsManager];
    double curTime = 1000 * [[NSDate date] timeIntervalSince1970];
    NSString *eventName = [NSString stringWithFormat:kTestEventName, curTime];
    [builder startTime:curTime];
    [builder name:eventName];
    [builder sessionId:1];
    [builder page:[[NSDictionary alloc] init]];
    [builder senderId:kTestSenderId];
    [builder schemaType:SchemaTypeError];
    [builder eventType:EventTypeSystem];
    [builder errorType:ErrorTypeWarn];
    return [builder buildEvent];
}

@end
