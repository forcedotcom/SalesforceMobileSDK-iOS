/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFQuerySpec.h"
#import <SalesforceCommonUtils/NSDictionary+SFAdditions.h>

NSString * const kQuerySpecSortOrderAscending = @"ascending";
NSString * const kQuerySpecSortOrderDescending = @"descending";

NSString * const kQuerySpecTypeExact = @"exact";
NSString * const kQuerySpecTypeRange = @"range";
NSString * const kQuerySpecTypeLike = @"like";

NSString * const kQuerySpecTypeSmart = @"smart";


NSString * const kQuerySpecParamQueryType = @"queryType";

NSString * const kQuerySpecParamIndexPath = @"indexPath";
NSString * const kQuerySpecParamOrder = @"order";
NSString * const kQuerySpecParamPageSize = @"pageSize";
NSUInteger const kQuerySpecDefaultPageSize = 10;

NSString * const kQuerySpecParamMatchKey = @"matchKey";
NSString * const kQuerySpecParamBeginKey = @"beginKey";
NSString * const kQuerySpecParamEndKey = @"endKey";
NSString * const kQuerySpecParamLikeKey = @"likeKey";
NSString * const kQuerySpecParamSmartSql = @"smartSql";


@implementation SFQuerySpec

@synthesize soupName = _soupName;
@synthesize queryType= _queryType;
@synthesize path = _path;
@synthesize beginKey = _beginKey;
@synthesize endKey = _endKey;
@synthesize smartSql = _smartSql;
@synthesize countSmartSql = _countSmartSql;
@synthesize order = _order;
@synthesize pageSize = _pageSize;

+ (SFQuerySpec*) newExactQuerySpec:(NSString*)soupName withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeExact;
        querySpec.path = path;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.beginKey = matchKey;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newLikeQuerySpec:(NSString*)soupName withPath:(NSString*)path withLikeKey:(NSString*)likeKey withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeLike;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.beginKey = likeKey;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newRangeQuerySpec:(NSString*)soupName withPath:(NSString*)path withBeginKey:(NSString*)beginKey withEndKey:(NSString*)endKey withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeRange;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.beginKey = beginKey;
        querySpec.endKey = endKey;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newSmartQuerySpec:(NSString*)smartSql withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeSmart;
        querySpec.smartSql = smartSql;
        querySpec.pageSize = pageSize;
    }
    querySpec.countSmartSql = [querySpec computeCountSql:smartSql];
    return querySpec;
}


- (id)initWithDictionary:(NSDictionary*)querySpec withSoupName:(NSString*) targetSoupName {
    
    NSString* rawQueryType = [querySpec nonNullObjectForKey:kQuerySpecParamQueryType];
    NSString* path = [querySpec nonNullObjectForKey:kQuerySpecParamIndexPath];
    NSString* beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamBeginKey];
    NSString* endKey = [querySpec nonNullObjectForKey:kQuerySpecParamEndKey];
    NSString* matchKey = [querySpec nonNullObjectForKey:kQuerySpecParamMatchKey];
    NSString* likeKey = [querySpec nonNullObjectForKey:kQuerySpecParamLikeKey];
    NSString* smartSql = [querySpec nonNullObjectForKey:kQuerySpecParamSmartSql];

    NSString* rawOrder =  [querySpec nonNullObjectForKey:kQuerySpecParamOrder];
    SFSoupQuerySortOrder order;
    if (rawOrder != nil && [rawOrder isEqualToString:kQuerySpecSortOrderDescending]) {
        order = kSFSoupQuerySortOrderDescending;
    } else {
        order = kSFSoupQuerySortOrderAscending;
    }
    
    NSNumber* rawPageSize = [querySpec nonNullObjectForKey:kQuerySpecParamPageSize];
    NSUInteger pageSize = ([rawPageSize integerValue] > 0 ? [rawPageSize integerValue] : kQuerySpecDefaultPageSize);
    
    
    if ([rawQueryType isEqualToString:kQuerySpecTypeRange]) {
        self = [SFQuerySpec newRangeQuerySpec:targetSoupName withPath:path withBeginKey:beginKey withEndKey:endKey withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeLike]) {
        self = [SFQuerySpec newLikeQuerySpec:targetSoupName withPath:path withLikeKey:likeKey withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeExact]) {
        self = [SFQuerySpec newExactQuerySpec:targetSoupName withPath:path withMatchKey:matchKey withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeSmart]) {
        self = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:pageSize];
    } else {
        [self log:SFLogLevelDebug format:@"Invalid queryType: '%@'", rawQueryType];
        self = nil;
    }
    
    return self;
}

- (void) dealloc
{
    SFRelease(_path);
    SFRelease(_beginKey);
    SFRelease(_endKey);
    SFRelease(_smartSql);
}

- (NSArray*) bindsForQuerySpec
{
    NSArray* result = nil;
    
    switch (self.queryType) {
        case kSFSoupQueryTypeRange:
            if ((nil != self.beginKey) && (nil != self.endKey))
                result = @[self.beginKey,self.endKey];
            else if (nil != self.beginKey)
                result = @[self.beginKey];
            else if (nil != self.endKey)
                result = @[self.endKey];
            break;
            
        case kSFSoupQueryTypeLike:
            if (nil != self.beginKey)
                result = @[self.beginKey];
            break;
            
        case kSFSoupQueryTypeExact:
            if (nil != self.beginKey)
                result = @[self.beginKey];
            break;
            
        default:
            break;
    }
    
    return result;
}


#pragma mark - Smart sql computation

