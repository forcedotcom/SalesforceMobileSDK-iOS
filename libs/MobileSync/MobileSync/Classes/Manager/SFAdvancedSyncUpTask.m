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

#import "SFAdvancedSyncUpTask.h"
#import "SFAdvancedSyncUpTarget.h"

@implementation SFAdvancedSyncUpTask

-(instancetype) init:(SFMobileSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [super init:syncManager sync:sync updateBlock:updateBlock];
}

- (void)syncUp:(SFSyncState*)sync recordIds:(NSArray*)recordIds {
    [self syncUpMultipleEntries:sync recordIds:recordIds index:0 batch:[NSMutableArray new]];
}

- (void)syncUpMultipleEntries:(SFSyncState*)sync
                    recordIds:(NSArray*)recordIds
                        index:(NSUInteger)i
                        batch:(NSMutableArray*)batch {

    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    sync.totalSize = recordIds.count;
    [self updateSync:sync countSynched:i];
    
    if ([sync isDone] || [self shouldStop]) {
        return;
    }

    NSMutableDictionary* record = [[target getFromLocalStore:self.syncManager soupName:soupName storeId:recordIds[i]] mutableCopy];
    [SFSDKMobileSyncLogger d:[self class] format:@"syncUpMultipleEntries:%@", record];
    
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged && ![target isLocallyCreated:record]) {
        // Need to check the modification date on the server, against the local date.
        __weak typeof(self) weakSelf = self;
        [target isNewerThanServer:self.syncManager record:record resultBlock:^(BOOL isNewerThanServer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (isNewerThanServer) {
                [strongSelf addToSyncUpBatchAndProcessIfNeeded:sync recordIds:recordIds index:i record:record batch:batch];
            }
            else {
                // Server date is newer than the local date.  Skip this update.
                [SFSDKMobileSyncLogger d:[strongSelf class] format:@"syncUpMultipleEntries: Record not synced since client does not have the latest from server:%@", record];
                // Calling addToSyncUpBatchAndProcessIfNeeded with nil for record - we don't want to add the current record to the batch
                // but we do want the batch to be processed if needed
                [strongSelf addToSyncUpBatchAndProcessIfNeeded:sync recordIds:recordIds index:i record:nil batch:batch];
            }
        }];
    } else {
        [self addToSyncUpBatchAndProcessIfNeeded:sync recordIds:recordIds index:i record:record batch:batch];
    }
}

- (void)addToSyncUpBatchAndProcessIfNeeded:(SFSyncState*)sync
                                 recordIds:(NSArray*)recordIds
                                     index:(NSUInteger)i
                                    record:(NSDictionary*)record
                                     batch:(NSMutableArray*)batch {
    
    SFSyncUpTarget<SFAdvancedSyncUpTarget>* advancedTarget = (SFSyncUpTarget<SFAdvancedSyncUpTarget>*) sync.target;
    NSUInteger maxBatchSize = advancedTarget.maxBatchSize;
    
    // Add record to batch unless nil
    if (record) {
        [batch addObject:record];
    }
    
    // Process batch if max batch size reached or at the end of recordIds
    if (batch.count == maxBatchSize || i == recordIds.count - 1) {
        [self processSyncUpBatch:sync recordIds:recordIds index:i batch:batch];
    } else {
        [self syncUpMultipleEntries:sync recordIds:recordIds index:i+1 batch:batch];
    }
}

- (void)processSyncUpBatch:(SFSyncState*)sync
                 recordIds:(NSArray*)recordIds
                     index:(NSUInteger)i
                     batch:(NSMutableArray*)batch {
    
    SFSyncUpTarget<SFAdvancedSyncUpTarget>* advancedTarget = (SFSyncUpTarget<SFAdvancedSyncUpTarget>*) sync.target;
    
    
    // Next
    __weak typeof(self) weakSelf = self;
    void (^nextBlock)(NSDictionary *)=^(NSDictionary *syncUpResult) {
        [batch removeAllObjects];
        [weakSelf syncUpMultipleEntries:sync recordIds:recordIds index:i+1 batch:batch];
    };
    
    SFSyncUpTargetErrorBlock failBlock = ^(NSError * err) {
        [weakSelf failSync:sync failureMessage:@"syncUpRecords failed" error:err];
    };
    
    [advancedTarget syncUpRecords:self.syncManager
                          records:batch
                        fieldlist:sync.options.fieldlist
                        mergeMode:sync.options.mergeMode
                     syncSoupName:sync.soupName
                  completionBlock:nextBlock
                        failBlock:failBlock];
}

@end
