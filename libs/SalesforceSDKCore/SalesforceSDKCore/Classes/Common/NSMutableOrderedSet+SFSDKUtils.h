/*
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

#import <Foundation/Foundation.h>

@interface NSMutableOrderedSet (SFSDKWeakObjects)

/**
 Adds a weakified object to the ordered set.
 @param obj The object to hold a weak reference to.
 */
- (void)msdkAddObjectToWeakify:(id)obj;

/**
 Removes a weakified object from the ordered set.  If the object doesn't exist in the
 ordered set, no action is takend.
 @param obj The object whose weak reference should be removed from the ordered set.
 */
- (void)msdkRemoveWeakifiedObject:(id)obj;

/**
 Enumerates the ordered set to take action against weakified objects.
 @param block The block to execute against each weakified object.
 */
- (void)msdkEnumerateWeakifiedObjectsWithBlock:(void (^)(id weakifiedObj))block;

/**
 Whether or not the ordered set contains the weakified object.
 @param obj The object to query in the ordered set.
 @return YES if the set contains a weakified reference to the object, NO otherwise.
 */
- (BOOL)msdkContainsWeakifiedObject:(id)obj;

/**
 Get the index of the weakified object in the ordered set.
 @param obj The object to query in the set.
 @return The index of the object in the ordered set, or NSNotFound if the object does have a weakified
 reference in the ordered set.
 */
- (NSUInteger)msdkIndexOfWeakifiedObject:(id)obj;

/**
 Returns the weakified object at the given index.
 @param index The index in the ordered set where the object exists.
 @return The weakified object, or nil if the object at that index is not in a weakified form.
 @throw NSRangeException if the index does not exist in the range of objects in the ordered set.
 */
- (id)msdkWeakifiedObjectAtIndex:(NSUInteger)index;

@end
