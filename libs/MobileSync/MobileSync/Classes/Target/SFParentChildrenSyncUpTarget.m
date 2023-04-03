/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "MobileSync.h"
#import "SFSyncTarget+Internal.h"
#import "SFSyncUpTarget+Internal.h"
#import "SFCompositeRequestHelper.h"

typedef void (^SFFetchLastModifiedDatesCompleteBlock)(NSDictionary<NSString *, NSString *> * idToLastModifiedDates);

@interface SFParentChildrenSyncUpTarget ()

@property(nonatomic) SFParentInfo *parentInfo;
@property(nonatomic) SFChildrenInfo *childrenInfo;
@property(nonatomic) NSArray<NSString *> *childrenCreateFieldlist;
@property(nonatomic) NSArray<NSString *> *childrenUpdateFieldlist;
@property(nonatomic) SFParentChildrenRelationshipType relationshipType;

@end

@implementation SFParentChildrenSyncUpTarget

- (instancetype)initWithParentInfo:(SFParentInfo *)parentInfo
             parentCreateFieldlist:(NSArray<NSString *> *)parentCreateFieldlist
             parentUpdateFieldlist:(NSArray<NSString *> *)parentUpdateFieldlist
                      childrenInfo:(SFChildrenInfo *)childrenInfo
           childrenCreateFieldlist:(NSArray<NSString *> *)childrenCreateFieldlist
           childrenUpdateFieldlist:(NSArray<NSString *> *)childrenUpdateFieldlist
                  relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    self = [super init];
    if (self) {
        self.parentInfo = parentInfo;
        self.idFieldName = parentInfo.idFieldName;
        self.modificationDateFieldName = parentInfo.modificationDateFieldName;
        self.createFieldlist = parentCreateFieldlist;
        self.updateFieldlist = parentUpdateFieldlist;
        self.childrenInfo = childrenInfo;
        self.childrenCreateFieldlist = childrenCreateFieldlist;
        self.childrenUpdateFieldlist = childrenUpdateFieldlist;
        self.relationshipType = relationshipType;
        [SFParentChildrenSyncHelper registerAppFeature];
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithParentInfo:[SFParentInfo newFromDict:dict[kSFParentChildrenSyncTargetParent]]
              parentCreateFieldlist:dict[kSFSyncUpTargetCreateFieldlist]
              parentUpdateFieldlist:dict[kSFSyncUpTargetUpdateFieldlist]
                       childrenInfo:[SFChildrenInfo newFromDict:dict[kSFParentChildrenSyncTargetChildren]]
            childrenCreateFieldlist:dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist]
            childrenUpdateFieldlist:dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist]
                   relationshipType:[SFParentChildrenSyncHelper relationshipTypeFromString:dict[kSFParentChildrenSyncTargetRelationshipType]]];
}


#pragma mark - Factory methods

+ (instancetype)newSyncTargetWithParentInfo:(SFParentInfo *)parentInfo
                      parentCreateFieldlist:(NSArray<NSString *> *)parentCreateFieldlist
                      parentUpdateFieldlist:(NSArray<NSString *> *)parentUpdateFieldlist
                               childrenInfo:(SFChildrenInfo *)childrenInfo
                    childrenCreateFieldlist:(NSArray<NSString *> *)childrenCreateFieldlist
                    childrenUpdateFieldlist:(NSArray<NSString *> *)childrenUpdateFieldlist
                           relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    return [[SFParentChildrenSyncUpTarget alloc] initWithParentInfo:parentInfo
                                              parentCreateFieldlist:parentCreateFieldlist
                                              parentUpdateFieldlist:parentUpdateFieldlist
                                                       childrenInfo:childrenInfo
                                            childrenCreateFieldlist:childrenCreateFieldlist
                                            childrenUpdateFieldlist:childrenUpdateFieldlist
                                                   relationshipType:relationshipType];
}

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFParentChildrenSyncUpTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFParentChildrenSyncTargetParent] = [self.parentInfo asDict];
    dict[kSFSyncUpTargetCreateFieldlist] = self.createFieldlist;
    dict[kSFSyncUpTargetUpdateFieldlist] = self.updateFieldlist;
    dict[kSFParentChildrenSyncTargetChildren] = [self.childrenInfo asDict];
    dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] = self.childrenCreateFieldlist;
    dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] = self.childrenUpdateFieldlist;
    dict[kSFParentChildrenSyncTargetRelationshipType] = [SFParentChildrenSyncHelper relationshipTypeToString:self.relationshipType];
    return dict;
}

#pragma mark - Other public methods

