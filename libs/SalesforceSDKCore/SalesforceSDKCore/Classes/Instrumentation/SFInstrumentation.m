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

#import "SFInstrumentation.h"
#import "SFMethodInterceptor.h"
#import <objc/runtime.h>

@interface SFInstrumentation ()

@property (nonatomic) Class clazz;

@property (nonatomic, strong) NSMutableArray<SFMethodInterceptor *> *interceptors;

@property (nonatomic, strong) NSMutableDictionary *collector;

@property (nonatomic, strong) NSString *sessionKey;
@property (nonatomic, strong) NSString *sessionValue;

@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval endTime;

@end

@implementation SFInstrumentation

+ (instancetype)instrumentationForClass:(Class)clazz {
    SFInstrumentation *perf = [[SFInstrumentation alloc] init];
    perf.clazz = clazz;
    return perf;
}

+ (instancetype)instrumentationForClassWithName:(NSString *)className {
    NSAssert(className.length > 0, @"Class name cannot be empty.");
    Class classToInstrument = NSClassFromString(className);
    NSAssert(classToInstrument != nil, @"Class '%@' does not exist.", className);
    return [self instrumentationForClass:classToInstrument];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.interceptors = [NSMutableArray array];
        self.collector = [NSMutableDictionary dictionary];
    }
    return self;
}

- (SFMethodInterceptor *)interceptorForSelector:(SEL)selector isInstanceSelector:(BOOL)isInstanceSelector {
    NSUInteger interceptorIndex = [self.interceptors indexOfObjectPassingTest:^BOOL(SFMethodInterceptor *obj, NSUInteger idx, BOOL *stop) {
        return (obj.classToIntercept == self.clazz && obj.selectorToIntercept == selector && obj.instanceMethod == isInstanceSelector);
    }];
    return (interceptorIndex == NSNotFound ? nil : self.interceptors[interceptorIndex]);
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        [self willChangeValueForKey:@"enabled"];
        _enabled = enabled;
        for (SFMethodInterceptor *interceptor in self.interceptors) {
            interceptor.enabled = enabled;
        }
        [self didChangeValueForKey:@"enabled"];
    }
}

- (void)interceptInstanceMethod:(SEL)selector beforeBlock:(SFMethodInterceptorInvocationCallback)before afterBlock:(SFMethodInterceptorInvocationAfterCallback)after {
    [self interceptMethod:selector beforeBlock:before afterBlock:after isInstanceMethod:YES];
}


- (void)interceptInstanceMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace {
    [self interceptMethod:selector replaceWithInvocationBlock:replace isInstanceMethod:YES];
}

- (void)interceptClassMethod:(SEL)selector beforeBlock:(SFMethodInterceptorInvocationCallback)before afterBlock:(SFMethodInterceptorInvocationAfterCallback)after {
    [self interceptMethod:selector beforeBlock:before afterBlock:after isInstanceMethod:NO];
}

- (void)interceptClassMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace {
    [self interceptMethod:selector replaceWithInvocationBlock:replace isInstanceMethod:NO];
}

- (void)interceptMethod:(SEL)selector
            beforeBlock:(SFMethodInterceptorInvocationCallback)before
             afterBlock:(SFMethodInterceptorInvocationAfterCallback)after
       isInstanceMethod:(BOOL)isInstanceMethod {
    SFMethodInterceptor *interceptor = [[SFMethodInterceptor alloc] init];
    interceptor.classToIntercept = self.clazz;
    interceptor.selectorToIntercept = selector;
    interceptor.targetBeforeBlock = before;
    interceptor.targetAfterBlock = after;
    interceptor.instanceMethod = isInstanceMethod;
    if (![self.interceptors containsObject:interceptor]) {
        interceptor.enabled = YES;
        [self.interceptors addObject:interceptor];
    } else {
        [self log:SFLogLevelWarning format:@"Interceptor with class '%@' and %@ selector '%@' is already configured. No action taken.", NSStringFromClass(self.clazz), (isInstanceMethod ? @"instance" : @"class"), NSStringFromSelector(selector)];
    }
}

- (void)interceptMethod:(SEL)selector
replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace
       isInstanceMethod:(BOOL)isInstanceMethod {
    SFMethodInterceptor *interceptor = [[SFMethodInterceptor alloc] init];
    interceptor.classToIntercept = self.clazz;
    interceptor.selectorToIntercept = selector;
    interceptor.targetReplaceBlock = replace;
    interceptor.instanceMethod = isInstanceMethod;
    if (![self.interceptors containsObject:interceptor]) {
        interceptor.enabled = YES;
        [self.interceptors addObject:interceptor];
    } else {
        [self log:SFLogLevelWarning format:@"Interceptor with class '%@' and %@ selector '%@' is already configured. No action taken.", NSStringFromClass(self.clazz), (isInstanceMethod ? @"instance" : @"class"), NSStringFromSelector(selector)];
    }
}

