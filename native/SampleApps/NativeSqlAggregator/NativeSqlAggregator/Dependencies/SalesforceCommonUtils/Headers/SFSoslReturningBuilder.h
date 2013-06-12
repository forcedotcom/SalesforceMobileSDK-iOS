//
//  SFSoslReturningBuilder.h
//  ChatterBox
//
//  Created by Sachin Desai on 5/17/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSoslReturningBuilder : NSObject

/** @name */
/** A builder to help create a returning statement.
 *
 * @param name the object to return.
 * @return the builder
 */
+ (SFSoslReturningBuilder *) withObjectName:(NSString *) name;

/** A builder to help create a returning statement.
 *
 * @param fields a list of one or more fields to return for a given object, comma separated
 * @return the builder
 */
- (SFSoslReturningBuilder *) fields:(NSString *) fields;

/** A builder to help create a returning statement.
 *
 * @param where a description of how search results for the given object should be filtered, based on individual field values. If unspecified, the search retrieves all the rows in the object that are visible to the user
 * @return the builder
 */
- (SFSoslReturningBuilder *) where:(NSString *) where;

/** A builder to help create a returning statement.
 *
 * @param orderBy a description of how to order the returned result, including ascending and descending order, and how nulls are ordered
 * @return the builder
 */
- (SFSoslReturningBuilder *) orderBy:(NSString *) orderBy;

/** A builder to help create a returning statement.
 *
 * @param limit the maximum number of records returned for the given object. If unspecified, all matching records are returned, up to the limit set for the query as a whole
 * @return the builder
 */
- (SFSoslReturningBuilder *) limit:(NSInteger) limit;

/** @name Query String Generation */
/** Builds a returning statement from the builder.
 *
 * @return the built returning statement
 */
- (NSString *) build;

@end
