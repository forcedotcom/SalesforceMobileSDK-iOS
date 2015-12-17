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

#import "SFMethodInterceptor.h"
#import <objc/message.h>
#import <objc/runtime.h>

/** This static dictionary contains a map of <class, selector> to <interceptor>.
 In other words, it helps get the interceptor instance for a given
 pair of class and selector. The class is the class to intercept
 an the selector is the selector to intercept
 */
static NSMutableDictionary *InterceptorsForClassAndSelector = nil;

/** This method returns a key given a class and a selector
 */
static NSString * interceptorKey(Class clazz, SEL selector) {
    return [NSString stringWithFormat:@"%@:%@", NSStringFromClass(clazz), NSStringFromSelector(selector)];
}

@interface SFMethodInterceptor ()

/** The instance or class of the intercepted object.
 */
@property (nonatomic, weak) id interceptedObject;

/** Returns a selector who's method implementation contains
 the original method that was intercepted.
 This selector has been renamed to ensure it doesn't collide
 with the original selector or any other existing method
 */
@property (nonatomic, readonly) SEL originalMethodRenamedSelector;
@property (nonatomic, readonly) SEL originalMethodRenamedSelectorForBlock;

@property (nonatomic, strong) NSMethodSignature *interceptedMethodSignature;

@end

@implementation SFMethodInterceptor

+ (void)initialize {
    if (self == [SFMethodInterceptor class] && nil == InterceptorsForClassAndSelector) {
        InterceptorsForClassAndSelector = [NSMutableDictionary dictionary];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = NO;
    }
    return self;
}

- (void)dealloc {
    @synchronized (InterceptorsForClassAndSelector) {
        [InterceptorsForClassAndSelector removeObjectForKey:interceptorKey(self.classToIntercept, self.selectorToIntercept)];
    }
}

- (SEL)originalMethodRenamedSelector {
    // Rename the original selector by inserting a string that ensure it's unique
    NSMutableString *name = [[NSMutableString alloc] initWithCString:sel_getName(self.selectorToIntercept) encoding:NSASCIIStringEncoding];
    [name insertString:@"__method_forwarded_" atIndex:0];
    
    // use sel_registerName() and not @selector to avoid warning
    SEL sel = sel_registerName([name cStringUsingEncoding:NSASCIIStringEncoding]);
    return sel;
}

- (SEL)originalMethodRenamedSelectorForBlock {
    // Rename the original selector by inserting a string that ensure it's unique
    NSMutableString *name = [[NSMutableString alloc] initWithCString:sel_getName(self.selectorToIntercept) encoding:NSASCIIStringEncoding];
    [name insertString:@"__method_forwarded_block_" atIndex:0];
    
    // use sel_registerName() and not @selector to avoid warning
    SEL sel = sel_registerName([name cStringUsingEncoding:NSASCIIStringEncoding]);
    return sel;
}

#pragma mark - Forwarding & Swizzling

- (id)forwardingTargetForSelector:(SEL)aSelector {
    // Here `self` is expected to refer to the class instance that's being intercepted
    if ([self isKindOfClass:[SFMethodInterceptor class]]) {
        // If not, then it means some unknown method is called on the SFMethodInterceptor class
        // instance which is left untouched.
        return [super forwardingTargetForSelector:aSelector];
    } else {
        // Let's find out which interceptor instance is managing
        // this selector and class
        SFMethodInterceptor *interceptor = InterceptorsForClassAndSelector[interceptorKey([self class], aSelector)];
        if (interceptor) {
            interceptor.interceptedObject = self;
            return interceptor;
        } else {
            return [super forwardingTargetForSelector:aSelector];
        }
    }
}

/** This method is invoked on the SFMethodInterceptor class when
 a unknown selector is invoked on that class. Normally, it's
 the selector that's being intercepted that's provided here.
 We return the intercepted method signature that was captured
 when the interceptor was created so the Objective-C forwarding
 machinery can correctly create the invocation.
 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return self.interceptedMethodSignature;
}

/** After `methodSignatureForSelector` has been invoked, this
 methid is invoked with the invocation that contains the description
 of the message that was intercepted.
 This is here that we intercept the message, call back any registered
 callback blocks and then invoke the original method code (or skip it).
 */
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([self isKindOfClass:[SFMethodInterceptor class]]) {
        anInvocation.target = self.interceptedObject;
        anInvocation.selector = self.originalMethodRenamedSelector;
        
        [self invokeCallbacks:anInvocation];        
    } else {
        [super forwardInvocation:anInvocation];
    }
}

