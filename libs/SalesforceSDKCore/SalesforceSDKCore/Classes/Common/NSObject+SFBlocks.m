/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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


#import "NSObject+SFBlocks.h"

@implementation NSObject (SFBlocks)

static NSTimeInterval const RUNLOOP_WAIT_TIME = 0.1;

- (void)scheduleInvocationWithBlock:(SFThreadBlock)block {
    if (block) {
        block();
    }
}

- (void)performBlock:(SFThreadBlock)block onThread:(NSThread*)thread waitUntilDone:(BOOL)waitUntilDone {
    [self performSelector:@selector(scheduleInvocationWithBlock:) 
                 onThread:thread
               withObject:[block copy]
            waitUntilDone:waitUntilDone];    
}

- (void)performBlockOnGlobalQueue:(SFThreadBlock)block afterDelay:(NSTimeInterval)delay {
    if (block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
    }
}

- (void)performBlockOnMainThread:(SFThreadBlock)block afterDelay:(NSTimeInterval)delay {
    if (block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), block);
    }
}

- (BOOL)waitForBlockCondition:(BOOL(^)(void))block timeout:(NSTimeInterval)duration {
    BOOL blockCondition = NO;
    @autoreleasepool {
        blockCondition = block();
        if (!blockCondition) {
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:duration];
            while ([date timeIntervalSinceNow] > 0) {
                if (block()) {
                    blockCondition = YES;
                    break;
                }
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:RUNLOOP_WAIT_TIME]];
            }        
        }
    }
    return blockCondition;
}

- (void)synchronouslyExecuteBlockOnMainThread:(void (^)(void))block {
    if (!block) { return; }
    
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (void)asynchronouslyExecuteBlockOnMainThread:(void(^)(void))block {
    if (!block) { return; }
    
    dispatch_async(dispatch_get_main_queue(), block);
}

- (void)executeBlockOrDispatchIfNotMainThread:(void(^)(void))block {
    if (!block) { return; }

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}


@end
