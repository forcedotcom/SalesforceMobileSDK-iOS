/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSyncUpdateCallbackQueue.h"

#define MAX_WAIT_TIME 5.0

@interface SFSmartSyncSyncManager()
- (void) runSync:(SFSyncState*) sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;
@end


@interface SFSyncUpdateCallbackQueue ()
@property (nonatomic, strong) NSMutableArray *queue;
@end

@implementation SFSyncUpdateCallbackQueue

- (id)init
{
    self = [super init];
    if (self)
    {
        self.queue = [[NSMutableArray alloc] init];
    }
    return self;
}

# pragma - public methods

- (void)runSync:(SFSyncState*)sync syncManager:(SFSmartSyncSyncManager*)syncManager
{
    [syncManager runSync:sync updateBlock:^(SFSyncState *sync) {
        @synchronized(self.queue) {
            [self.queue addObject:[sync copy]];
        }
    }];
}

- (SFSyncState*) runReSync:(NSNumber*)syncId syncManager:(SFSmartSyncSyncManager*)syncManager
{
    return [syncManager reSync:syncId updateBlock:^(SFSyncState *sync) {
        @synchronized(self.queue) {
            [self.queue addObject:[sync copy]];
        }
    }];
}

- (SFSyncState*)getNextSyncUpdate
{
    SFSyncState* syncState = [self getNextSyncUpdate:MAX_WAIT_TIME];
    return syncState;
}

- (SFSyncState*)getNextSyncUpdate:(NSTimeInterval) maxWaitTime
{
    NSDate *startTime = [NSDate date];
    SFSyncState* sync;
    while (YES) {
        sync = [self getFirst];
        if (sync != nil) {
            // we got one!
            break;
        }
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > maxWaitTime) {
            [SFSDKSmartSyncLogger d:[self class] format:@"getNextSyncUpdate took too long (> %f secs) to complete.", elapsed];
            return nil;
        }
        [SFSDKSmartSyncLogger d:[self class] format:@"## sleeping..."];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    };
    return sync;
}

- (SFSyncState*)getFirst
{
    @synchronized(self.queue) {
        if (self.queue.count > 0) {
            SFSyncState* sync = [self.queue objectAtIndex:0];
            [self.queue removeObjectAtIndex:0];
            return sync;
        }
        else {
            return nil;
        }
    }
}
@end
