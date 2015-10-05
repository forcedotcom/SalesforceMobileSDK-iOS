//
//  NSArray+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Jonathan Arbogast on 6/3/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (SFAdditions)

/**
 Returns an array whose elements are guaranteed to be a kind of the given class
 @param aClass The class to filter on
 @return An array whose elements are all of the given type (or a subtype)
 */
- (NSArray *)filteredArrayWithElementsOfClass:(Class)aClass;

/** 
 Returns an array whose elements have a give value at a given keypath.
 @param value The value to filter on
 @param key The key path for the value to filter on
 */
- (NSArray*)filteredArrayWithValue:(id)value forKeyPath:(NSString*)key;

/**
 Returns an array whose elements exclude a give value at a given keypath.
 @param value The value to filter on
 @param key The key path for the value to filter on
 */
- (NSArray*)filteredArrayExcludingValue:(id)value forKeyPath:(NSString*)key;

/**
 Returns an array cleansed of any nil objects
 */
- (NSArray *)cleansedArray;

@end
