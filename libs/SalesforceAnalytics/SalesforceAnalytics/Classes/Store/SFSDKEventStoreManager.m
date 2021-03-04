/*
 EventStoreManager.m
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

#import "SFSDKEventStoreManager.h"
#import "SFSDKInstrumentationEvent+Internal.h"

@interface SFSDKEventStoreManager ()

@property (nonatomic, strong, readwrite) NSString *storeDirectory;
@property (nonatomic, strong, readwrite) DataEncryptorBlock dataEncryptorBlock;
@property (nonatomic, strong, readwrite) DataDecryptorBlock dataDecryptorBlock;
@property (nonatomic, assign, readwrite) NSInteger numStoredEvents;
@property (nonatomic, strong, readwrite) NSObject *eventCountMutex;

@end

@implementation SFSDKEventStoreManager

- (instancetype) initWithStoreDirectory:(NSString *) storeDirectory dataEncryptorBlock:(DataEncryptorBlock) dataEncryptorBlock dataDecryptorBlock:(DataDecryptorBlock) dataDecryptorBlock {
    self = [super init];
    if (self) {
        self.loggingEnabled = YES;
        self.maxEvents = 1000;
        self.storeDirectory = storeDirectory;

        // If a data encryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if (dataEncryptorBlock) {
            self.dataEncryptorBlock = dataEncryptorBlock;
        } else {
            self.dataEncryptorBlock = ^NSData*(NSData *data) {
                return data;
            };
        }

        // If a data decryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if (dataDecryptorBlock) {
            self.dataDecryptorBlock = dataDecryptorBlock;
        } else {
            self.dataDecryptorBlock = ^NSData*(NSData *data) {
                return data;
            };
        }

        // Gets current number of events stored.
        self.eventCountMutex = [[NSObject alloc] init];
        self.numStoredEvents = 0;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.storeDirectory error:nil];
        if (files) {
            self.numStoredEvents = files.count;
        }
    }
    return self;
}

- (void) storeEvent:(SFSDKInstrumentationEvent *) event {
    if (!event) {
        return;
    }

    // Copies event, to isolate data for I/O.
    SFSDKInstrumentationEvent *eventCopy = [event copy];
    if (!eventCopy) {
        return;
    }
    if (![self shouldStoreEvent]) {
        return;
    }
    NSData *encryptedData = self.dataEncryptorBlock([eventCopy jsonRepresentation]);
    NSError *error = nil;
    if (encryptedData) {
        NSString *filename = [self filenameForEvent:eventCopy.eventId];
        NSString *parentDir = [filename stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes: @{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error];
        [encryptedData writeToFile:filename options:NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&error];
        if (error) {
            [SFSDKAnalyticsLogger w:[self class] format:@"Error occurred while writing to file: %@", error.localizedDescription];
        } else {
            @synchronized (self.eventCountMutex) {
                self.numStoredEvents++;
            }
        }
    }
}

- (void) storeEvents:(NSArray<SFSDKInstrumentationEvent *> *) events {
    if (!events || [events count] == 0) {
        return;
    }
    if (![self shouldStoreEvent]) {
        return;
    }
    for (SFSDKInstrumentationEvent* event in events) {
        [self storeEvent:event];
    }
}

- (SFSDKInstrumentationEvent *) fetchEvent:(NSString *) eventId {
    if (!eventId) {
        return nil;
    }
    NSString *filePath = [self filenameForEvent:eventId];
    return [self fetchEventFromFile:filePath];
}

- (NSArray<SFSDKInstrumentationEvent *> *) fetchAllEvents {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.storeDirectory error:nil];
    NSMutableArray *events = [[NSMutableArray alloc] init];
    for (NSString *file in files) {
        SFSDKInstrumentationEvent *event = [self fetchEventFromFile:[self filenameForEvent:file]];
        if (event) {
            [events addObject:event];
        }
    }
    return events;
}

- (BOOL) deleteEvent:(NSString *) eventId {
    if (!eventId) {
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self filenameForEvent:eventId];
    BOOL success = NO;
    if ([fileManager fileExistsAtPath:filePath]) {
        success = [fileManager removeItemAtPath:filePath error:nil];
        if (success) {
            @synchronized (self.eventCountMutex) {
                self.numStoredEvents--;
            }
        }
        return success;
    }
    return NO;
}

- (void) deleteEvents:(NSArray<NSString *> *) eventIds {
    if (!eventIds || [eventIds count] == 0) {
        return;
    }
    for (NSString* eventId in eventIds) {
        [self deleteEvent:eventId];
    }
}

- (void) deleteAllEvents {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:self.storeDirectory error:nil];
    for (NSString *file in files) {
        NSString *filePath = [self filenameForEvent:file];
        if ([fileManager fileExistsAtPath:filePath]) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
    @synchronized (self.eventCountMutex) {
        self.numStoredEvents = 0;
    }
}

- (BOOL) shouldStoreEvent {
    return (self.isLoggingEnabled && (self.numStoredEvents < self.maxEvents));
}

- (BOOL) isLoggingEnabled {
    BOOL globalAnalyticsDisabled = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFDCAnalyticsDisabled"] boolValue];
    if (globalAnalyticsDisabled) {
        return NO;
    }
    return _loggingEnabled;
}

- (SFSDKInstrumentationEvent *) fetchEventFromFile:(NSString *) file {
    if (!file) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:file]) {
        return nil;
    }
    NSData *data = self.dataDecryptorBlock([NSData dataWithContentsOfFile:file]);
    SFSDKInstrumentationEvent *event = [[SFSDKInstrumentationEvent alloc] initWithJson:data];
    if (event && event.eventId) {
        return [event copy];
    }
    return nil;
}

- (NSString *) filenameForEvent:(NSString *) eventId {
    return [self.storeDirectory stringByAppendingPathComponent:eventId];
}

@end
