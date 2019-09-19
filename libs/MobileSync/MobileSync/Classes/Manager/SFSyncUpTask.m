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

#import "SFSyncUpTask.h"
#import "SFMobileSyncConstants.h"

@implementation SFSyncUpTask

-(instancetype) init:(SFMobileSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    self = [super init:syncManager sync:sync updateBlock:updateBlock];
    return self;
}

- (void) runSync:(SFSyncState*)sync {
    SFSyncUpTarget* target = (SFSyncUpTarget*) sync.target;
    NSArray* dirtyRecordIds = [target getIdsOfRecordsToSyncUp:self.syncManager soupName:sync.soupName];
    [self syncUp:sync recordIds:dirtyRecordIds];
}

- (void)syncUp:(SFSyncState*)sync recordIds:(NSArray*)recordIds {
    [self syncUpOneEntry:sync recordIds:recordIds index:0];
}

- (void)syncUpOneEntry:(SFSyncState*)sync
             recordIds:(NSArray*)recordIds
                 index:(NSUInteger)i {
    
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    sync.totalSize = recordIds.count;
    [self updateSync:sync countSynched:i];
    
    
    if ([sync isDone] || [self shouldStop]) {
        return;
    }

    NSMutableDictionary* record = [[target getFromLocalStore:self.syncManager soupName:soupName storeId:recordIds[i]] mutableCopy];
    [SFSDKMobileSyncLogger d:[self class] format:@"syncUpOneRecord:%@", record];
    
    // Do we need to do a create, update or delete
    BOOL locallyCreated = [target isLocallyCreated:record];
    BOOL locallyUpdated = [target isLocallyUpdated:record];
    BOOL locallyDeleted = [target isLocallyDeleted:record];
    
    SFSyncUpTargetAction action = SFSyncUpTargetActionNone;
    if (locallyDeleted)
        action = SFSyncUpTargetActionDelete;
    else if (locallyCreated)
        action = SFSyncUpTargetActionCreate;
    else if (locallyUpdated)
        action = SFSyncUpTargetActionUpdate;
    
    /*
     * Checks if we are attempting to update a record that has been updated
     * on the server AFTER the client's last sync down. If the merge mode
     * passed in tells us to leave the record alone under these
     * circumstances, we will do nothing.
     */
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged && !locallyCreated) {
        // Need to check the modification date on the server, against the local date.
        __weak typeof(self) weakSelf = self;
        [target isNewerThanServer:self.syncManager record:record resultBlock:^(BOOL isNewerThanServer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (isNewerThanServer) {
                [strongSelf resumeSyncUpOneEntry:sync
                                       recordIds:recordIds
                                           index:i
                                          record:record
                                          action:action];
            }
            else {
                // Server date is newer than the local date.  Skip this update.
                [SFSDKMobileSyncLogger d:[strongSelf class] format:@"syncUpOneRecord: Record not synced since client does not have the latest from server:%@", record];
                [strongSelf syncUpOneEntry:sync
                                 recordIds:recordIds
                                     index:i+1];
            }
        }];
    } else {
        // State is such that we can simply update the record directly.
        [self resumeSyncUpOneEntry:sync recordIds:recordIds index:i record:record action:action];
    }
}

- (void)resumeSyncUpOneEntry:(SFSyncState*)sync
                   recordIds:(NSArray*)recordIds
                       index:(NSUInteger)i
                      record:(NSMutableDictionary*)record
                      action:(SFSyncUpTargetAction)action {
    
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    __weak typeof(self) weakSelf = self;
    // Next
    void (^nextBlock)(void)=^() {
        [weakSelf syncUpOneEntry:sync recordIds:recordIds index:i+1];
    };
    
    // If it is not a advanced sync up target and there is no changes on the record, go to next
    if (action == SFSyncUpTargetActionNone) {
        // Next
        nextBlock();
        return;
    }
    // Delete handler
    SFSyncUpTargetCompleteBlock completeBlockDelete = ^(NSDictionary *d) {
        // Remove entry on delete
        [target deleteFromLocalStore:weakSelf.syncManager soupName:soupName record:record];
        
        // Next
        nextBlock();
    };
    
    // Update handler
    SFSyncUpTargetCompleteBlock completeBlockUpdate = ^(NSDictionary *d) {
        [target cleanAndSaveInLocalStore:weakSelf.syncManager soupName:soupName record:record];
        
        // Next
        nextBlock();
    };
    
    // Create handler
    NSString *fieldName = target.idFieldName;
    SFSyncUpTargetCompleteBlock completeBlockCreate = ^(NSDictionary *d) {
        // Replace id with server id during create
        record[fieldName] = d[kCreatedId];
        completeBlockUpdate(d);
    };
    
    // Create failure handler
    SFSyncUpTargetErrorBlock failBlockCreate = ^ (NSError* err){
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if ([SFRestRequest isNetworkError:err]) {
            [strongSelf failSync:sync failureMessage:@"Create server call failed" error:err];
        }
        else {
            [target saveRecordToLocalStoreWithLastError:weakSelf.syncManager soupName:soupName record:record];
            
            // Next
            nextBlock();
        }
    };
    
    // Update failure handler
    SFSyncUpTargetErrorBlock failBlockUpdate = ^ (NSError* err){
        __strong typeof (weakSelf) strongSelf = weakSelf;
        // Handling remotely deleted records
        if (err.code == 404) {
            if (mergeMode == SFSyncStateMergeModeOverwrite) {
                [target createOnServer:strongSelf.syncManager record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockCreate failBlock:failBlockCreate];
            }
            else {
                // Next
                nextBlock();
            }
        }
        else if ([SFRestRequest isNetworkError:err]) {
            [strongSelf failSync:sync failureMessage:@"Update server call failed" error:err];
        }
        else {
            [target saveRecordToLocalStoreWithLastError:strongSelf.syncManager soupName:soupName record:record];
            
            // Next
            nextBlock();
        }
    };
    
    // Delete failure handler
    SFSyncUpTargetErrorBlock failBlockDelete = ^ (NSError* err){
        __strong typeof (weakSelf) strongSelf = weakSelf;
        // Handling remotely deleted records
        if (err.code == 404) {
            completeBlockDelete(nil);
        }
        else if ([SFRestRequest isNetworkError:err]) {
            [strongSelf failSync:sync failureMessage:@"Delete server call failed" error:err];
        }
        else {
            [target saveRecordToLocalStoreWithLastError:strongSelf.syncManager soupName:soupName record:record];
            
            // Next
            nextBlock();
        }
    };
    
    switch(action) {
        case SFSyncUpTargetActionCreate:
            [target createOnServer:self.syncManager record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockCreate failBlock:failBlockCreate];
            break;
        case SFSyncUpTargetActionUpdate:
            [target updateOnServer:self.syncManager record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockUpdate failBlock:failBlockUpdate];
            break;
        case SFSyncUpTargetActionDelete:
            // if locally created it can't exist on the server - we don't need to actually do the deleteOnServer call
            if ([target isLocallyCreated:record]) {
                completeBlockDelete(record);
            }
            else {
                [target deleteOnServer:self.syncManager record:record completionBlock:completeBlockDelete failBlock:failBlockDelete];
            }
            break;
        default:
            // Action is unsupported here.  Move on.
            [SFSDKMobileSyncLogger i:[self class] format:@"%@ unsupported action with value %lu.  Moving to the next record.", NSStringFromSelector(_cmd), (unsigned long) action];
            nextBlock();
            return;
    }
}

@end
