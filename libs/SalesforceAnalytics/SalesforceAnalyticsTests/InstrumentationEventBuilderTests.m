/*
 InstrumentationEventBuilderTests.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/5/16.
 
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
#import <SalesforceAnalytics/DeviceAppAttributes.h>
#import <SalesforceAnalytics/AnalyticsManager.h>

static DeviceAppAttributes * const kDeviceAppAttributes = [[DeviceAppAttributes alloc] init:@"TEST_APP_VERSION" appName:@"TEST_APP_NAME" osVersion:@"TEST_OS_VERSION" osName:@"TEST_OS_NAME" nativeAppType:@"TEST_NATIVE_APP_TYPE" mobileSdkVersion:@"TEST_MOBILE_SDK_VERSION" deviceModel:@"TEST_DEVICE_MODEL" deviceId:@"TEST_DEVICE_ID"];
static NSString * const kTestEventName = @"TEST_EVENT_NAME_%@";
static NSString * const kTestSenderId = @"TEST_SENDER_ID";

@interface InstrumentationEventBuilderTests : XCTestCase

@property (nonatomic, readwrite, strong) NSString *uniqueId;
@property (nonatomic, readwrite, strong) AnalyticsManager *analyticsManager;

@end

@implementation InstrumentationEventBuilderTests

- (void) setUp {
    [super setUp];
    self.uniqueId = [[NSUUID UUID] UUIDString];
    self.AnalyticsManager = [AnalyticsManager sharedInstance:self.uniqueId dataEncryptorBlock:nil dataDecryptorBlock:nil deviceAttributes:kDeviceAppAttributes];
}

- (void) tearDown {
    [AnalyticsManager removeSharedInstance:self.uniqueId];
    [super tearDown];
}

@end