- (void)createOnServer:(SFMobileSyncSyncManager *)syncManager record:(NSDictionary *)record fieldlist:(NSArray *)fieldlist completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (void)updateOnServer:(SFMobileSyncSyncManager *)syncManager record:(NSDictionary *)record fieldlist:(NSArray *)fieldlist completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteOnServer:(SFMobileSyncSyncManager *)syncManager record:(NSDictionary *)record completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger) maxBatchSize {
    return 1;
}

- (void)syncUpRecords:(SFMobileSyncSyncManager *)syncManager
              records:(NSArray<NSMutableDictionary*>*)records
            fieldlist:(NSArray*)fieldlist
            mergeMode:(SFSyncStateMergeMode)mergeMode
         syncSoupName:(NSString*)syncSoupName
      completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
            failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    
    
    if (records.count == 0) {
        // Nothing to do
        completionBlock(nil);
    }
    else {
        [self syncUpRecord:syncManager record:records[0] fieldlist:fieldlist mergeMode:mergeMode completionBlock:completionBlock failBlock:failBlock];
    }
}

- (void)syncUpRecord:(SFMobileSyncSyncManager *)syncManager
              record:(NSMutableDictionary *)record
           fieldlist:(NSArray *)fieldlist
           mergeMode:(SFSyncStateMergeMode)mergeMode
     completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
           failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    // Getting children
    NSArray<NSMutableDictionary*> *children = (self.relationshipType == SFParentChildrenRelationpshipMasterDetail && isDelete && !isCreate)
            // deleting master in a master-detail relationship will delete the children
            // so no need to actually do any work on the children
            ? [NSArray new]
            : [SFParentChildrenSyncHelper getMutableChildrenFromLocalStore:syncManager.store
                                                                parentInfo:self.parentInfo
                                                              childrenInfo:self.childrenInfo
                                                                    parent:record];

    [self syncUpRecord:syncManager
                record:record
              children:children
             fieldlist:fieldlist
             mergeMode:mergeMode
       completionBlock:completionBlock
             failBlock:failBlock];
}

- (NSString *)getDirtyRecordIdsSql:(NSString *)soupName idField:(NSString *)idField {
    return [SFParentChildrenSyncHelper getDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}

- (void)isNewerThanServer:(SFMobileSyncSyncManager *)syncManager record:(NSDictionary *)record resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock {
    if ([self isLocallyCreated:record]) {
        resultBlock(YES);
        return;
    }

    NSDictionary<NSString *, SFRecordModDate *> *idToLocalTimestamps = [self getLocalLastModifiedDates:syncManager record:record];
    [self fetchLastModifiedDates:syncManager record:record completionBlock:^(NSDictionary<NSString *, NSString *> *idToRemoteTimestamps) {
        if (idToLocalTimestamps) {
            for (NSString *id in [idToLocalTimestamps allKeys]) {
                SFRecordModDate *localModDate = idToLocalTimestamps[id];
                NSString *remoteTimestamp = idToRemoteTimestamps[id];
                SFRecordModDate *remoteModDate = [[SFRecordModDate alloc]
                                                  initWithTimestamp:remoteTimestamp
                                                  isDeleted:remoteTimestamp == nil // if it wasn't returned by fetchLastModifiedDates, then the record must have been deleted
                                                  ];
                
                if (![super isNewerThanServer:localModDate remoteModDate:remoteModDate]) {
                    resultBlock(NO); // no need to go further
                    return;
                }
            }
        }

        resultBlock(YES);
    }];
}

#pragma mark - Helper methods

- (NSDictionary<NSString *, SFRecordModDate *> *)getLocalLastModifiedDates:(SFMobileSyncSyncManager *)syncManager record:(NSDictionary *)record {
    NSMutableDictionary<NSString *, SFRecordModDate *> *idToLocalTimestamps = [NSMutableDictionary new];
    BOOL isParentDeleted = [self isLocallyDeleted:record];
    SFRecordModDate *parentModDate = [[SFRecordModDate alloc] initWithTimestamp:record[self.modificationDateFieldName] isDeleted:isParentDeleted];
    idToLocalTimestamps[record[self.idFieldName]] = parentModDate;

    NSArray<NSMutableDictionary *> *children = [SFParentChildrenSyncHelper getMutableChildrenFromLocalStore:syncManager.store
                                                                                                 parentInfo:self.parentInfo
                                                                                               childrenInfo:self.childrenInfo
                                                                                                     parent:record];

    for (NSDictionary *childRecord in children) {
        SFRecordModDate *childModDate = [[SFRecordModDate alloc]
                initWithTimestamp:childRecord[self.childrenInfo.modificationDateFieldName]
                        isDeleted: [self isLocallyDeleted:childRecord]
                                || (isParentDeleted && self.relationshipType == SFParentChildrenRelationpshipMasterDetail)
                ];
        idToLocalTimestamps[childRecord[self.childrenInfo.idFieldName]] = childModDate;
    }

    return idToLocalTimestamps;
}

- (void)fetchLastModifiedDates:(SFMobileSyncSyncManager *)manager
                        record:(NSDictionary *)record
        completionBlock:(SFFetchLastModifiedDatesCompleteBlock)completionBlock {
    if ([self isLocallyCreated:record]) {
        completionBlock(nil);
        return;
    }

    NSString* parentId = record[self.idFieldName];
    SFRestRequest* lastModRequest = [self getRequestForTimestamps:parentId];
    [SFMobileSyncNetworkUtils sendRequestWithMobileSyncUserAgent:lastModRequest
                                                     failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
                                                         completionBlock(nil);
                                                     }
                                                 successBlock:^(id lastModResponse, NSURLResponse *rawResponse) {
                                                     NSMutableDictionary<NSString *, NSString *> * idToRemoteTimestamps = nil;
                                                     id rows = lastModResponse[kResponseRecords];
                                                     if (rows && rows != [NSNull null] && [rows count] > 0) {
                                                         idToRemoteTimestamps = [NSMutableDictionary new];
                                                         NSDictionary * row = rows[0];
                                                         idToRemoteTimestamps[row[self.idFieldName]] = row[self.modificationDateFieldName];
                                                         id childrenRows = row[self.childrenInfo.sobjectTypePlural];
                                                         if (childrenRows && childrenRows != [NSNull null]) {
                                                             for (NSDictionary * childRow in childrenRows[kResponseRecords]) {
                                                                 idToRemoteTimestamps[childRow[self.childrenInfo.idFieldName]] = childRow[self.childrenInfo.modificationDateFieldName];
                                                             }
                                                         }
                                                     }
                                                     completionBlock(idToRemoteTimestamps);
                                                 }];
}

