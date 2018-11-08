/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSafeMutableSet.h"

@interface SFSDKSafeMutableSet()
@property (nonatomic,strong) NSMutableSet *backingSet;
@property (nonatomic,strong) dispatch_queue_t queue;
@end

@implementation SFSDKSafeMutableSet

- (id)init {
    if ((self = [super init]))
    {
        self.backingSet = [NSMutableSet set];
        [self initQueue];
    }
    return self;
}

- (id)initWithCapacity:(NSUInteger)numItems {
    if ((self = [super init]))
    {
        self.backingSet = [NSMutableSet setWithCapacity:numItems];
        [self initQueue];
    }
    return self;
}

- (NSUInteger)count {
    __block NSUInteger size;
    dispatch_sync(self.queue, ^{
        size = self.backingSet.count;
    });
    
    return size;
}

- (id)anyObject {
    __block id object;
    dispatch_sync(self.queue, ^{
        object = [self.backingSet anyObject];
    });
    return object;
}

- (BOOL)containsObject:(id)anObject {
    __block BOOL exists;
    dispatch_sync(self.queue, ^{
        exists = [self.backingSet containsObject:anObject];
    });
    return exists;
}

- (NSArray *)allObjects {
    __block NSArray *array;
    dispatch_sync(self.queue, ^{
        array = [self.backingSet allObjects];
    });
    return array;
}

- (NSSet *)asSet {
    __block NSSet *set;
    dispatch_sync(self.queue, ^{
        set = [NSSet setWithSet:self.backingSet];
    });
    return set;
}

- (BOOL)isEqualToSet:(SFSDKSafeMutableSet *)that {
    BOOL isEqual = [self isEqual:that];
    if (!isEqual) {
         NSSet *thisSet = [self asSet];
         NSSet *thatSet = [that asSet];
         isEqual = [thisSet isEqualToSet:thatSet];
    }
    return isEqual;
}

- (void)addObject:(id)obj {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet addObject:obj];
    });
}

- (void)addObjectsFromArray:(NSArray *)array {
    dispatch_barrier_async(self.queue, ^{
         [self.backingSet addObjectsFromArray:array];
    });
}

- (void)removeAllObjects {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet removeAllObjects];
    });
}

- (void)removeObject:(id)object {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet removeObject:object];
    });
}

- (void)unionSet:(NSSet *)set {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet unionSet:set];
    });
}

- (void)minusSet:(NSSet *)set {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet minusSet:set];
    });
}

- (void)intersectSet:(NSSet *)set {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet intersectSet:set];
    });
}

- (void)setSet:(NSSet *)set {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet setSet:set];
    });
}

- (void)filterUsingPredicate:(NSPredicate *)predicate {
    dispatch_barrier_async(self.queue, ^{
        [self.backingSet filterUsingPredicate:predicate];
    });
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block {
    __block NSArray *array = [self allObjects];
    dispatch_barrier_sync(self.queue, ^{
        [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            block(obj, stop);
        }];
    });
}

#pragma mark - Class Level

+ (id)set {
    id retVal = [[self alloc] init];
    return retVal;
}

+ (id)setWithCapacity:(NSUInteger)numItems {
    id retVal = [[self alloc] initWithCapacity:numItems];
    return retVal;
}

#pragma private methods
- (void)initQueue {
     self.queue = dispatch_queue_create([NSString stringWithFormat:@"com.salesforce.mobilesdk.readWriteSetQ%u", arc4random_uniform(UINT32_MAX)].UTF8String, DISPATCH_QUEUE_CONCURRENT);
}

@end
