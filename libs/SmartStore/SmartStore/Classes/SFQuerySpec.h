/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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


//kQuerySpecSortOrderFoo constants are used when translating to SFSoupQuerySortOrder from JS (dictionary) values
extern NSString * const kQuerySpecSortOrderAscending;
extern NSString * const kQuerySpecSortOrderDescending;

extern NSString * const kQuerySpecParamQueryType;

//kQuerySpecTypeFoo constants are used when translating to SFSoupQueryType from JS (dictionary) values
extern NSString * const kQuerySpecTypeExact;
extern NSString * const kQuerySpecTypeRange;
extern NSString * const kQuerySpecTypeLike;
extern NSString * const kQuerySpecTypeSmart;
extern NSString * const kQuerySpecTypeMatch;

extern NSString * const kQuerySpecParamSelectPaths;
extern NSString * const kQuerySpecParamIndexPath;
extern NSString * const kQuerySpecParamOrder;
extern NSString * const kQuerySpecParamPageSize;
extern NSUInteger const kQuerySpecDefaultPageSize;

extern NSString * const kQuerySpecParamMatchKey;
extern NSString * const kQuerySpecParamBeginKey;
extern NSString * const kQuerySpecParamEndKey;
extern NSString * const kQuerySpecParamLikeKey;


typedef NS_ENUM(NSInteger, SFSoupQueryType) {
    kSFSoupQueryTypeExact = 2,
    kSFSoupQueryTypeRange = 4,
    kSFSoupQueryTypeLike = 8,
    kSFSoupQueryTypeSmart = 16,
    kSFSoupQueryTypeMatch = 32
};

typedef NS_ENUM(NSUInteger, SFSoupQuerySortOrder) {
    kSFSoupQuerySortOrderAscending,
    kSFSoupQuerySortOrderDescending
};

/**
 * Object containing the query specification for queries against a soup.
 */
@interface SFQuerySpec : NSObject

/**
 * The type of query to run (exact, range, like).
 */
@property (nonatomic, assign) SFSoupQueryType queryType;

/**
 smartSql passed in for smart queries, computed for all others.
 */
@property (nonatomic, strong) NSString *smartSql;

/**
 countSmartSql: query to compute count of results for smartSql
 */
@property (nonatomic, strong) NSString *countSmartSql;

/**
 idsSmartSql: query returning only ids
 */
@property (nonatomic, strong) NSString *idsSmartSql;

/**
 * The number of entries per page to return.
 */
@property (nonatomic, assign) NSUInteger pageSize;

/**
 soupName is used for range, exact, and like queries.
 */
@property (nonatomic, strong) NSString *soupName;

/**
 The paths to return in an array. nil means return the entire soup element.
 */
@property (nonatomic, strong) NSArray *selectPaths;

/**
 The indexPath to use for the query. Compound paths must be dot-delimited ie parent.child.grandchild.field .
 */
@property (nonatomic, strong) NSString *path;

/**
 beginKey is used for range queries.
 */
@property (nonatomic, strong) NSString *beginKey;

/**
 endKey is used for range queries.
 */
@property (nonatomic, strong) NSString *endKey;

/**
 likeKey is used for like queries.
 */
@property (nonatomic, strong) NSString *likeKey;

/**
 matchKey is used for exact and match queries.
 */
@property (nonatomic, strong) NSString *matchKey;

/**
 The indexPath to use for sorting. Compound paths must be dot-delimited ie parent.child.grandchild.field .
 */
@property (nonatomic, strong) NSString *orderPath;

/**
 * A sort order for the query (ascending, descending).
 */
@property (nonatomic, assign) SFSoupQuerySortOrder order;

/**
 ASC or DESC
 */
@property (strong, nonatomic, readonly) NSString *sqlSortOrder;


/**
 * Factory method to build an exact query spec
 * Note: caller is responsible for releaseing the query spec
 * @param soupName The target soup name.
 * @param selectPaths The paths to return - if nil the entire soup element is returned.
 * @param path The path to filter on.
 * @param matchKey The exact value to match.
 * @param orderPath The path to sort by.
 * @param order The sort order.
 * @param pageSize The page size.
 * @return A query spec object.
 */
+ (SFQuerySpec*) newExactQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec*) newExactQuerySpec:(NSString*)soupName withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;

/**
 * Factory method to build an like query spec
 * Note: caller is responsible for releaseing the query spec
 * @param soupName The target soup name.
 * @param selectPaths The paths to return - if nil the entire soup element is returned.
 * @param path The path to filter on.
 * @param likeKey The value to match on.
 * @param orderPath The path to sort by.
 * @param order The sort order.
 * @param pageSize The page size.
 * @return A query spec object.
 */
+ (SFQuerySpec*) newLikeQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withLikeKey:(NSString*)likeKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec*) newLikeQuerySpec:(NSString*)soupName withPath:(NSString*)path withLikeKey:(NSString*)likeKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;

/**
 * Factory method to build an range query spec
 * Note: caller is responsible for releaseing the query spec
 * @param soupName The target soup name.
 * @param selectPaths The paths to return - if nil the entire soup element is returned.
 * @param path The path to filter on.
 * @param beginKey The start of the range.
 * @param endKey The end of the range.
 * @param orderPath The path to sort by.
 * @param order The sort order.
 * @param pageSize The page size.
 * @return A query spec object.
 */
+ (SFQuerySpec*) newRangeQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withBeginKey:(NSString*)beginKey withEndKey:(NSString*)endKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec*) newRangeQuerySpec:(NSString*)soupName withPath:(NSString*)path withBeginKey:(NSString*)beginKey withEndKey:(NSString*)endKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;

/**
 * Factory method to build a query spec to return all data from a soup.
 * @param soupName The target soup name.
 * @param selectPaths The paths to return - if nil the entire soup element is returned.
 * @param orderPath The path to sort by.
 * @param order The sort order.
 * @param pageSize The page size.
 */
+ (SFQuerySpec*) newAllQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec*) newAllQuerySpec:(NSString*)soupName withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;

/**
 * Factory method to build a match query spec (full-text search)
 * Note: caller is responsible for releaseing the query spec
 * @param soupName The target soup name.
 * @param selectPaths The paths to return - if nil the entire soup element is returned.
 * @param path The path to filter on - can be nil to match against any full-text indexed paths.
 * @param matchKey The match query string.
 * @param orderPath The path to sort by.
 * @param order The sort order.
 * @param pageSize The page size.
 * @return A query spec object.
 */
+ (SFQuerySpec*) newMatchQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec*) newMatchQuerySpec:(NSString*)soupName withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;

/**
 * Factory method to build a smart query spec
 * Note: caller is responsible for releaseing the query spec
 * @param smartSql The smart sql query.
 * @param pageSize The page size.
 * @return A query spec object.
 */
+ (SFQuerySpec*) newSmartQuerySpec:(NSString*)smartSql withPageSize:(NSUInteger)pageSize;

/**
 * Initializes the object with the given query spec.
 * @param querySpec the name/value pairs defining the query spec.
 * @param targetSoupName the soup name targeted (not nil for exact/like/range queries)
 * @return A new instance of the object.
 */
- (id)initWithDictionary:(NSDictionary*)querySpec withSoupName:(NSString*) targetSoupName;

/**
 * The NSDictionary representation of the query spec.
 */
- (NSDictionary*)asDictionary;

/**
 * Return bind arguments for query.
 * @return bind arguments.
 */
- (NSArray*) bindsForQuerySpec;

@end
