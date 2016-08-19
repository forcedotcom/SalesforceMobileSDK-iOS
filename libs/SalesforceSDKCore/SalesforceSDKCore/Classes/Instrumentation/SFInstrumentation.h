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

#import <Foundation/Foundation.h>
#import "SFMethodInterceptor.h"

typedef BOOL (^SFInstrumentationSelectorFilter)(SEL selector);


/** This class exposes API that allow to intercept
 method call and introspect the object being intercepted.
 It can be used to record timing & usage information for example.
 */
@interface SFInstrumentation : NSObject

/** Enable or disable this instrumentation instance
 */
@property (nonatomic) BOOL enabled;

/** Returns an instrumentation instance for the specified class
 @param clazz The class to be instrumented
 */
+ (instancetype)instrumentationForClass:(Class)clazz;

/** Use this method to intercept the instance method specified by `selector`
 @param selector The selector to intercept
 @param before An optional block invoked before the selector is executed
 @param after An optional block invoked after the selector is executed
 */
- (void)interceptInstanceMethod:(SEL)selector beforeBlock:(SFMethodInterceptorInvocationCallback)before afterBlock:(SFMethodInterceptorInvocationAfterCallback)after;

/** Use this method to intercept the instance method specified by `selector`
 and provide a block that will be invoked instead of the method.
 Note: the block contains a single argument which is the NSInvocation of the message.
 @param selector The instance method to be intercepted
 @param before The block to be invoked 
 */
- (void)interceptInstanceMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)before;

/** Instrument some selectors of a the target class for performance timing
 @param selectorFilter A block invoked when to select selectors from the class to instrument
 @param after An optional block invoked after any selector is executed
 */
-(void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter afterBlock:(SFMethodInterceptorInvocationAfterCallback)after;

/** Loads the array of instructions execute them. The instructions usually
 comes from a JSON file.
 @param instructions The array of instructions
 @param completion Optional completion block
 */
- (void)loadInstructions:(NSArray*)instructions completion:(dispatch_block_t)completion;

/** Start the timing measurement
 */
- (void)startMeasure;

/** Stop the timing measurement
 */
- (void)stopMeasure;


@end
