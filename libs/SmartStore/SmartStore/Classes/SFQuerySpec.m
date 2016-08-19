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
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFSmartStore.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>

NSString * const kQuerySpecSortOrderAscending = @"ascending";
NSString * const kQuerySpecSortOrderDescending = @"descending";

NSString * const kQuerySpecTypeExact = @"exact";
NSString * const kQuerySpecTypeRange = @"range";
NSString * const kQuerySpecTypeLike = @"like";
NSString * const kQuerySpecTypeSmart = @"smart";
NSString * const kQuerySpecTypeMatch = @"match";

NSString * const kQuerySpecParamQueryType = @"queryType";
NSString * const kQuerySpecParamSelectPaths = @"selectPaths";
NSString * const kQuerySpecParamIndexPath = @"indexPath";
NSString * const kQuerySpecParamOrderPath = @"orderPath";
NSString * const kQuerySpecParamOrder = @"order";
NSString * const kQuerySpecParamPageSize = @"pageSize";
NSUInteger const kQuerySpecDefaultPageSize = 10;
NSString * const kQuerySpecParamMatchKey = @"matchKey";
NSString * const kQuerySpecParamBeginKey = @"beginKey";
NSString * const kQuerySpecParamEndKey = @"endKey";
NSString * const kQuerySpecParamLikeKey = @"likeKey";
NSString * const kQuerySpecParamSmartSql = @"smartSql";


@implementation SFQuerySpec

+ (SFQuerySpec*) newExactQuerySpec:(NSString*)soupName withPath:(NSString*)path withMatchKey:(NSString*)matchKey  withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [SFQuerySpec newExactQuerySpec:soupName withSelectPaths:nil withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newExactQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withMatchKey:(NSString*)matchKey  withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeExact;
        querySpec.path = path;
        querySpec.selectPaths = selectPaths;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.matchKey = matchKey;
        querySpec.orderPath = orderPath;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountAndIdsSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newLikeQuerySpec:(NSString*)soupName withPath:(NSString*)path withLikeKey:(NSString*)likeKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [SFQuerySpec newLikeQuerySpec:soupName withSelectPaths:nil withPath:path withLikeKey:likeKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newLikeQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withLikeKey:(NSString*)likeKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeLike;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.selectPaths = selectPaths;
        querySpec.likeKey = likeKey;
        querySpec.orderPath = orderPath;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountAndIdsSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newRangeQuerySpec:(NSString*)soupName withPath:(NSString*)path withBeginKey:(NSString*)beginKey withEndKey:(NSString*)endKey  withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [SFQuerySpec newRangeQuerySpec:soupName withSelectPaths:nil withPath:path withBeginKey:beginKey withEndKey:endKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newRangeQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withBeginKey:(NSString*)beginKey withEndKey:(NSString*)endKey  withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeRange;
        querySpec.soupName = soupName;
        querySpec.path = path;
        querySpec.selectPaths = selectPaths;
        querySpec.beginKey = beginKey;
        querySpec.endKey = endKey;
        querySpec.orderPath = orderPath;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountAndIdsSql];
    }
    return querySpec;
}

