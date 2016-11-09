/*
 InstrumentationEvent.h
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 5/25/16.
 
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

#import "SFSDKDeviceAppAttributes.h"

static NSString * _Nonnull const kEventIdKey = @"eventId";
static NSString * _Nonnull const kStartTimeKey = @"startTime";
static NSString * _Nonnull const kEndTimeKey = @"endTime";
static NSString * _Nonnull const kNameKey = @"name";
static NSString * _Nonnull const kAttributesKey = @"attributes";
static NSString * _Nonnull const kSessionIdKey = @"sessionId";
static NSString * _Nonnull const kSequenceIdKey = @"sequenceId";
static NSString * _Nonnull const kSenderIdKey = @"senderId";
static NSString * _Nonnull const kSenderContextKey = @"senderContext";
static NSString * _Nonnull const kSchemaTypeKey = @"schemaType";
static NSString * _Nonnull const kEventTypeKey = @"eventType";
static NSString * _Nonnull const kErrorTypeKey = @"errorType";
static NSString * _Nonnull const kConnectionTypeKey = @"connectionType";
static NSString * _Nonnull const kDeviceAppAttributesKey = @"deviceAppAttributes";
static NSString * _Nonnull const kSenderParentIdKey = @"senderParentId";
static NSString * _Nonnull const kSessionStartTimeKey = @"sessionStartTime";
static NSString * _Nonnull const kPageKey = @"page";
static NSString * _Nonnull const kPreviousPageKey = @"previousPage";
static NSString * _Nonnull const kMarksKey = @"marks";

/**
 * Represents the type of schema being logged.
 */
typedef NS_ENUM(NSInteger, SFASchemaType) {
    SchemaTypeInteraction = 0,
    SchemaTypePageView,
    SchemaTypePerf,
    SchemaTypeError
};

/**
 * Represents the type of event being logged.
 */
typedef NS_ENUM(NSInteger, SFAEventType) {
    EventTypeUser = 0,
    EventTypeSystem,
    EventTypeError,
    EventTypeCrud
};

/**
 * Represents the type of error being logged.
 */
typedef NS_ENUM(NSInteger, SFAErrorType) {
    ErrorTypeInfo = 0,
    ErrorTypeWarn,
    ErrorTypeError
};

@interface SFSDKInstrumentationEvent : NSObject <NSCopying>

@property (nonatomic, copy, readonly, nonnull) NSString *eventId;
@property (nonatomic, assign, readonly) NSInteger startTime;
@property (nonatomic, assign, readonly) NSInteger endTime;
@property (nonatomic, copy, readonly, nonnull) NSString *name;
@property (nonatomic, copy, readonly, nullable) NSDictionary *attributes;
@property (nonatomic, copy, readonly, nullable) NSString *sessionId;
@property (nonatomic, assign, readonly) NSInteger sequenceId;
@property (nonatomic, copy, readonly, nullable) NSString *senderId;
@property (nonatomic, copy, readonly, nullable) NSDictionary *senderContext;
@property (nonatomic, assign, readonly) SFASchemaType schemaType;
@property (nonatomic, assign, readonly) SFAEventType eventType;
@property (nonatomic, assign, readonly) SFAErrorType errorType;
@property (nonatomic, strong, readonly, nonnull) SFSDKDeviceAppAttributes *deviceAppAttributes;
@property (nonatomic, copy, readonly, nonnull) NSString *connectionType;
@property (nonatomic, copy, readonly, nullable) NSString *senderParentId;
@property (nonatomic, assign, readonly) NSInteger sessionStartTime;
@property (nonatomic, copy, readonly, nullable) NSDictionary *page;
@property (nonatomic, copy, readonly, nullable) NSDictionary *previousPage;
@property (nonatomic, copy, readonly, nullable) NSDictionary *marks;

/**
 * Parameterized initializer.
 *
 * @param jsonRepresentation JSON representation.
 * @return Instance of this class.
 */
- (nonnull instancetype) initWithJson:(nonnull NSData *) jsonRepresentation;

/**
 * Returns a JSON representation of this event.
 *
 * @return JSON representation.
 */
- (nonnull NSData *) jsonRepresentation;

/**
 * Returns a string representation of schema type.
 *
 * @param schemaType Schema type.
 * @return String representation of schema type.
 */
- (nonnull NSString *) stringValueOfSchemaType:(SFASchemaType) schemaType;

/**
 * Returns a string representation of event type.
 *
 * @param eventType Event type.
 * @return String representation of event type.
 */
- (nonnull NSString *) stringValueOfEventType:(SFAEventType) eventType;

/**
 * Returns a string representation of error type.
 *
 * @param errorType Error type.
 * @return String representation of error type.
 */
- (nonnull NSString *) stringValueOfErrorType:(SFAErrorType) errorType;

@end