- (void)computeSmartAndCountSql {
    NSString* selectClause = [self computeSelectClause];
    NSString* fromClause = [self computeFromClause];
    NSString* whereClause = [self computeWhereClause];
    NSString* orderClause = [self computeOrderClause];
    
    NSMutableString* computedSmartSql = [NSMutableString string];
    [computedSmartSql appendString:selectClause];
    [computedSmartSql appendString:fromClause];
    [computedSmartSql appendString:whereClause];
    [computedSmartSql appendString:orderClause];
     self.smartSql = computedSmartSql;
     
     NSMutableString* countSmartSql = [NSMutableString string];
     [countSmartSql appendString:@"SELECT count(*) "];
     [countSmartSql appendString:fromClause];
     [countSmartSql appendString:whereClause];
     self.countSmartSql = countSmartSql;
}

- (NSString*) computeCountSql:(NSString*) selectSql {
    NSRange fromLocation = [[selectSql lowercaseString] rangeOfString:@" from "];
    NSMutableString* computedCountSql = [NSMutableString string];
    [computedCountSql appendString:@"SELECT count(*) "];
    if (fromLocation.location == NSNotFound) {
        [computedCountSql appendString:@" FROM ("];
        [computedCountSql appendString:selectSql];
        [computedCountSql appendString:@")"];
    }
    else {
        [computedCountSql appendString:[selectSql substringFromIndex:fromLocation.location]];
    }
    return computedCountSql;
}


- (NSString*)computeSelectClause {
    return [@[@"SELECT ", [self computeFieldReference:@"_soup"], @" "] componentsJoinedByString:@""];
}

- (NSString*)computeFromClause {
    return [@[@"FROM ", [self computeSoupReference], @" "] componentsJoinedByString:@""];
}

- (NSString*)computeWhereClause {
    if (self.path == nil) {
        return @"";
    }
    
    NSString* field = [self computeFieldReference:self.path];
    
    switch(self.queryType) {
        case kSFSoupQueryTypeExact:
            return [@[@"WHERE ", field, @" = ? "] componentsJoinedByString:@""];
        case kSFSoupQueryTypeLike:
            return [@[@"WHERE ", field, @" LIKE ? "] componentsJoinedByString:@""];
        case kSFSoupQueryTypeRange:
            if (self.beginKey == nil && self.endKey == nil)
                return @"";
            else if (self.endKey == nil)
                return [@[@"WHERE ", field, @" >= ? "] componentsJoinedByString:@""];
            else if (self.beginKey == nil)
                return [@[@"WHERE ", field, @" <= ? "] componentsJoinedByString:@""];
            else
                return [@[@"WHERE ", field, @" >= ? AND ", field, @" <= ? "] componentsJoinedByString:@""];
        default: break;
    }

    return @""; // we should never get here
}

- (NSString*)computeOrderClause {
    if (self.path == nil) {
        return @"";
    }
    
    return [@[@"ORDER BY ", [self computeFieldReference:self.path], @" ", [self sqlSortOrder], @" "] componentsJoinedByString:@""];
}

- (NSString*)computeFieldReference:(NSString*) field {
    NSString* fieldRef = [@[@"{", self.soupName, @":", field, @"}"] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"computeFieldReference: %@ --> %@", field, fieldRef];
    return fieldRef;
}

- (NSString*)computeSoupReference {
    return [@[@"{", self.soupName, @"}"] componentsJoinedByString:@""];
}


- (NSString*)sqlSortOrder {
    NSString *result = @"ASC";
    if (self.order == kSFSoupQuerySortOrderDescending) {
        result = @"DESC";
    }

    return result;
}


#pragma mark - Converting to JSON

- (NSDictionary*)asDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInteger:self.pageSize],kQuerySpecParamPageSize,
                                   nil];
    if (nil != self.path) {
        result[kQuerySpecParamIndexPath] = self.path;
    }
        
    if (self.order == kSFSoupQuerySortOrderDescending) {
        result[kQuerySpecParamOrder] = kQuerySpecSortOrderDescending;
    } else {
        result[kQuerySpecParamOrder] = kQuerySpecSortOrderAscending;
    }
     
    switch (self.queryType) {
        case kSFSoupQueryTypeRange:
            if (nil != self.beginKey)
                result[kQuerySpecParamBeginKey] = self.beginKey;
            if (nil != self.endKey)
                result[kQuerySpecParamEndKey] = self.endKey;
            break;
        case kSFSoupQueryTypeLike:
            if (nil != self.beginKey)
                result[kQuerySpecParamLikeKey] = self.beginKey;
            break;
            
        case kSFSoupQueryTypeExact:
            if (nil != self.beginKey)
                result[kQuerySpecParamMatchKey] = self.beginKey;
            break;
        case kSFSoupQueryTypeSmart:
            result[kQuerySpecParamSmartSql] = self.smartSql;
            break;
        }
    
    return result;
}



- (NSString*)description {
    if (self.queryType == kSFSoupQueryTypeSmart) {
        return [NSString stringWithFormat:@"<SFSoupQuerySpec: %p> { \n  queryType:\"%d\" \n smartSql:\"%@\" \n pageSize: %lu}", self,self.queryType, self.smartSql,(unsigned long)self.pageSize];
    }
    else {
        return [NSString stringWithFormat:@"<SFSoupQuerySpec: %p> { \n  queryType:\"%d\" \n soupName:\"%@\" \n smartSql:\"%@\" \n path:\"%@\" \n beginKey:\"%@\" \n endKey:\"%@\" \n  order:%d \n pageSize: %lu}",
                self,self.queryType, self.soupName, self.smartSql, self.path,self.beginKey,self.endKey,self.order,(unsigned long)self.pageSize];
    }
}


@end