+ (SFQuerySpec*) newAllQuerySpec:(NSString *)soupName withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [SFQuerySpec newAllQuerySpec:soupName withSelectPaths:nil withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newAllQuerySpec:(NSString *)soupName withSelectPaths:(NSArray*)selectPaths withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [self newRangeQuerySpec:soupName withSelectPaths:selectPaths withPath:nil withBeginKey:nil withEndKey:nil withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newMatchQuerySpec:(NSString*)soupName withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    return [SFQuerySpec newMatchQuerySpec:soupName withSelectPaths:nil withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
}

+ (SFQuerySpec*) newMatchQuerySpec:(NSString*)soupName withSelectPaths:(NSArray*)selectPaths withPath:(NSString*)path withMatchKey:(NSString*)matchKey withOrderPath:(NSString*)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize {
    SFQuerySpec* querySpec = [[super alloc] init];
    if (nil != querySpec) {
        querySpec.queryType = kSFSoupQueryTypeMatch;
        querySpec.path = path;
        querySpec.soupName = soupName;
        querySpec.selectPaths = selectPaths;
        querySpec.path = path;
        querySpec.matchKey = matchKey;
        querySpec.orderPath = orderPath;
        querySpec.order = order;
        querySpec.pageSize = pageSize;
        [querySpec computeSmartAndCountAndIdsSql];
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
    querySpec.idsSmartSql = [querySpec computeIdsSql:smartSql];
    return querySpec;
}

- (id)initWithDictionary:(NSDictionary*)querySpec withSoupName:(NSString*) targetSoupName {
    
    NSString* rawQueryType = [querySpec nonNullObjectForKey:kQuerySpecParamQueryType];
    NSString* path = [querySpec nonNullObjectForKey:kQuerySpecParamIndexPath];
    NSArray* selectPaths = [querySpec nonNullObjectForKey:kQuerySpecParamSelectPaths];
    NSString* beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamBeginKey];
    NSString* endKey = [querySpec nonNullObjectForKey:kQuerySpecParamEndKey];
    NSString* matchKey = [querySpec nonNullObjectForKey:kQuerySpecParamMatchKey];
    NSString* likeKey = [querySpec nonNullObjectForKey:kQuerySpecParamLikeKey];
    NSString* smartSql = [querySpec nonNullObjectForKey:kQuerySpecParamSmartSql];
    NSString* orderPath = [querySpec nonNullObjectForKey:kQuerySpecParamOrderPath];

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
        self = [SFQuerySpec newRangeQuerySpec:targetSoupName withSelectPaths:selectPaths withPath:path withBeginKey:beginKey withEndKey:endKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeLike]) {
        self = [SFQuerySpec newLikeQuerySpec:targetSoupName withSelectPaths:selectPaths withPath:path withLikeKey:likeKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeExact]) {
        self = [SFQuerySpec newExactQuerySpec:targetSoupName withSelectPaths:selectPaths withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeMatch]) {
        self = [SFQuerySpec newMatchQuerySpec:targetSoupName withSelectPaths:selectPaths withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:order withPageSize:pageSize];
    } else if ([rawQueryType isEqualToString:kQuerySpecTypeSmart]) {
        self = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:pageSize];
    } else {
        [self log:SFLogLevelDebug format:@"Invalid queryType: '%@'", rawQueryType];
        self = nil;
    }
    
    return self;
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
            if (nil != self.likeKey)
                result = @[self.likeKey];
            break;
            
        case kSFSoupQueryTypeExact:
            if (nil != self.matchKey)
                result = @[self.matchKey];
            break;

        case kSFSoupQueryTypeMatch:
            // baking matchKey into query
            break;
            
        case kSFSoupQueryTypeSmart:
            break;
    }
    
    return result;
}


#pragma mark - Smart sql computation

- (void)computeSmartAndCountAndIdsSql {
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

    NSMutableString* idsSmartSql = [NSMutableString string];
    [idsSmartSql appendString:[NSString stringWithFormat:@"SELECT %@ ", ID_COL]];
    [idsSmartSql appendString:fromClause];
    [idsSmartSql appendString:whereClause];
    [idsSmartSql appendString:orderClause];
    self.idsSmartSql = idsSmartSql;
}

- (NSString*) computeCountSql:(NSString*) smartSql {
    return [NSString stringWithFormat:@"SELECT count(*) FROM (%@)", smartSql];
}

- (NSString*) computeIdsSql:(NSString*) smartSql {
    return [NSString stringWithFormat:@"SELECT %@ FROM (%@)", ID_COL, smartSql];
    // NB: that query won't successfully run if smartSql doesn't select the id col
}

- (NSString*)computeSelectClause {
    NSMutableArray* fieldReferences = [NSMutableArray new];
    for (NSString* selectPath in (self.selectPaths ? self.selectPaths : @[@"_soup"])) {
        [fieldReferences addObject:[self computeFieldReference:selectPath]];
    }

    return [@[@"SELECT ",
              [fieldReferences componentsJoinedByString:@", "],
              @" "]
            componentsJoinedByString:@""];
}

- (NSString*)computeFromClause {
    return [@[@"FROM ", [self computeSoupReference], @" "] componentsJoinedByString:@""];
}

- (NSString*)computeWhereClause {
    if (self.path == nil && self.queryType != kSFSoupQueryTypeMatch /* null path allowed for fts match query */) {
        return @"";
    }
    
    NSString* field;
    
    if (self.path) {
        field = [self computeFieldReference:self.path];
    }
    
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

        case kSFSoupQueryTypeMatch:
            return [@[@"WHERE ",
                      [self computeFieldReference:SOUP_ENTRY_ID],
                      @" IN ",
                      @"(SELECT ",
                      ROWID_COL,
                      @" FROM ",
                      [self computeSoupFtsReference],
                      @" WHERE ",
                      [self computeSoupFtsReference],
                      @" MATCH '",
                      [SFQuerySpec qualifyMatchKey:self.matchKey field:field], // match clause -- statement arg binding doesn't seem to work so inlining matchKey
                      @"') "
                      ]
                    componentsJoinedByString:@""];

        default: break;
    }

    return @""; // we should never get here
}

