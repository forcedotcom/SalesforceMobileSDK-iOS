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
#import "SFSyncDownTarget.h"
#import "SFSyncOptions.h"
#import "SFSyncUpTarget.h"
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFJsonUtils.h>

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
NSString * const kSyncStateMaxTimeStamp = @"maxTimeStamp";

// Possible value for sync type
NSString * const kSFSyncStateTypeDown = @"syncDown";
NSString * const kSFSyncStateTypeUp = @"syncUp";

// Possible value for sync status
NSString * const kSFSyncStateStatusNew = @"NEW";
NSString * const kSFSyncStateStatusRunning = @"RUNNING";
NSString * const kSFSyncStateStatusDone = @"DONE";
NSString * const kSFSyncStateStatusFailed = @"FAILED";

// Possible value for merge mode
NSString * const kSFSyncStateMergeModeOverwrite = @"OVERWRITE";
NSString * const kSFSyncStateMergeModeLeaveIfChanged = @"LEAVE_IF_CHANGED";

@interface SFSyncState ()

@property (nonatomic, readwrite) NSInteger syncId;
@property (nonatomic, readwrite) SFSyncStateSyncType type;
@property (nonatomic, strong, readwrite) NSString* soupName;
@property (nonatomic, strong, readwrite) SFSyncTarget* target;
@property (nonatomic, strong, readwrite) SFSyncOptions* options;

@end

@implementation SFSyncState

# pragma mark - Setup

+ (void) setupSyncsSoupIfNeeded:(SFSmartStore*)store {
    if ([store soupExists:kSFSyncStateSyncsSoupName])
        return;
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:kSFSyncStateSyncsSoupSyncType indexType:kSoupIndexTypeString columnName:nil]
                            ];
    
    [store registerSoup:kSFSyncStateSyncsSoupName withIndexSpecs:indexSpecs error:nil];
}

#pragma mark - Factory methods

+ (SFSyncState*) newSyncDownWithOptions:(SFSyncOptions*)options target:(SFSyncDownTarget*)target soupName:(NSString*)soupName store:(SFSmartStore*)store {
    NSDictionary* dict = @{
                           kSFSyncStateType: kSFSyncStateTypeDown,
                           kSFSyncStateTarget: [target asDict],
                           kSFSyncStateSoupName: soupName,
                           kSFSyncStateOptions: [options asDict],
                           kSFSyncStateStatus: kSFSyncStateStatusNew,
                           kSFSyncStateProgress: [NSNumber numberWithInteger:0],
                           kSFSyncStateTotalSize: [NSNumber numberWithInteger:-1]
                           };
    NSArray* savedDicts = [store upsertEntries:@[ dict ] toSoup:kSFSyncStateSyncsSoupName];
    SFSyncState* sync = [SFSyncState newFromDict:savedDicts[0]];
    return sync;
}

+ (SFSyncState*)newSyncUpWithOptions:(SFSyncOptions *)options soupName:(NSString *)soupName store:(SFSmartStore *)store {
    SFSyncUpTarget *target = [[SFSyncUpTarget alloc] init];
    return [self newSyncUpWithOptions:options target:target soupName:soupName store:store];
}

+ (SFSyncState*) newSyncUpWithOptions:(SFSyncOptions*)options
                               target:(SFSyncUpTarget*)target
                             soupName:(NSString*)soupName
                                store:(SFSmartStore*)store {
    NSDictionary* dict = @{
                           kSFSyncStateType: kSFSyncStateTypeUp,
                           kSFSyncStateTarget: [target asDict],
                           kSFSyncStateSoupName: soupName,
                           kSFSyncStateOptions: [options asDict],
                           kSFSyncStateStatus: kSFSyncStateStatusNew,
                           kSFSyncStateProgress: [NSNumber numberWithInteger:0],
                           kSFSyncStateTotalSize: [NSNumber numberWithInteger:-1]
                           };
    NSArray* savedDicts = [store upsertEntries:@[ dict ] toSoup:kSFSyncStateSyncsSoupName];
    if (savedDicts == nil || savedDicts.count == 0)
        return nil;
    SFSyncState* sync = [SFSyncState newFromDict:savedDicts[0]];
    return sync;
}

#pragma mark - Save/retrieve to/from smartstore

+ (SFSyncState*) newById:(NSNumber*)syncId store:(SFSmartStore*)store {
    NSArray* retrievedDicts = [store retrieveEntries:@ [ syncId ] fromSoup:kSFSyncStateSyncsSoupName];
    if (retrievedDicts == nil || retrievedDicts.count == 0)
        return nil;
    SFSyncState* sync = [SFSyncState newFromDict:retrievedDicts[0]];
    return sync;
}

- (void) save:(SFSmartStore*) store {
    NSArray* savedDicts = [store upsertEntries:@[ [self asDict] ] toSoup:kSFSyncStateSyncsSoupName];
    [self fromDict:savedDicts[0]];
}

#pragma mark - From/to dictionary

+ (SFSyncState*) newFromDict:(NSDictionary*)dict {
    SFSyncState* syncState = [[SFSyncState alloc] init];
    if (syncState) {
        [syncState fromDict:dict];
    }
    return syncState;
}

