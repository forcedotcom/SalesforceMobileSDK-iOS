/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSyncDownTask.h"

@implementation SFSyncDownTask

-(instancetype) init:(SFSmartSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [super init:syncManager sync:sync updateBlock:updateBlock];
}

- (void) runSync:(SFSyncState*)sync {
    __weak typeof (self) weakSelf = self;
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncDownTarget* target = (SFSyncDownTarget*) sync.target;
    long long maxTimeStamp = sync.maxTimeStamp;
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];
    
    __block NSUInteger countFetched = 0;
    __block NSUInteger totalSize = 0;
    __block NSUInteger progress = 0;
    __block SFSyncDownTargetFetchCompleteBlock continueFetchBlockRecurse = ^(NSArray *records) {};
    
    __block NSOrderedSet* idsToSkip = nil;
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged) {
        idsToSkip = [target getIdsToSkip:self.syncManager soupName:soupName];
    }
    
    SFSyncDownTargetFetchErrorBlock failBlock = ^(NSError *error) {
        [self failSync:@"Server call for sync down failed" error:error];
        continueFetchBlockRecurse = nil;
    };
    
    SFSyncDownTargetFetchCompleteBlock startFetchBlock = ^(NSArray* records) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        totalSize = target.totalSize;
        if (totalSize != 0) {
            [strongSelf updateSync:SFSyncStateStatusRunning progress:0 totalSize:totalSize maxTimeStamp:kSyncManagerUnchanged];
            continueFetchBlockRecurse(records);
        }
        else {
            [strongSelf updateSync:SFSyncStateStatusDone progress:100 totalSize:0 maxTimeStamp:kSyncManagerUnchanged];
            continueFetchBlockRecurse = nil;
        }
    };
    
    SFSyncDownTargetFetchCompleteBlock continueFetchBlock = ^(NSArray* records) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if (records != nil) {
            // Figure out records to save
            NSArray* recordsToSave = idsToSkip && idsToSkip.count > 0 ? [strongSelf  removeWithIds:records idsToSkip:idsToSkip idField:target.idFieldName] : records;
            
            // Save to smartstore.
            [target cleanAndSaveRecordsToLocalStore:self.syncManager soupName:soupName records:recordsToSave syncId:syncId];
            countFetched += [records count];
            progress = 100*countFetched / totalSize;
            
            long long maxTimeStampForFetched = [target getLatestModificationTimeStamp:records];
            
            // Update sync status.
            [strongSelf updateSync:SFSyncStateStatusRunning progress:progress totalSize:totalSize maxTimeStamp:maxTimeStampForFetched];
            
            // Fetch next records, if any.
            [target continueFetch:self.syncManager errorBlock:failBlock completeBlock:continueFetchBlockRecurse];
        }
        else {
            // In some cases (e.g. resync for refresh sync down), the totalSize is just an (over)estimation
            // As a result progress might not get to 100 and therefore a DONE would never be sent
            if (progress < 100) {
                [strongSelf updateSync:SFSyncStateStatusDone progress:100 totalSize:kSyncManagerUnchanged maxTimeStamp:kSyncManagerUnchanged];
            }
            continueFetchBlockRecurse = nil;
        }
    };
    
    // initialize the alias
    continueFetchBlockRecurse = continueFetchBlock;
    
    // Start fetch
    [target startFetch:self.syncManager maxTimeStamp:maxTimeStamp errorBlock:failBlock completeBlock:startFetchBlock];
}

- (NSArray*) removeWithIds:(NSArray*)records idsToSkip:(NSOrderedSet*)idsToSkip idField:(NSString*)idField {
    NSMutableArray * arr = [NSMutableArray new];
    for (NSDictionary* record in records) {
        // Keep ?
        NSString* id = record[idField];
        if (!id || ![idsToSkip containsObject:id]) {
            [arr addObject:record];
        }
    }
    return arr;
}

@end