- (void)syncUpRecord:(SFMobileSyncSyncManager *)syncManager
              record:(NSMutableDictionary *)record
            children:(NSArray<NSMutableDictionary *> *)children
           fieldlist:(NSArray *)fieldlist
           mergeMode:(SFSyncStateMergeMode)mergeMode
     completionBlock:(nullable SFSyncUpTargetCompleteBlock)completionBlock
           failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    NSMutableArray<SFSDKRecordRequest *> *requests = [NSMutableArray new];

    // Preparing request for parent
    NSString *parentId = record[self.idFieldName];
    SFSDKRecordRequest *parentRequest = [self buildRequestForParentRecord:record fieldlist:fieldlist];

    // Parent request goes first unless it's a delete
    if (parentRequest && !isDelete) {
        parentRequest.referenceId = parentId;
        [requests addObject:parentRequest];
    }

    // Preparing requests for children
    for (NSMutableDictionary* childRecord in children) {
        NSString *childId = childRecord[self.childrenInfo.idFieldName];

        // Parent will get a server id
        // Children need to be updated
        if (isCreate) {
            childRecord[kSyncTargetLocal] = @YES;
            childRecord[kSyncTargetLocallyUpdated] = @YES;
        }

        SFSDKRecordRequest *childRequest = [self buildRequestForChildRecord:childRecord useParentIdReference:isCreate parentId:isDelete ? nil : parentId];

        if (childRequest) {
            childRequest.referenceId = childId;
            [requests addObject:childRequest];
        }

    }

    // Parent request goes last when it's a delete
    if (parentRequest && isDelete) {
        parentRequest.referenceId = parentId;
        [requests addObject:parentRequest];
    }

    // Sending composite request
    SFSendCompositeRequestCompleteBlock sendCompositeRequestCompleteBlock = ^(NSDictionary *refIdToResponses) {
        // Build refId to server id
        NSDictionary *refIdToServerId = [SFCompositeRequestHelper parseIdsFromResponses:refIdToResponses];

        // Will a re-run be required?
        BOOL needReRun = NO;

        // Update parent in local store
        if ([self isDirty:record]) {
            needReRun = [self updateParentRecordInLocalStore:syncManager
                                                      record:record
                                                    children:children
                                                   mergeMode:mergeMode
                                             refIdToServerId:refIdToServerId
                                                    response:refIdToResponses[record[self.idFieldName]]];
        }

        // Update children local store
        for (NSMutableDictionary *childRecord in children) {
            if ([self isDirty:childRecord] || isCreate) {
                needReRun = needReRun || [self updateChildRecordInLocalStore:syncManager
                                                                      record:childRecord
                                                                      parent:record
                                                                   mergeMode:mergeMode
                                                             refIdToServerId:refIdToServerId
                                                                    response:refIdToResponses[childRecord[self.childrenInfo.idFieldName]]];
            }
        }

        // Re-run if required
        if (needReRun) {
            [SFSDKMobileSyncLogger d:[self class] format:@"syncUpOneRecord:%@", record];
            [self syncUpRecord:syncManager record:record children:children fieldlist:fieldlist mergeMode:mergeMode completionBlock:completionBlock failBlock:failBlock];
        } else {
            // Done
            completionBlock(nil);
        }
    };
    
    [SFCompositeRequestHelper sendAsCompositeBatchRequest:syncManager
                                                allOrNone:NO
                                           recordRequests:requests
                                               onComplete:sendCompositeRequestCompleteBlock
                                                   onFail:failBlock];
}


