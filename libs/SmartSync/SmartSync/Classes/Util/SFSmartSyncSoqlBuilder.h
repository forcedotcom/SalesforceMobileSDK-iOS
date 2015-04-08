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

@interface SFSmartSyncSoqlBuilder : NSObject

/** @name Query Builder */
/** A builder to help create a SOQL statement.
 *
 * @param fields a list of one or more fields, separated by commas, that are to be retrieved from the specified object
 * @return the builder
 */
+ (SFSmartSyncSoqlBuilder *) withFields:(NSString *) fields;

/** @name Query Builder */
/** A builder to help create a SOQL statement.
 *
 * @param fields an array of one or more fields, that are to be retrieved from the specified object
 * @return the builder
 */
+ (SFSmartSyncSoqlBuilder *) withFieldsArray:(NSArray *) fields;

/** A builder to help create a SOQL statement.
 *
 * @param from the object to be queried
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) from:(NSString *) from;

/** A builder to help create a SOQL statement.
 *
 * @param whereClause a conditional statement
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) whereClause:(NSString *) whereClause;

/** A builder to help create a SOQL statement.
 *
 * @param with used to filter records based on field values. 
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) with:(NSString *) with;

/** A builder to help create a SOQL statement.
 *
 * @param groupBy a list of one or more fields, separated by commas, the resutls are to be grouped by 
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) groupBy:(NSString *) groupBy;

/** A builder to help create a SOQL statement.
 *
 * @param having specifies one or more conditional expressions using aggregate functions to filter the query results
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) having:(NSString *) having;

/** A builder to help create a SOQL statement.
 *
 * @param orderBy controls the order of the query results
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) orderBy:(NSString *) orderBy;

/** A builder to help create a SOQL statement.
 *
 * @param limit specifies the maximum number of rows to return
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) limit:(NSInteger) limit;

/** A builder to help create a SOQL statement.
 *
 * @param offset  specifies the starting row offset into the result set returned by the query
 * @return the builder
 */
- (SFSmartSyncSoqlBuilder *) offset:(NSInteger) offset;

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