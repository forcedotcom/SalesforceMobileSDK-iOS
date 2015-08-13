//
//  SFSoslBuilder.h
//  ChatterBox
//
//  Created by Sachin Desai on 5/17/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFSoslReturningBuilder.h"

@interface SFSoslBuilder : NSObject

/** @name Query Builder */
/** A builder to help create a SOSL statement.
 *
 * @param searchTerm text or word phrases to search for
 * @return the builder
 */
+ (SFSoslBuilder *) withSearchTerm:(NSString *) searchTerm;

/** A builder to help create a SOSL statement.
 *
 * @param searchGroup scope of fields to search. Values may be: ALL FIELDS, NAME FIELDS, EMAIL FIELDS, PHONE FIELDS, SIDEBAR FIELDS
 * @return the builder
 */
- (SFSoslBuilder *) searchGroup:(NSString *) searchGroup;

/** A builder to help create a SOSL statement.
 *
 * @param returningSpec information to return in the search result. List of one or more objects and, within each object, list of one or more fields, with optional values to filter against. If unspecified, then the search results contain the IDs of all objects found
 * @return the builder
 */
- (SFSoslBuilder *) returning:(SFSoslReturningBuilder *) returningSpec;

/** A builder to help create a SOSL statement.
 *
 * @param divisionFilter if an organization uses divisions, filters all search results based on values for the Division field
 * @return the builder
 */
- (SFSoslBuilder *) divisionFilter:(NSString *) divisionFilter;

/** A builder to help create a SOSL statement.
 *
 * @param dataCategory if an organization uses Salesforce Knowledge articles or answers, filters all search results based on one or more data categories
 * @return the builder
 */
- (SFSoslBuilder *) dataCategory:(NSString *) dataCategory;

/** A builder to help create a SOSL statement.
 *
 * @param networkCategory if an organization uses communities (aka networks), filters all search results based on the network category
 * @return the builder
 */
- (SFSoslBuilder *) networkCategory:(NSString *) networkCategory;

/** A builder to help create a SOSL statement.
 *
 * @param limit the maximum number of rows returned in the text query, up to 200. If unspecified, the default is 200, the largest number of rows that can be returned
 * @return the builder
 */
- (SFSoslBuilder *) limit:(NSInteger) limit;

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