- (void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter afterBlock:(SFMethodInterceptorInvocationAfterCallback)after {
    [self instrumentForTiming:selectorFilter inheritanceLevels:0 afterBlock:after];
}

- (void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter
          inheritanceLevels:(NSUInteger)numInheritanceLevels
                 afterBlock:(SFMethodInterceptorInvocationAfterCallback)after {
    if (after == nil) {
        after = [self defaultPostTimingBlock];
    }
    
    NSMutableDictionary<NSString *, NSNumber *> *configuredSelectorsDict = [NSMutableDictionary dictionary];
    NSUInteger currentInheritanceLevel = 0;
    Class currentClass = self.clazz;
    while (currentInheritanceLevel <= numInheritanceLevels && currentClass != nil) {
        // Instance methods
        unsigned int mc = 0;
        Method *instanceMethodList = class_copyMethodList(currentClass, &mc);
        for(NSUInteger i = 0; i < mc; i++) {
            SEL selector = method_getName(instanceMethodList[i]);
            NSString *selectorName = [NSString stringWithFormat:@"%@_%@", NSStringFromSelector(selector), @"inst"];
            if (configuredSelectorsDict[selectorName] == nil && selectorFilter(selector, YES)) {
                configuredSelectorsDict[selectorName] = @YES;
                [self interceptInstanceMethod:selector beforeBlock:nil afterBlock:after];
            }
        }
        
        // Class methods
        mc = 0;
        Method *classMethodList = class_copyMethodList(object_getClass(currentClass), &mc);
        for(NSUInteger i = 0; i < mc; i++) {
            SEL selector = method_getName(classMethodList[i]);
            NSString *selectorName = [NSString stringWithFormat:@"%@_%@", NSStringFromSelector(selector), @"class"];
            if (configuredSelectorsDict[selectorName] == nil && selectorFilter(selector, NO)) {
                configuredSelectorsDict[selectorName] = @YES;
                [self interceptClassMethod:selector beforeBlock:nil afterBlock:after];
            }
        }
        
        currentInheritanceLevel++;
        currentClass = [currentClass superclass];
    }
}

- (SFMethodInterceptorInvocationAfterCallback)defaultPostTimingBlock {
    __weak __typeof(self) weakSelf = self;
    return ^(NSInvocation *invocation, SFSDKInstrumentationPostExecutionData *data) {
        __strong __typeof(self) strongSelf = weakSelf;
        [SFLogger log:strongSelf.clazz
                level:SFLogLevelInfo
               format:@"TIMING %@.%@: %.3f ms", NSStringFromClass(strongSelf.clazz), data.selectorName, data.executionTime*1000];
    };
}

#pragma mark - Driven

- (void)loadInstructions:(NSArray*)instructions completion:(dispatch_block_t)completion {
    for (NSDictionary *instruction in instructions) {
        self.clazz = NSClassFromString(instruction[@"class"]);
        NSDictionary *session = instruction[@"session"];
        if (session) {
            self.sessionKey = session.allKeys[0];
            self.sessionValue = session.allValues[0];
        }
        
        for (NSDictionary *interceptor in instruction[@"intercept"]) {
            SEL selector = NSSelectorFromString(interceptor[@"selector"]);
            NSString *action = interceptor[@"action"];
            NSArray *keys = interceptor[@"keys"];
            
            [self interceptInstanceMethod:selector beforeBlock:^(NSInvocation *invocation) {
                if ([self isInstanceSession:invocation.target]) {
                    [self collectKeys:keys invocation:invocation selector:selector];
                    if ([action isEqualToString:@"start"]) {
                        [self startMeasure];
                    }
                    if ([action isEqualToString:@"end"]) {
                        [self stopMeasure];
                        if (completion) completion();
                    }
                }
            } afterBlock:nil];
        }
        
        self.enabled = YES;
    }
}

- (BOOL)isInstanceSession:(id)instance {
    if (nil == self.sessionKey) {
        return YES;
    }
    
    id value = [instance valueForKey:self.sessionKey];
    return [self.sessionValue isEqualToString:[value description]];
}

- (void)collectKeys:(NSArray*)keys invocation:(NSInvocation*)invocation selector:(SEL)selector {
    if (nil == keys) {
        return;
    }
    
    id instance = invocation.target;

    NSMutableDictionary *collection = [NSMutableDictionary dictionary];

    NSMutableArray *args = [NSMutableArray array];
    for (NSUInteger index=2; index<invocation.methodSignature.numberOfArguments; index++) {
        // TODO support for non-object argument
        __unsafe_unretained id arg = nil;
        [invocation getArgument:&arg atIndex:index];
        if (arg) {
            [args addObject:[arg description]];
        }
    }
    collection[@"args"] = args;
    
    for (NSString *key in keys) {
        id value = [instance valueForKey:key];
        if (value) {
            collection[key] = value;
        } else {
            collection[key] = @"nil";
        }
    }
    self.collector[NSStringFromSelector(selector)] = collection;
}

#pragma mark - Measure

- (void)startMeasure {
    self.startTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)stopMeasure {
    self.endTime = [NSDate timeIntervalSinceReferenceDate];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p, duration=%.2f, collector=%@>", NSStringFromClass([self class]), self, self.endTime-self.startTime, self.collector];
}

@end
