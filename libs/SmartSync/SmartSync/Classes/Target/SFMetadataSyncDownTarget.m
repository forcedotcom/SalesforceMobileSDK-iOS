/*
 SFMetadataSyncDownTarget.m
 SmartSync
 
 Created by Bharath Hariharan on 5/6/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFMetadataSyncDownTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"

static NSString * const kSFSyncTargetObjectType = @"sobjectType";

@interface SFMetadataSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString *objectType;

@end

@implementation SFMetadataSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeMetadata;
        self.objectType = dict[kSFSyncTargetObjectType];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeMetadata;
    }
    return self;
}

+ (SFMetadataSyncDownTarget *)newSyncTarget:(NSString *)objectType {
    SFMetadataSyncDownTarget *syncTarget = [[SFMetadataSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeMetadata;
    syncTarget.objectType = objectType;
    return syncTarget;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetObjectType] = self.objectType;
    return dict;
}

- (void)startFetch:(SFSmartSyncSyncManager *)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [self startFetch:syncManager maxTimeStamp:maxTimeStamp objectType:self.objectType errorBlock:errorBlock completeBlock:completeBlock];
}

- (void)startFetch:(SFSmartSyncSyncManager *)syncManager
       maxTimeStamp:(long long)maxTimeStamp
           objectType:(NSString *)objectType
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak typeof(self) weakSelf = self;
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:objectType];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        errorBlock(e);
    } completeBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        weakSelf.totalSize = 1;
        NSMutableDictionary *record = [[NSMutableDictionary alloc] initWithDictionary:d];
        record[kId] = weakSelf.objectType;
        NSMutableArray *records = [[NSMutableArray alloc] initWithCapacity:1];
        records[0] = record;
        completeBlock(records);
    }];
}

- (void)getRemoteIds:(SFSmartSyncSyncManager *)syncManager
             localIds:(NSArray *)localIds
           errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
        completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    completeBlock(nil);
}

- (void)cleanGhosts:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName syncId:(NSNumber *)syncId errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    completeBlock(nil);
}

@end
