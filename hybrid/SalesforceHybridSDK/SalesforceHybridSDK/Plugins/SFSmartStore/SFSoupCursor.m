/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
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

#import "SFSoupCursor.h"


@interface SFSoupCursor ()

@property (nonatomic, readwrite, strong) NSString *cursorId;

@property (nonatomic, readwrite, strong) NSDictionary *querySpec;
@property (nonatomic, readwrite, strong) NSArray *currentPageOrderedEntries;
@property (nonatomic, readwrite, strong) NSNumber *pageSize;
@property (nonatomic, readwrite, strong) NSNumber *totalPages;


@end

@implementation SFSoupCursor

@synthesize soupName = _soupName;
@synthesize cursorId = _cursorId;
@synthesize querySpec = _querySpec;

@synthesize currentPageOrderedEntries = _currentPageOrderedEntries;
@synthesize currentPageIndex = _currentPageIndex;
@synthesize pageSize = _pageSize;
@synthesize totalPages = _totalPages;





- (id)initWithSoupName:(NSString*)soupName querySpec:(NSDictionary*)querySpec entries:(NSArray*)entries
{
    self = [super init];
    
    if (nil != self) {
        [self setCursorId:[NSString stringWithFormat:@"0x%x",[self hash]]];
        self.soupName = soupName;
        self.querySpec = querySpec;
        _orderedEntries = [entries copy];
        
        NSInteger myPageSize = 10;
        NSNumber *querySpecPageSize = [querySpec objectForKey:@"pageSize"];
        if (nil != querySpecPageSize) {
            myPageSize = [querySpecPageSize integerValue];
        } 
        
        self.pageSize = [NSNumber numberWithInteger:myPageSize]; 


        //(A+B-1)/B   is essentially ceil(A/B)
        NSInteger pageCount =   ([_orderedEntries count] + myPageSize - 1) / myPageSize;
        self.totalPages = [NSNumber numberWithInteger:pageCount];
        
        [self setCurrentPageIndex:[NSNumber numberWithInteger:0]];
    }
    return self;
}

                            
- (void)dealloc {
    self.soupName = nil;
    self.cursorId = nil;
    self.querySpec = nil;
    
    self.currentPageOrderedEntries = nil;
    self.currentPageIndex = nil;
    self.pageSize = nil;
    self.totalPages = nil;
    
    [_orderedEntries release]; _orderedEntries = nil;
    
    [super dealloc];
}


#pragma mark - Properties

- (void)setCurrentPageIndex:(NSNumber *)pageIdx
{
    if ((nil != pageIdx) && ![_currentPageIndex isEqualToNumber:pageIdx]) {
        NSInteger newPageIdx = [pageIdx integerValue];
        NSInteger totalPages = [self.totalPages integerValue];
        if (newPageIdx < totalPages) {
            NSUInteger maxItems = [_orderedEntries count];
            NSUInteger pageSize = [self.pageSize integerValue];
            NSUInteger loc = newPageIdx * [self.pageSize integerValue];
            NSUInteger len = MIN( maxItems - loc, pageSize);
            NSRange pageRange = NSMakeRange(loc, len);
            self.currentPageOrderedEntries = [_orderedEntries subarrayWithRange:pageRange];
        } else {
            self.currentPageOrderedEntries = [NSArray array];
        }
    }
    
    _currentPageIndex = [pageIdx retain];
    
}

#pragma mark - Converting to JSON

- (NSDictionary*)asDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setObject:self.soupName forKey:@"soupName"];
    [result setObject:self.cursorId forKey:@"cursorId"];
    if (nil != self.querySpec) {
        [result setObject:self.querySpec forKey:@"querySpec"];
    }
    //note that we only encode the current page worth of entries
    [result setObject:self.currentPageOrderedEntries forKey:@"currentPageOrderedEntries"];
    [result setObject:self.currentPageIndex forKey:@"currentPageIndex"];
    [result setObject:self.pageSize forKey:@"pageSize"];
    [result setObject:self.totalPages forKey:@"totalPages"];
    
    return result;
}



@end
