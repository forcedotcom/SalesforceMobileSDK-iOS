/*
 InstrumentationEventBuilder.h
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

#import "SFSDKAnalyticsManager.h"

@interface SFSDKInstrumentationEventBuilder : NSObject

@property (nonatomic, assign, readwrite) NSInteger startTime;
@property (nonatomic, assign, readwrite) NSInteger endTime;
@property (nonatomic, strong, readwrite, nonnull) NSString *name;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *attributes;
@property (nonatomic, strong, readwrite, nullable) NSString *sessionId;
@property (nonatomic, strong, readwrite, nullable) NSString *senderId;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *senderContext;
@property (nonatomic, assign, readwrite) SFASchemaType schemaType;
@property (nonatomic, assign, readwrite) SFAEventType eventType;
@property (nonatomic, assign, readwrite) SFAErrorType errorType;
@property (nonatomic, strong, readwrite, nullable) NSString *senderParentId;
@property (nonatomic, assign, readwrite) NSInteger sessionStartTime;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *page;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *previousPage;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *marks;

typedef void (^ _Nonnull SFSDKInstrumentationEventBuilderBlock)(SFSDKInstrumentationEventBuilder * _Nonnull eventBuilder);

/**
 * Builds the event. Returns nil if required fields are missing.
 *
 * @return Event instance.
 */
+ (nullable SFSDKInstrumentationEvent *) buildEventWithBuilderBlock:(nonnull SFSDKInstrumentationEventBuilderBlock) builderBlock analyticsManager:(nonnull SFSDKAnalyticsManager *) analyticsManager;

@end
