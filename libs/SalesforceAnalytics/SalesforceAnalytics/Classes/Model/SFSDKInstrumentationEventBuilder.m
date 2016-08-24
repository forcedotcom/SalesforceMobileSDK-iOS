/*
 InstrumentationEventBuilder.m
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

#import "SFSDKInstrumentationEventBuilder.h"
#import "SFSDKReachability.h"
#import "SFSDKAnalyticsManager+Internal.h"
#import "SFSDKInstrumentationEvent+Internal.h"

@interface SFSDKInstrumentationEventBuilder ()

@property (nonatomic, strong, readwrite) SFSDKAnalyticsManager *analyticsManager;
@property (nonatomic, assign, readwrite) NSInteger startTime;
@property (nonatomic, assign, readwrite) NSInteger endTime;
@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSDictionary *attributes;
@property (nonatomic, strong, readwrite) NSString *sessionId;
@property (nonatomic, strong, readwrite) NSString *senderId;
@property (nonatomic, strong, readwrite) NSDictionary *senderContext;
@property (nonatomic, assign, readwrite) SFASchemaType schemaType;
@property (nonatomic, assign, readwrite) SFAEventType eventType;
@property (nonatomic, assign, readwrite) SFAErrorType errorType;
@property (nonatomic, strong, readwrite) NSString *senderParentId;
@property (nonatomic, assign, readwrite) NSInteger sessionStartTime;
@property (nonatomic, strong, readwrite) NSDictionary *page;
@property (nonatomic, strong, readwrite) NSDictionary *previousPage;
@property (nonatomic, strong, readwrite) NSDictionary *marks;

@end

@implementation SFSDKInstrumentationEventBuilder

+ (SFSDKInstrumentationEventBuilder *) eventBuilderWithAnalyticsManager:(SFSDKAnalyticsManager *) analyticsManager {
    return [[SFSDKInstrumentationEventBuilder alloc] initWithAnalyticsManager:analyticsManager];
}

- (SFSDKInstrumentationEventBuilder *) initWithAnalyticsManager:(SFSDKAnalyticsManager *) analyticsManager {
    self = [super init];
    if (self) {
        self.analyticsManager = analyticsManager;
    }
    return self;
}

- (SFSDKInstrumentationEventBuilder *) startTime:(NSInteger) startTime {
    self.startTime = startTime;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) endTime:(NSInteger) endTime {
    self.endTime = endTime;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) name:(NSString *) name {
    self.name = name;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) attributes:(NSDictionary *) attributes {
    self.attributes = attributes;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) sessionId:(NSString *) sessionId {
    self.sessionId = sessionId;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) senderId:(NSString *) senderId {
    self.senderId = senderId;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) senderContext:(NSDictionary *) senderContext {
    self.senderContext = senderContext;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) schemaType:(SFASchemaType) schemaType {
    self.schemaType = schemaType;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) eventType:(SFAEventType) eventType {
    self.eventType = eventType;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) errorType:(SFAErrorType) errorType {
    self.errorType = errorType;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) senderParentId:(NSString *) senderParentId {
    self.senderParentId = senderParentId;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) sessionStartTime:(NSInteger) sessionStartTime {
    self.sessionStartTime = sessionStartTime;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) page:(NSDictionary *) page {
    self.page = page;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) previousPage:(NSDictionary *) previousPage {
    self.previousPage = previousPage;
    return self;
}

- (SFSDKInstrumentationEventBuilder *) marks:(NSDictionary *) marks {
    self.marks = marks;
    return self;
}

- (SFSDKInstrumentationEvent *) buildEvent {
    NSString *eventId = [[NSUUID UUID] UUIDString];
    NSString *errorMessage = nil;
    if (!self.name) {
        errorMessage = @"Mandatory field 'name' not set!";
    }
    SFSDKDeviceAppAttributes *deviceAppAttributes = self.analyticsManager.deviceAttributes;
    if (!deviceAppAttributes) {
        errorMessage = @"Mandatory field 'device app attributes' not set!";
    }
    if (self.schemaType != SchemaTypePerf && !self.page) {
        errorMessage = @"Mandatory field 'page' not set!";
    }
    if (errorMessage) {
        @throw [NSException exceptionWithName:@"EventBuilderException" reason:errorMessage userInfo:nil];
    }
    NSInteger sequenceId = self.analyticsManager.globalSequenceId + 1;
    self.analyticsManager.globalSequenceId = sequenceId;

    // Defaults to current time if not explicitly set.
    NSInteger curTime = [[NSDate date] timeIntervalSince1970] * 1000;
    self.startTime = (self.startTime == 0) ? curTime : self.startTime;
    self.sessionStartTime = (self.sessionStartTime == 0) ? curTime : self.sessionStartTime;
    return [[SFSDKInstrumentationEvent alloc] initWithEventId:eventId startTime:self.startTime endTime:self.endTime name:self.name attributes:self.attributes sessionId:self.sessionId sequenceId:sequenceId senderId:self.senderId senderContext:self.senderContext schemaType:self.schemaType eventType:self.eventType errorType:self.errorType deviceAppAttributes:deviceAppAttributes connectionType:[self getConnectionType] senderParentId:self.senderParentId sessionStartTime:self.sessionStartTime page:self.page previousPage:self.previousPage marks:self.marks];
}

- (NSString *) getConnectionType {
    SFSDKReachability *reachability = [SFSDKReachability reachabilityForInternetConnection];
    [reachability startNotifier];
    SFSDKReachabilityNetworkStatus networkStatus = [reachability currentReachabilityStatus];
    switch (networkStatus) {
        case SFSDKReachabilityNotReachable:
            return @"None";
        case SFSDKReachabilityReachableViaWWAN:
            return @"Cellular";
        case SFSDKReachabilityReachableViaWiFi:
            return @"WiFi";
        default:
            return @"Unknown";
    }
}

@end