- (SFSDKRecordRequest *)buildRequestForParentRecord:(NSDictionary *)record fieldlist:(NSArray *)fieldlist {
    return [self buildRequestForRecord:record fieldlist:fieldlist isParent:true useParentIdReference:false parentId:nil];
}

- (SFSDKRecordRequest *)buildRequestForChildRecord:(NSDictionary *)record
                         useParentIdReference:(BOOL)useParentIdReference
                                     parentId:(NSString *)parentId {

    return [self buildRequestForRecord:record fieldlist:nil isParent:false useParentIdReference:useParentIdReference parentId:parentId];
}

- (SFSDKRecordRequest *)buildRequestForRecord:(NSDictionary *)record
                               fieldlist:(NSArray *)fieldlist
                                isParent:(BOOL)isParent
                    useParentIdReference:(BOOL)useParentIdReference
                                parentId:(NSString *)parentId {

    if (![self isDirty:record]) {
        return nil; // nothing to do
    }

    SFParentInfo *info = isParent ? self.parentInfo : self.childrenInfo;
    NSString *id = record[info.idFieldName];

    // Delete case
    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    if (isDelete) {
        if (isCreate) {
            return nil; // no need to go to server
        } else {
            return [SFSDKRecordRequest requestForDeleteWithObjectType:info.sobjectType objectId:id];
        }
    }
    // Create/update cases
    else {
        fieldlist = isParent
                ? isCreate
                        ? (self.createFieldlist ? self.createFieldlist : fieldlist)
                        : (self.updateFieldlist ? self.updateFieldlist : fieldlist)
                : isCreate
                        ? self.childrenCreateFieldlist
                        : self.childrenUpdateFieldlist;

        NSMutableDictionary *fields = [self buildFieldsMap:record fieldlist:fieldlist idFieldName:info.idFieldName modificationDateFieldName:info.modificationDateFieldName];
        if (parentId) {
            fields[((SFChildrenInfo *) info).parentIdFieldName] = useParentIdReference ? [NSString stringWithFormat:@"@{%@.%@}", parentId, kCreatedId] : parentId;
        }

        if (isCreate) {
            NSString *externalId = info.externalIdFieldName ? record[info.externalIdFieldName] : nil;
            if (externalId
                // the following check is there for the case
                // where the the external id field is the id field
                // and the field is populated by a local id
                && ![SFSyncTarget isLocalId:externalId]) {
                return [SFSDKRecordRequest requestForUpsertWithObjectType:info.sobjectType externalIdFieldName:info.externalIdFieldName externalId:externalId fields:fields];
            } else {
                return [SFSDKRecordRequest requestForCreateWithObjectType:info.sobjectType fields:fields];
            }
        } else {
            return [SFSDKRecordRequest requestForUpdateWithObjectType:info.sobjectType objectId:id fields:fields];
        }
    }
}

