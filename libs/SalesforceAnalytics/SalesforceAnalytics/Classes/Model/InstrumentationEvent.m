/*
 InstrumentationEvent.m
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

#import "InstrumentationEvent+Internal.h"

@interface InstrumentationEvent ()

@property (nonatomic, strong, readwrite) NSString *eventId;
@property (nonatomic, assign, readwrite) NSInteger startTime;
@property (nonatomic, assign, readwrite) NSInteger endTime;
@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSDictionary *attributes;
@property (nonatomic, assign, readwrite) NSInteger sessionId;
@property (nonatomic, assign, readwrite) NSInteger sequenceId;
@property (nonatomic, strong, readwrite) NSString *senderId;
@property (nonatomic, strong, readwrite) NSDictionary *senderContext;
@property (nonatomic, assign, readwrite) EventType eventType;
@property (nonatomic, assign, readwrite) Type type;
@property (nonatomic, assign, readwrite) Subtype subtype;
@property (nonatomic, assign, readwrite) ErrorType errorType;
@property (nonatomic, strong, readwrite) DeviceAppAttributes *deviceAppAttributes;
@property (nonatomic, strong, readwrite) NSString *connectionType;

@end

@implementation InstrumentationEvent

- (id) init:(NSString *) eventId startTime:(NSInteger) startTime endTime:(NSInteger) endTime name:(NSString *) name attributes:(NSDictionary *) attributes sessionId:(NSInteger) sessionId sequenceId:(NSInteger) sequenceId senderId:(NSString *) senderId senderContext:(NSDictionary *) senderContext eventType:(EventType) eventType type:(Type) type subtype:(Subtype) subtype errorType:(ErrorType) errorType deviceAppAttributes:(DeviceAppAttributes *) deviceAppAttributes connectionType:(NSString *) connectionType {
    self = [super init];
    if (self) {
        self.eventId = eventId;
        self.startTime = startTime;
        self.endTime = endTime;
        self.name = name;
        self.attributes = attributes;
        self.sessionId = sessionId;
        self.sequenceId = sequenceId;
        self.senderId = senderId;
        self.senderContext = senderContext;
        self.eventType = eventType;
        self.type = type;
        self.subtype = subtype;
        self.errorType = errorType;
        self.deviceAppAttributes = deviceAppAttributes;
        self.connectionType = connectionType;
    }
    return self;
}

- (id) initWithJson:(NSData *) jsonRepresentation {
    self = [super init];
    if (self && jsonRepresentation) {
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonRepresentation
                                                             options:NSJSONReadingAllowFragments
                                                               error:&error];
        if (dict) {
            self.eventId = dict[kEventIdKey];
            if (dict[kStartTimeKey]) {
                self.startTime = [dict[kStartTimeKey] integerValue];
            }
            if (dict[kEndTimeKey]) {
                self.endTime = [dict[kEndTimeKey] integerValue];
            }
            self.name = dict[kNameKey];
            self.attributes = dict[kAttributesKey];
            if (dict[kSessionIdKey]) {
                self.sessionId = [dict[kSessionIdKey] integerValue];
            }
            if (dict[kSequenceIdKey]) {
                self.sequenceId = [dict[kSequenceIdKey] integerValue];
            }
            self.senderId = dict[kSenderIdKey];
            self.senderContext = dict[kSenderContextKey];
            NSString *stringEventType = dict[kEventTypeKey];
            if (stringEventType) {
                self.eventType = [self eventTypeFromString:stringEventType];
            }
            NSString *stringType = dict[kTypeKey];
            if (stringType) {
                self.type = [self typeFromString:stringType];
            }
            NSString *stringSubtype = dict[kSubtypeKey];
            if (stringSubtype) {
                self.subtype = [self subtypeFromString:stringSubtype];
            }
            NSString *stringErrorType = dict[kErrorTypeKey];
            if (stringErrorType) {
                self.errorType = [self errorTypeFromString:stringErrorType];
            }
            NSData *deviceAttrDict = dict[kDeviceAppAttributesKey];
            if (deviceAttrDict) {
                self.deviceAppAttributes = [[DeviceAppAttributes alloc] initWithJson:deviceAttrDict];
            }
            self.connectionType = dict[kConnectionTypeKey];
        }
    }
    return self;
}

- (NSData *) jsonRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[kEventIdKey] = self.eventId;
    dict[kStartTimeKey] = [NSNumber numberWithInteger:self.startTime];
    dict[kEndTimeKey] = [NSNumber numberWithInteger:self.endTime];
    dict[kNameKey] = self.name;
    dict[kAttributesKey] = self.attributes;
    dict[kSessionIdKey] = [NSNumber numberWithInteger:self.sessionId];
    dict[kSequenceIdKey] = [NSNumber numberWithInteger:self.sequenceId];
    dict[kSenderIdKey] = self.senderId;
    dict[kSenderContextKey] = self.senderContext;
    if (self.eventType) {
        dict[kEventTypeKey] = [self stringValueOfEventType:self.eventType];
    }
    if (self.type) {
        dict[kTypeKey] = [self stringValueOfType:self.type];
    }
    if (self.subtype) {
        dict[kSubtypeKey] = [self stringValueOfSubtype:self.subtype];
    }
    if (self.errorType) {
        dict[kErrorTypeKey] = [self stringValueOfErrorType:self.errorType];
    }
    if (self.deviceAppAttributes) {
        dict[kDeviceAppAttributesKey] = [self.deviceAppAttributes jsonRepresentation];
    }
    dict[kConnectionTypeKey] = self.connectionType;
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    return jsonData;
}

- (NSUInteger) hash {
    return [self.eventId hash];
}

- (BOOL) isEqual:(id) object {
    if (nil == object || ![object isKindOfClass:[InstrumentationEvent class]]) {
        return NO;
    }
    InstrumentationEvent *otherObj = (InstrumentationEvent *) object;

    /*
     * Since event ID is globally unique and is set during construction of the event,
     * if the event IDs of both events are equal, the events themselves are the same.
     */
    if ([self.eventId isEqualToString:otherObj.eventId]) {
        return YES;
    }
    return NO;
}

