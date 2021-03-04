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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_NAME(SafeMutableDictionary)
@interface SFSDKSafeMutableDictionary<KeyType, ObjectType> : NSObject

@property (copy, nonatomic, readonly) NSArray *allKeys;
@property (copy, nonatomic, readonly) NSArray *allValues;

/**
 Retrieves object for the key specified (Thread Safe)
 @return object for specified key
 */
- (nullable ObjectType)objectForKey:(KeyType<NSCopying>)aKey;

/**
 Retrieves object for the key specified (Thread Safe)
 @return object for specified key
 */
- (nullable ObjectType)objectForKeyedSubscript:(KeyType<NSCopying>)key;

/**
 Retreives all keys for object specified (Thread Safe)
 @return Array with keys
 */
- (NSArray<KeyType> *)allKeysForObject:(ObjectType)anObject;

/**
 * Get a NSDictionary from the mutable Dictionary (Thread Safe)
 */
- (NSDictionary<KeyType, ObjectType> *)dictionary;

/**
 Sets object for key specified (Thread Safe)
 @param object to add to collection
 @param aKey for to map the object to
 */
- (void)setObject:(ObjectType)object forKey:(KeyType<NSCopying>)aKey;

/**
 Sets object for key specified (Thread Safe)
 @param object to add to collection
 @param aKey for to map the object to
 */
- (void)setObject:(ObjectType)object forKeyedSubscript:(KeyType<NSCopying>)aKey;

/**
 Removes object for key specified (Thread Safe)
 @param aKey to remove from the collection.
 */
- (void)removeObject:(KeyType<NSCopying>)aKey;

/**
 removes all objects (Thread Safe)
 */
- (void)removeAllObjects;

/**
 removes objects for keys (Thread Safe)
 @param keys to remove from the collection.
 */
- (void)removeObjects:(NSArray<KeyType<NSCopying>> *)keys;

/**
 Adds entries from the dictionary passed in (Thread Safe)
 @param otherDictionary to add to collection
 */
- (void)addEntries:(NSDictionary<KeyType, ObjectType> *)otherDictionary;

/**
 Sets the dictionary collection to the dictionary passed in(Thread Safe)
 @param dictionary to set
 */
- (void)setDictionary:(NSDictionary<KeyType, ObjectType> *)dictionary;

@end

NS_ASSUME_NONNULL_END
