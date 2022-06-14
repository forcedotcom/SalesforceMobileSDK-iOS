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
#import <SmartStore/SFSmartStore.h>

@implementation SFAdvancedSyncUpTask

-(instancetype) init:(SFMobileSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [super init:syncManager sync:sync updateBlock:updateBlock];
}

- (void)syncUp:(SFSyncState*)sync recordIds:(NSArray*)recordIds {
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    sync.totalSize = recordIds.count;
    
    NSArray<NSDictionary*>* records = [target getFromLocalStore:self.syncManager
                                                       soupName:soupName
                                                       storeIds:recordIds];
    
    // Figuring out what records need to be synced up based on merge mode and last mod date on server
    [self shouldSyncUpRecords:self.syncManager target:target records:records options:sync.options resultBlock:^(NSDictionary * _Nonnull recordIdToShouldSyncUp) {
        [self syncUpMultipleEntries:sync
                            records:records
             recordIdToShouldSyncUp:recordIdToShouldSyncUp
                              index:0
                              batch:[NSMutableArray new]];
    }];
}

- (void) shouldSyncUpRecords:(SFMobileSyncSyncManager *)syncManager
                      target:(SFSyncUpTarget*)target
                     records:(NSArray<NSDictionary*>*)records
                     options:(SFSyncOptions*)options
                 resultBlock:(SFSyncUpRecordsNewerThanServerBlock)resultBlock {
        
    if (options.mergeMode == SFSyncStateMergeModeOverwrite) {
        NSMutableDictionary* result = [NSMutableDictionary new];
        
        for (NSDictionary* record in records) {
            result[record[SOUP_ENTRY_ID]] = @YES;
        }
        
        resultBlock(result);
    } else {
        [target areNewerThanServer:syncManager records:records resultBlock:resultBlock];
    }
}

- (void)syncUpMultipleEntries:(SFSyncState*)sync
                      records:(NSArray<NSDictionary*>*)records
       recordIdToShouldSyncUp:(NSDictionary*)recordIdToShouldSyncUp
                        index:(NSUInteger)i
                        batch:(NSMutableArray*)batch {

    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSUInteger maxBatchSize = ((SFSyncUpTarget<SFAdvancedSyncUpTarget>*) target).maxBatchSize;
    sync.totalSize = records.count;
    [self updateSync:sync countSynched:i];
    
    if ([sync isDone] || [self shouldStop]) {
        return;
    }

    NSMutableDictionary* record = [records[i] mutableCopy];
    [SFSDKMobileSyncLogger d:[self class] format:@"syncUpMultipleEntries:%@", record];
    
    NSNumber* storeId = record[SOUP_ENTRY_ID];
    BOOL shouldSyncUp =  [((NSNumber*) recordIdToShouldSyncUp[storeId]) boolValue];
    if (shouldSyncUp) {
        [batch addObject:record];
    }
        
    // Process batch if max batch size reached or at the end of recordIds
    if (batch.count == maxBatchSize || i == records.count - 1) {
        
        [self processSyncUpBatch:sync
                         records:records
          recordIdToShouldSyncUp:recordIdToShouldSyncUp
                           index:i
                           batch:batch];
    } else {
        [self syncUpMultipleEntries:sync
                            records:records
             recordIdToShouldSyncUp:recordIdToShouldSyncUp
                              index:i+1
                              batch:batch];
    }
}

- (void)processSyncUpBatch:(SFSyncState*)sync
                   records:(NSArray<NSDictionary*>*)records
    recordIdToShouldSyncUp:(NSDictionary*)recordIdToShouldSyncUp
                     index:(NSUInteger)i
                     batch:(NSMutableArray*)batch {
    
    SFSyncUpTarget<SFAdvancedSyncUpTarget>* advancedTarget = (SFSyncUpTarget<SFAdvancedSyncUpTarget>*) sync.target;
    
    
    // Next
    __weak typeof(self) weakSelf = self;
    void (^nextBlock)(NSDictionary *)=^(NSDictionary *syncUpResult) {
        [batch removeAllObjects];
        [weakSelf syncUpMultipleEntries:sync
                                records:records
                 recordIdToShouldSyncUp:recordIdToShouldSyncUp
                                  index:i+1
                                  batch:batch];
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
