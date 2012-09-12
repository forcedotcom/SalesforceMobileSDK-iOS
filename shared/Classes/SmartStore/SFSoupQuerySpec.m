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

#import "SFSoupQuerySpec.h"

#import "NSDictionary+SFAdditions.h"

NSString * const kQuerySpecSortOrderAscending = @"ascending";
NSString * const kQuerySpecSortOrderDescending = @"descending";

NSString * const kQuerySpecTypeExact = @"exact";
NSString * const kQuerySpecTypeRange = @"range";
NSString * const kQuerySpecTypeLike = @"like";



NSString * const kQuerySpecParamQueryType = @"queryType";

NSString * const kQuerySpecParamIndexPath = @"indexPath";
NSString * const kQuerySpecParamOrder = @"order";
NSString * const kQuerySpecParamPageSize = @"pageSize";
NSUInteger const kQuerySpecDefaultPageSize = 10;

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
        NSString *rawQueryType = [querySpec nonNullObjectForKey:kQuerySpecParamQueryType];
        
        if ([rawQueryType isEqualToString:kQuerySpecTypeRange]) {
            self.queryType = kSFSoupQueryTypeRange;
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamBeginKey];
            self.endKey = [querySpec nonNullObjectForKey:kQuerySpecParamEndKey];
        } else if ([rawQueryType isEqualToString:kQuerySpecTypeLike]) {
            self.queryType = kSFSoupQueryTypeLike;
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamLikeKey];
        } else if ([rawQueryType isEqualToString:kQuerySpecTypeExact]) {
            self.queryType = kSFSoupQueryTypeExact;
            self.beginKey = [querySpec nonNullObjectForKey:kQuerySpecParamMatchKey];
        } else {
            NSLog(@"Invalid queryType: '%@'",rawQueryType);
            [self release];
            self = nil;
        }
        
        if (nil != self) {
            self.path = [querySpec nonNullObjectForKey:kQuerySpecParamIndexPath];
            
            NSString *rawOrder =  [querySpec nonNullObjectForKey:kQuerySpecParamOrder];
            if ([rawOrder isEqualToString:kQuerySpecSortOrderDescending]) {
                self.order = kSFSoupQuerySortOrderDescending;
            } else {
                self.order = kSFSoupQuerySortOrderAscending;
            }
            
            NSNumber *pageSize = [querySpec nonNullObjectForKey:kQuerySpecParamPageSize];
            self.pageSize = ([pageSize integerValue] > 0 ? [pageSize integerValue] : kQuerySpecDefaultPageSize);
        }
                
    }
    return self;
}

- (void)dealloc {
    self.path = nil;
    self.beginKey = nil;
    self.endKey = nil;
    
    [super dealloc];
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
        [result setObject:self.path forKey:kQuerySpecParamIndexPath];
    }
        
    if (self.order == kSFSoupQuerySortOrderDescending) {
        [result setObject:kQuerySpecSortOrderDescending forKey:kQuerySpecParamOrder];
    } else {
        [result setObject:kQuerySpecSortOrderAscending forKey:kQuerySpecParamOrder];
    }
     
    switch (self.queryType) {
        case kSFSoupQueryTypeRange:
            if (nil != self.beginKey) 
                [result setObject:self.beginKey forKey:kQuerySpecParamBeginKey];
            if (nil != self.endKey)
                [result setObject:self.endKey forKey:kQuerySpecParamEndKey];
            break;
        case kSFSoupQueryTypeLike:
            if (nil != self.beginKey)
                [result setObject:self.beginKey forKey:kQuerySpecParamLikeKey];
            break;
            
        case kSFSoupQueryTypeExact:
        default:
            if (nil != self.beginKey)
                [result setObject:self.beginKey forKey:kQuerySpecParamMatchKey];
            break;
    }
    
    return result;
}



- (NSString*)description {
    return [NSString stringWithFormat:@"<SFSoupQuerySpec: %p> { \n  queryType:\"%d\" \n path:\"%@\" \n beginKey:\"%@\" \n endKey:\"%@\" \n  order:%d \n pageSize: %d}",
                        self,self.queryType, self.path,self.beginKey,self.endKey,self.order,self.pageSize];
}

    
@end
