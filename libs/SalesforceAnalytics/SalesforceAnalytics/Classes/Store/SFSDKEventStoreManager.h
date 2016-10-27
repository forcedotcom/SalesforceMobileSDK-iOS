/*
 EventStoreManager.h
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/4/16.
 
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

@interface SFSDKEventStoreManager : NSObject

typedef NSData * _Nullable (^ _Nullable DataEncryptorBlock)(NSData * _Nullable data);
typedef NSData * _Nullable (^ _Nullable DataDecryptorBlock)(NSData * _Nullable data);

@property (nonatomic, strong, readonly, nonnull) NSString *storeDirectory;
@property (nonatomic, strong, readonly, nullable) DataEncryptorBlock dataEncryptorBlock;
@property (nonatomic, strong, readonly, nullable) DataDecryptorBlock dataDecryptorBlock;
@property (nonatomic, assign, readonly) NSInteger numStoredEvents;
@property (nonatomic, assign, readwrite, getter=isLoggingEnabled) BOOL loggingEnabled;
@property (nonatomic, assign, readwrite) NSInteger maxEvents;

/**
 * Parameterized initializer.
 *
 * @param storeDirectory Store directory.
 * @param dataEncryptorBlock Block that performs encryption.
 * @param dataDecryptorBlock Block that performs decryption.
 * @return Instance of this class.
 */
- (nonnull instancetype) initWithStoreDirectory:(nonnull NSString *) storeDirectory dataEncryptorBlock:(nullable DataEncryptorBlock) dataEncryptorBlock dataDecryptorBlock:(nullable DataDecryptorBlock) dataDecryptorBlock;

/**
 * Stores an event to the filesystem. A combination of event's unique ID and
 * filename suffix is used to generate a unique filename per event.
 *
 * @param event Event to be persisted.
 */
- (void) storeEvent:(nullable SFSDKInstrumentationEvent *) event;

/**
 * Stores a list of events to the filesystem.
 *
 * @param events List of events.
 */
- (void) storeEvents:(nullable NSArray<SFSDKInstrumentationEvent *> *) events;

/**
 * Returns a specific event stored on the filesystem.
 *
 * @param eventId Unique identifier for the event.
 * @return Event.
 */
- (nullable SFSDKInstrumentationEvent *) fetchEvent:(nullable NSString *) eventId;

/**
 * Returns all the events stored on the filesystem for that unique identifier.
 *
 * @return List of events.
 */
- (nullable NSArray<SFSDKInstrumentationEvent *> *) fetchAllEvents;

/**
 * Deletes a specific event stored on the filesystem.
 *
 * @param eventId Unique identifier for the event.
 * @return True - if successful, False - otherwise.
 */
- (BOOL) deleteEvent:(nullable NSString *) eventId;

/**
 * Deletes the events stored on the filesystem for that unique identifier.
 */
- (void) deleteEvents:(nullable NSArray<NSString *> *) eventIds;

/**
 * Deletes all the events stored on the filesystem for that unique identifier.
 */
- (void) deleteAllEvents;

@end
