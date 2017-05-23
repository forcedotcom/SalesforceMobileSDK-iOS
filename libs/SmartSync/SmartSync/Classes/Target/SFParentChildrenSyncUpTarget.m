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

#import "SFSyncTarget+Internal.h"
#import "SFParentChildrenSyncUpTarget.h"
#import "SFSmartSyncNetworkUtils.h"
#import "SmartSync.h"

typedef void (^SFSendCompositeRequestCompleteBlock)(NSDictionary *refIdToResponses);

@interface  SFSyncUpTarget ()
@property (nonatomic, strong) NSArray*  createFieldlist;
@property (nonatomic, strong) NSArray*  updateFieldlist;

- (NSMutableDictionary *)buildFieldsMap:(NSDictionary *)record
                              fieldlist:(NSArray *)fieldlist
                            idFieldName:(NSString *)idFieldName
              modificationDateFieldName:(NSString *)modificationDateFieldName;
@end

@interface SFParentChildrenSyncUpTarget ()

@property (nonatomic) SFParentInfo* parentInfo;
@property (nonatomic) SFChildrenInfo* childrenInfo;
@property (nonatomic) NSArray<NSString*>* childrenCreateFieldlist;
@property (nonatomic) NSArray<NSString*>* childrenUpdateFieldlist;
@property (nonatomic) SFParentChildrenRelationshipType relationshipType;

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
              parentCreateFieldlist:dict[kSFParentChildrenSyncTargetParentCreateFieldlist]
              parentUpdateFieldlist:dict[kSFParentChildrenSyncTargetParentUpdateFieldlist]
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
    dict[kSFParentChildrenSyncTargetParentCreateFieldlist] = self.createFieldlist;
    dict[kSFParentChildrenSyncTargetParentUpdateFieldlist] = self.updateFieldlist;
    dict[kSFParentChildrenSyncTargetChildren] = [self.childrenInfo asDict];
    dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] = self.childrenCreateFieldlist;
    dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] = self.childrenUpdateFieldlist;
    dict[kSFParentChildrenSyncTargetRelationshipType] = [SFParentChildrenSyncHelper relationshipTypeToString:self.relationshipType];
    return dict;
}

#pragma mark - Other public methods

- (void)createOnServer:(SFSmartSyncSyncManager *)syncManager record:(NSDictionary *)record fieldlist:(NSArray *)fieldlist completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (void)updateOnServer:(SFSmartSyncSyncManager *)syncManager record:(NSDictionary *)record fieldlist:(NSArray *)fieldlist completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteOnServer:(SFSmartSyncSyncManager *)syncManager record:(NSDictionary *)record completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    // For advanced sync up target, call syncUpOneRecord
    [self doesNotRecognizeSelector:_cmd];
}

- (void)syncUpRecord:(SFSmartSyncSyncManager *)syncManager
              record:(NSDictionary*)record
           fieldlist:(NSArray*)fieldlist
           mergeMode:(SFSyncStateMergeMode)mergeMode
     completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
           failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    // Getting children
    NSArray<NSDictionary *> *children = (self.relationshipType == SFParentChildrenRelationpshipMasterDetail && isDelete && !isCreate)
            // deleting master in a master-detail relationship will delete the children
            // so no need to actually do any work on the children
            ? [NSArray new]
            : [SFParentChildrenSyncHelper getChildrenFromLocalStore:syncManager.store parentInfo:self.parentInfo childrenInfo:self.childrenInfo parent:record];

    [self syncUpRecord:syncManager record:record children:children fieldlist:fieldlist mergeMode:mergeMode completionBlock:completionBlock failBlock:failBlock];
}

- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
    return [SFParentChildrenSyncHelper getDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}

- (void)isNewerThanServer:(SFSmartSyncSyncManager *)syncManager record:(NSDictionary *)record resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock {
    /*

     // FIXME

    if (isLocallyCreated(record)) {
        return true;
    }

    Map<String, RecordModDate> idToLocalTimestamps = getLocalLastModifiedDates(syncManager, record);
    Map<String, String> idToRemoteTimestamps = fetchLastModifiedDates(syncManager, record);

    for (String id : idToLocalTimestamps.keySet()) {

        final RecordModDate localModDate = idToLocalTimestamps.get(id);
        final String remoteTimestamp = idToRemoteTimestamps.get(id);
        final RecordModDate remoteModDate = new RecordModDate(
                remoteTimestamp,
                remoteTimestamp == null // if it wasn't returned by fetchLastModifiedDates, then the record must have been deleted
        );

        if (!super.isNewerThanServer(localModDate, remoteModDate)) {
            return false; // no need to go further
        }
    }

    return true;
     */
}

