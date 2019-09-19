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

#import "SFCleanSyncGhostsTask.h"
#import "SFMobileSyncSyncManager+SFSyncTask.h"
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>

@interface SFCleanSyncGhostsTask ()

@property (nonatomic, copy) SFSyncSyncManagerCompletionStatusBlock completionStatusBlock;

@end

@implementation SFCleanSyncGhostsTask

-(instancetype) init:(SFMobileSyncSyncManager*)syncManager sync:(SFSyncState*)sync completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock {
    self = [super init:syncManager sync:sync updateBlock:nil];
    if (self) {
        self.completionStatusBlock = completionStatusBlock;
    }
    return self;
}


- (void) updateSync:(SFSyncState*)sync countSynched:(NSUInteger)countSynched {
    // Not a true sync
    // Leaving sync state alone
}

- (void) runSync:(SFSyncState*)sync {
    __weak typeof (self) weakSelf = self;
    SFSyncDownTarget* target = (SFSyncDownTarget*) sync.target;
    NSString* soupName = sync.soupName;
    NSNumber* syncId = @(sync.syncId);
    [target cleanGhosts:self.syncManager
               soupName:soupName
                 syncId:syncId
             errorBlock:^(NSError *e) {
                 __strong typeof (weakSelf) strongSelf = weakSelf;
                 [SFSDKMobileSyncLogger e:[strongSelf class] format:@"Failed to get list of remote IDs, %@", [e localizedDescription]];
                 [strongSelf createAndStoreEvent:sync numRecords:-1];
                 [self.syncManager removeFromActiveSyncs:strongSelf];
                 strongSelf.completionStatusBlock(SFSyncStateStatusFailed, 0);
             }
          completeBlock:^(NSArray *localIds) {
              __strong typeof (weakSelf) strongSelf = weakSelf;
              [self createAndStoreEvent:sync numRecords:localIds.count];
              [self.syncManager removeFromActiveSyncs:strongSelf];
              strongSelf.completionStatusBlock(SFSyncStateStatusDone, localIds.count);
          }];
}

- (void)createAndStoreEvent:(SFSyncState*)sync numRecords:(NSInteger)numRecords {
    NSMutableDictionary *eventAttrs = [[NSMutableDictionary alloc] init];
    eventAttrs[@"syncId"] = @(sync.syncId);
    eventAttrs[@"syncTarget"] = NSStringFromClass([sync.target class]);
    if (numRecords >= 0) eventAttrs[@"numRecords"] = [NSNumber numberWithInteger:numRecords];

    [SFSDKEventBuilderHelper createAndStoreEvent:@"cleanResyncGhosts" userAccount:nil className:NSStringFromClass([self class]) attributes:eventAttrs];
}

@end
