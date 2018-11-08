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

#import "SFSDKSafeMutableArray.h"

@interface SFSDKSafeMutableArray()
@property (nonatomic,strong) NSMutableArray *backingArray;
@property (nonatomic,strong) dispatch_queue_t queue;
@end

@implementation SFSDKSafeMutableArray

- (id)init {
    if ((self = [super init]))
    {
        self.backingArray = [NSMutableArray array];
        [self initQueue];
    }
    return self;
}

- (id)initWithCapacity:(NSUInteger)numItems {
    if ((self = [super init]))
    {
        self.backingArray = [NSMutableArray arrayWithCapacity:numItems];
        [self initQueue];
    }
    return self;
}

- (NSUInteger)count {
    __block NSUInteger size;
    dispatch_sync(self.queue, ^{
        size = self.backingArray.count;
    });

    return size;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    __block SFSDKSafeMutableArray *mutableCopy = [[[self class] allocWithZone:zone] init];
    dispatch_sync(self.queue, ^{
        mutableCopy.backingArray = [self.backingArray mutableCopy];
    });
    return mutableCopy;
}

-(BOOL)containsObject:(id)anObject {
    __block BOOL exists;
    dispatch_sync(self.queue, ^{
        exists = [self.backingArray containsObject:anObject];
    });
    return exists;
}

-(id)objectAtIndexedSubscript:(NSUInteger)idx {
    __block id object;
    dispatch_sync(self.queue, ^{
        object = [self.backingArray objectAtIndexedSubscript:idx];
    });
    return object;
}

-(id)objectAtIndexed:(NSUInteger)idx {
    __block id object;
    dispatch_sync(self.queue, ^{
        object = [self.backingArray objectAtIndex:idx];
    });
    return object;
}

- (NSArray *)asArray {
    __block NSArray *array;
    dispatch_sync(self.queue, ^{
        array = [NSArray arrayWithArray:self.backingArray];
    });
    return array;
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block {
    dispatch_sync(self.queue, ^{
        [self.backingArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            block(obj, idx, stop);
        }];
    });
}

#pragma Mark - Mutating Methods

- (void)addObject:(id)obj {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray addObject:obj];
    });
}

- (void)addObjectsFromArray:(NSArray *)array {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray addObjectsFromArray:array];
    });
}

- (void)insertObject:(id)obj atIndex:(NSUInteger)index {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray insertObject:obj atIndex:index];
    });
}

- (void)insertObjects:(id)objects atIndexes:(NSIndexSet *)indexes {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray insertObjects:objects atIndexes:indexes];
    });
}

- (void)removeAllObjects {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeAllObjects];
    });
}

-(void)removeLastObject {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeLastObject];
    });
}

- (void)removeObject:(id)object {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObject:object];
    });
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectAtIndex:index];
    });
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectsAtIndexes:indexes];
    });
}

- (void)removeObjectIdenticalTo:(id)object {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectIdenticalTo:object];
    });
}

- (void)removeObjectIdenticalTo:(id)object inRange:(NSRange)range {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectIdenticalTo:object inRange:range];
    });
}

- (void)removeObject:(id)object inRange:(NSRange)range {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObject:object inRange:range];
    });
}

- (void)removeObjectsInArray:(NSArray *)otherArray {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectsInArray:otherArray];
    });
}

- (void)removeObjectsInRange:(NSRange)range {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray removeObjectsInRange:range];
    });
}

- (void)setArray:(NSArray *)array {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray setArray:array];
    });
}

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray setObject:object atIndexedSubscript:index];
    });
}


- (void)filterUsingPredicate:(NSPredicate *)predicate {
    dispatch_barrier_async(self.queue, ^{
        [self.backingArray filterUsingPredicate:predicate];
    });
}

#pragma mark - Class Level

+ (id)array {
    id retVal = [[self alloc] init];
    return retVal;
}

+ (id)arrayWithCapacity:(NSUInteger)numItems {
    id retVal = [[self alloc] initWithCapacity:numItems];
    return retVal;
}

#pragma private methods
- (void)initQueue {
    self.queue = dispatch_queue_create([NSString stringWithFormat:@"com.salesforce.mobilesdk.readWriteArrayQ%u", arc4random_uniform(UINT32_MAX)].UTF8String, DISPATCH_QUEUE_CONCURRENT);
}

@end
