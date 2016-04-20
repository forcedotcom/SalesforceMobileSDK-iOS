/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFMruSyncDownTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"

NSString * const kSFSyncTargetObjectType = @"sobjectType";
NSString * const kSFSyncTargetFieldlist = @"fieldlist";


@interface SFMruSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* objectType;
@property (nonatomic, strong, readwrite) NSArray*  fieldlist;

@end

@implementation SFMruSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeMru;
        self.objectType = dict[kSFSyncTargetObjectType];
        self.fieldlist = dict[kSFSyncTargetFieldlist];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeMru;
    }
    return self;
}

#pragma mark - Factory methods

+ (SFMruSyncDownTarget*) newSyncTarget:(NSString*)objectType fieldlist:(NSArray*)fieldlist {
    SFMruSyncDownTarget* syncTarget = [[SFMruSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeMru;
    syncTarget.objectType = objectType;
    syncTarget.fieldlist = fieldlist;
    return syncTarget;
}

#pragma mark - To dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetObjectType] = self.objectType;
    dict[kSFSyncTargetFieldlist] = self.fieldlist;
    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak SFMruSyncDownTarget *weakSelf = self;
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:self.objectType];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(NSDictionary* d) {
        NSArray* recentItems = [weakSelf pluck:d[kRecentItems] key:self.idFieldName];
        NSString* inPredicate = [@[ self.idFieldName, @" IN ('", [recentItems componentsJoinedByString:@"', '"], @"')"]
                                 componentsJoinedByString:@""];
        NSString* soql = [[[[SFSmartSyncSoqlBuilder withFieldsArray:self.fieldlist]
                            from:self.objectType]
                           whereClause:inPredicate]
                          build];
        [weakSelf startFetch:syncManager maxTimeStamp:maxTimeStamp queryRun:soql errorBlock:errorBlock completeBlock:completeBlock];
    }];
}

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
           queryRun:(NSString*)queryRun
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak SFMruSyncDownTarget *weakSelf = self;
    SFRestRequest * soqlRequest = [[SFRestAPI sharedInstance] requestForQuery:queryRun];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:soqlRequest failBlock:errorBlock completeBlock:^(NSDictionary * d) {
        weakSelf.totalSize = [d[kResponseTotalSize] integerValue];
        completeBlock(d[kResponseRecords]);
    }];
}

- (void) getListOfRemoteIds:(SFSmartSyncSyncManager*)syncManager
                   localIds:(NSArray*)localIds
                 errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
              completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (localIds == nil) {
        completeBlock(nil);
    }
    NSString* inPredicate = [@[ self.idFieldName, @" IN ('", [localIds componentsJoinedByString:@"', '"], @"')"]
                             componentsJoinedByString:@""];
    NSString* soql = [[[[SFSmartSyncSoqlBuilder withFields:self.idFieldName]
                        from:self.objectType]
                       whereClause:inPredicate]
                      build];
    [self startFetch:syncManager maxTimeStamp:0 queryRun:soql errorBlock:errorBlock completeBlock:completeBlock];
}

- (NSArray*) pluck:(NSArray*)arrayOfDictionaries key:(NSString*)key {
    NSMutableArray* result = [NSMutableArray array];
    for (NSDictionary* d in arrayOfDictionaries) {
        [result addObject:d[key]];
    }
    return result;
}

@end