- (BOOL)updateParentRecordInLocalStore:(SFMobileSyncSyncManager *)syncManager
                                record:(NSMutableDictionary *)record
                              children:(NSArray<NSMutableDictionary*> *)children
                             mergeMode:(SFSyncStateMergeMode)mergeMode
                       refIdToServerId:(NSDictionary *)refIdToServerId
                              response:(SFSDKRecordResponse *)response {
    
    BOOL needReRun = NO;
    NSString* soupName = self.parentInfo.soupName;
    NSString* idFieldName = self.idFieldName;
    NSString *lastError = [SFJsonUtils JSONRepresentation:response.errorJson];

    // Delete case
    if ([self isLocallyDeleted:record]) {
        if ([self isLocallyCreated:record]  // we didn't go to the sever
                || response.success  // or we successfully deleted on the server
                || response.recordDoesNotExist) // or the record was already deleted on the server
        {
            if (self.relationshipType == SFParentChildrenRelationpshipMasterDetail) {
                [SFParentChildrenSyncHelper deleteChildrenFromLocalStore:syncManager.store parentInfo:self.parentInfo childrenInfo:self.childrenInfo parentIds:@[record[idFieldName]]];
            }

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
            NSDictionary* updatedRecord = [SFCompositeRequestHelper updateReferences:record fieldWithRefId:idFieldName refIdToServerId:refIdToServerId];

            // Clean and save
            [self cleanAndSaveInLocalStore:syncManager soupName:soupName record:updatedRecord];
        }
        // Handling remotely deleted records
        else if (response.recordDoesNotExist) {
            // Record needs to be recreated
            if (mergeMode == SFSyncStateMergeModeOverwrite) {
                record[kSyncTargetLocal] = @YES;
                record[kSyncTargetLocallyCreated] = @YES;

                // Children need to be updated or recreated as well (since the parent will get a new server id)
                for (NSMutableDictionary *childRecord in children) {
                    childRecord[kSyncTargetLocal] = @YES;
                    childRecord[self.relationshipType == SFParentChildrenRelationpshipMasterDetail ? kSyncTargetLocallyCreated : kSyncTargetLocallyUpdated] = @YES;
                }

                needReRun = YES;
            }
        }
        // Failure
        else {
            [self saveRecordToLocalStoreWithLastError:syncManager soupName:soupName record:record lastError:lastError];
        }

    }

    return needReRun;
}

- (BOOL)updateChildRecordInLocalStore:(SFMobileSyncSyncManager *)syncManager
                               record:(NSMutableDictionary *)record
                               parent:(NSMutableDictionary *)parent
                            mergeMode:(SFSyncStateMergeMode)mergeMode
                      refIdToServerId:(NSDictionary *)refIdToServerId
                             response:(SFSDKRecordResponse *)response {
    BOOL needReRun = NO;
    NSString* soupName = self.childrenInfo.soupName;
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
            NSDictionary* updatedRecord = [SFCompositeRequestHelper updateReferences:record fieldWithRefId:self.childrenInfo.idFieldName refIdToServerId:refIdToServerId];

            // Plugging server id in parent id field
            NSDictionary* fullUpdatedRecord = [SFCompositeRequestHelper updateReferences:updatedRecord fieldWithRefId:self.childrenInfo.parentIdFieldName refIdToServerId:refIdToServerId];

            // Clean and save
            [self cleanAndSaveInLocalStore:syncManager soupName:soupName record:fullUpdatedRecord];
        }

        // Handling remotely deleted records
        else if (response.recordDoesNotExist) {

            // Record needs to be recreated
            if (mergeMode == SFSyncStateMergeModeOverwrite) {
                record[kSyncTargetLocal] = @YES;
                record[kSyncTargetLocallyCreated] = @YES;

                // We need a re-run
                needReRun = YES;
            }
        }

        // Handling remotely deleted parent
        else if(response.relatedRecordDoesNotExist) {
            // Parent record needs to be recreated
            if (mergeMode == SFSyncStateMergeModeOverwrite) {
                parent[kSyncTargetLocal] = @YES;
                parent[kSyncTargetLocallyCreated] = @YES;
                
                // We need a re-run
                needReRun = YES;
            }
        }

        // Failure
        else {
            [self saveRecordToLocalStoreWithLastError:syncManager soupName:soupName record:record lastError:lastError];
        }

    }

    return needReRun;
}


- (SFRestRequest*) getRequestForTimestamps:(NSString*) parentId {
    SFSDKSoqlBuilder * builderNested = [SFSDKSoqlBuilder withFieldsArray:@[self.childrenInfo.idFieldName, self.childrenInfo.modificationDateFieldName]];
    [builderNested from:self.childrenInfo.sobjectTypePlural];

    SFSDKSoqlBuilder * builder = [SFSDKSoqlBuilder withFieldsArray:@[self.idFieldName, self.modificationDateFieldName, [NSString stringWithFormat:@"(%@)", [builderNested build]]]];
    [builder from:self.parentInfo.sobjectType];
    [builder whereClause:[NSString stringWithFormat:@"%@ = '%@'", self.idFieldName, parentId]];

    SFRestRequest * request = [[SFRestAPI sharedInstance] requestForQuery:[builder build] apiVersion:nil];
    return request;
}


@end
