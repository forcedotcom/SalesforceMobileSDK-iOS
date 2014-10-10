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

#import "SObjectDataSpec.h"
#import <SalesforceSDKCore/SFSoupIndex.h>

NSString * const kSObjectIdField = @"Id";

@implementation SObjectDataSpec

- (id)initWithObjectType:(NSString *)objectType
            objectFields:(NSArray *)objectFields
              indexSpecs:(NSArray *)indexSpecs
                soupName:(NSString *)soupName
        orderByFieldName:(NSString *)orderByFieldName {
    self = [super init];
    if (self) {
        self.objectType = objectType;
        self.objectFields = [self buildObjectFields:objectFields];
        self.indexSpecs = [self buildSoupIndexSpecs:indexSpecs];
        self.soupName = soupName;
        self.orderByFieldName = orderByFieldName;
    }
    return self;
}

- (NSArray *)soupFieldNames {
    NSMutableArray *retNames = [NSMutableArray array];
    for (NSString *fieldName in [self.objectFields copy]) {
        [retNames addObject:[NSString stringWithFormat:@"{%@:%@}", self.soupName, fieldName]];
    }
    return retNames;
}

// createSObjectData is abstract.
+ (SObjectData *)createSObjectData:(NSDictionary *)soupDict {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

#pragma mark - Private methods

- (NSArray *)buildObjectFields:(NSArray *)origObjectFields {
    BOOL foundIdField = NO;
    for (NSString *objectField in origObjectFields) {
        if ([objectField isEqualToString:kSObjectIdField]) {
            foundIdField = YES;
            break;
        }
    }
    
    if (!foundIdField) {
        NSMutableArray *objectFieldsWithId = [NSMutableArray arrayWithArray:origObjectFields];
        [objectFieldsWithId insertObject:kSObjectIdField atIndex:0];
        return objectFieldsWithId;
    } else {
        return origObjectFields;
    }
}

- (NSArray *)buildSoupIndexSpecs:(NSArray *)origIndexSpecs {
    BOOL foundIdSpec = NO;
    for (SFSoupIndex *indexSpec in origIndexSpecs) {
        if ([indexSpec.path isEqualToString:kSObjectIdField]) {
            foundIdSpec = YES;
            break;
        }
    }
    
    if (!foundIdSpec) {
        NSMutableArray *indexSpecsWithId = [NSMutableArray arrayWithArray:origIndexSpecs];
        SFSoupIndex *idIndexSpec = [[SFSoupIndex alloc] initWithPath:kSObjectIdField indexType:kSoupIndexTypeString columnName:kSObjectIdField];
        [indexSpecsWithId insertObject:idIndexSpec atIndex:0];
        return indexSpecsWithId;
    } else {
        return origIndexSpecs;
    }
}

@end
