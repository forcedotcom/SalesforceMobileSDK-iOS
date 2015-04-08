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

#import "SFSmartSyncSoslReturningBuilder.h"

@interface SFSmartSyncSoslReturningBuilder() {
    NSMutableDictionary *properties;
}

- (SFSmartSyncSoslReturningBuilder *) objectName:(NSString *) name;

@end

@implementation SFSmartSyncSoslReturningBuilder

#pragma mark -
#pragma mark SOSL Returning Builder

+ (SFSmartSyncSoslReturningBuilder *) withObjectName:(NSString *) name {
    SFSmartSyncSoslReturningBuilder *builder = [[SFSmartSyncSoslReturningBuilder alloc] init];
    [builder objectName: name];
    [builder limit:0];
    return builder;
}

- (id) init {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString*)objectName {
    return properties[@"objectName"];
}

- (SFSmartSyncSoslReturningBuilder *) objectName:(NSString *) name {
    [properties setObject:name forKey:@"objectName"];
    return self;
}

- (SFSmartSyncSoslReturningBuilder *) fields:(NSString *) fields {
    [properties setObject:fields forKey:@"fields"];
    return self;
}

- (SFSmartSyncSoslReturningBuilder *) whereClause:(NSString *) whereClause {
    [properties setObject:whereClause forKey:@"whereClause"];
    return self;
}

- (SFSmartSyncSoslReturningBuilder *) withNetwork:(NSString *) networkId {
    [properties setObject:networkId forKey:@"withNetwork"];
    return self;
}

- (SFSmartSyncSoslReturningBuilder *) orderBy:(NSString *) orderBy {
    [properties setObject:orderBy forKey:@"orderBy"];
    return self;
}

- (SFSmartSyncSoslReturningBuilder *) limit:(NSInteger) limit {
    [properties setObject:[NSNumber numberWithInteger:limit] forKey:@"limit"];
    return self;
}

#pragma mark -
#pragma mark SOSL Returning Query

- (NSString *) build {
    NSMutableString *query = [[NSMutableString alloc] init];
    NSString *objectName = [properties objectForKey:@"objectName"];
    if ([objectName length] == 0) {
        // missing object name
        return nil;
    }
    [query appendString:@" "];
    [query appendString:objectName];
    NSString *fields = [properties objectForKey:@"fields"];
    if ([fields length] > 0) {
        [query appendFormat:@"(%@", fields];
        NSString *whereClause = [properties objectForKey:@"whereClause"];
        if ([whereClause length] > 0) {
            [query appendString:@" where "];
            [query appendString: whereClause];
        }
        NSString *orderBy = [properties objectForKey:@"orderBy"];
        if ([orderBy length] > 0) {
            [query appendString:@" order by "];
            [query appendString: orderBy];
        }
        NSString *withNetwork = [properties objectForKey:@"withNetwork"];
        if ([withNetwork length] > 0) {
            [query appendString:@" with network = "];
            [query appendString: withNetwork];
        }
        NSNumber *limit = [properties objectForKey:@"limit"];
        if ([limit intValue] != 0) {
            [query appendString:@" limit "];
            [query appendFormat:@"%d", [limit intValue]];
        }
        [query appendString:@")"];
    }
    return query;
}

@end