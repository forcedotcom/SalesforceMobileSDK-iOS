/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova
 
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

extern NSString * const kQuerySpecParamIndexPath;
extern NSString * const kQuerySpecParamOrder;
extern NSString * const kQuerySpecParamPageSize;

extern NSString * const kQuerySpecParamMatchKey;
extern NSString * const kQuerySpecParamBeginKey;
extern NSString * const kQuerySpecParamEndKey;
extern NSString * const kQuerySpecParamLikeKey;


typedef enum {
    kSFSoupQueryTypeExact = 2,
    kSFSoupQueryTypeRange = 4,
    kSFSoupQueryTypeLike = 8
} SFSoupQueryType;

typedef enum {
    kSFSoupQuerySortOrderAscending,
    kSFSoupQuerySortOrderDescending
} SFSoupQuerySortOrder;

/**
 * Object containing the query specification for queries against a soup.
 */
@interface SFSoupQuerySpec : NSObject {
    SFSoupQueryType _queryType;
    NSString *_path;
    NSString *_beginKey;
    NSString *_endKey;
    SFSoupQuerySortOrder _order;
    NSUInteger _pageSize;
    
}

/**
 * The type of query to run (exact, range, like).
 */
@property (nonatomic, assign) SFSoupQueryType queryType;

/**
 The indexPath to use for the query.  Compound paths must be dot-delimited ie parent.child.grandchild.field .
 */
@property (nonatomic, strong) NSString *path;

/**
 beginKey is used for range, exact, and like queries.
 */
@property (nonatomic, strong) NSString *beginKey;

/**
 endKey is used for range queries.
 */
@property (nonatomic, strong) NSString *endKey;

/**
 * A sort order for the query (ascending, descending).
 */
@property (nonatomic, assign) SFSoupQuerySortOrder order;

/**
 * The number of entries per page to return.
 */
@property (nonatomic, assign) NSUInteger pageSize;


/**
 ASC or DESC
 */
@property (nonatomic, readonly) NSString *sqlSortOrder;

/**
 * Initializes the object with the given query spec.
 * @param querySpec the name/value pairs defining the query spec.
 * @return A new instance of the object.
 */
- (id)initWithDictionary:(NSDictionary*)querySpec;

/**
 * The NSDictionary representation of the query spec.
 */
- (NSDictionary*)asDictionary;

@end
