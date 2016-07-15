/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFSoupIndex.h"

NSString * const kSoupIndexTypeString   = @"string";
NSString * const kSoupIndexTypeInteger  = @"integer";
NSString * const kSoupIndexTypeFloating = @"floating";
NSString * const kSoupIndexTypeFullText = @"full_text";
NSString * const kSoupIndexTypeJSON1    = @"json1";
NSString * const kSoupIndexPath         = @"path";
NSString * const kSoupIndexType         = @"type";
NSString * const kSoupIndexColumnName   = @"columnName";

SFIndexSpecTypeFilterBlock const kValueExtractedToColumn = ^BOOL (SFSoupIndex* idx) { return ![idx.indexType isEqualToString:kSoupIndexTypeJSON1]; };
SFIndexSpecTypeFilterBlock const kValueExtractedToFtsColumn = ^BOOL (SFSoupIndex* idx) { return [idx.indexType isEqualToString:kSoupIndexTypeFullText]; };;
SFIndexSpecTypeFilterBlock const kValueIndexedWithJSONExtract = ^BOOL (SFSoupIndex* idx) { return [idx.indexType isEqualToString:kSoupIndexTypeJSON1]; };;


@implementation SFSoupIndex

@synthesize path = _path;
@synthesize indexType = _indexType;
@synthesize columnName = _columnName;

- (id)initWithPath:(NSString*)path indexType:(NSString*)type columnName:(NSString*)columnName {
    self = [super init];
    if (nil != self) {
        self.path = path;
        self.indexType = type;
        _columnName = columnName;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary*)dict {
    self = [self initWithPath:dict[kSoupIndexPath]
                    indexType:dict[kSoupIndexType]
                   columnName:dict[kSoupIndexColumnName]
            ];
    return self;
}

- (void) dealloc {
    SFRelease(_columnName);
    SFRelease(_indexType);
    SFRelease(_path);
}

/**
 Maps the IndexSpec type to the SQL column type
 */
- (NSString*)columnType {
    NSString *result = @"TEXT";
    if ([self.indexType isEqualToString:kSoupIndexTypeString]) {
        result = @"TEXT";
    } else if ([self.indexType isEqualToString:kSoupIndexTypeFullText]) {
        result = @"TEXT";
    } else if ([self.indexType isEqualToString:kSoupIndexTypeInteger]) {
        result = @"INTEGER";
    } else if ([self.indexType isEqualToString:kSoupIndexTypeFloating]) {
        result = @"REAL";
    } else if ([self.indexType isEqualToString:kSoupIndexTypeJSON1]) {
        result = nil;
    }
    return  result;
}
    
#pragma mark - Converting to JSON
    
- (NSDictionary*)asDictionary
{
    return [self asDictionary:NO];
}

- (NSDictionary*)asDictionary:(BOOL)withColumnName
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[kSoupIndexPath] = self.path;
    result[kSoupIndexType] = self.indexType;
    if (withColumnName && self.columnName)
        result[kSoupIndexColumnName] = self.columnName;
    return result;
}

+ (NSArray*) asArrayOfDictionaries:(NSArray*) arrayOfSoupIndexes withColumnName:(BOOL)withColumnName
{
    NSMutableArray* result = [NSMutableArray array];
    for (id soupIndex in arrayOfSoupIndexes) {
        NSDictionary* dict = [soupIndex isKindOfClass:[SFSoupIndex class]]
                                               ? [(SFSoupIndex*) soupIndex asDictionary:withColumnName]
                                               : (NSDictionary*) soupIndex;
        [result addObject:dict];
    }
    return result;
}

+ (NSArray*) asArraySoupIndexes:(NSArray*) arrayOfDictionaries
{
    NSMutableArray* result = [NSMutableArray array];
    for (id dict in arrayOfDictionaries) {
        SFSoupIndex* soupIndex= [dict isKindOfClass:[SFSoupIndex class]]
                                        ? (SFSoupIndex*) dict
                                        : [[SFSoupIndex alloc] initWithDictionary:dict];
        [result addObject:soupIndex];
    }
    return result;
}


#pragma mark - Useful methods

+ (NSDictionary*) mapForSoupIndexes:(NSArray*)soupIndexes
{
    NSMutableDictionary* map = [NSMutableDictionary dictionary];
    for (SFSoupIndex* soupIndex in soupIndexes) {
        map[soupIndex.path] = soupIndex;
    }
    return map;
}

+ (BOOL) hasFts:(NSArray*)soupIndexes
{
    for (SFSoupIndex* soupIndex in soupIndexes) {
        if ([soupIndex.indexType isEqualToString:kSoupIndexTypeFullText]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL) hasJSON1:(NSArray*)soupIndexes
{
    for (SFSoupIndex* soupIndex in soupIndexes) {
        if ([soupIndex.indexType isEqualToString:kSoupIndexTypeJSON1]) {
            return YES;
        }
    }
    return NO;
}

- (NSString*) getPathType
{
    // XXX shouldn't create a new string every time
    return [NSString stringWithFormat:@"%@--%@", self.path, self.indexType];
}


@end
