/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFMruSyncTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"

NSString * const kSFSyncTargetObjectType = @"sobjectType";
NSString * const kSFSyncTargetFieldlist = @"fieldlist";


@interface SFMruSyncTarget ()

@property (nonatomic, strong, readwrite) NSString* objectType;
@property (nonatomic, strong, readwrite) NSArray*  fieldlist;

@end

@implementation SFMruSyncTarget

#pragma mark - Factory methods

+ (SFMruSyncTarget*) newSyncTarget:(NSString*)objectType fieldlist:(NSArray*)fieldlist {
    SFMruSyncTarget* syncTarget = [[SFMruSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeMru;
    syncTarget.objectType = objectType;
    syncTarget.fieldlist = fieldlist;
    return syncTarget;
}

#pragma mark - From/to dictionary

+ (SFMruSyncTarget*) newFromDict:(NSDictionary*)dict {
    SFMruSyncTarget* syncTarget = nil;
    if (dict != nil && [dict count] != 0) {
        syncTarget = [[SFMruSyncTarget alloc] init];
        syncTarget.queryType = SFSyncTargetQueryTypeMru;
        syncTarget.objectType = dict[kSFSyncTargetObjectType];
        syncTarget.fieldlist = dict[kSFSyncTargetFieldlist];
    }
    return syncTarget;
}

- (NSDictionary*) asDict {
    return @{
             kSFSyncTargetTypeKey: [SFSyncTarget queryTypeToString:self.queryType],
             kSFSyncTargetObjectType: self.objectType,
             kSFSyncTargetFieldlist: self.fieldlist
             };
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    __weak SFMruSyncTarget *weakSelf = self;
    
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:self.objectType];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(NSDictionary* d) {
        NSArray* recentItems = [weakSelf pluck:d[kRecentItems] key:kId];
        NSString* inPredicate = [@[ @"Id IN ('", [recentItems componentsJoinedByString:@"', '"], @"')"]
                                 componentsJoinedByString:@""];
        NSString* soql = [[[[SFSmartSyncSoqlBuilder withFieldsArray:self.fieldlist]
                            from:self.objectType]
                           where:inPredicate]
                          build];
        
        
        SFRestRequest * soqlRequest = [[SFRestAPI sharedInstance] requestForQuery:soql];
        [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:soqlRequest failBlock:errorBlock completeBlock:^(NSDictionary * d) {
            weakSelf.totalSize = [d[kResponseTotalSize] integerValue];
            completeBlock(d[kResponseRecords]);
        }];
    }];
}

- (NSArray*) pluck:(NSArray*)arrayOfDictionaries key:(NSString*)key {
    NSMutableArray* result = [NSMutableArray array];
    for (NSDictionary* d in arrayOfDictionaries) {
        [result addObject:d[key]];
    }
    return result;
}


@end
