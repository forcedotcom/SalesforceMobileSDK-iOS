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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Block that will be invoked in a thread.
 */
typedef void (^SFThreadBlock)(void);

@interface NSObject (SFBlocks)

/**
 Perform a block on a specific thread.
 @param block The block to execute on the thread
 @param thread The thread in which to execute the block
 @param waitUntilDone Flag that indicates if this method should block until the block is done executing
 */
- (void)performBlock:(SFThreadBlock)block onThread:(NSThread*)thread waitUntilDone:(BOOL)waitUntilDone;

/**
 Perform a block on a global queue thread after a delay.
 @param block The block to execute
 @param delay The delay before executing the block
 */
- (void)performBlockOnGlobalQueue:(SFThreadBlock)block afterDelay:(NSTimeInterval)delay;

/**
 Perform a block on the main thread after a delay.
 @param block The block to execute
 @param delay The delay before executing the block
 */
- (void)performBlockOnMainThread:(SFThreadBlock)block afterDelay:(NSTimeInterval)delay;

/**
 Wait until a block return value is YES or a time-out happens.
 @param block The block that will be invoked regularily until it returns YES or a time-out happen.
 @param duration Time-out duration.
 @return YES if the block returned YES or NO if a time-out happened
 */
- (BOOL)waitForBlockCondition:(BOOL(^)(void))block timeout:(NSTimeInterval)duration;

/**
 Executes the given block directly if called from the main thread. Otherwise the block
 is synchronously dispatched for execution on the main thread.
 @param block The block to execute
 */
- (void)synchronouslyExecuteBlockOnMainThread:(void(^)(void))block;

/**
 The block is asynchronously dispatched for execution on the main thread.
 @param block The block to execute
 */
- (void)asynchronouslyExecuteBlockOnMainThread:(void(^)(void))block;

/**
 Executes the given block directly if called from the main thread. Otherwise the block
 is asynchronously dispatched for execution on the main thread.
 @param block The block to execute
 */
- (void)executeBlockOrDispatchIfNotMainThread:(void(^)(void))block;

@end

NS_ASSUME_NONNULL_END
