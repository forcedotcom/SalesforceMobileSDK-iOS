/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFStoreCursor.h"

#import "SFSmartStore+Internal.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>

@interface SFStoreCursor ()

@property (nonatomic, readwrite, strong) SFQuerySpec *querySpec;
@property (nonatomic, readwrite, strong) NSString *cursorId;
@property (nonatomic, readwrite, strong) NSNumber *pageSize;
@property (nonatomic, readwrite, strong) NSNumber *totalPages;
@property (nonatomic, readwrite, strong) NSNumber *totalEntries;

@end

@implementation SFStoreCursor

- (id)initWithStore:(SFSmartStore*)store querySpec:(SFQuerySpec*)querySpec;
{
    self = [super init];
    
    if (nil != self) {
        self.querySpec = querySpec;
        self.cursorId = [NSString stringWithFormat:@"0x%lx",(unsigned long)[self hash]];
        self.pageSize = @(querySpec.pageSize);

        NSUInteger totalEntries = [[store countWithQuerySpec:querySpec error:nil] unsignedIntegerValue];
        float totalPagesFloat = totalEntries / (float) querySpec.pageSize;
        NSUInteger totalPages = ceilf(totalPagesFloat);
        if (0 == totalEntries)
            totalPages = 0;
        
        self.totalPages = @(totalPages);
        self.totalEntries = @(totalEntries);
        self.currentPageIndex = @0;
    }
    return self;
}

                            
- (void) dealloc {
    if (self.cursorId) // otherwise close has already been called
        [self close];
}


- (void)close {
    [SFSDKSmartStoreLogger v:[self class] format:@"closing cursor id: %@",self.cursorId];
    self.cursorId = nil;
    self.querySpec = nil;
    self.currentPageIndex = nil;
    self.pageSize = nil;
    self.totalPages = nil;
}

- (NSString*)getDataSerialized:(SFSmartStore*)store error:(NSError**)error {
    NSMutableString* resultBuilder = [NSMutableString new];
    [resultBuilder appendString:@"{"];
    [resultBuilder appendFormat:@"\"%@\":\"%@\", ", @"cursorId", self.cursorId];
    [resultBuilder appendFormat:@"\"%@\":%@, ", @"currentPageIndex", self.currentPageIndex ?: @0];
    [resultBuilder appendFormat:@"\"%@\":%@, ", @"pageSize", self.pageSize ?: @0];
    [resultBuilder appendFormat:@"\"%@\":%@, ", @"totalPages", self.totalPages ?: @0];
    [resultBuilder appendFormat:@"\"%@\":%@, ", @"totalEntries", self.totalEntries ?: @0];
    [resultBuilder appendFormat:@"\"%@\":", @"currentPageOrderedEntries"];
    BOOL succ = [store queryAsString:resultBuilder querySpec:self.querySpec pageIndex:[self.currentPageIndex integerValue] error:error];
    [resultBuilder appendString:@"}"];

    if (succ && [store checkRawJson:resultBuilder fromMethod:NSStringFromSelector(_cmd)]) {
        // NB: checkRawJson is only called if query succeeded
        return resultBuilder;
    } else {
        return nil;
    }
}

- (NSDictionary*)getDataDeserialized:(SFSmartStore*)store error:(NSError**)error
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"cursorId"] = self.cursorId;
    result[@"currentPageIndex"] = self.currentPageIndex ?: @0;
    result[@"pageSize"] = self.pageSize ?: @0;
    result[@"totalPages"] = self.totalPages ?: @0;
    result[@"totalEntries"] = self.totalEntries ?: @0;
    
    NSArray* entries = [store queryWithQuerySpec:self.querySpec pageIndex:[self.currentPageIndex integerValue] error:error];
    if (entries) {
        result[@"currentPageOrderedEntries"] = entries;
        return result;
    } else {
        return nil;
    }
}

@end

