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

@interface EventStoreManager ()

@property (nonatomic, strong, readwrite) NSString *rootStoreDir;
@property (nonatomic, strong, readwrite) NSString *encryptionKey;

@end

@implementation EventStoreManager

- (id) init:(NSString *) rootStoreDir encryptionKey:(NSString *) encryptionKey {
    self = [super init];
    if (self) {
        self.rootStoreDir = rootStoreDir;
        self.encryptionKey = encryptionKey;
    }
    return self;
}

- (void) storeEvent:(InstrumentationEvent *) event {
    if (!event || ![event jsonRepresentation]) {
        NSLog(@"Invalid event");
        return;
    }

    /*
     * TODO: Add implementation.
     */
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

    /*
     * TODO: Add implementation.
     */
    return nil;
}

- (NSArray<InstrumentationEvent *> *) fetchAllEvents {

    /*
     * TODO: Add implementation.
     */
    return nil;
}

- (BOOL) deleteEvent:(NSString *) eventId {
    if (!eventId) {
        NSLog(@"Invalid event ID supplied: %@", eventId);
        return NO;
    }

    /*
     * TODO: Add implementation.
     */
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

    /*
     * TODO: Add implementation.
     */
}

- (InstrumentationEvent *) fetchEventFromFile:(NSFileHandle *) file {
    if (!file) {
        NSLog(@"File does not exist");
        return nil;
    }

    /*
     * TODO: Add implementation.
     */
    return nil;
}

- (NSArray<InstrumentationEvent *> *) getAllFiles {

    /*
     * TODO: Add implementation.
     */
    return nil;
}

- (NSData *) encrypt:(NSData *) data {

    /*
     * TODO: Add implementation.
     */
    return nil;
}

- (NSData *) decrypt:(NSData *) data {
    
    /*
     * TODO: Add implementation.
     */
    return nil;
}

@end
