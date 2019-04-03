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
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>

NSInteger const kSyncManagerUnchanged = -1;

@interface SFSmartSyncSyncManager (SFSyncTask)

- (void) addToActiveSyncs:(NSNumber*)syncId;
- (void) removeFromActiveSyncs:(NSNumber*)syncId;

@end

@interface SFSyncTask ()

@property (nonatomic, strong) SFSmartSyncSyncManager* syncManager;
@property (nonatomic, strong) SFSyncState* sync;
@property (nonatomic, copy) SFSyncSyncManagerUpdateBlock updateBlock;

@end

@implementation SFSyncTask

-(instancetype) init:(SFSmartSyncSyncManager*)syncManager sync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    self = [super init];
    if (self) {
        self.syncManager = syncManager;
        self.sync = sync;
        self.updateBlock = updateBlock;
        
        [self.syncManager addToActiveSyncs:[NSNumber numberWithInteger:sync.syncId]];
        [self updateSync:SFSyncStateStatusRunning progress:0 totalSize:kSyncManagerUnchanged maxTimeStamp:kSyncManagerUnchanged];
        // XXX not actually running on worker thread until run() gets invoked
        //     may be we should introduce another state?
    }
    return self;
}

-(void) checkIfStopRequested {
    
}

- (void)run {
    [self checkIfStopRequested];
    [self runSync];    
}

- (void) runSync ABSTRACT_METHOD

-(void) failSync:(NSString*) failureMessage error:(NSError*) error {
    //Set error message to sync state
    [self.sync setError: [error.userInfo description]];
    [SFSDKSmartSyncLogger e:[self class] format:@"runSync failed:%@ cause:%@ error%@", sync, failureMessage, error];
    [self updateSync:SFSyncStateStatusFailed progress:kSyncManagerUnchanged totalSize:kSyncManagerUnchanged maxTimeStamp:kSyncManagerUnchanged];
}

- (void) updateSync:(SFSyncStateStatus)status progress:(NSInteger)progress totalSize:(NSInteger)totalSize maxTimeStamp:(long long) maxTimeStamp {
    //if (status == nil) status = (progress == 100 ? SFSyncStateStatusDone : SFSyncStateStatusRunning);
    self.sync.status = status;
    if (progress>=0)  self.sync.progress = progress;
    if (totalSize>=0) self.sync.totalSize = totalSize;
    if (maxTimeStamp>=0) self.sync.maxTimeStamp = (self.sync.maxTimeStamp < maxTimeStamp ? maxTimeStamp : self.sync.maxTimeStamp);
    [self.sync save:self.syncManager.store];
    [SFSDKSmartSyncLogger d:[self class] format:@"Sync update:%@", sync];
    
    switch (self.sync.status) {
        case SFSyncStateStatusNew:
            break; // should not happen
        case SFSyncStateStatusRunning:
            break;
        case SFSyncStateStatusStopped:
        case SFSyncStateStatusDone:
        case SFSyncStateStatusFailed:
            [self createAmdStoreEvent:self.sync];
            [self.syncManager removeFromActiveSyncs:[NSNumber numberWithInteger:self.sync.syncId]];
            break;
    }
    if (self.updateBlock) {
        self.updateBlock(self.sync);
    }
}

- (void)createAmdStoreEvent:(SFSyncState*)sync {
    NSString *eventName = nil;
    switch (sync.type) {
        case SFSyncStateSyncTypeDown:
            eventName = @"syncDown";
            break;
        case SFSyncStateSyncTypeUp:
            eventName = @"syncUp";
            break;
    }
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"numRecords"] = [NSNumber numberWithInteger:sync.totalSize];
    attributes[@"syncId"] = [NSNumber numberWithInteger:sync.syncId];
    attributes[@"syncTarget"] = NSStringFromClass([sync.target class]);
    attributes[kSFSDKEventBuilderHelperStartTime] = [NSNumber numberWithInteger:sync.startTime];
    attributes[kSFSDKEventBuilderHelperEndTime] = [NSNumber numberWithInteger:sync.endTime];
    [SFSDKEventBuilderHelper createAndStoreEvent:eventName userAccount:nil className:NSStringFromClass([self.syncManager class]) attributes:attributes];
}


@end
