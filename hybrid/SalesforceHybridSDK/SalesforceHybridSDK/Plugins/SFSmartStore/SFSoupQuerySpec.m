/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
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

#import "SFSoupQuerySpec.h"

#import "NSDictionary+NullHandling.h"

NSString * const kQuerySpecSortOrderAscending = @"ascending";
NSString * const kQuerySpecSortOrderDescending = @"descending";

@implementation SFSoupQuerySpec

@synthesize path = _path;
@synthesize beginKey = _beginKey;
@synthesize endKey = _endKey;
@synthesize order = _order;
@synthesize pageSize = _pageSize;



- (id)initWithDictionary:(NSDictionary*)querySpec {
    self = [super init];
    if (nil != self) {
        self.path = [querySpec nonNullObjectForKey:@"indexPath"];
        self.order = [querySpec nonNullObjectForKey:@"order"];
        NSNumber *pageSize = [querySpec nonNullObjectForKey:@"pageSize"];
        NSUInteger myPageSize = 10;
        if (nil != pageSize) {
            myPageSize = [pageSize integerValue];
        } 
        self.pageSize = myPageSize;
        
        //use matchKey in preference to anything else
        NSString *matchKey = [querySpec nonNullObjectForKey:@"matchKey"];

        if (nil != matchKey) {
            self.beginKey = matchKey;
            self.endKey = matchKey;
        } else {
            self.beginKey = [querySpec nonNullObjectForKey:@"beginKey"];
            self.endKey = [querySpec nonNullObjectForKey:@"endKey"];
        }

    }
    return self;
}

- (NSString*)sqlSortOrder {
    NSString *result = @"ASC";
    if ([self.order isEqualToString:kQuerySpecSortOrderDescending]) {
        result = @"DESC";
    }

    return result;
}


#pragma mark - Converting to JSON

- (NSDictionary*)asDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    self.path, @"indexPath",
                                    self.order, @"order",
                                    [NSNumber numberWithInteger:self.pageSize],@"pageSize",
                                    nil];
    
    if ([self.beginKey isEqualToString:self.endKey]) {
        [result setObject:self.beginKey forKey:@"matchKey"];
    } else {
        if (nil != self.beginKey) 
            [result setObject:self.beginKey forKey:@"beginKey"];
        if (nil != self.endKey)
            [result setObject:self.endKey forKey:@"endKey"];
    }
    
    
    return result;
}



- (NSString*)description {
    return [NSString stringWithFormat:@"<SFSoupQuerySpec: 0x%x> { \n path:\"%@\" \n beginKey:\"%@\" \n endKey:\"%@\" \n order:%@ \n pageSize: %d}",
                        self,self.path,self.beginKey,self.endKey,self.order,self.pageSize];
}

    
@end