#pragma mark - Helper methods

- (NSDictionary *)sendCompositeRequest:(SFSmartSyncSyncManager *)manager
                             allOrNone:(BOOL)allOrNone
                                refIds:(NSArray<NSString*>*)refIds
                              requests:(NSArray<SFRestRequest*> *)requests
        completionBlock:(SFSendCompositeRequestCompleteBlock)completionBlock
              failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    SFRestRequest* compositeRequest = [[SFRestAPI sharedInstance] compositeRequest:requests refIds:refIds allOrNone:allOrNone];

    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:compositeRequest
                                                     failBlock:failBlock
                                                 completeBlock:^(id compositeResponse) {
                                                     NSMutableDictionary *refIdToResponses = [NSMutableDictionary new];
                                                     NSArray *responses = compositeResponse[@"compositeResponse"];
                                                     for (NSDictionary *response in responses) {
                                                         refIdToResponses[response[@"referenceId"]] = response;
                                                     }
                                                     completionBlock(refIdToResponses);
                                                 }];

    return nil;
}

- (void) syncUpRecord:(SFSmartSyncSyncManager *)syncManager
               record:(NSDictionary*)record
             children:(NSArray<NSDictionary*>*)children
            fieldlist:(NSArray*)fieldlist
            mergeMode:(SFSyncStateMergeMode)mergeMode
      completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
            failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    NSMutableArray<NSString*> *refIds = [NSMutableArray new];
    NSMutableArray<SFRestRequest*> *requests = [NSMutableArray new];

    // Preparing request for parent
    NSString* parentId = record[self.idFieldName];
    SFRestRequest * parentRequest = [self buildRequestForParentRecord:record fieldlist:fieldlist];

    // Parent request goes first unless it's a delete
    if (parentRequest && !isDelete) {
        [refIds addObject:parentId];
        [requests addObject:parentRequest];
    }

    // Preparing requests for children
    for (NSUInteger i=0; i<children.count; i++) {
        NSMutableDictionary * childRecord = [children[i] mutableCopy];
        NSString* childId = childRecord[self.childrenInfo.idFieldName];

        // Parent will get a server id
        // Children need to be updated
        if (isCreate) {
            childRecord[kSyncTargetLocal] = @YES;
            childRecord[kSyncTargetLocallyUpdated] = @YES;
        }

        SFRestRequest * childRequest = [self buildRequestForChildRecord:childRecord useParentIdReference:isCreate parentId:isDelete ? nil : parentId];

        if (childRequest) {
            [refIds addObject:childId];
            [requests addObject:childRequest];
        }

    }

    // Parent request goes last when it's a delete
    if (parentRequest && isDelete) {
        [refIds addObject:parentId];
        [requests addObject:parentRequest];
    }

    // Sending composite request
    SFSendCompositeRequestCompleteBlock sendCompositeRequestCompleteBlock = ^(NSDictionary * refIdToResponses) {
            // Build refId to server id / status code / time stamp maps
            NSDictionary * refIdToServerId = [self parseIdsFromResponse:refIdToResponses];
            NSDictionary * refIdToHttpStatusCode = [self parseStatusCodesFromResponse:refIdToResponses];

            // Will a re-run be required?
            BOOL needReRun = NO;

            // Update parent in local store
            if ([self isDirty:record]) {
                needReRun = [self updateParentRecordInLocalStore:syncManager
                                                          record:record
                                                        children:children
                                                       mergeMode:mergeMode
                                                 refIdToServerId:refIdToServerId
                                               refIdToStatusCode:refIdToHttpStatusCode];
            }

            // Update children local store
            for (NSDictionary * childRecord in children) {
                if ([self isDirty:childRecord] || isCreate) {
                    needReRun = needReRun || [self updateChildRecordInLocalStore:syncManager
                                                                          record:record
                                                                       mergeMode:mergeMode
                                                                 refIdToServerId:refIdToServerId
                                                               refIdToStatusCode:refIdToHttpStatusCode];
                }
            }

            // Re-run if required
            if (needReRun) {
                LogSyncDebug(@"syncUpOneRecord:%@", record);
                [self syncUpRecord:syncManager record:record children:children fieldlist:fieldlist mergeMode:mergeMode completionBlock:completionBlock failBlock:failBlock];
            }
            else {
                // Done
                completionBlock(nil);
            }
    };

    NSDictionary * refIdToResponses = [self sendCompositeRequest:syncManager
                                                       allOrNone:NO
                                                          refIds:refIds
                                                        requests:requests
                                                 completionBlock:sendCompositeRequestCompleteBlock
                                                       failBlock:failBlock];
}


