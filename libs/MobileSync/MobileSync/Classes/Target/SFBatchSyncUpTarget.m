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


#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "MobileSync.h"
#import "SFSyncTarget+Internal.h"
#import "SFSyncUpTarget+Internal.h"
#import "SFCompositeRequestHelper.h"

NSString * const kSFSyncUpTargetMaxBatchSize = @"maxBatchSize";

static NSUInteger const kSFMaxSubRequestsCompositeAPI = 25;

@interface SFBatchSyncUpTarget ()

@property(nonatomic, readwrite) NSUInteger maxBatchSize;

@end


@implementation SFBatchSyncUpTarget

#pragma mark - Initialization methods

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.maxBatchSize = [self computeMaxBatchSize:dict[kSFSyncUpTargetMaxBatchSize]];
    }
    return self;
}

- (instancetype)init {
    return [self initWithCreateFieldlist:nil updateFieldlist:nil maxBatchSize:nil];
}

- (instancetype)initWithCreateFieldlist:(nullable NSArray<NSString*> *)createFieldlist
                        updateFieldlist:(nullable NSArray<NSString*> *)updateFieldlist {
    return [self initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldlist maxBatchSize:nil];
}

- (instancetype)initWithCreateFieldlist:(NSArray<NSString*> *)createFieldlist
                        updateFieldlist:(NSArray<NSString*> *)updateFieldlist
                           maxBatchSize:(NSNumber*)maxBatchSize;
{
    self = [super initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldlist];
    if (self) {
        self.maxBatchSize = [self computeMaxBatchSize:maxBatchSize];
    }
    return self;
}

#pragma mark - Factory method

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFBatchSyncUpTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncUpTargetMaxBatchSize] = [NSNumber numberWithUnsignedInteger:self.maxBatchSize];
    return dict;
}

#pragma mark - SFAdvancedSyncUpTarget methods

- (void)syncUpRecords:(nonnull SFMobileSyncSyncManager *)syncManager records:(nonnull NSArray<NSMutableDictionary *> *)records fieldlist:(nonnull NSArray *)fieldlist mergeMode:(SFSyncStateMergeMode)mergeMode syncSoupName:(nonnull NSString *)syncSoupName completionBlock:(nonnull SFSyncUpTargetCompleteBlock)completionBlock failBlock:(nonnull SFSyncUpTargetErrorBlock)failBlock {
    [self syncUpRecords:syncManager records:records fieldlist:fieldlist mergeMode:mergeMode syncSoupName:syncSoupName isReRun:NO completionBlock:completionBlock failBlock:failBlock];
}

- (void)syncUpRecords:(nonnull SFMobileSyncSyncManager *)syncManager records:(nonnull NSArray<NSMutableDictionary *> *)records fieldlist:(nonnull NSArray *)fieldlist mergeMode:(SFSyncStateMergeMode)mergeMode syncSoupName:(nonnull NSString *)syncSoupName isReRun:(BOOL)isReRun completionBlock:(nonnull SFSyncUpTargetCompleteBlock)completionBlock failBlock:(nonnull SFSyncUpTargetErrorBlock)failBlock {
    
    if (records.count == 0) {
        completionBlock(nil);
        return;
    }
    
    NSMutableArray<SFSDKRecordRequest *> *requests = [NSMutableArray new];

    // Preparing requests
    for (NSMutableDictionary* record in records) {
        NSString *refId;
        if (record[self.idFieldName] == nil || [record[self.idFieldName] isEqual:[NSNull null]]) {
            // create local id - needed for refId
            refId = record[self.idFieldName] = [SFSyncTarget createLocalId];
        } else {
            refId = record[self.idFieldName];
        }
        
        SFSDKRecordRequest *request = [self buildRequestForRecord:record fieldlist:fieldlist];
        
        if (request) {
            request.referenceId = refId;
            [requests addObject:request];
        }
    }
    
    // Sending composite request
    __weak typeof(self) weakSelf = self;
    SFSendCompositeRequestCompleteBlock sendCompositeRequestCompleteBlock = ^(NSDictionary *refIdToResponses) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        // Build refId to server id
        NSDictionary *refIdToServerId = [SFCompositeRequestHelper parseIdsFromResponses:refIdToResponses];
        
        // Will a re-run be required?
        BOOL needReRun = NO;
        
        // Update local store
        for (NSMutableDictionary *record in records) {
            if ([strongSelf isDirty:record]) {
                needReRun = needReRun || [strongSelf updateRecordInLocalStore:syncManager
                                                                     soupName:syncSoupName
                                                                       record:record
                                                                    mergeMode:mergeMode
                                                              refIdToServerId:refIdToServerId
                                                                     response:refIdToResponses[record[strongSelf.idFieldName]]
                                                                      isReRun:isReRun];
            }
        }
        
        // Re-run if required
        if (needReRun && !isReRun) {
            [strongSelf syncUpRecords:syncManager
                              records:records
                            fieldlist:fieldlist
                            mergeMode:mergeMode
                         syncSoupName:syncSoupName
                              isReRun:YES
                      completionBlock:completionBlock
                            failBlock:failBlock];
        } else {
            // Done
            completionBlock(nil);
        }
    };
        
    [self sendRecordRequests:syncManager
              recordRequests:requests
                  onComplete:sendCompositeRequestCompleteBlock
                      onFail:failBlock];
}
- (void) sendRecordRequests:(nonnull SFMobileSyncSyncManager *)syncManager
             recordRequests:(nonnull NSArray<SFSDKRecordRequest *> *)requests
                 onComplete:(nonnull SFSendCompositeRequestCompleteBlock)sendCompleteBlock
                     onFail:(nonnull SFSyncUpTargetErrorBlock)failBlock {
    
    [SFCompositeRequestHelper sendAsCompositeBatchRequest:syncManager
                                                allOrNone:NO
                                           recordRequests:requests
                                               onComplete:sendCompleteBlock
                                                   onFail:failBlock];
    
}

