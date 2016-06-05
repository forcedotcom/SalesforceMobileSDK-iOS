/*
 InstrumentationEvent.h
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 5/25/16.
 
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

#import "DeviceAppAttributes.h"

static NSString* const kEventIdKey = @"eventId";
static NSString* const kStartTimeKey = @"startTime";
static NSString* const kEndTimeKey = @"endTime";
static NSString* const kNameKey = @"name";
static NSString* const kAttributesKey = @"attributes";
static NSString* const kSessionIdKey = @"sessionId";
static NSString* const kSequenceIdKey = @"sequenceId";
static NSString* const kSenderIdKey = @"senderId";
static NSString* const kSenderContextKey = @"senderContext";
static NSString* const kEventTypeKey = @"eventType";
static NSString* const kTypeKey = @"type";
static NSString* const kSubtypeKey = @"subtype";
static NSString* const kErrorTypeKey = @"errorType";
static NSString* const kConnectionTypeKey = @"connectionType";
static NSString* const kDeviceAppAttributesKey = @"deviceAppAttributes";

/**
 * Represents the type of event being measured.
 */
typedef NS_ENUM(NSInteger, EventType) {
    EventTypeInteraction = 0,
    EventTypePageView,
    EventTypePerf,
    EventTypeError
};

/**
 * Represents the type of interaction being logged.
 */
typedef NS_ENUM(NSInteger, Type) {
    TypeUser = 0,
    TypeSystem,
    TypeError,
    TypeCrud
};

/**
 * Represents the subtype of interaction being logged.
 */
typedef NS_ENUM(NSInteger, Subtype) {
    SubtypeClick = 0,
    SubtypeMouseover,
    SubtypeCreate,
    SubtypeSwipe
};

/**
 * Represents the type of error being logged.
 */
typedef NS_ENUM(NSInteger, ErrorType) {
    ErrorTypeInfo = 0,
    ErrorTypeWarn,
    ErrorTypeError
};

@interface InstrumentationEvent : NSObject

@property (nonatomic, strong, readonly) NSString *eventId;
@property (nonatomic, assign, readonly) NSInteger startTime;
@property (nonatomic, assign, readonly) NSInteger endTime;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSDictionary *attributes;
@property (nonatomic, assign, readonly) NSInteger sessionId;
@property (nonatomic, assign, readonly) NSInteger sequenceId;
@property (nonatomic, strong, readonly) NSString *senderId;
@property (nonatomic, strong, readonly) NSDictionary *senderContext;
@property (nonatomic, assign, readonly) EventType eventType;
@property (nonatomic, assign, readonly) Type type;
@property (nonatomic, assign, readonly) Subtype subtype;
@property (nonatomic, assign, readonly) ErrorType errorType;
@property (nonatomic, strong, readonly) DeviceAppAttributes *deviceAppAttributes;
@property (nonatomic, strong, readonly) NSString *connectionType;

/**
 * Parameterized initializer.
 *
 * @param jsonRepresentation JSON representation.
 */
- (id) initWithJson:(NSData *) jsonRepresentation;

/**
 * Returns a JSON representation of this event.
 *
 * @return JSON representation.
 */
- (NSData *) jsonRepresentation;

@end
