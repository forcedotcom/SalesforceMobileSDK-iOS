/*
 SFMutableDictionaryThreadSafe.m
 SalesforceSDKCore
 
 Created by Raj Rao on Wed Oct 21 17:47:00 PDT 2016.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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
#import "SFMutableDictionaryThreadSafe.h"
@interface SFMutableDictionaryThreadSafe(){
    dispatch_queue_t _dispatchQueue;
    NSMutableDictionary *_mutableInternalDictionary;
}
@end

@implementation SFMutableDictionaryThreadSafe

- (instancetype)init
{
    self = [self initInternal];
    if (self) {
        _mutableInternalDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
    self = [self initInternal];
    if (self) {
        _mutableInternalDictionary = [NSMutableDictionary dictionaryWithCapacity:numItems];
    }
    return self;
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
    self = [self initInternal];
    if (self) {
        _mutableInternalDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self initInternal];
    if (self) {
        _mutableInternalDictionary = [[NSMutableDictionary alloc] initWithCoder:aDecoder];
    }
    return self;
}

- (instancetype)initInternal
{
    self = [super init];
    if (self) {
        _dispatchQueue = dispatch_queue_create([@"SFMutableDictionaryThreadSafe Queue" UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}


- (instancetype)initWithObjects:(const id [])objects forKeys:(const id<NSCopying> [])keys count:(NSUInteger)cnt
{
    self = [self initInternal];
    if (self) {
        if (keys != nil && objects!=nil) {
            for (NSUInteger i = 0; i < cnt; ++i) {
                _mutableInternalDictionary[keys[i]] = objects[i];
            }
        }
    }
    return self;
}


- (NSUInteger)count
{
    __block NSUInteger count;
    dispatch_sync(_dispatchQueue, ^{
        count = self->_mutableInternalDictionary.count;
    });
    return count;
}

- (id)objectForKey:(id)aKey
{
    __block id obj;
    dispatch_sync(_dispatchQueue, ^{
        obj = self->_mutableInternalDictionary[aKey];
    });
    return obj;
}

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey
{
    aKey = [aKey copyWithZone:NULL];
    dispatch_barrier_async(_dispatchQueue, ^{
        self->_mutableInternalDictionary[aKey] = anObject;
    });
}

- (void)removeObjectForKey:(id)aKey
{
    dispatch_barrier_async(_dispatchQueue, ^{
        [self->_mutableInternalDictionary removeObjectForKey:aKey];
    });
}

- (void)removeAllObjects
{
    dispatch_barrier_async(_dispatchQueue, ^{
        [self->_mutableInternalDictionary removeAllObjects];
    });
}

- (void)removeObjectsForKeys:(NSArray<id> *)keyArray
{
    dispatch_barrier_async(_dispatchQueue, ^{
        [self->_mutableInternalDictionary removeObjectsForKeys:keyArray];
    });
}

- (NSEnumerator *)keyEnumerator
{
    __block NSEnumerator *enu;
    dispatch_sync(_dispatchQueue, ^{
        enu = [self->_mutableInternalDictionary keyEnumerator];
    });
    return enu;
}

@end
