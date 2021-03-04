/*
 SFLayoutSyncDownTarget.m
 MobileSync
 
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

#import "SFLayoutSyncDownTarget.h"
#import "SFMobileSyncSyncManager.h"
#import "SFMobileSyncConstants.h"
#import "SFMobileSyncNetworkUtils.h"

static NSString * const kSFSyncTargetObjectType = @"sobjectType";
static NSString * const kSFSyncTargetFormFactor = @"formFactor";
static NSString * const kSFSyncTargetLayoutType = @"layoutType";
static NSString * const kSFSyncTargetMode = @"mode";
static NSString * const kSFSyncTargetRecordTypeId = @"recordTypeId";
static NSString * const kIDFieldValue = @"%@-%@-%@-%@-%@";

@interface SFLayoutSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString *objectAPIName;
@property (nonatomic, strong, readwrite) NSString *formFactor;
@property (nonatomic, strong, readwrite) NSString *layoutType;
@property (nonatomic, strong, readwrite) NSString *mode;
@property (nonatomic, strong, readwrite) NSString *recordTypeId;

@end

@implementation SFLayoutSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeLayout;
        self.objectAPIName = dict[kSFSyncTargetObjectType];
        self.formFactor = dict[kSFSyncTargetFormFactor];
        self.layoutType = dict[kSFSyncTargetLayoutType];
        self.mode = dict[kSFSyncTargetMode];
        self.recordTypeId = dict[kSFSyncTargetRecordTypeId];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeLayout;
    }
    return self;
}

+ (SFLayoutSyncDownTarget *)newSyncTarget:(NSString *)objectAPIName
                               formFactor:(NSString *)formFactor
                               layoutType:(NSString *)layoutType
                                     mode:(NSString *)mode
                             recordTypeId:(NSString *)recordTypeId {
    SFLayoutSyncDownTarget *syncTarget = [[SFLayoutSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeLayout;
    syncTarget.objectAPIName = objectAPIName;
    syncTarget.formFactor = formFactor;
    syncTarget.layoutType = layoutType;
    syncTarget.mode = mode;
    syncTarget.recordTypeId = recordTypeId;
    return syncTarget;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetObjectType] = self.objectAPIName;
    dict[kSFSyncTargetFormFactor] = self.formFactor;
    dict[kSFSyncTargetLayoutType] = self.layoutType;
    dict[kSFSyncTargetMode] = self.mode;
    dict[kSFSyncTargetRecordTypeId] = self.recordTypeId;
    return dict;
}

- (void)startFetch:(SFMobileSyncSyncManager *)syncManager
      maxTimeStamp:(long long)maxTimeStamp
        errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
     completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [self startFetch:syncManager maxTimeStamp:maxTimeStamp objectAPIName:self.objectAPIName formFactor:self.formFactor layoutType:self.layoutType mode:self.mode recordTypeId:self.recordTypeId errorBlock:errorBlock completeBlock:completeBlock];
}

- (void)startFetch:(SFMobileSyncSyncManager *)syncManager
      maxTimeStamp:(long long)maxTimeStamp
     objectAPIName:(NSString *)objectAPIName
        formFactor:(NSString *)formFactor
        layoutType:(NSString *)layoutType
              mode:(NSString *)mode
      recordTypeId:(NSString *)recordTypeId
        errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
     completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak typeof(self) weakSelf = self;
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId apiVersion:nil];
    [SFMobileSyncNetworkUtils sendRequestWithMobileSyncUserAgent:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        errorBlock(e);
    } successBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        weakSelf.totalSize = 1;
        NSMutableDictionary *record = [[NSMutableDictionary alloc] initWithDictionary:d];
        record[kId] = [NSString stringWithFormat:kIDFieldValue, weakSelf.objectAPIName, weakSelf.formFactor, weakSelf.layoutType, weakSelf.mode, weakSelf.recordTypeId];
        NSMutableArray *records = [[NSMutableArray alloc] initWithCapacity:1];
        records[0] = record;
        completeBlock(records);
    }];
}

- (void)getRemoteIds:(SFMobileSyncSyncManager *)syncManager
            localIds:(NSArray *)localIds
          errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
       completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    completeBlock(nil);
}

- (void)cleanGhosts:(SFMobileSyncSyncManager *)syncManager
           soupName:(NSString *)soupName
             syncId:(NSNumber *)syncId
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    completeBlock(nil);
}

@end
