//
//  NSObject+SFBlocks.m
//  ChatterSDK
//
//  Created by Jean Bovet on 12/12/11.
//  Copyright (c) 2011 Salesforce.com. All rights reserved.
//

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
