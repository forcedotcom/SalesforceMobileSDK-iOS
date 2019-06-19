/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSqlCache.h"

@interface SFSmartSqlCache ()

@property (nonatomic, strong) NSCache* cache;
@property (nonatomic, strong) NSMutableSet* keys;

@end

@implementation SFSmartSqlCache

- (id)initWithCountLimit:(NSUInteger)countLimit {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = countLimit;
        _cache.delegate = self;
        _keys = [NSMutableSet new];
    }
    return self;
}

- (void) setSql:(NSString*)sql forSmartSql:(NSString*)smartSql {
    [self.cache setObject:sql forKey:smartSql];
    [self.keys addObject:smartSql];
}

- (NSString*) sqlForSmartSql:(NSString*)smartSql {
    return [self.cache objectForKey:smartSql];
}

- (void) removeEntriesForSoup:(NSString*)soupName {
    NSString* soupRef = [@[@"{", soupName, @"}"] componentsJoinedByString:@""];
    NSMutableArray* keysToRemove = [NSMutableArray array];
    for (NSString* smartSql in [self.keys allObjects]) {
        if ([smartSql rangeOfString:soupRef].location != NSNotFound) {
            [keysToRemove addObject:smartSql];
        }
    }
    for (NSString* keyToRemove in keysToRemove) {
        [self.cache removeObjectForKey:keyToRemove];
        [self.keys removeObject:keyToRemove];
    }
}

# pragma Mark - NSCacheDelegate methods
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    [self.keys removeObject:obj];
}

@end
