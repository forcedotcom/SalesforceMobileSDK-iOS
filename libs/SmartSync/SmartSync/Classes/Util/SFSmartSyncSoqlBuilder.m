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

#import "SFSmartSyncSoqlBuilder.h"

@interface SFSmartSyncSoqlBuilder() {
    NSMutableDictionary *properties;
}
@end

@implementation SFSmartSyncSoqlBuilder

#pragma mark -
#pragma mark SOQL Builder

+ (SFSmartSyncSoqlBuilder *) withFields:(NSString *) fields {
    SFSmartSyncSoqlBuilder *builder = [[SFSmartSyncSoqlBuilder alloc] init];
    [builder fields: fields];
    [builder limit:0];
    [builder offset:0];
    return builder;
}

+ (SFSmartSyncSoqlBuilder *) withFieldsArray:(NSArray *) fields {
    return [SFSmartSyncSoqlBuilder withFields:[fields componentsJoinedByString:@", "]];
}

- (id) init {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (SFSmartSyncSoqlBuilder *) fields:(NSString *) fields {
    [properties setObject:fields forKey:@"fields"];
    return self;
}

- (SFSmartSyncSoqlBuilder *) from:(NSString *) from {
    [properties setObject:from forKey:@"from"];
     return self;
}
     
- (SFSmartSyncSoqlBuilder *) whereClause:(NSString *) whereClause {
    [properties setObject:whereClause forKey:@"whereClause"];
     return self;
}
     
- (SFSmartSyncSoqlBuilder *) with:(NSString *) with {
    [properties setObject:with forKey:@"with"];
     return self;
}         
     
- (SFSmartSyncSoqlBuilder *) groupBy:(NSString *) groupBy {
    [properties setObject:groupBy forKey:@"groupBy"];
     return self;
}
         
- (SFSmartSyncSoqlBuilder *) having:(NSString *) having {
    [properties setObject:having forKey:@"having"];
    return self;        
}
     
- (SFSmartSyncSoqlBuilder *) orderBy:(NSString *) orderBy {
    [properties setObject:orderBy forKey:@"orderBy"];
    return self;   
}

- (SFSmartSyncSoqlBuilder *) limit:(NSInteger) limit {
    [properties setObject:[NSNumber numberWithInteger:limit] forKey:@"limit"];
    return self;
}
     
- (SFSmartSyncSoqlBuilder *) offset:(NSInteger) offset {
    [properties setObject:[NSNumber numberWithInteger:offset] forKey:@"offset"];
    return self;
}

#pragma mark -
#pragma mark Encoded Queries

- (NSString *) encodeAndBuild {
    return [[self build] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *) encodeAndBuildWithPath:(NSString *) path {
    if ([path hasSuffix:@"/"]) {
        return [NSString stringWithFormat:@"%@query/?q=%@", path, [self encodeAndBuild]];
    }
    return [NSString stringWithFormat:@"%@/query/?q=%@", path, [self encodeAndBuild]];
}

#pragma mark -
#pragma mark Raw Queries

- (NSString *) buildWithPath:(NSString *) path {
    if ([path hasSuffix:@"/"]) {
        return [NSString stringWithFormat:@"%@query/?q=%@", path, [self build]];
    }
    return [NSString stringWithFormat:@"%@/query/?q=%@", path, [self build]];
}

- (NSString *) build {
    NSMutableString *query = [[NSMutableString alloc] init];
    NSString *fieldList = [properties objectForKey:@"fields"];
    if ([fieldList length] == 0) {
        // invalid field list
        return nil;
    }
    [query appendString:@"select "];
    [query appendString:fieldList];
    NSString *from = [properties objectForKey:@"from"];
    if ([from length] == 0) {
        // from field not specified
        return nil;
    }
    [query appendString:@" from "];
    [query appendString:from];
    NSString *whereClause = [properties objectForKey:@"whereClause"];
    if ([whereClause length] > 0) {
        [query appendString:@" where "];
        [query appendString:whereClause];
    }
    NSString *groupBy = [properties objectForKey:@"groupBy"];
    if ([groupBy length] > 0) {
        [query appendString:@" group by "];
        [query appendString:groupBy];
    }
    NSString *having = [properties objectForKey:@"having"];
    if ([having length] > 0) {
        [query appendString:@" having "];
        [query appendString:having];
    }
    NSString *orderBy = [properties objectForKey:@"orderBy"];
    if ([orderBy length] > 0) {
        [query appendString:@" order by "];
        [query appendString:orderBy];
    }
    NSNumber *limit = [properties objectForKey:@"limit"];
    if ([limit intValue] != 0) {
        [query appendString:@" limit "];
        [query appendFormat:@"%d", [limit intValue]];
    }
    NSNumber *offset = [properties objectForKey:@"offset"];
    if ([offset intValue] != 0) {
        [query appendString:@" offset "];
        [query appendFormat:@"%d", [offset intValue]];
    }
    return query;
}

@end