/**
 * fts5 doesn't allow WHERE column MATCH 'value' - only allows WHERE table MATCH 'column:value'
 * This method changes the matchKey to add field: in the right places
 */
+ (NSString*) qualifyMatchKey:(NSString*)matchKey field:(NSString*)field {
    if (!field) {
        return matchKey;
    }
    else {
        NSMutableString* qualifiedMatchKey = [NSMutableString new];
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[^\\(\\) ]+" options:NSRegularExpressionCaseInsensitive error:nil];
        
        NSArray *matches = [regex matchesInString:matchKey
                                          options:0
                                            range:NSMakeRange(0, [matchKey length])];
        
        NSUInteger locationAlreadyCopied = 0;
        for (NSTextCheckingResult *match in matches) {
            NSRange matchRange = [match range];
            NSString* part = [matchKey substringWithRange:matchRange];
            NSString* lowerCasePart = [part lowercaseString];
            
            NSRange beforeMatchRange = NSMakeRange(locationAlreadyCopied, matchRange.location - locationAlreadyCopied);
            [qualifiedMatchKey appendString:[matchKey substringWithRange:beforeMatchRange]];
            locationAlreadyCopied = matchRange.location + matchRange.length;
            
            if ([lowerCasePart isEqualToString:@"and"] || [lowerCasePart isEqualToString:@"or"] || [lowerCasePart isEqualToString:@"not"] || [lowerCasePart hasPrefix:@"{"]) {
                [qualifiedMatchKey appendString:part];
            }
            else {
                [qualifiedMatchKey appendString:[NSString stringWithFormat:@"%@:%@", field, part]];
            }
        }
        // tail
        NSRange tailRange = NSMakeRange(locationAlreadyCopied, [matchKey length] - locationAlreadyCopied);
        [qualifiedMatchKey appendString:[matchKey substringWithRange:tailRange]];
        
        return qualifiedMatchKey;
    }
}

- (NSString*)computeOrderClause {
    if (self.orderPath == nil) {
        return @"";
    }
    
    return [@[@"ORDER BY ", [self computeFieldReference:self.orderPath], @" ", [self sqlSortOrder], @" "] componentsJoinedByString:@""];
}

- (NSString*)computeFieldReference:(NSString*) field {
    NSString* fieldRef = [@[@"{", self.soupName, @":", field, @"}"] componentsJoinedByString:@""];
    [self log:SFLogLevelVerbose format:@"computeFieldReference: %@ --> %@", field, fieldRef];
    return fieldRef;
}

- (NSString*)computeSoupReference {
    return [@[@"{", self.soupName, @"}"] componentsJoinedByString:@""];
}

- (NSString*)computeSoupFtsReference {
    return [@[@"{", self.soupName, @"}_fts"] componentsJoinedByString:@""];
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

    if (nil != self.orderPath) {
        result[kQuerySpecParamOrderPath] = self.orderPath;
    }
    
    if (self.order == kSFSoupQuerySortOrderDescending) {
        result[kQuerySpecParamOrder] = kQuerySpecSortOrderDescending;
    } else {
        result[kQuerySpecParamOrder] = kQuerySpecSortOrderAscending;
    }
     
    switch (self.queryType) {
        case kSFSoupQueryTypeRange:
            result[kQuerySpecParamQueryType] = kQuerySpecTypeRange;
            if (nil != self.beginKey)
                result[kQuerySpecParamBeginKey] = self.beginKey;
            if (nil != self.endKey)
                result[kQuerySpecParamEndKey] = self.endKey;
            break;

        case kSFSoupQueryTypeLike:
            result[kQuerySpecParamQueryType] = kQuerySpecTypeLike;
            result[kQuerySpecParamLikeKey] = self.likeKey;
            break;
            
        case kSFSoupQueryTypeExact:
            result[kQuerySpecParamQueryType] = kQuerySpecTypeExact;
            result[kQuerySpecParamMatchKey] = self.matchKey;
            break;

        case kSFSoupQueryTypeSmart:
            result[kQuerySpecParamQueryType] = kQuerySpecTypeSmart;
            result[kQuerySpecParamSmartSql] = self.smartSql;
            break;

        case kSFSoupQueryTypeMatch:
            result[kQuerySpecParamQueryType] = kQuerySpecTypeMatch;
            result[kQuerySpecParamMatchKey] = self.matchKey;
            break;
        }
    
    return result;
}



- (NSString*)description {
    return [SFJsonUtils JSONRepresentation:[self asDictionary]];
}


@end