- (SFRestRequest*) buildRequestForParentRecord:(NSDictionary*)record fieldlist:(NSArray*)fieldlist {
    return [self buildRequestForRecord:record fieldlist:fieldlist isParent:true useParentIdReference:false parentId:nil];
}

- (SFRestRequest*) buildRequestForChildRecord:(NSDictionary*)record
                         useParentIdReference:(BOOL)useParentIdReference
                                     parentId:(NSString*)parentId {

    return [self buildRequestForRecord:record fieldlist:nil isParent:false useParentIdReference:useParentIdReference parentId:parentId];
}

- (SFRestRequest*) buildRequestForRecord:(NSDictionary*)record
                               fieldlist:(NSArray*)fieldlist
                                isParent:(BOOL)isParent
                    useParentIdReference:(BOOL)useParentIdReference
                                parentId:(NSString*)parentId {

    if (![self isDirty:record]) {
        return nil; // nothing to do
    }

    SFParentInfo * info = isParent ? self.parentInfo : self.childrenInfo;
    NSString* id = record[info.idFieldName];

    // Delete case
    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    if (isDelete) {
        if (isCreate) {
            return nil; // no need to go to server
        }
        else {
            return [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:info.sobjectType objectId:id];
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
                    : self.childrenUpdateFieldlist
                ;

        NSMutableDictionary *fields = [self buildFieldsMap:record fieldlist:fieldlist idFieldName:info.idFieldName modificationDateFieldName:info.modificationDateFieldName];
        if (parentId) {
            fields[((SFChildrenInfo *) info).parentIdFieldName] = useParentIdReference ? [NSString stringWithFormat:@"{%@.%@}", parentId, @"id"]  : parentId;
        }

        if (isCreate) {
            return [[SFRestAPI sharedInstance] requestForCreateWithObjectType:info.sobjectType fields:fields];
        }
        else {
            return [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:info.sobjectType objectId:id fields:fields];
        }
    }
}

-(NSDictionary*) parseIdsFromResponse:(NSDictionary*) refIdToResponses {
    NSMutableDictionary* refIdToId = [NSMutableDictionary new];
    for (NSString* refId in [refIdToResponses allKeys]) {
        NSDictionary * response = refIdToResponses[refId];
        if (response[@"httpStatusCode"] == @201) {
            NSString* serverId = response[@"body"][@"id"];
            refIdToId[refId] = serverId;
        }
    }
    return refIdToId;
}

-(NSDictionary*) parseStatusCodesFromResponse:(NSDictionary*) refIdToResponses {
    NSMutableDictionary* refIdToStatusCode = [NSMutableDictionary new];
    for (NSString* refId in [refIdToResponses allKeys]) {
        NSDictionary * response = refIdToResponses[refId];
        NSNumber* statusCode = response[@"httpStatusCode"];
        refIdToStatusCode[refId] = statusCode;
    }
    return refIdToStatusCode;
}

- (BOOL) updateParentRecordInLocalStore:(SFSmartSyncSyncManager *)syncManager
                                 record:(NSDictionary *)record
                               children:(NSArray*)children
                              mergeMode:(SFSyncStateMergeMode)mergeMode
                        refIdToServerId:(NSDictionary *)refIdToServerId
                      refIdToStatusCode:(NSDictionary *)refIdToStatusCode {
    BOOL needReRun = NO;
/*
    final String soupName = parentInfo.soupName;
    final String idFieldName = getIdFieldName();
    final String refId = record.getString(idFieldName);

    final Integer statusCode = refIdToHttpStatusCode.containsKey(refId) ? refIdToHttpStatusCode.get(refId) : -1;

    // Delete case
    if (isLocallyDeleted(record)) {
        if (isLocallyCreated(record)  // we didn't go to the sever
                || RestResponse.isSuccess(statusCode) // or we successfully deleted on the server
                || statusCode == HttpURLConnection.HTTP_NOT_FOUND) // or the record was already deleted on the server
        {
            if (relationshipType == RelationshipType.MASTER_DETAIL) {
                ParentChildrenSyncTargetHelper.deleteChildrenFromLocalStore(syncManager.getSmartStore(), parentInfo, childrenInfo, record.getString(idFieldName));
            }

            deleteFromLocalStore(syncManager, soupName, record);
        }
    }

        // Create / update case
    else {
        // Success case
        if (RestResponse.isSuccess(statusCode))
        {
            // Plugging server id in id field
            updateReferences(record, idFieldName, refIdToServerId);

            // Clean and save
            cleanAndSaveInLocalStore(syncManager, soupName, record);
        }
            // Handling remotely deleted records
        else if (statusCode == HttpURLConnection.HTTP_NOT_FOUND) {
            // Record needs to be recreated
            if (mergeMode == SyncState.MergeMode.OVERWRITE) {

                record.put(LOCAL, true);
                record.put(LOCALLY_CREATED, true);

                // Children need to be updated or recreated as well (since the parent will get a new server id)
                for (int i=0; i<children.length(); i++) {
                    JSONObject childRecord = children.getJSONObject(i);
                    childRecord.put(LOCAL, true);
                    childRecord.put(relationshipType == RelationshipType.MASTER_DETAIL ? LOCALLY_CREATED : LOCALLY_UPDATED, true);
                }

                needReRun = true;
            }
        }
    }
*/
    return needReRun;
}

- (BOOL) updateChildRecordInLocalStore:(SFSmartSyncSyncManager *)syncManager
                                 record:(NSDictionary *)record
                              mergeMode:(SFSyncStateMergeMode)mergeMode
                        refIdToServerId:(NSDictionary *)refIdToServerId
                      refIdToStatusCode:(NSDictionary *)refIdToStatusCode {
    BOOL needReRun = NO;
/*
    final String soupName = childrenInfo.soupName;
    final String idFieldName = childrenInfo.idFieldName;
    final String refId = record.getString(idFieldName);

    final Integer statusCode = refIdToHttpStatusCode.containsKey(refId) ? refIdToHttpStatusCode.get(refId) : -1;

    // Delete case
    if (isLocallyDeleted(record)) {
        if (isLocallyCreated(record)  // we didn't go to the sever
                || RestResponse.isSuccess(statusCode) // or we successfully deleted on the server
                || statusCode == HttpURLConnection.HTTP_NOT_FOUND) // or the record was already deleted on the server
        {
            deleteFromLocalStore(syncManager, soupName, record);
        }
    }

        // Create / update case
    else {
        // Success case
        if (RestResponse.isSuccess(statusCode))
        {
            // Plugging server id in id field
            updateReferences(record, idFieldName, refIdToServerId);

            // Plugging server id in parent id field
            updateReferences(record, childrenInfo.parentIdFieldName, refIdToServerId);

            // Clean and save
            cleanAndSaveInLocalStore(syncManager, soupName, record);
        }
            // Handling remotely deleted records
        else if (statusCode == HttpURLConnection.HTTP_NOT_FOUND) {
            // Record needs to be recreated
            if (mergeMode == SyncState.MergeMode.OVERWRITE) {

                record.put(LOCAL, true);
                record.put(LOCALLY_CREATED, true);

                // We need a re-run
                needReRun = true;
            }
        }
    }
*/
    return needReRun;
}


- (void) updateReferences:(NSMutableDictionary*) record
           fieldWithRefId:(NSString*) fieldWithRefId
          refIdToServerId:(NSDictionary*)refIdToServerId {

    NSString* refId = record[fieldWithRefId];
    if (refId && refIdToServerId[refId]) {
        record[fieldWithRefId] = refIdToServerId[refId];
    }
}

@end
