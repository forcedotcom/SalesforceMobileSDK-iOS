/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

@interface SFSmartSyncSyncManager()
- (void) runSync:(SFSyncState*) sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;
@end

@interface SFSyncUpdateCallbackQueue()
@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSCondition *lock;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@end

@implementation SFSyncUpdateCallbackQueue

- (id)init
{
    self = [super init];
    if (self)
    {
        self.queue = [[NSMutableArray alloc] init];
        self.lock = [[NSCondition alloc] init];
        self.dispatchQueue = dispatch_queue_create("SFSyncUpdateCallbackQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    self.dispatchQueue = nil;
    self.queue = nil;
    self.lock = nil;
}

# pragma - public methods

- (void)runSync:(SFSyncState*)sync syncManager:(SFSmartSyncSyncManager*)syncManager
{
    __weak SFSyncUpdateCallbackQueue* weakSelf = self;
    [syncManager runSync:sync updateBlock:^(SFSyncState *sync) {
        [weakSelf enqueue:sync];
    }];
}

- (SFSyncState*)getNextSyncUpdate
{
    return (SFSyncState*) [self dequeue];
}

# pragma - enqueue/dequeue methods

- (void)enqueue:(id)object
{
    [_lock lock];
    [_queue addObject:object];
    [_lock signal];
    [_lock unlock];
}

- (id)dequeue
{
    __block id object;
    dispatch_sync(_dispatchQueue, ^{
        [_lock lock];
        while (_queue.count == 0)
        {
            [_lock wait];
        }
        object = [_queue objectAtIndex:0];
        [_queue removeObjectAtIndex:0];
        [_lock unlock];
    });
    
    return object;
}

- (NSUInteger)count
{
    return [_queue count];
}


@end