- (void)invokeCallbacks:(NSInvocation*)anInvocation {
    if (self.targetBeforeBlock) {
        self.targetBeforeBlock(anInvocation);
    }
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    if (self.targetReplaceBlock) {
        self.targetReplaceBlock(anInvocation);
    } else {
        [self invokeOriginal:anInvocation];
    }
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    if (self.targetAfterBlock) {
        self.targetAfterBlock(anInvocation, endTime - startTime);
    }
}

- (void)invokeOriginal:(NSInvocation*)anInvocation {
    anInvocation.selector = self.originalMethodRenamedSelector;
    [anInvocation invokeWithTarget:self.interceptedObject];
}

- (void)swizzle {
    if (_enabled) {
        return;
    }
    if (self.instanceMethod) {
        Method originalMethod = class_getInstanceMethod(self.classToIntercept, self.selectorToIntercept);
        const char *methodTypes = method_getTypeEncoding(originalMethod);
        
        InterceptorsForClassAndSelector[interceptorKey(self.classToIntercept, self.selectorToIntercept)] = self;
        
        // forward method
        IMP originalMethodIMP = method_setImplementation(originalMethod, (IMP)_objc_msgForward);
        NSAssert(originalMethodIMP, @"Original method implementation must be found");
        
        SEL forwardingSelector = @selector(forwardingTargetForSelector:);
        Method forwardingMethod = class_getInstanceMethod([self class], forwardingSelector);
        IMP forwardingMethodIMP = method_getImplementation(forwardingMethod);
        const char *forwardingMethodTypes = method_getTypeEncoding(forwardingMethod);
        class_replaceMethod(self.classToIntercept, forwardingSelector, forwardingMethodIMP, forwardingMethodTypes);
        
        self.interceptedMethodSignature = [self.classToIntercept instanceMethodSignatureForSelector:self.selectorToIntercept];
        
        class_replaceMethod(self.classToIntercept, self.originalMethodRenamedSelector, originalMethodIMP, methodTypes);
    } else {
        // Note: class method must be added to the class's metaclass
        Class originalMetaClass = objc_getMetaClass(object_getClassName(self.classToIntercept));
        
        Method originalMethod = class_getClassMethod(originalMetaClass, self.selectorToIntercept);
        const char *methodTypes = method_getTypeEncoding(originalMethod);
        
        InterceptorsForClassAndSelector[interceptorKey(self.classToIntercept, self.selectorToIntercept)] = self;
                
        // forward method
        IMP originalMethodIMP = method_setImplementation(originalMethod, (IMP)_objc_msgForward);
        NSAssert(originalMethodIMP, @"Original method implementation must be found");
        
        SEL forwardingSelector = @selector(forwardingTargetForSelector:);
        Method forwardingMethod = class_getInstanceMethod([self class], forwardingSelector);
        IMP forwardingMethodIMP = method_getImplementation(forwardingMethod);
        const char *forwardingMethodTypes = method_getTypeEncoding(forwardingMethod);
        class_replaceMethod(originalMetaClass, forwardingSelector, forwardingMethodIMP, forwardingMethodTypes);
        
        self.interceptedMethodSignature = [self.classToIntercept methodSignatureForSelector:self.selectorToIntercept];
        
        class_replaceMethod(originalMetaClass, self.originalMethodRenamedSelector, originalMethodIMP, methodTypes);
    }
    _enabled = YES;
    NSLog(@"%@ is ENABLED", self);
}

- (void)unswizzle {
    if (!_enabled) {
        return;
    }
    if (self.instanceMethod) {
        Method targetMethod = class_getInstanceMethod(self.classToIntercept, self.selectorToIntercept);
        Method originalMethod = class_getInstanceMethod(self.classToIntercept, self.originalMethodRenamedSelector);
        method_exchangeImplementations(originalMethod, targetMethod);
    } else {
        Method targetMethod = class_getClassMethod(self.classToIntercept, self.selectorToIntercept);
        Method originalMethod = class_getClassMethod(self.classToIntercept, self.originalMethodRenamedSelector);
        method_exchangeImplementations(originalMethod, targetMethod);
    }
    _enabled = NO;
    NSLog(@"%@ is DISABLED", self);
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        [self willChangeValueForKey:@"enabled"];
        if (enabled) {
            [self swizzle];
        } else {
            [self unswizzle];
        }
        _enabled = enabled;
        [self didChangeValueForKey:@"enabled"];
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p, %@::%@>", NSStringFromClass([self class]), self, NSStringFromClass(self.classToIntercept), NSStringFromSelector(self.selectorToIntercept)];
}

@end
