/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSyncState.h"
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSoupIndex.h>

// soups and soup fields
NSString * const kSFSyncStateSyncsSoupName = @"syncs_soup";
NSString * const kSFSyncStateSyncsSoupSyncType = @"type";

// Fields in dict representation
NSString * const kSFSyncStateId = @"_soupEntryId";
NSString * const kSFSyncStateType = @"type";
NSString * const kSFSyncStateTarget = @"target";
NSString * const kSFSyncStateSoupName = @"soupName";
NSString * const kSFSyncStateOptions = @"options";
NSString * const kSFSyncStateStatus = @"status";
NSString * const kSFSyncStateProgress = @"progress";
NSString * const kSFSyncStateTotalSize = @"totalSize";

// Possible value for sync type
NSString * const kSFSyncStateTypeDown = @"syncDown";
NSString * const kSFSyncStateTypeUp = @"syncUp";

// Possible value for sync status
NSString * const kSFSyncStateStatusNew = @"NEW";
NSString * const kSFSyncStateStatusRunning = @"RUNNING";
NSString * const kSFSyncStateStatusDone = @"DONE";
NSString * const kSFSyncStateStatusFailed = @"FAILED";

@interface SFSyncState ()
    @property (atomic, readwrite) NSInteger syncId;
@end

@implementation SFSyncState

# pragma mark - Setup

+ (void) setupSyncsSoupIfNeeded:(SFSmartStore*)store {
    if ([store soupExists:kSFSyncStateSyncsSoupName])
        return;
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:kSFSyncStateSyncsSoupSyncType indexType:kSoupIndexTypeString columnName:nil]
                            ];
    
    [store registerSoup:kSFSyncStateSyncsSoupName withIndexSpecs:indexSpecs];
}

#pragma mark - Factory methods

+ (SFSyncState*) newSyncDownWithTarget:(NSDictionary*)target soupName:(NSString*)soupName store:(SFSmartStore*)store {
    NSDictionary* dict = @{
                           kSFSyncStateType: kSFSyncStateTypeDown,
                           kSFSyncStateTarget: target,
                           kSFSyncStateSoupName: soupName,
                           kSFSyncStateOptions: @{},
                           kSFSyncStateStatus: kSFSyncStateStatusNew,
                           kSFSyncStateProgress: [NSNumber numberWithInteger:0],
                           kSFSyncStateTotalSize: [NSNumber numberWithInteger:-1]
                           };
    NSArray* savedDicts = [store upsertEntries:@[ dict ] toSoup:kSFSyncStateSyncsSoupName];
    SFSyncState* sync = [[[SFSyncState alloc] init] fromDict:savedDicts[0]];
    return sync;
}

+ (SFSyncState*) newSyncUpWithOptions:(NSDictionary*)options soupName:(NSString*)soupName store:(SFSmartStore*)store {
    NSDictionary* dict = @{
                           kSFSyncStateType: kSFSyncStateTypeUp,
                           kSFSyncStateTarget: @{},
                           kSFSyncStateSoupName: soupName,
                           kSFSyncStateOptions: options,
                           kSFSyncStateStatus: kSFSyncStateStatusNew,
                           kSFSyncStateProgress: [NSNumber numberWithInteger:0],
                           kSFSyncStateTotalSize: [NSNumber numberWithInteger:-1]
                           };
    NSArray* savedDicts = [store upsertEntries:@[ dict ] toSoup:kSFSyncStateSyncsSoupName];
    if (savedDicts == nil || savedDicts.count == 0)
        return nil;
    SFSyncState* sync = [[[SFSyncState alloc] init] fromDict:savedDicts[0]];
    return sync;
}

#pragma mark - Save/retrieve to/from smartstore

+ (SFSyncState*) byId:(NSNumber*)syncId store:(SFSmartStore*)store {
    NSArray* retrievedDicts = [store retrieveEntries:@ [ syncId ] fromSoup:kSFSyncStateSyncsSoupName];
    if (retrievedDicts == nil || retrievedDicts.count == 0)
        return nil;
    SFSyncState* sync = [[[SFSyncState alloc] init] fromDict:retrievedDicts[0]];
    return sync;
}

- (SFSyncState*) save:(SFSmartStore*) store {
    NSArray* savedDicts = [store upsertEntries:@[ [self asDict] ] toSoup:kSFSyncStateSyncsSoupName];
    [self fromDict:savedDicts[0]];
    return self;
}

#pragma mark - From/to dictionary

- (SFSyncState*) fromDict:(NSDictionary*)dict {
    self.syncId = [(NSNumber*) dict[kSFSyncStateId] integerValue];
    self.type = dict[kSFSyncStateType];
    self.target = dict[kSFSyncStateTarget];
    self.soupName = dict[kSFSyncStateSoupName];
    self.options = dict[kSFSyncStateOptions];
    self.status = dict[kSFSyncStateStatus];
    self.progress = [(NSNumber*) dict[kSFSyncStateProgress] integerValue];
    self.totalSize = [(NSNumber*) dict[kSFSyncStateTotalSize] integerValue];
    
    return self;
}



- (NSDictionary*) asDict {
    NSDictionary* dict = @{
                           kSFSyncStateType: self.type,
                           kSFSyncStateTarget: self.target,
                           kSFSyncStateSoupName: self.soupName,
                           kSFSyncStateOptions: self.options,
                           kSFSyncStateStatus: self.status,
                           kSFSyncStateProgress: [NSNumber numberWithInteger:self.progress],
                           kSFSyncStateTotalSize: [NSNumber numberWithInteger:self.totalSize]
                           };
    return dict;
}

#pragma mark - Easy status check
- (BOOL) isDone {
    return [self.status isEqualToString:kSFSyncStateStatusDone];
}

- (BOOL) hasFailed {
    return [self.status isEqualToString:kSFSyncStateStatusFailed];
}

@end
