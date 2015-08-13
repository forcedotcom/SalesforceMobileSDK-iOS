//
//  SFSoqlBuilder.h
//  ChatterBox
//
//  Created by Sachin Desai on 5/17/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSoqlBuilder : NSObject

/** @name Query Builder */
/** A builder to help create a SOQL statement.
 *
 * @param fields a list of one or more fields, separated by commas, that are to be retrieved from the specified object
 * @return the builder
 */
+ (SFSoqlBuilder *) withFields:(NSString *) fields;

/** A builder to help create a SOQL statement.
 *
 * @param from the object to be queried
 * @return the builder
 */
- (SFSoqlBuilder *) from:(NSString *) from;

/** A builder to help create a SOQL statement.
 *
 * @param where a conditional statement
 * @return the builder
 */
- (SFSoqlBuilder *) where:(NSString *) where;

/** A builder to help create a SOQL statement.
 *
 * @param with used to filter records based on field values. 
 * @return the builder
 */
- (SFSoqlBuilder *) with:(NSString *) with;

/** A builder to help create a SOQL statement.
 *
 * @param groupBy a list of one or more fields, separated by commas, the resutls are to be grouped by 
 * @return the builder
 */
- (SFSoqlBuilder *) groupBy:(NSString *) groupBy;

/** A builder to help create a SOQL statement.
 *
 * @param having specifies one or more conditional expressions using aggregate functions to filter the query results
 * @return the builder
 */
- (SFSoqlBuilder *) having:(NSString *) having;

/** A builder to help create a SOQL statement.
 *
 * @param orderBy controls the order of the query results
 * @return the builder
 */
- (SFSoqlBuilder *) orderBy:(NSString *) orderBy;

/** A builder to help create a SOQL statement.
 *
 * @param networkId The network id to scope this returning statement with or nil if no network id
 * @return the builder
 */
- (SFSoqlBuilder *) networkId:(NSString *) networkId;

/** A builder to help create a SOQL statement.
 *
 * @param limit specifies the maximum number of rows to return
 * @return the builder
 */
- (SFSoqlBuilder *) limit:(NSInteger) limit;

/** A builder to help create a SOQL statement.
 *
 * @param offset  specifies the starting row offset into the result set returned by the query
 * @return the builder
 */
- (SFSoqlBuilder *) offset:(NSInteger) offset;

/** @name Query String Generation */
/** Builds an encoded query from the builder.
 *
 * @return the built query
 */
- (NSString *) encodeAndBuild;

/** Builds an enoded query from the builder.
 *
 * @param path the path to build the query for
 * @return the built query
 */
- (NSString *) encodeAndBuildWithPath:(NSString *) path;

/** Builds a raw (unencoded) query from the builder.
 *
 * @param path the path to build the query for
 * @return the built query
 */
- (NSString *) buildWithPath:(NSString *) path;

/** Builds a raw (unencoded) query from the builder.
 *
 * @return the built query
 */
- (NSString *) build;

@end
