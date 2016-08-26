/*
 InstrumentationEventBuilder.h
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

#import "SFSDKAnalyticsManager.h"

@interface SFSDKInstrumentationEventBuilder : NSObject

/**
 * Returns an instance of this class.
 *
 * @return Instance of this class.
 */
+ (nonnull SFSDKInstrumentationEventBuilder *) eventBuilderWithAnalyticsManager:(nonnull SFSDKAnalyticsManager *) analyticsManager;

/**
 * Sets start time.
 *
 * @param startTime Start time.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) startTime:(NSInteger) startTime;

/**
 * Sets end time.
 *
 * @param endTime End time.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) endTime:(NSInteger) endTime;

/**
 * Sets name.
 *
 * @param name Name.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) name:(nonnull NSString *) name;

/**
 * Sets attributes.
 *
 * @param attributes Attributes.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) attributes:(nonnull NSDictionary *) attributes;

/**
 * Sets session ID.
 *
 * @param sessionId Session ID.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) sessionId:(nonnull NSString *) sessionId;

/**
 * Sets sender ID.
 *
 * @param senderId Sender ID.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) senderId:(nonnull NSString *) senderId;

/**
 * Sets sender conetxt.
 *
 * @param senderContext Sender context.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) senderContext:(nonnull NSDictionary *) senderContext;

/**
 * Sets schema type.
 *
 * @param schemaType Schema type.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) schemaType:(SFASchemaType) schemaType;

/**
 * Sets event type.
 *
 * @param eventType Event type.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) eventType:(SFAEventType) eventType;

/**
 * Sets error type.
 *
 * @param errorType Error type.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) errorType:(SFAErrorType) errorType;

/**
 * Sets sender parent ID.
 *
 * @param senderParentId Sender parent ID.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) senderParentId:(nonnull NSString *) senderParentId;

/**
 * Sets session start time.
 *
 * @param sessionStartTime Session start time.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) sessionStartTime:(NSInteger) sessionStartTime;

/**
 * Sets page.
 *
 * @param page Page.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) page:(nonnull NSDictionary *) page;

/**
 * Sets previous page.
 *
 * @param previousPage Previous page.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) previousPage:(nonnull NSDictionary *) previousPage;

/**
 * Sets marks.
 *
 * @param marks Marks.
 * @return Instance of this class.
 */
- (nonnull SFSDKInstrumentationEventBuilder *) marks:(nonnull NSDictionary *) marks;

/**
 * Builds the event.
 *
 * @return Event instance.
 */
- (nonnull SFSDKInstrumentationEvent *) buildEvent;

@end
