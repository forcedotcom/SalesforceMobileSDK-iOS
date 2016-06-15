/*
 EventStoreManager.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/4/16.
 
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

#import "EventStoreManager.h"
#import "InstrumentationEvent+Internal.h"

@interface EventStoreManager ()

@property (nonatomic, strong, readwrite) NSString *storeDirectory;
@property (nonatomic, strong, readwrite) DataEncryptorBlock dataEncryptorBlock;
@property (nonatomic, strong, readwrite) DataDecryptorBlock dataDecryptorBlock;

@end

@implementation EventStoreManager

- (id) init:(NSString *) storeDirectory dataEncryptorBlock:(DataEncryptorBlock) dataEncryptorBlock dataDecryptorBlock:(DataDecryptorBlock) dataDecryptorBlock {
    self = [super init];
    if (self) {
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
    }
    return self;
}

- (void) storeEvent:(InstrumentationEvent *) event {
    if (!event || ![event jsonRepresentation]) {
        NSLog(@"Invalid event");
        return;
    }
    NSData *encryptedData = self.dataEncryptorBlock([event jsonRepresentation]);
    NSError *error = nil;
    if (encryptedData) {
        NSString *filename = [self filenameForEvent:event.eventId];
        NSString *parentDir = [filename stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileProtectionCompleteUntilFirstUserAuthentication, NSFileProtectionKey, nil] error:&error];
        [encryptedData writeToFile:filename options:NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&error];
        if (error) {
            NSLog(@"Error occurred while writing to file: %@", error.localizedDescription);
        }
    }
}

- (void) storeEvents:(NSArray<InstrumentationEvent *> *) events {
    if (!events || [events count] == 0) {
        NSLog(@"No events to store");
        return;
    }
    for (InstrumentationEvent* event in events) {
        [self storeEvent:event];
    }
}

- (InstrumentationEvent *) fetchEvent:(NSString *) eventId {
    if (!eventId) {
        NSLog(@"Invalid event ID supplied: %@", eventId);
        return nil;
    }
    NSString *filePath = [self filenameForEvent:eventId];
    return [self fetchEventFromFile:filePath];
}

- (NSArray<InstrumentationEvent *> *) fetchAllEvents {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.storeDirectory error:nil];
    NSMutableArray *events = [[NSMutableArray alloc] init];
    for (NSString *file in files) {
        InstrumentationEvent *event = [self fetchEventFromFile:file];
        [events addObject:event];
    }
    return events;
}

- (BOOL) deleteEvent:(NSString *) eventId {
    if (!eventId) {
        NSLog(@"Invalid event ID supplied: %@", eventId);
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self filenameForEvent:eventId];
    if ([fileManager fileExistsAtPath:filePath]) {
        return [fileManager removeItemAtPath:filePath error:nil];
    }
    return NO;
}

- (void) deleteEvents:(NSArray<NSString *> *) eventIds {
    if (!eventIds || [eventIds count] == 0) {
        NSLog(@"No events to delete");
        return;
    }
    for (NSString* eventId in eventIds) {
        [self deleteEvent:eventId];
    }
}

- (void) deleteAllEvents {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.storeDirectory error:nil];
    for (NSString *file in files) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:file]) {
            [fileManager removeItemAtPath:file error:nil];
        }
    }
}

- (InstrumentationEvent *) fetchEventFromFile:(NSString *) file {
    if (!file) {
        NSLog(@"Filename must be specified");
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:file]) {
        NSLog(@"File does not exist");
        return nil;
    }
    NSData *data = self.dataDecryptorBlock([NSData dataWithContentsOfFile:file]);
    return [[InstrumentationEvent alloc] initWithJson:data];
}

- (NSString *) filenameForEvent:(NSString *) eventId {
    return [self.storeDirectory stringByAppendingPathComponent:eventId];
}

@end
