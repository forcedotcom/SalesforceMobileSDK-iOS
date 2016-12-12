/*
 AILTNTransform.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/16/16.
 
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

#import "SFSDKAILTNTransform.h"

static NSString* const kSFConnectionTypeKey = @"connectionType";
static NSString* const kSFVersionKey = @"version";
static NSString* const kSFVersionValue = @"0.2";
static NSString* const kSFSchemaTypeKey = @"schemaType";
static NSString* const kSFIdKey = @"id";
static NSString* const kSFEventSourceKey = @"eventSource";
static NSString* const kSFTsKey = @"ts";
static NSString* const kSFPageStartTimeKey = @"pageStartTime";
static NSString* const kSFDurationKey = @"duration";
static NSString* const kSFEptKey = @"ept";
static NSString* const kSFClientSessionIdKey = @"clientSessionId";
static NSString* const kSFSequenceKey = @"sequence";
static NSString* const kSFAttributesKey = @"attributes";
static NSString* const kSFLocatorKey = @"locator";
static NSString* const kSFEventTypeKey = @"eventType";
static NSString* const kSFErrorTypeKey = @"errorType";
static NSString* const kSFTargetKey = @"target";
static NSString* const kSFScopeKey = @"scope";
static NSString* const kSFContextKey = @"context";
static NSString* const kSFDeviceAttributesKey = @"deviceAttributes";
static NSString* const kSFPageKey = @"page";
static NSString* const kSFPreviousPageKey = @"previousPage";
static NSString* const kSFMarksKey = @"marks";
static NSString* const kSFPerfEventType = @"defs";

@implementation SFSDKAILTNTransform

- (id) transform:(SFSDKInstrumentationEvent *) event {
    if (!event) {
        return nil;
    }
    NSMutableDictionary *logLine = [[NSMutableDictionary alloc] init];
    NSDictionary *payload = [[self class] buildPayload:event];
    if (payload) {
        logLine = [NSMutableDictionary dictionaryWithDictionary:payload];
        if (logLine) {
            logLine[kSFDeviceAttributesKey] = [[self class] buildDeviceAttributes:event];
        }
    }
    return logLine;
}

+ (NSDictionary *) buildDeviceAttributes:(SFSDKInstrumentationEvent *) event {
    NSMutableDictionary *deviceAttributes = [[NSMutableDictionary alloc] init];
    SFSDKDeviceAppAttributes *deviceAppAttributes = event.deviceAppAttributes;
    if (deviceAppAttributes) {
        deviceAttributes = [NSMutableDictionary dictionaryWithDictionary:[deviceAppAttributes jsonRepresentation]];
        if (deviceAttributes) {
            deviceAttributes[kSFConnectionTypeKey] = event.connectionType;
        }
    }
    return deviceAttributes;
}

+ (NSDictionary *) buildPayload:(SFSDKInstrumentationEvent *) event {
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    payload[kSFVersionKey] = kSFVersionValue;
    SFASchemaType schemaType = event.schemaType;
    payload[kSFSchemaTypeKey] = [event stringValueOfSchemaType:schemaType];
    payload[kSFIdKey] = event.eventId;
    payload[kSFEventSourceKey] = event.name;
    NSInteger startTime = event.startTime;
    payload[kSFTsKey] = [NSNumber numberWithInteger:startTime];
    payload[kSFPageStartTimeKey] = [NSNumber numberWithInteger:event.sessionStartTime];
    NSInteger endTime = event.endTime;
    NSInteger duration = endTime - startTime;
    if (duration > 0) {
        if (schemaType == SchemaTypeInteraction || schemaType == SchemaTypePerf) {
            payload[kSFDurationKey] = [NSNumber numberWithInteger:duration];
        } else if (schemaType == SchemaTypePageView) {
            payload[kSFEptKey] = [NSNumber numberWithInteger:duration];
        }
    }
    NSString *sessionId = event.sessionId;
    if (sessionId) {
        payload[kSFClientSessionIdKey] = sessionId;
    }
    if (schemaType != SchemaTypePerf) {
        payload[kSFSequenceKey] = [NSNumber numberWithInteger:event.sequenceId];
    }
    NSDictionary *attributes = event.attributes;
    if (attributes) {
        payload[kSFAttributesKey] = attributes;
    }
    if (schemaType != SchemaTypePerf) {
        payload[kPageKey] = event.page;
    }
    NSDictionary *previousPage = event.previousPage;
    if (previousPage && schemaType == SchemaTypePageView) {
        payload[kPreviousPageKey] = previousPage;
    }
    NSDictionary *marks = event.marks;
    if (marks && (schemaType == SchemaTypePageView || schemaType == SchemaTypePerf)) {
        payload[kMarksKey] = marks;
    }
    if (schemaType == SchemaTypeInteraction || schemaType == SchemaTypePageView) {
        NSDictionary *locator = [[self class] buildLocator:event];
        if (locator) {
            payload[kSFLocatorKey] = locator;
        }
    }
    SFAEventType eventType = event.eventType;
    NSString *eventTypeString;
    if (schemaType == SchemaTypePerf) {
        eventTypeString = kSFPerfEventType;
    } else if (schemaType == SchemaTypeInteraction) {
        eventTypeString = [event stringValueOfEventType:eventType];
    }
    if (eventTypeString) {
        payload[kSFEventTypeKey] = eventTypeString;
    }
    SFAErrorType errorType = event.errorType;
    if (schemaType == SchemaTypeError) {
        payload[kSFErrorTypeKey] = [event stringValueOfErrorType:errorType];
    }
    return payload;
}

+ (NSDictionary *) buildLocator:(SFSDKInstrumentationEvent *) event {
    NSMutableDictionary *locator = [[NSMutableDictionary alloc] init];
    NSString *senderId = event.senderId;
    NSString *senderParentId = event.senderParentId;
    if (!senderId || !senderParentId) {
        return nil;
    }
    locator[kSFTargetKey] = senderId;
    locator[kSFScopeKey] = senderParentId;
    NSDictionary *senderContext = event.senderContext;
    if (senderContext) {
        locator[kSFContextKey] = senderContext;
    }
    return locator;
}

@end
