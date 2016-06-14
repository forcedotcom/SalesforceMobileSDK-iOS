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

#import "InstrumentationEventBuilder.h"
#import "SFSDKReachability.h"
#import "AnalyticsManager+Internal.h"
#import "InstrumentationEvent+Internal.h"

@interface InstrumentationEventBuilder ()

@property (nonatomic, strong, readwrite) AnalyticsManager *analyticsManager;
@property (nonatomic, assign, readwrite) NSInteger startTime;
@property (nonatomic, assign, readwrite) NSInteger endTime;
@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSDictionary *attributes;
@property (nonatomic, assign, readwrite) NSInteger sessionId;
@property (nonatomic, strong, readwrite) NSString *senderId;
@property (nonatomic, strong, readwrite) NSDictionary *senderContext;
@property (nonatomic, assign, readwrite) EventType eventType;
@property (nonatomic, assign, readwrite) Type type;
@property (nonatomic, assign, readwrite) Subtype subtype;
@property (nonatomic, assign, readwrite) ErrorType errorType;

@end

@implementation InstrumentationEventBuilder

+ (InstrumentationEventBuilder *) getInstance:(AnalyticsManager *) analyticsManager {
    return [[InstrumentationEventBuilder alloc] init:analyticsManager];
}

- (InstrumentationEventBuilder *) init:(AnalyticsManager *) analyticsManager {
    self = [super init];
    if (self) {
        self.analyticsManager = analyticsManager;
    }
    return self;
}

- (InstrumentationEventBuilder *) startTime:(NSInteger) startTime {
    self.startTime = startTime;
    return self;
}

- (InstrumentationEventBuilder *) endTime:(NSInteger) endTime {
    self.endTime = endTime;
    return self;
}

- (InstrumentationEventBuilder *) name:(NSString *) name {
    self.name = name;
    return self;
}

- (InstrumentationEventBuilder *) attributes:(NSDictionary *) attributes {
    self.attributes = attributes;
    return self;
}

- (InstrumentationEventBuilder *) sessionId:(NSInteger) sessionId {
    self.sessionId = sessionId;
    return self;
}

- (InstrumentationEventBuilder *) senderId:(NSString *) senderId {
    self.senderId = senderId;
    return self;
}

- (InstrumentationEventBuilder *) senderContext:(NSDictionary *) senderContext {
    self.senderContext = senderContext;
    return self;
}

- (InstrumentationEventBuilder *) eventType:(EventType) eventType {
    self.eventType = eventType;
    return self;
}

- (InstrumentationEventBuilder *) type:(Type) type {
    self.type = type;
    return self;
}

- (InstrumentationEventBuilder *) subtype:(Subtype) subtype {
    self.subtype = subtype;
    return self;
}

- (InstrumentationEventBuilder *) errorType:(ErrorType) errorType {
    self.errorType = errorType;
    return self;
}

- (InstrumentationEvent *) buildEvent {
    NSString *eventId = [[NSUUID UUID] UUIDString];
    NSString *errorMessage = nil;
    if (!self.eventType) {
        errorMessage = @"Mandatory field 'event type' not set!";
    }
    if (!self.name) {
        errorMessage = @"Mandatory field 'name' not set!";
    }
    DeviceAppAttributes *deviceAppAttributes = self.analyticsManager.deviceAttributes;
    if (!deviceAppAttributes) {
        errorMessage = @"Mandatory field 'device app attributes' not set!";
    }
    if (errorMessage) {
        @throw [NSException exceptionWithName:@"EventBuilderException" reason:errorMessage userInfo:nil];
    }
    NSInteger sequenceId = self.analyticsManager.globalSequenceId + 1;
    self.analyticsManager.globalSequenceId = sequenceId;

    // Defaults to current time if not explicitly set.
    NSInteger curTime = [[NSDate date] timeIntervalSince1970] * 1000;
    self.startTime = (self.startTime == 0) ? curTime : self.startTime;
    return [[InstrumentationEvent alloc] init:eventId startTime:self.startTime endTime:self.endTime name:self.name attributes:self.attributes sessionId:self.sessionId sequenceId:sequenceId senderId:self.senderId senderContext:self.senderContext eventType:self.eventType type:self.type subtype:self.subtype errorType:self.errorType deviceAppAttributes:deviceAppAttributes connectionType:[self getConnectionType]];
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
