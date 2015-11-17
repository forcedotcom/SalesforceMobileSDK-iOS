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

#import "SFInstrumentation.h"
#import "SFMethodInterceptor.h"
#import <objc/runtime.h>

@interface SFInstrumentation ()

@property (nonatomic) Class clazz;

@property (nonatomic, strong) NSMutableArray *interceptors;

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

- (instancetype)init {
    self = [super init];
    if (self) {
        self.interceptors = [NSMutableArray array];
        self.collector = [NSMutableDictionary dictionary];
    }
    return self;
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
    SFMethodInterceptor *interceptor = [[SFMethodInterceptor alloc] init];
    interceptor.classToIntercept = self.clazz;
    interceptor.selectorToIntercept = selector;
    interceptor.targetBeforeBlock = before;
    interceptor.targetAfterBlock = after;
    interceptor.instanceMethod = YES;
    interceptor.enabled = YES;
    [self.interceptors addObject:interceptor];
}


- (void)interceptInstanceMethod:(SEL)selector replaceWithInvocationBlock:(SFMethodInterceptorInvocationCallback)replace {
    SFMethodInterceptor *interceptor = [[SFMethodInterceptor alloc] init];
    interceptor.classToIntercept = self.clazz;
    interceptor.selectorToIntercept = selector;
    interceptor.targetReplaceBlock = replace;
    interceptor.instanceMethod = YES;
    interceptor.enabled = YES;
    [self.interceptors addObject:interceptor];
}

-(void)instrumentForTiming:(SFInstrumentationSelectorFilter)selectorFilter afterBlock:(SFMethodInterceptorInvocationAfterCallback)after {
    if (after == nil) {
        after = ^(NSInvocation *invocation, NSTimeInterval executionTime) {
            [SFLogger log:self.clazz
                    level:SFLogLevelInfo
                   format:@"TIMING %@.%@: %.3f ms", NSStringFromClass(self.clazz), [NSStringFromSelector(invocation.selector) substringFromIndex:19], executionTime*1000]; /* cutting off __method_forwarded_ */
        };
    }
    
    unsigned int mc = 0;
    Method * mlist = class_copyMethodList(self.clazz, &mc);
    for(int i=0;i<mc;i++) {
        SEL selector = method_getName(mlist[i]);
        if (selectorFilter(selector)) {
            [self interceptInstanceMethod:selector beforeBlock:nil afterBlock:after];
        }
    }
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