#pragma mark - helper methods

- (SFSDKRecordRequest*) buildRequestForRecord:(nonnull NSDictionary*)record fieldlist:(nonnull NSArray *)fieldlist {
    if (![self isDirty:record]) {
        return nil; // nothing to do
    }
    
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString* objectId = record[self.idFieldName];

    // Delete case
    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];
    
    if (isDelete) {
        if (isCreate) {
            return nil; // no need to go to server
        } else {
            return [SFSDKRecordRequest requestForDeleteWithObjectType:objectType objectId:objectId];
        }
    }
    // Create/update cases
    else {
        NSMutableDictionary *fields;
        
        if (isCreate) {
            fieldlist = self.createFieldlist ? self.createFieldlist : fieldlist;
            fields = [self buildFieldsMap:record fieldlist:fieldlist idFieldName:self.idFieldName modificationDateFieldName:self.modificationDateFieldName];
            NSString* externalId = self.externalIdFieldName ? record[self.externalIdFieldName] : nil;
            if (externalId
                // the following check is there for the case
                // where the the external id field is the id field
                // and the field is populated by a local id
                && ![SFSyncTarget isLocalId:externalId]) {
                return [SFSDKRecordRequest requestForUpsertWithObjectType:objectType externalIdFieldName:self.externalIdFieldName externalId:externalId fields:fields];
            } else {
                return [SFSDKRecordRequest requestForCreateWithObjectType:objectType fields:fields];
            }
        }
        else {
            fieldlist = self.updateFieldlist ? self.updateFieldlist : fieldlist;
            fields = [self buildFieldsMap:record fieldlist:fieldlist idFieldName:self.idFieldName modificationDateFieldName:self.modificationDateFieldName];
            return [SFSDKRecordRequest requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
        }
    }
}

- (BOOL) updateRecordInLocalStore:(nonnull SFMobileSyncSyncManager *)syncManager soupName:(nonnull NSString *)soupName record:(nonnull NSMutableDictionary *)record mergeMode:(SFSyncStateMergeMode)mergeMode refIdToServerId:(NSDictionary*)refIdToServerId response:(SFSDKRecordResponse*)response isReRun:(BOOL)isReRun {

    BOOL needReRun = NO;
    NSString *lastError = [SFJsonUtils JSONRepresentation:response.errorJson];
    
    // Delete case
    if ([self isLocallyDeleted:record]) {
        if ([self isLocallyCreated:record]  // we didn't go to the sever
            || response.success  // or we successfully deleted on the server
            || response.recordDoesNotExist) // or the record was already deleted on the server
        {
            [self deleteFromLocalStore:syncManager soupName:soupName record:record];
        }
        // Failure
        else {
            [self saveRecordToLocalStoreWithLastError:syncManager soupName:soupName record:record lastError:lastError];
        }
    }
    
    // Create / update case
    else {
        // Success case
        if (response.success)
        {
            // Plugging server id in id field
            NSDictionary* updatedRecord = [SFCompositeRequestHelper updateReferences:record fieldWithRefId:self.idFieldName refIdToServerId:refIdToServerId];
            
            // Clean and save
            [self cleanAndSaveInLocalStore:syncManager soupName:soupName record:updatedRecord];
        }
        // Handling remotely deleted records
        else if (response.recordDoesNotExist
                 && mergeMode == SFSyncStateMergeModeOverwrite // Record needs to be recreated
                 && !isReRun) {
            record[kSyncTargetLocal] = @YES;
            record[kSyncTargetLocallyCreated] = @YES;
            needReRun = YES;
        }
        // Failure
        else {
            [self saveRecordToLocalStoreWithLastError:syncManager soupName:soupName record:record lastError:lastError];
        }
        
    }
    
    return needReRun;    
}

- (NSUInteger) computeMaxBatchSize:(NSNumber*)maxBatchSize {
    return (maxBatchSize == nil || [maxBatchSize unsignedIntegerValue] > [self maxAPIBatchSize])
        ? [self maxAPIBatchSize]
        : [maxBatchSize unsignedIntegerValue];
}

- (NSUInteger) maxAPIBatchSize {
    return kSFMaxSubRequestsCompositeAPI;
}

@end
