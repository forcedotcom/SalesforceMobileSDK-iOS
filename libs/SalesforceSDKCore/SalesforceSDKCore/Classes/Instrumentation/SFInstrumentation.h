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

#import <Foundation/Foundation.h>
#import "SFMethodInterceptor.h"

typedef BOOL (^SFInstrumentationSelectorFilter)(SEL selector, BOOL isInstanceSelector);


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

/** Returns an instrumentation instance for the class with the specified name.
 @param className The name of the class to be instrumented.
 */
+ (instancetype)instrumentationForClassWithName:(NSString *)className;

/** Returns the interceptor configured for the class with the given selector, or `nil`
 if an interceptor is not configured for the given selector.
 @param selector The selector to check
 @param isInstanceSelector Whether or not the selector is an instance selector.
 @return The configured `SFMethodInterceptor` instance, or `nil` if an interceptor is
 not configured.
 */
- (SFMethodInterceptor *)interceptorForSelector:(SEL)selector isInstanceSelector:(BOOL)isInstanceSelector;

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
 @param replace The block to be invoked
 */
- (void)interceptInstanceMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace;

/** Use this method to intercept the class method specified by `selector`
 @param selector The selector to intercept
 @param before An optional block invoked before the selector is executed
 @param after An optional block invoked after the selector is executed
 */
- (void)interceptClassMethod:(SEL)selector beforeBlock:(SFMethodInterceptorInvocationCallback)before afterBlock:(SFMethodInterceptorInvocationAfterCallback)after;

/** Use this method to intercept the class method specified by `selector`
 and provide a block that will be invoked instead of the method.
 Note: the block contains a single argument which is the NSInvocation of the message.
 @param selector The instance method to be intercepted
 @param replace The block to be invoked
 */
- (void)interceptClassMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace;

/** Instrument some selectors of a the target class for performance timing.
 @param selectorFilter A block invoked when to select selectors from the class to instrument
 @param after An optional block invoked after any selector is executed
 @discussion This method will only instrument selectors defined on or explicitly overridden
 in the class.  To instrument inherited selectors, use the
 instrumentForTiming:inheritanceLevels:afterBlock: overload.  Calling this method is
 the same as calling instrumentForTiming:inheritanceLevels:afterBlock: with an
 inheritance levels value of zero.
 */
-(void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter afterBlock:(SFMethodInterceptorInvocationAfterCallback)after;

/** Instrument some selectors of the target class and its parent class(es)
 for performance timing.
 @param selectorFilter A block invoked when to select selectors from the class to instrument
 @param numInheritanceLevels The number of inherited classes whose selectors will be made available.
 @param after An optional block invoked after any selector is executed
 */
- (void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter
          inheritanceLevels:(NSUInteger)numInheritanceLevels
                 afterBlock:(SFMethodInterceptorInvocationAfterCallback)after;

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
