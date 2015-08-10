//
//  NSObject+SFBlocks.h
//  SalesforceCommonUtils
//
//  Created by Jean Bovet on 12/12/11.
//  Copyright (c) 2011-2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Block that will be invoked in a thread.
 */
typedef void (^SFThreadBlock)(void);

@interface NSObject (SFBlocks)

/** Perform a block asynchronously on the main thread. If the code is running within the context of unit tests,
 the block is instead executed immediately on the current thread.
 */
- (void)dispatchAsyncOnMain:(dispatch_block_t)block;

/**
 Perform a block on a specific thread.
 @param block The block to execute on the thread
 @param thread The thread in which to execute the block
 @param waitUntilDone Flag that indicates if this method should block until the block is done executing
 */
- (void)performBlock:(SFThreadBlock)block onThread:(NSThread*)thread waitUntilDone:(BOOL)waitUntilDone;

/**
 Perform a block on the current thread after a delay.
 @param block The block to execute
 @param delay The delay before executing the block
 */
- (void)performBlock:(SFThreadBlock)block afterDelay:(NSTimeInterval)delay;

/**
 Wait until a block return value is YES or a time-out happens.
 @param block The block that will be invoked regularily until it returns YES or a time-out happen.
 @param duration Time-out duration.
 @return YES if the block returned YES or NO if a time-out happened
 */
- (BOOL)waitForBlockCondition:(BOOL(^)(void))block timeout:(NSTimeInterval)duration;

@end
