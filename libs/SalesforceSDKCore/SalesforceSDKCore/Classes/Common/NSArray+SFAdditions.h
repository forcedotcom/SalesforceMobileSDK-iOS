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

#import <Foundation/Foundation.h>
/** Provides Salesforce Mobile SDK filtering for NSArray objects.
 */

@interface NSArray (SFAdditions)

/**
 Returns an array whose elements are guaranteed to be instances of the given class.
 @param aClass The class to filter on.
 @return An array whose elements are all of the given type (or a subtype).
 */
- (NSArray *)filteredArrayWithElementsOfClass:(Class)aClass;

/** 
 Returns an array whose elements have a given value at a given keypath.
 @param value The value to filter on.
 @param key The key path for the value to filter on.
 */
- (NSArray*)filteredArrayWithValue:(id)value forKeyPath:(NSString*)key;

/**
 Returns an array whose elements exclude a given value at a given keypath.
 @param value The value to filter on.
 @param key The key path for the value to filter on.
 */
- (NSArray*)filteredArrayExcludingValue:(id)value forKeyPath:(NSString*)key;

@end
