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
#import <Foundation/Foundation.h>
NS_SWIFT_NAME(SafeMutableArray)
@interface SFSDKSafeMutableArray : NSObject

/**
 * The number of elements in this array.
 */
@property (nonatomic,readonly) NSUInteger count;

/**
* Returns a new instance that’s a mutable copy of the receiver.
*/
- (id)mutableCopyWithZone:(NSZone *)zone;

/**
 * Returns true if the object exists in the array.
 */
- (BOOL)containsObject:(id)anObject;

/**
 * Returns the object at the specified index.
 */
- (id)objectAtIndexedSubscript:(NSUInteger)idx;

/**
 * Returns the object at the specified index.
 */
- (id)objectAtIndexed:(NSUInteger)idx;

/**
 * Get a NSArray from the mutable array
 */
- (NSArray *)asArray;

/**
 * Enumerate objects in the array safely, using a block.
 */
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;

/**
 * Inserts a given object at the end of the array.
 */
- (void)addObject:(id)obj;

/**
 * Adds the objects contained in another given array to the end of the receiving array’s content.
 */
- (void)addObjectsFromArray:(NSArray *)array;

/**
 * Inserts a given object into the array’s contents at a given index.
 */
- (void)insertObject:(id)obj atIndex:(NSUInteger)index;

/**
 * Inserts the objects in the provided array into the receiving array at the specified indexes.
 */
- (void)insertObjects:(id)obj atIndexes:(NSIndexSet *)indexes;

/**
 * Removes all objects from the array.
 */
- (void)removeAllObjects;

/**
 * Removes the object with the highest-valued index in the array
 */
- (void)removeLastObject;

/**
 * Removes all occurrences in the array of a given object.
 */
- (void)removeObject:(id)object;

/**
 * Removes the object at index.
 */
- (void)removeObjectAtIndex:(NSUInteger)index;

/**
 * Removes the objects at the specified indexes from the array.
 **/
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;

/**
 * Removes all occurrences of a given object in the array.
 **/
- (void)removeObjectIdenticalTo:(id)object;

/**
 * Removes all occurrences of anObject within the specified range in the array.
 **/
- (void)removeObjectIdenticalTo:(id)object inRange:(NSRange)range;

/**
 * Removes all occurrences within a specified range in the array of a given object.
 */
- (void)removeObject:(id)object inRange:(NSRange)range;

/**
 * Removes from the receiving array the objects in another given array.
 **/
- (void)removeObjectsInArray:(NSArray *)otherArray;

/**
 * Removes from the array each of the objects within a given range.
 */
- (void)removeObjectsInRange:(NSRange)range;

/**
 * Replaces the object at the index with the new object, possibly adding the object..
 */
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;

/**
 * Empties the receiving set, then adds each object contained in another given array.
 */
- (void)setArray:(NSArray *)otherArray;

/**
 * Filter the array using a predicate.
 */
- (void)filterUsingPredicate:(NSPredicate *)predicate;

/**
 * A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableArray.
 *
 * @return A new SFSDKSafeMutableArray instance.
 */
+ (id)array;

/**
 * A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableArrayWithCapacity.
 *
 * @return A new SFSDKSafeMutableArray instance.
 */
+ (id)arrayWithCapacity:(NSUInteger)numItems;

@end
