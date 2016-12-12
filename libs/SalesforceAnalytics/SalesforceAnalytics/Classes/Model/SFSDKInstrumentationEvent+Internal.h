/*
 InstrumentationEvent+Internal.h
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

#import "SFSDKInstrumentationEvent.h"

@interface SFSDKInstrumentationEvent ()

/**
 * Parameterized initializer.
 *
 * @param eventId Event ID.
 * @param startTime Start time.
 * @param endTime End time.
 * @param name Name.
 * @param attributes Attributes.
 * @param sessionId Session ID.
 * @param sequenceId Sequence ID.
 * @param senderId Sender ID.
 * @param senderContext Sender context.
 * @param schemaType Schema type.
 * @param eventType Event type.
 * @param errorType Error type.
 * @param deviceAppAttributes Device app attributes.
 * @param connectionType Connection type.
 * @param senderParentId Sender parent ID.
 * @param sessionStartTime Session start time.
 * @param page Page.
 * @param previousPage Previous page.
 * @param marks Marks.
 * @return Instance of this class.
 */
- (nonnull instancetype) initWithEventId:(nonnull NSString *) eventId startTime:(NSInteger) startTime endTime:(NSInteger) endTime name:(nonnull NSString *) name attributes:(nullable NSDictionary *) attributes sessionId:(nullable NSString *) sessionId sequenceId:(NSInteger) sequenceId senderId:(nullable NSString *) senderId senderContext:(nullable NSDictionary *) senderContext schemaType:(SFASchemaType) schemaType eventType:(SFAEventType) eventType errorType:(SFAErrorType) errorType deviceAppAttributes:(nonnull SFSDKDeviceAppAttributes *) deviceAppAttributes connectionType:(nonnull NSString *) connectionType senderParentId:(nullable NSString *) senderParentId sessionStartTime:(NSInteger) sessionStartTime page:(nullable NSDictionary *) page previousPage:(nullable NSDictionary *) previousPage marks:(nullable NSDictionary *) marks;

@end
