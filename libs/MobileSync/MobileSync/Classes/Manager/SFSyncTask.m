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

#import "SFSyncTask.h"
#import "SFMobileSyncSyncManager+SFSyncTask.h"
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>

NSInteger const kSyncManagerUnchanged = -1;

@interface SFSyncTask ()

@property (nonatomic, strong) SFMobileSyncSyncManager* syncManager;
@property (nonatomic, strong) SFSyncState* sync;
@property (nonatomic, strong) NSNumber* syncId;
@property (nonatomic, strong) SFSyncSyncManagerUpdateBlock updateBlock;

@end

@implementation SFSyncTask

-(instancetype) init:(SFMobileSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    self = [super init];
    if (self) {
        self.syncManager = syncManager;
        self.sync = sync;
        self.syncId = @(sync.syncId);
        self.updateBlock = updateBlock;
        
        [self.syncManager addToActiveSyncs:self];
        sync.status = SFSyncStateStatusRunning;
        [self updateSync:sync countSynched:0];
        // XXX not actually running on worker thread until run() gets invoked
        //     may be we should introduce another state?
    }
    return self;
}

- (BOOL) shouldStop {
    if (![self.syncManager checkAcceptingSyncs:nil]) {
        self.sync.status = SFSyncStateStatusStopped;
        [self updateSync:self.sync countSynched:kSyncManagerUnchanged];
        return YES;
    } else {
        return NO;
    }
}

- (void) run {
    if (![self shouldStop]) {
        [self runSync:self.sync];
    }
}
    
- (void) runSync:(SFSyncState*)sync    ABSTRACT_METHOD

-(void) failSync:(SFSyncState*)sync failureMessage:(NSString*)failureMessage error:(NSError*) error {
    [SFSDKMobileSyncLogger e:[self class] format:@"runSync failed:%@ cause:%@ error%@", sync, failureMessage, error];
    sync.error = [error.userInfo description];
    sync.status = SFSyncStateStatusFailed;
    [self updateSync:sync countSynched:kSyncManagerUnchanged];
}

- (void) updateSync:(SFSyncState*)sync countSynched:(NSUInteger)countSynched {
    
    // Update progress
    if (countSynched != kSyncManagerUnchanged) {
        sync.progress = sync.totalSize == 0 ? 100 : countSynched*100/sync.totalSize;
    }
    
    // Update status
    if (sync.status == SFSyncStateStatusRunning && sync.progress == 100) {
        sync.status = SFSyncStateStatusDone;
    }

    // Save sync state
    [sync save:self.syncManager.store];
    [SFSDKMobileSyncLogger d:[self class] format:@"updateSync: syncId:%@ status:%@ progress:%ld totalSize:%ld", @(sync.syncId), [SFSyncState syncStatusToString:sync.status], (long)sync.progress, (long)sync.totalSize];
    
    // Create event and remove from active sync list if stopped/done/failed
    switch (self.sync.status) {
        case SFSyncStateStatusNew:
        case SFSyncStateStatusRunning:
            break;
        case SFSyncStateStatusStopped:
        case SFSyncStateStatusDone:
        case SFSyncStateStatusFailed:
            [self createAndStoreEvent:sync];
            [self.syncManager removeFromActiveSyncs:self];
            break;
    }
    
    // Call updateBlock if any
    if (self.updateBlock) {
        self.updateBlock(sync);
    }
}

- (void)createAndStoreEvent:(SFSyncState*)sync {
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    if (sync.totalSize > 0) {
        attributes[@"numRecords"] = [NSNumber numberWithInteger:sync.totalSize];
    }
    attributes[@"syncId"] = @(sync.syncId);
    attributes[@"syncTarget"] = NSStringFromClass([sync.target class]);
    attributes[kSFSDKEventBuilderHelperStartTime] = [NSNumber numberWithInteger:sync.startTime];
    attributes[kSFSDKEventBuilderHelperEndTime] = [NSNumber numberWithInteger:sync.endTime];
    [SFSDKEventBuilderHelper createAndStoreEvent:[SFSyncState syncTypeToString:sync.type]
                                     userAccount:nil
                                       className:NSStringFromClass([self.syncManager class])
                                      attributes:attributes];
}


@end
