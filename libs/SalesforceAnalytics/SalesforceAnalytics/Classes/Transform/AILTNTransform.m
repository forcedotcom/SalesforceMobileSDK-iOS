/*
 AILTNTransform.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/16/16.
 
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

#import "AILTNTransform.h"

static NSString* const kSFConnectionTypeKey = @"connectionType";
static NSString* const kSFPayloadKey = @"payload";
static NSString* const kSFVersionKey = @"version";
static NSString* const kSFVersionValue = @"0.2";
static NSString* const kSFSchemaTypeKey = @"schemaType";
static NSString* const kSFIdKey = @"id";
static NSString* const kSFEventSourceKey = @"eventSource";
static NSString* const kSFTsKey = @"ts";
static NSString* const kSFPageStartTimeKey = @"pageStartTime";
static NSString* const kSFDurationKey = @"duration";
static NSString* const kSFClientSessionIdKey = @"clientSessionId";
static NSString* const kSFSequenceKey = @"sequence";
static NSString* const kSFAttributesKey = @"attributes";
static NSString* const kSFLocatorKey = @"locator";
static NSString* const kSFEventTypeKey = @"eventType";
static NSString* const kSFErrorTypeKey = @"errorType";
static NSString* const kSFTargetKey = @"target";
static NSString* const kSFScopeKey = @"scope";
static NSString* const kSFContextKey = @"context";

@implementation AILTNTransform

+ (NSDictionary *) transform:(InstrumentationEvent *) event {
    if (!event) {
        return nil;
    }
    NSMutableDictionary *logLine = [[NSMutableDictionary alloc] init];
    DeviceAppAttributes *deviceAppAttributes = event.deviceAppAttributes;
    if (deviceAppAttributes) {
        logLine = [NSMutableDictionary dictionaryWithDictionary:[deviceAppAttributes jsonRepresentation]];
    }
    logLine[kSFConnectionTypeKey] = event.connectionType;
    NSDictionary *payload = [[self class] buildPayload:event];
    if (payload) {
        logLine[kSFPayloadKey] = payload;
    }
    return logLine;
}

+ (NSDictionary *) buildPayload:(InstrumentationEvent *) event {
    
    // TODO: Implementation.
    return nil;
}

@end
