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

#import "SFStoreCursor.h"

#import "SFSmartStore.h"
#import "SFQuerySpec.h"

@interface SFStoreCursor ()

@property (nonatomic, readwrite, strong) NSString *cursorId;
@property (nonatomic, readwrite, strong) NSString *soupName;

@property (nonatomic, readwrite, strong) SFQuerySpec *querySpec;
@property (nonatomic, readwrite, strong) NSArray *currentPageOrderedEntries;
@property (nonatomic, readwrite, strong) NSNumber *pageSize;
@property (nonatomic, readwrite, strong) NSNumber *totalPages;
@property (nonatomic, readwrite, strong) NSNumber *totalEntries;

@end

@implementation SFStoreCursor

@synthesize cursorId = _cursorId;
@synthesize querySpec = _querySpec;

@synthesize currentPageOrderedEntries = _currentPageOrderedEntries;
@synthesize currentPageIndex = _currentPageIndex;
@synthesize pageSize = _pageSize;
@synthesize totalPages = _totalPages;
@synthesize totalEntries = _totalEntries;




- (id)initWithStore:(SFSmartStore*)store
             querySpec:(SFQuerySpec*)querySpec  
          totalEntries:(NSUInteger)totalEntries
   firstPageEntries:(NSArray*) firstPageEntries
{
    self = [super init];
    
    if (nil != self) {
        _store = store;
        [self setCursorId:[NSString stringWithFormat:@"0x%lx",(unsigned long)[self hash]]];
        
        self.querySpec = querySpec;
        
        NSInteger myPageSize = 10;
        myPageSize =  [querySpec pageSize];

        self.pageSize = @(myPageSize); 
        
        float totalPagesFloat = totalEntries / (float)querySpec.pageSize;
        int totalPages = ceilf(totalPagesFloat);
        if (0 == totalEntries)
            totalPages = 0;
        
        self.totalPages = @(totalPages);
        self.totalEntries = @(totalEntries);
        _currentPageIndex = @0;
        self.currentPageOrderedEntries = firstPageEntries;
    }
    return self;
}

                            
- (void)dealloc {
    if (self.cursorId) // otherwise close has already been called
        [self close];
}


- (void)close {
    [self log:SFLogLevelVerbose format:@"closing cursor id: %@",self.cursorId];

     _store = nil;
    self.cursorId = nil;
    self.querySpec = nil;
    
    self.currentPageOrderedEntries = nil;
    self.currentPageIndex = nil;
    self.pageSize = nil;
    self.totalPages = nil;
}

#pragma mark - Properties

- (void)setCurrentPageIndex:(NSNumber *)pageIdx {
    //TODO check bounds?
    if (![pageIdx isEqual:_currentPageIndex]) {
        _currentPageIndex = pageIdx;
        
        if (nil != _currentPageIndex) {
            if ([self.totalPages integerValue] > 0) {
                NSUInteger pageIdx = [_currentPageIndex integerValue];
                NSArray *newEntries = [_store queryWithQuerySpec:self.querySpec pageIndex:pageIdx error:nil];
                self.currentPageOrderedEntries = newEntries;
            } else {
                self.currentPageOrderedEntries = @[];
            }
        } 
    }
}

#pragma mark - Converting to JSON

- (NSDictionary*)asDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"cursorId"] = self.cursorId;
    //note that we only encode the current page worth of entries
    result[@"currentPageOrderedEntries"] = self.currentPageOrderedEntries ?: @[];
    result[@"currentPageIndex"] = self.currentPageIndex ?: @0;
    result[@"pageSize"] = self.pageSize ?: @0;
    result[@"totalPages"] = self.totalPages ?: @0;
    result[@"totalEntries"] = self.totalEntries ?: @0;
    
    return result;
}


- (NSString*)description {
    return [NSString stringWithFormat:@"<SFStoreCursor: %p> {\n cursorId: %@ \n totalEntries:%@ \n totalPages:%@ \n currentPage:%@ \n currentPageOrderedEntries: [%lu] \n querySpec: %@ \n }",
            self,self.cursorId,
            self.totalEntries,
            self.totalPages,
            self.currentPageIndex,
            (unsigned long)[self.currentPageOrderedEntries count],
            self.querySpec
            ];
}

@end
