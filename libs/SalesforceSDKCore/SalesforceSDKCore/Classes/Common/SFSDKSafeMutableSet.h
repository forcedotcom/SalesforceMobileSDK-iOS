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

@interface SFSDKSafeMutableSet : NSObject

/**
 * Adds a given object to the set, if it is not already a member.
 */
- (id)anyObject;

/**
 * Returns true if the object exists in the set.
 */
- (BOOL)containsObject:(id)anObject;

/**
 * Adds a given object to the set, if it is not already a member.
 */
- (void)addObject:(id)obj;

/**
 * Adds to the set each object contained in a given array that is not already a member.
 */
- (void)addObjectsFromArray:(NSArray *)array;

/**
 * Removes all objects from the set.
 */
- (void)removeAllObjects;

/**
 * Removes a given object from the set.
 */
- (void)removeObject:(id)object;

/**
 * Removes each object in another given set from the receiving set, if present.
 */
- (void)unionSet:(NSSet *)otherSet;

/**
 * Empties the receiving set, then adds each object contained in another given set.
 */
- (void)minusSet:(NSSet *)set;

/**
 * Empties the receiving set, then adds each object contained in another given set.
 */
- (void)intersectSet:(NSSet *)otherSet;

/**
 * Empties the receiving set, then adds each object contained in another given set.
 */
- (void)setSet:(NSSet *)otherSet;

/**
 * Filter the set using a predicate.
 */
- (void)filterUsingPredicate:(NSPredicate *)predicate;

/**
 * Enumerate objects in the set safely, using a block.
 */
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block;

/**
 * Get a NSSet from the mutable set
 */
- (NSSet *)asSet;

/**
 * Return an Array of all Objects
 */
- (NSArray *)allObjects;

/**
 * Returns true if the sets are equal.
 */
- (BOOL)isEqualToSet:(SFSDKSafeMutableSet *)otherSet;

/**
 * The number of elements in this set.
 */
@property (nonatomic,readonly) NSUInteger count;

/**
 * A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableSet.
 *
 * @return A new SFSDKSafeMutableSet instance.
 */
+ (id)set;

/**
 * A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableSetWithCapacity.
 *
 * @return A new SFSDKSafeMutableSet instance.
 */
+ (id)setWithCapacity:(NSUInteger)numItems;

@end
