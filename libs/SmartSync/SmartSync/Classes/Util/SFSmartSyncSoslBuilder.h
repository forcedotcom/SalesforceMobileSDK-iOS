/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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
#import "SFSmartSyncSoslReturningBuilder.h"

@interface SFSmartSyncSoslBuilder : NSObject

/** @name Query Builder */
/** A builder to help create a SOSL statement.
 *
 * @param searchTerm text or word phrases to search for
 * @return the builder
 */
+ (SFSmartSyncSoslBuilder *) withSearchTerm:(NSString *) searchTerm;

/** A builder to help create a SOSL statement.
 *
 * @param searchGroup scope of fields to search. Values may be: ALL FIELDS, NAME FIELDS, EMAIL FIELDS, PHONE FIELDS, SIDEBAR FIELDS
 * @return the builder
 */
- (SFSmartSyncSoslBuilder *) searchGroup:(NSString *) searchGroup;

/** A builder to help create a SOSL statement.
 *
 * @param returningSpec information to return in the search result. List of one or more objects and, within each object, list of one or more fields, with optional values to filter against. If unspecified, then the search results contain the IDs of all objects found
 * @return the builder
 */
- (SFSmartSyncSoslBuilder *) returning:(SFSmartSyncSoslReturningBuilder *) returningSpec;

/** A builder to help create a SOSL statement.
 *
 * @param divisionFilter if an organization uses divisions, filters all search results based on values for the Division field
 * @return the builder
 */
- (SFSmartSyncSoslBuilder *) divisionFilter:(NSString *) divisionFilter;

/** A builder to help create a SOSL statement.
 *
 * @param dataCategory if an organization uses Salesforce Knowledge articles or answers, filters all search results based on one or more data categories
 * @return the builder
 */
- (SFSmartSyncSoslBuilder *) dataCategory:(NSString *) dataCategory;

/** A builder to help create a SOSL statement.
 *
 * @param limit the maximum number of rows returned in the text query, up to 200. If unspecified, the default is 200, the largest number of rows that can be returned
 * @return the builder
 */
- (SFSmartSyncSoslBuilder *) limit:(NSInteger) limit;

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