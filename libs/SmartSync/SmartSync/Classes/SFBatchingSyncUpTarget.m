/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSyncTarget+Internal.h"
#import "SFBatchingSyncUpTarget.h"
#import "SFSmartSyncNetworkUtils.h"
#import "SmartSync.h"
#import "SFSyncUpTarget+Internal.h"

static NSUInteger const kSFMaxSubRequestsCompositeAPI = 25;
static NSString * const kSFMaxBatchSize = @"maxBatchSize";

@interface SFBatchingSyncUpSyncUpTarget ()

@property(nonatomic, readwrite) NSUInteger maxBatchSize;

@end


@implementation SFBatchingSyncUpSyncUpTarget

#pragma mark - Initialization methods

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithCreateFieldlist:dict[kSFSyncUpTargetCreateFieldlist]
                         updateFieldlist:dict[kSFSyncUpTargetUpdateFieldlist]
                            maxBatchSize:dict[kSFMaxBatchSize]
            ];
}

- (instancetype)init {
    return [self initWithCreateFieldlist:nil updateFieldlist:nil maxBatchSize:nil];
}

- (instancetype)initWithCreateFieldlist:(NSArray *)createFieldlist
                        updateFieldlist:(NSArray *)updateFieldlist
                           maxBatchSize:(NSNumber*)maxBatchSize;
{
    self = [super initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldlist];
    if (self) {
        self.maxBatchSize = (maxBatchSize == nil || [maxBatchSize unsignedIntegerValue] > kSFMaxSubRequestsCompositeAPI)
                             ? kSFMaxSubRequestsCompositeAPI
                             : [maxBatchSize unsignedIntegerValue];
    }
    return self;
}

#pragma mark - Factory methods
                             
+ (instancetype)newSyncTargetWithCreateFieldlist:(NSArray *)createFieldlist
                                 updateFieldlist:(NSArray *)updateFieldList
                                    maxBatchSize:(NSNumber*)maxBatchSize {

    return [[SFBatchingSyncUpSyncUpTarget alloc] initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldList maxBatchSize:maxBatchSize];
}

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFBatchingSyncUpSyncUpTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFMaxBatchSize] = [NSNumber numberWithUnsignedInteger:self.maxBatchSize];
    return dict;
}

#pragma mark - SFAdvancedSyncUpTarget methods

- (NSUInteger) maxBatchSize {
    return self.maxBatchSize;
}

- (void)syncUpRecords:(nonnull SFSmartSyncSyncManager *)syncManager records:(nonnull NSArray<NSMutableDictionary *> *)records fieldlist:(nonnull NSArray *)fieldlist mergeMode:(SFSyncStateMergeMode)mergeMode syncSoupName:(nonnull NSString *)syncSoupName completionBlock:(nonnull SFSyncUpTargetCompleteBlock)completionBlock failBlock:(nonnull SFSyncUpTargetErrorBlock)failBlock {
    
    // TBD
    
}

@end
