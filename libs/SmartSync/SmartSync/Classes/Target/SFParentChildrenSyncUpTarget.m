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

- (void) syncUpRecord:(SFSmartSyncSyncManager *)syncManager
               record:(NSDictionary*)record
             children:(NSArray<NSDictionary*>*)children
            fieldlist:(NSArray*)fieldlist
            mergeMode:(SFSyncStateMergeMode)mergeMode
      completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
            failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    BOOL isCreate = [self isLocallyCreated:record];
    BOOL isDelete = [self isLocallyDeleted:record];

    NSMutableArray *refIds = [NSMutableArray new];
    NSMutableArray *requests = [NSMutableArray new];

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

    /*

        // Sending composite request
        Map<String, JSONObject> refIdToResponses = sendCompositeRequest(syncManager, false, refIdToRequests);

        // Build refId to server id / status code / time stamp maps
        Map<String, String> refIdToServerId = parseIdsFromResponse(refIdToResponses);
        Map<String, Integer> refIdToHttpStatusCode = parseStatusCodesFromResponse(refIdToResponses);

        // Will a re-run be required?
        boolean needReRun = false;

        // Update parent in local store
        if (isDirty(record)) {
            needReRun = updateParentRecordInLocalStore(syncManager, record, children, mergeMode, refIdToServerId, refIdToHttpStatusCode);
        }

        // Update children local store
        for (int i = 0; i < children.length(); i++) {
            JSONObject childRecord = children.getJSONObject(i);
            if (isDirty(childRecord) || isCreate) {
                needReRun = needReRun || updateChildRecordInLocalStore(syncManager, childRecord, mergeMode, refIdToServerId, refIdToHttpStatusCode);
            }
        }

        // Re-run if required
        if (needReRun) {
            syncManager.getLogger().d(this, "syncUpOneRecord", record);
            syncUpRecord(syncManager, record, children, fieldlist, mergeMode);
        }

     */
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

- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
     return [SFParentChildrenSyncHelper getDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}

@end