- (void) fromDict:(NSDictionary*) dict {
    self.syncId = [(NSNumber*) dict[kSFSyncStateId] integerValue];
    self.type = [SFSyncState syncTypeFromString:dict[kSFSyncStateType]];
    self.target = (self.type == SFSyncStateSyncTypeDown
                   ? [SFSyncDownTarget newFromDict:dict[kSFSyncStateTarget]]
                   : [SFSyncUpTarget newFromDict:dict[kSFSyncStateTarget]]);
    self.options = (dict[kSFSyncStateOptions] == nil ? nil : [SFSyncOptions newFromDict:dict[kSFSyncStateOptions]]);
    self.soupName = dict[kSFSyncStateSoupName];
    self.status = [SFSyncState syncStatusFromString:dict[kSFSyncStateStatus]];
    self.progress = [(NSNumber*) dict[kSFSyncStateProgress] integerValue];
    self.totalSize = [(NSNumber*) dict[kSFSyncStateTotalSize] integerValue];
    self.maxTimeStamp = [(NSNumber*) dict[kSyncStateMaxTimeStamp] longLongValue];
}

- (NSDictionary*) asDict {
    NSMutableDictionary* dict = [NSMutableDictionary new];
    dict[SOUP_ENTRY_ID] = [NSNumber numberWithInteger:self.syncId];
    dict[kSFSyncStateType] = [SFSyncState syncTypeToString:self.type];
    if (self.target) dict[kSFSyncStateTarget] = [self.target asDict];
    if (self.options) dict[kSFSyncStateOptions] = [self.options asDict];
    dict[kSFSyncStateSoupName] = self.soupName;
    dict[kSFSyncStateStatus] = [SFSyncState syncStatusToString:self.status];
    dict[kSFSyncStateProgress] = [NSNumber numberWithInteger:self.progress];
    dict[kSFSyncStateTotalSize] = [NSNumber numberWithInteger:self.totalSize];
    dict[kSyncStateMaxTimeStamp] = [NSNumber numberWithLongLong:self.maxTimeStamp];
    return dict;
}

#pragma mark - Easy status check
- (BOOL) isDone {
    return self.status == SFSyncStateStatusDone;
}

- (BOOL) hasFailed {
    return self.status == SFSyncStateStatusFailed;
}

- (BOOL) isRunning {
    return self.status == SFSyncStateStatusRunning;
}


#pragma mark - Getter for merge mode
- (SFSyncStateMergeMode) mergeMode {
    return self.options.mergeMode;
}


#pragma mark - string to/from enum for sync type

+ (SFSyncStateSyncType) syncTypeFromString:(NSString*)syncType {
    if ([syncType isEqualToString:kSFSyncStateTypeDown]) {
        return SFSyncStateSyncTypeDown;
    }
    // Must be up
    return SFSyncStateSyncTypeUp;
}

+ (NSString*) syncTypeToString:(SFSyncStateSyncType)syncType {
    switch(syncType) {
        case SFSyncStateSyncTypeDown: return kSFSyncStateTypeDown;
        case SFSyncStateSyncTypeUp: return kSFSyncStateTypeUp;
    }
}

#pragma mark - string to/from enum for sync status

+ (SFSyncStateStatus) syncStatusFromString:(NSString*)syncStatus {
    if ([syncStatus isEqualToString:kSFSyncStateStatusNew]) {
        return SFSyncStateStatusNew;
    }
    if ([syncStatus isEqualToString:kSFSyncStateStatusRunning]) {
        return SFSyncStateStatusRunning;
    }
    if ([syncStatus isEqualToString:kSFSyncStateStatusDone]) {
        return SFSyncStateStatusDone;
    }
    // Must be failed // if ([syncStatus isEqualToString:kSFSyncStateStatusFailed]) {
    return SFSyncStateStatusFailed;
}

+ (NSString*) syncStatusToString:(SFSyncStateStatus)syncStatus {
    switch (syncStatus) {
        case SFSyncStateStatusNew: return kSFSyncStateStatusNew;
        case SFSyncStateStatusRunning: return kSFSyncStateStatusRunning;
        case SFSyncStateStatusDone: return kSFSyncStateStatusDone;
        case SFSyncStateStatusFailed: return kSFSyncStateStatusFailed;
    }
}

#pragma mark - string to/from enum for merge mode

+ (SFSyncStateMergeMode) mergeModeFromString:(NSString*)mergeMode {
    if ([mergeMode isEqualToString:kSFSyncStateMergeModeLeaveIfChanged]) {
        return SFSyncStateMergeModeLeaveIfChanged;
    }
    // if ([mergeMode isEqualToString:kSFSyncStateMergeModeOverwrite]) {
    return SFSyncStateMergeModeOverwrite;
}

+ (NSString*) mergeModeToString:(SFSyncStateMergeMode)mergeMode {
    switch (mergeMode) {
        case SFSyncStateMergeModeLeaveIfChanged: return kSFSyncStateMergeModeLeaveIfChanged;
        case SFSyncStateMergeModeOverwrite: return kSFSyncStateMergeModeOverwrite;
    }
}

#pragma mark - description

- (NSString*)description
{
    return [SFJsonUtils JSONRepresentation:[self asDict]];
}

#pragma mark - copy

-(id)copyWithZone:(NSZone *)zone
{
    SFSyncState* clone = [SFSyncState new];
    [clone fromDict:[self asDict]];
    return clone;
}

@end
