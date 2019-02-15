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

#import "SmartSync.h"
#import "SFSyncTarget+Internal.h"
#import "SFSyncUpTarget+Internal.h"
#import "SFCompositeRequestHelper.h"

NSString * const kSFSyncUpTargetMaxBatchSize = @"maxBatchSize";

static NSUInteger const kSFMaxSubRequestsCompositeAPI = 25;

@interface SFBatchingSyncUpTarget ()

@property(nonatomic, readwrite) NSUInteger maxBatchSize;

@end


@implementation SFBatchingSyncUpTarget

#pragma mark - Initialization methods

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithCreateFieldlist:dict[kSFSyncUpTargetCreateFieldlist]
                         updateFieldlist:dict[kSFSyncUpTargetUpdateFieldlist]
                            maxBatchSize:dict[kSFSyncUpTargetMaxBatchSize]
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

    return [[SFBatchingSyncUpTarget alloc] initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldList maxBatchSize:maxBatchSize];
}

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFBatchingSyncUpTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncUpTargetMaxBatchSize] = [NSNumber numberWithUnsignedInteger:self.maxBatchSize];
    return dict;
}

#pragma mark - SFAdvancedSyncUpTarget methods

- (void)syncUpRecords:(nonnull SFSmartSyncSyncManager *)syncManager records:(nonnull NSArray<NSMutableDictionary *> *)records fieldlist:(nonnull NSArray *)fieldlist mergeMode:(SFSyncStateMergeMode)mergeMode syncSoupName:(nonnull NSString *)syncSoupName completionBlock:(nonnull SFSyncUpTargetCompleteBlock)completionBlock failBlock:(nonnull SFSyncUpTargetErrorBlock)failBlock {
    
    if (records.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableArray<NSString *> *refIds = [NSMutableArray new];
    NSMutableArray<SFRestRequest *> *requests = [NSMutableArray new];

    // Preparing requests
    for (NSMutableDictionary* record in records) {
        NSString *recordId = record[self.idFieldName];
        
        SFRestRequest *request = [self buildRequestForRecord:record fieldlist:fieldlist];
        
        if (request) {
            [refIds addObject:recordId];
            [requests addObject:request];
        }
    }
    
    // Sending composite request
    __weak typeof(self) weakSelf = self;
    SFSendCompositeRequestCompleteBlock sendCompositeRequestCompleteBlock = ^(NSDictionary *refIdToResponses) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        // Build refId to server id
        NSDictionary *refIdToServerId = [SFCompositeRequestHelper parseIdsFromResponse:refIdToResponses];
        
        // Will a re-run be required?
        BOOL needReRun = NO;
        
        // Update local store
        for (NSMutableDictionary *record in records) {
            if ([strongSelf isDirty:record]) {
                needReRun = needReRun || [strongSelf updateRecordInLocalStore:syncManager
                                                                 syncSoupName:syncSoupName
                                                                       record:record
                                                                    mergeMode:mergeMode
                                                              refIdToServerId:refIdToServerId
                                                                     response:refIdToResponses[record[strongSelf.idFieldName]]];
            }
        }
        
        // Re-run if required
        if (needReRun) {
            [strongSelf syncUpRecords:syncManager
                              records:records
                            fieldlist:fieldlist
                            mergeMode:mergeMode
                         syncSoupName:syncSoupName
                      completionBlock:completionBlock
                            failBlock:failBlock];
        } else {
            // Done
            completionBlock(nil);
        }
    };
        
    [SFCompositeRequestHelper sendCompositeRequest:syncManager
                                         allOrNone:NO
                                            refIds:refIds
                                          requests:requests
                                   completionBlock:sendCompositeRequestCompleteBlock
                                         failBlock:failBlock];
}

#pragma mark - helper methods

- (SFRestRequest*) buildRequestForRecord:(nonnull NSDictionary*)record fieldlist:(nonnull NSArray *)fieldlist {
    return nil; // TBD
}

- (BOOL) updateRecordInLocalStore:(nonnull SFSmartSyncSyncManager *)syncManager syncSoupName:(nonnull NSString *)syncSoupName record:(nonnull NSMutableDictionary *)record mergeMode:(SFSyncStateMergeMode)mergeMode refIdToServerId:(NSDictionary*)refIdToServerId response:(NSDictionary*)response {

    return NO; // TBD
    
}



@end
