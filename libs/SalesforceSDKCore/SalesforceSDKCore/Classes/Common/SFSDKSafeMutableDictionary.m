/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSafeMutableDictionary.h"

@interface SFSDKSafeMutableDictionary()

@property (strong, nonatomic) NSMutableDictionary *backingDictionary;
@property (strong, nonatomic) dispatch_queue_t queue;

@end

@implementation SFSDKSafeMutableDictionary

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backingDictionary = [NSMutableDictionary new];
        self.queue = dispatch_queue_create([NSString stringWithFormat:@"com.salesforce.mobilesdk.readWriteQueue%u", arc4random_uniform(UINT32_MAX)].UTF8String, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (NSArray *)allKeys {
    __block NSArray *keys;
    dispatch_sync(self.queue, ^{
        keys = self.backingDictionary.allKeys;
    });
    return keys;
}

- (NSArray *)allValues {
    __block NSArray *values;
    dispatch_sync(self.queue, ^{
        values = self.backingDictionary.allValues;
    });
    return values;
}

- (id)objectForKey:(id<NSCopying>)aKey {
    __block id value;
    dispatch_sync(self.queue, ^{
        value = self.backingDictionary[aKey];
    });
    return value;
}

- (NSArray *)allKeysForObject:(id)anObject {
    __block NSArray *keys;
    dispatch_sync(self.queue, ^{
        keys = [self.backingDictionary allKeysForObject:anObject];
    });
    return keys;
}

#pragma Mark - Mutating Methods

- (void)setObject:(id)object forKey:(id<NSCopying>)aKey {
    dispatch_barrier_async(self.queue, ^{
        self.backingDictionary[aKey] = object;
    });
}

- (void)removeObject:(id<NSCopying>)aKey {
    dispatch_barrier_async(self.queue, ^{
        [self.backingDictionary removeObjectForKey:aKey];
    });
}

- (void)removeAllObjects {
    dispatch_barrier_async(self.queue, ^{
        [self.backingDictionary removeAllObjects];
    });
}

- (void)removeObjects:(NSArray<id<NSCopying>> *)keys {
    dispatch_barrier_async(self.queue, ^{
        [self.backingDictionary removeObjectsForKeys:keys];
    });
}

- (void)addEntries:(NSDictionary *)otherDictionary {
    dispatch_barrier_async(self.queue, ^{
        [self.backingDictionary addEntriesFromDictionary:otherDictionary];
    });
}

- (void)setDictionary:(NSDictionary *)dictionary {
    dispatch_barrier_async(self.queue, ^{
        [self.backingDictionary setDictionary:dictionary];
    });
}

@end


