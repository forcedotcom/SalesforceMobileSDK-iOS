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

#import "SFSoslSyncDownTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"

NSString * const kSFSoslSyncTargetQuery = @"query";

@interface SFSmartSyncSyncManager ()

@end

@interface SFSoslSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* query;

@end

@implementation SFSoslSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeSosl;
        self.query = dict[kSFSoslSyncTargetQuery];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeSosl;
    }
    return self;
}

#pragma mark - Factory methods

+ (SFSoslSyncDownTarget*) newSyncTarget:(NSString*)query {
    SFSoslSyncDownTarget* syncTarget = [[SFSoslSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeSosl;
    syncTarget.query = query;
    return syncTarget;
}


#pragma mark - To dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSoslSyncTargetQuery] = self.query;
    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [self startFetch:syncManager maxTimeStamp:maxTimeStamp queryRun:self.query errorBlock:errorBlock completeBlock:completeBlock];
}

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
           queryRun:(NSString*)queryRun
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak SFSoslSyncDownTarget* weakSelf = self;
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearch:queryRun];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(NSArray* records) {
        weakSelf.totalSize = [records count];
        completeBlock(records);
    }];
}

- (void) getListOfRemoteIds:(SFSmartSyncSyncManager*)syncManager
                       localIds:(NSArray*)localIds
                     errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
                  completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [self startFetch:syncManager maxTimeStamp:0 queryRun:self.query errorBlock:errorBlock completeBlock:completeBlock];
}

@end