- (NSString *) stringValueOfEventType:(EventType) eventType {
    NSString *typeString = nil;
    switch (eventType) {
        case EventTypeInteraction:
            typeString = @"interaction";
            break;
        case EventTypePageView:
            typeString = @"pageView";
            break;
        case EventTypePerf:
            typeString = @"perf";
            break;
        case EventTypeError:
            typeString = @"error";
            break;
        default:
            typeString = @"error";
    }
    return typeString;
}

- (EventType) eventTypeFromString:(NSString *) eventType {
    EventType type = EventTypeError;
    if (eventType) {
        if ([eventType isEqualToString:@"interaction"]) {
            type = EventTypeInteraction;
        } else if ([eventType isEqualToString:@"pageView"]) {
            type = EventTypePageView;
        } else if ([eventType isEqualToString:@"perf"]) {
            type = EventTypePerf;
        } else if ([eventType isEqualToString:@"error"]) {
            type = EventTypeError;
        }
    }
    return type;
}

- (NSString *) stringValueOfType:(Type) type {
    NSString *typeString = nil;
    switch (type) {
        case TypeUser:
            typeString = @"user";
            break;
        case TypeSystem:
            typeString = @"system";
            break;
        case TypeError:
            typeString = @"error";
            break;
        case TypeCrud:
            typeString = @"crud";
            break;
        default:
            typeString = @"error";
    }
    return typeString;
}

- (Type) typeFromString:(NSString *) type {
    Type typeRes = TypeError;
    if (type) {
        if ([type isEqualToString:@"user"]) {
            typeRes = TypeUser;
        } else if ([type isEqualToString:@"system"]) {
            typeRes = TypeSystem;
        } else if ([type isEqualToString:@"error"]) {
            typeRes = TypeError;
        } else if ([type isEqualToString:@"crud"]) {
            typeRes = TypeCrud;
        }
    }
    return typeRes;
}

- (NSString *) stringValueOfSubtype:(Subtype) subtype {
    NSString *typeString = nil;
    switch (subtype) {
        case SubtypeClick:
            typeString = @"click";
            break;
        case SubtypeMouseover:
            typeString = @"mouseover";
            break;
        case SubtypeCreate:
            typeString = @"create";
            break;
        case SubtypeSwipe:
            typeString = @"swipe";
            break;
        default:
            typeString = @"click";
    }
    return typeString;
}

- (Subtype) subtypeFromString:(NSString *) subtype {
    Subtype type = SubtypeClick;
    if (subtype) {
        if ([subtype isEqualToString:@"click"]) {
            type = SubtypeClick;
        } else if ([subtype isEqualToString:@"mouseover"]) {
            type = SubtypeMouseover;
        } else if ([subtype isEqualToString:@"create"]) {
            type = SubtypeCreate;
        } else if ([subtype isEqualToString:@"swipe"]) {
            type = SubtypeSwipe;
        }
    }
    return type;
}

- (NSString *) stringValueOfErrorType:(ErrorType) errorType {
    NSString *typeString = nil;
    switch (errorType) {
        case ErrorTypeInfo:
            typeString = @"info";
            break;
        case ErrorTypeWarn:
            typeString = @"warn";
            break;
        case ErrorTypeError:
            typeString = @"error";
            break;
        default:
            typeString = @"error";
    }
    return typeString;
}

- (ErrorType) errorTypeFromString:(NSString *) errorType {
    ErrorType type = ErrorTypeError;
    if (errorType) {
        if ([errorType isEqualToString:@"info"]) {
            type = ErrorTypeInfo;
        } else if ([errorType isEqualToString:@"warn"]) {
            type = ErrorTypeWarn;
        } else if ([errorType isEqualToString:@"error"]) {
            type = ErrorTypeError;
        }
    }
    return type;
}

@end
