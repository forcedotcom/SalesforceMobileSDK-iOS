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

NSString * const kQuerySpecTypeExact = @"exact";
NSString * const kQuerySpecTypeRange = @"range";
NSString * const kQuerySpecTypeLike = @"like";


NSString * const kQuerySpecParamQueryType = @"queryType";

NSString * const kQuerySpecParamIndexPath = @"indexPath";
NSString * const kQuerySpecParamOrder = @"order";
NSString * const kQuerySpecParamPageSize = @"pageSize";

NSString * const kQuerySpecParamMatchKey = @"matchKey";
NSString * const kQuerySpecParamBeginKey = @"beginKey";
NSString * const kQuerySpecParamEndKey = @"endKey";
NSString * const kQuerySpecParamLikeKey = @"likeKey";


@implementation SFSoupQuerySpec

@synthesize queryType= _queryType;
@synthesize path = _path;
@synthesize beginKey = _beginKey;
@synthesize endKey = _endKey;
@synthesize order = _order;
@synthesize pageSize = _pageSize;



- (id)initWithDictionary:(NSDictionary*)querySpec {
    self = [super init];
    if (nil != self) {
        self.queryType = [querySpec nonNullObjectForKey:kQuerySpecParamQueryType];
        
        if ([self.queryType isEqualToString:kQuerySpecTypeRange]) {
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamBeginKey];
            self.endKey = [querySpec nonNullObjectForKey:kQuerySpecParamEndKey];
        } else if ([self.queryType isEqualToString:kQuerySpecTypeLike]) {
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamLikeKey];
        } else if ([self.queryType isEqualToString:kQuerySpecTypeExact]) {
            self.queryType = kQuerySpecTypeExact;
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamMatchKey];
        } else {
            NSLog(@"Invalid queryType: '%@'",self.queryType);
            [self release];
            self = nil;
        }
        
        if (nil != self) {
            self.path = [querySpec nonNullObjectForKey:kQuerySpecParamIndexPath];
            self.order = [querySpec nonNullObjectForKey:kQuerySpecParamOrder];
            NSNumber *pageSize = [querySpec nonNullObjectForKey:kQuerySpecParamPageSize];
            self.pageSize = [pageSize integerValue];
        }
                
    }
    return self;
}

- (void)dealloc {
    self.queryType = nil;
    self.path = nil;
    self.beginKey = nil;
    self.endKey = nil;
    self.order = nil;
    
    [super dealloc];
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
                                   [NSNumber numberWithInteger:self.pageSize],kQuerySpecParamPageSize,
                                   nil];
    if (nil != self.path) {
        [result setObject:self.path forKey:kQuerySpecParamIndexPath];
    }
        
    if (nil != self.order) {
        [result setObject:self.order forKey:kQuerySpecParamOrder];
    }
    
     
    if ([self.queryType isEqualToString:kQuerySpecTypeRange]) {
        if (nil != self.beginKey) 
            [result setObject:self.beginKey forKey:kQuerySpecParamBeginKey];
        if (nil != self.endKey)
            [result setObject:self.endKey forKey:kQuerySpecParamEndKey];
    } else if ([self.queryType isEqualToString:kQuerySpecTypeLike]) {
        [result setObject:self.beginKey forKey:kQuerySpecParamLikeKey];
    } else { //kQuerySpecTypeExact or other
        if (nil != self.beginKey)
            [result setObject:self.beginKey forKey:kQuerySpecParamMatchKey];
    }
    
    return result;
}



- (NSString*)description {
    return [NSString stringWithFormat:@"<SFSoupQuerySpec: 0x%x> { \n  queryType:\"%@\" \n path:\"%@\" \n beginKey:\"%@\" \n endKey:\"%@\" \n  order:%@ \n pageSize: %d}",
                        self,self.queryType, self.path,self.beginKey,self.endKey,self.order,self.pageSize];
}

    
@end
