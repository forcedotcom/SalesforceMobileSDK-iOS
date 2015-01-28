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

#import "SFSmartSyncSoslBuilder.h"

@interface SFSmartSyncSoslBuilder() {
    NSMutableDictionary *properties;
    NSMutableArray *returning;
}

- (SFSmartSyncSoslBuilder *) searchTerm:(NSString *) searchTerm;

@end

@implementation SFSmartSyncSoslBuilder

#pragma mark -
#pragma mark SOSL Builder

+ (SFSmartSyncSoslBuilder *) withSearchTerm:(NSString *) searchTerm {
    SFSmartSyncSoslBuilder *builder = [[SFSmartSyncSoslBuilder alloc] init];
    [builder searchTerm: searchTerm];
    [builder limit:0];
    return builder;
}

- (id) init {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] init];
        returning = [[NSMutableArray alloc] init];
    }
    return self;
}

- (SFSmartSyncSoslBuilder *) searchTerm:(NSString *) searchTerm {

    // Escapes special characters.
    NSString *searchValue = searchTerm;
    if (nil != searchValue) {
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"~" withString:@"\\~"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"-" withString:@"\\-"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"&" withString:@"\\&"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@":" withString:@"\\:"];
        searchValue = [searchValue stringByReplacingOccurrencesOfString:@"!" withString:@"\\!"];
    } else {
        searchValue = @"";
    }
    [properties setObject:searchValue forKey:@"searchTerm"];
    return self;
}

- (SFSmartSyncSoslBuilder *) searchGroup:(NSString *) searchGroup {
    [properties setObject:searchGroup forKey:@"searchGroup"];
    return self;
}

- (SFSmartSyncSoslBuilder *) returning:(SFSmartSyncSoslReturningBuilder *) returningSpec {
    [returning addObject:returningSpec];
    return self;
}

- (SFSmartSyncSoslBuilder *) divisionFilter:(NSString *) divisionFilter {
    [properties setObject:divisionFilter forKey:@"divisionFilter"];
    return self;
}

- (SFSmartSyncSoslBuilder *) dataCategory:(NSString *) dataCategory {
    [properties setObject:dataCategory forKey:@"dataCategory"];
    return self;
}

- (SFSmartSyncSoslBuilder *) limit:(NSInteger) limit {
    [properties setObject:[NSNumber numberWithInteger:limit] forKey:@"limit"];
    return self;
}

#pragma mark -
#pragma mark Encoded Queries

- (NSString *) encodeAndBuild {
    return [[self build] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *) encodeAndBuildWithPath:(NSString *) path {
    NSString *result = nil;
    if ([path hasSuffix:@"/"]) {
        result = [NSString stringWithFormat:@"%@search/?q=%@", path, [self encodeAndBuild]];
    } else {
        result = [NSString stringWithFormat:@"%@/search/?q=%@", path, [self encodeAndBuild]];
    }
    return result;
}

#pragma mark -
#pragma mark Raw Queries

- (NSString *) buildWithPath:(NSString *) path {
    if ([path hasSuffix:@"/"]) {
        return [NSString stringWithFormat:@"%@search/?q=%@", path, [self build]];
    }
    return [NSString stringWithFormat:@"%@/search/?q=%@", path, [self build]];
}

- (NSString *) build {
    NSMutableString *query = [[NSMutableString alloc] init];
    NSString *searchTerm = [properties objectForKey:@"searchTerm"];
    if ([searchTerm length] == 0) {
        // invalid search term
        return nil;
    }
    [query appendFormat:@"find {%@}", searchTerm];
    NSString *searchGroup = [properties objectForKey:@"searchGroup"];
    if ([searchGroup length] > 0) {
        [query appendString:@" in "];
        [query appendString:searchGroup];
    }
    if ([returning count] > 0) {
        [query appendString:@" returning "];
        [query appendString:[[returning objectAtIndex:0] build]];
        for (int i = 1; i < [returning count]; i++) {
            [query appendString:@", "];
            [query appendString:[[returning objectAtIndex:i] build]];
        }
    }
    NSString *divisionFilter = [properties objectForKey:@"divisionFilter"];
    if ([divisionFilter length] > 0) {
        [query appendString:@" with "];
        [query appendString:divisionFilter];
    }
    NSString *dataCategory = [properties objectForKey:@"dataCategory"];
    if ([dataCategory length] > 0) {
        [query appendString:@" with data category "];
        [query appendString:dataCategory];
    }
    NSNumber *limit = [properties objectForKey:@"limit"];
    if ([limit intValue] != 0) {
        [query appendString:@" limit "];
        [query appendFormat:@"%d", [limit intValue]];
    }
    return query;
}

@end