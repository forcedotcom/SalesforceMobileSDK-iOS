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
#import "SFSyncDownTarget+Internal.h"
#import "SFSoqlSyncDownTarget+Internal.h"
#import "SFParentChildrenSyncDownTarget.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSmartSyncConstants.h"
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>

@interface SFParentChildrenSyncDownTarget ()

@property (nonatomic) SFParentInfo* parentInfo;
@property (nonatomic) NSArray<NSString*>* parentFieldlist;
@property (nonatomic) NSString* parentSoqlFilter;
@property (nonatomic) SFChildrenInfo* childrenInfo;
@property (nonatomic) NSArray<NSString*>* childrenFieldlist;
@property (nonatomic) SFParentChildrenRelationshipType relationshipType;

@end

@implementation SFParentChildrenSyncDownTarget

- (instancetype)initWithParentInfo:(SFParentInfo *)parentInfo
                   parentFieldlist:(NSArray<NSString *> *)parentFieldlist
                  parentSoqlFilter:(NSString *)parentSoqlFilter
                      childrenInfo:(SFChildrenInfo *)childrenInfo
                 childrenFieldlist:(NSArray<NSString *> *)childrenFieldlist
                  relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeParentChildren;
        self.parentInfo = parentInfo;
        self.idFieldName = parentInfo.idFieldName;
        self.modificationDateFieldName = parentInfo.modificationDateFieldName;
        self.parentFieldlist = parentFieldlist;
        self.parentSoqlFilter = parentSoqlFilter;
        self.childrenInfo = childrenInfo;
        self.childrenFieldlist = childrenFieldlist;
        self.relationshipType = relationshipType;
        [SFParentChildrenSyncHelper registerAppFeature];
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithParentInfo:[SFParentInfo newFromDict:dict[kSFParentChildrenSyncTargetParent]]
                    parentFieldlist:dict[kSFParentChildrenSyncTargetParentFieldlist]
                   parentSoqlFilter:dict[kSFParentChildrenSyncTargetParentSoqlFilter]
                       childrenInfo:[SFChildrenInfo newFromDict:dict[kSFParentChildrenSyncTargetChildren]]
                  childrenFieldlist:dict[kSFParentChildrenSyncTargetChildrenFieldlist]
                   relationshipType:[SFParentChildrenSyncHelper relationshipTypeFromString:dict[kSFParentChildrenSyncTargetRelationshipType]]];
}


#pragma mark - Factory methods

+ (instancetype)newSyncTargetWithParentInfo:(SFParentInfo *)parentInfo
                            parentFieldlist:(NSArray<NSString *> *)parentFieldlist
                           parentSoqlFilter:(NSString *)parentSoqlFilter
                               childrenInfo:(SFChildrenInfo *)childrenInfo
                          childrenFieldlist:(NSArray<NSString *> *)childrenFieldlist
                           relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    return [[SFParentChildrenSyncDownTarget alloc] initWithParentInfo:parentInfo
                                                      parentFieldlist:parentFieldlist
                                                     parentSoqlFilter:parentSoqlFilter
                                                         childrenInfo:childrenInfo
                                                    childrenFieldlist:childrenFieldlist
                                                     relationshipType:relationshipType];
}

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFParentChildrenSyncDownTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFParentChildrenSyncTargetParent] = [self.parentInfo asDict];
    dict[kSFParentChildrenSyncTargetParentFieldlist] = self.parentFieldlist;
    dict[kSFParentChildrenSyncTargetParentSoqlFilter] = self.parentSoqlFilter;
    dict[kSFParentChildrenSyncTargetChildren] = [self.childrenInfo asDict];
    dict[kSFParentChildrenSyncTargetChildrenFieldlist] = self.childrenFieldlist;
    dict[kSFParentChildrenSyncTargetRelationshipType] = [SFParentChildrenSyncHelper relationshipTypeToString:self.relationshipType];
    return dict;
}

#pragma mark - Other public methods

- (NSString*) getQueryToRun:(long long)maxTimeStamp {
    NSMutableString * childrenWhere = [NSMutableString new];
    NSMutableString * parentWhere = [NSMutableString new];

    if (maxTimeStamp > 0) {
        // This is for re-sync
        //
        // Ideally we should target parent-children 'groups' where the parent changed or a child changed
        //
        // But that is not possible with SOQL:
        //   select fields, (select childrenFields from children where lastModifiedDate > xxx)
        //   from parent
        //   where lastModifiedDate > xxx
        //   or Id in (select parent-id from children where lastModifiedDate > xxx)
        // Gives the following error: semi join sub-selects are not allowed with the 'OR' operator
        //
        // Also if we do:
        //   select fields, (select childrenFields from children where lastModifiedDate > xxx)
        //   from parent
        //   where Id in (select parent-id from children where lastModifiedDate > xxx or parent.lastModifiedDate > xxx)
        // Then we miss parents without children
        //
        // So we target parent-children 'goups' where the parent changed
        // And we only download the changed children

        [childrenWhere appendString:[self buildModificationDateFilter:self.childrenInfo.modificationDateFieldName maxTimeStamp:maxTimeStamp]];
        [parentWhere appendString:[self buildModificationDateFilter:self.modificationDateFieldName maxTimeStamp:maxTimeStamp]];
        if (self.parentSoqlFilter.length > 0) [parentWhere appendString:@" and "];
    }
    if (self.parentSoqlFilter) [parentWhere appendString:self.parentSoqlFilter];

    // Nested query
    NSMutableArray * nestedFields = [NSMutableArray arrayWithArray:self.childrenFieldlist];
    if (![nestedFields containsObject:self.childrenInfo.idFieldName]) [nestedFields addObject:self.childrenInfo.idFieldName];
    if (![nestedFields containsObject:self.childrenInfo.modificationDateFieldName]) [nestedFields addObject:self.childrenInfo.modificationDateFieldName];
    SFSDKSoqlBuilder * builderNested = [[[SFSDKSoqlBuilder withFieldsArray:nestedFields] from:self.childrenInfo.sobjectTypePlural] whereClause:childrenWhere];

    // Parent query
    NSMutableArray * fields = [NSMutableArray arrayWithArray:self.parentFieldlist];
    if (![fields containsObject:self.idFieldName]) [fields addObject:self.idFieldName];
    if (![fields containsObject:self.modificationDateFieldName]) [fields addObject:self.modificationDateFieldName];
    [fields addObject:[@[@"(", [builderNested build], @")"] componentsJoinedByString:@""]];
    SFSDKSoqlBuilder * builder = [[[SFSDKSoqlBuilder withFieldsArray:fields] from:self.parentInfo.sobjectType] whereClause:parentWhere];

    return [builder build];
}

- (void)cleanGhosts:(SFSmartSyncSyncManager *)syncManager
           soupName:(NSString *)soupName
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    // Taking care of ghost parents
    [super cleanGhosts:syncManager
              soupName:soupName
            errorBlock:errorBlock
         completeBlock:^(NSArray *localIdsArr) {

             // Taking care of ghost children

             // NB: ParentChildrenSyncDownTarget's getNonDirtyRecordIdsSql does a join between parent and children soups
             // We only want to look at the children soup, so using SoqlSyncDownTarget's getNonDirtyRecordIdsSql
             NSMutableOrderedSet* localChildrenIds = [[self getIdsWithQuery:[super getNonDirtyRecordIdsSql:self.childrenInfo.soupName idField:self.childrenInfo.idFieldName] syncManager:syncManager] mutableCopy];

             [self getChildrenRemoteIdsWithSoql:syncManager soqlForChildrenRemoteIds:[self getSoqlForRemoteChildrenIds] errorBlock:errorBlock completeBlock:^(NSArray *remoteChildrenIds) {
                 [localChildrenIds removeObjectsInArray:remoteChildrenIds];

                 // Delete extra IDs from SmartStore.
                 [self deleteRecordsFromLocalStore:syncManager soupName:self.childrenInfo.soupName ids:[localChildrenIds array] idField:self.childrenInfo.idFieldName];

                 completeBlock(localIdsArr);
             }];
    }];
}

- (long long)getLatestModificationTimeStamp:(NSArray *)records {
     // NB: method is called during sync down so for this target records contain parent and children

    // Compute max time stamp of parents
    long long maxTimeStamp = [super getLatestModificationTimeStamp:records];

    // Compute max time stamp of parents and children
    for (NSDictionary * record in records) {
        NSArray* children = record[self.childrenInfo.sobjectTypePlural];
        long long maxTimeStampChildren = [super getLatestModificationTimeStamp:children modificationDateFieldName:self.childrenInfo.modificationDateFieldName];
        maxTimeStamp = (maxTimeStamp > maxTimeStampChildren ? maxTimeStamp : maxTimeStampChildren);
    }

    return maxTimeStamp;
}

- (void)saveRecordsToLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName records:(NSArray *)records {
    // NB: method is called during sync down so for this target records contain parent and children

    return [SFParentChildrenSyncHelper saveRecordTreesToLocalStore:syncManager target:self parentInfo:self.parentInfo childrenInfo:self.childrenInfo recordTrees:records];
}

#pragma mark - Utility methods

- (NSString*) buildModificationDateFilter:(NSString*)modificationDateFieldName maxTimeStamp:(long long)maxTimeStamp
{
    return [@[modificationDateFieldName, @" > ", [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp]] componentsJoinedByString:@""];
}


- (NSString *)getSoqlForRemoteIds {
    // This is for clean re-sync ghosts
    //
    // This is the soql to identify parents

    SFSDKSoqlBuilder * builder = [[[SFSDKSoqlBuilder withFieldsArray:@[self.idFieldName]] from:self.parentInfo.sobjectType] whereClause:self.parentSoqlFilter];

    return [builder build];
}

- (NSString *)getSoqlForRemoteChildrenIds {
    // This is for clean re-sync ghosts
    //
    // This is the soql to identify children

    // We are doing
    //  select Id, (select Id from children) from Parents where soqlParentFilter
    // It could be better to do
    //  select Id from child where qualified-soqlParentFilter (e.g. if filter is Name = 'A' then we would use Parent.Name = 'A')
    // But "qualifying" parentSoqlFilter without parsing it could prove tricky

    // Nested query
    SFSDKSoqlBuilder * builderNested = [[SFSDKSoqlBuilder withFieldsArray:@[self.childrenInfo.idFieldName]] from:self.childrenInfo.sobjectTypePlural];

    // Parent query
    NSArray* fields = @[self.idFieldName, [@[@"(", [builderNested build], @")"] componentsJoinedByString:@""]];
    SFSDKSoqlBuilder * builder = [[[SFSDKSoqlBuilder withFieldsArray:fields] from:self.parentInfo.sobjectType] whereClause:self.parentSoqlFilter];

    return [builder build];
}

- (void)getChildrenRemoteIdsWithSoql:(SFSmartSyncSyncManager *)syncManager
        soqlForChildrenRemoteIds:(NSString *)soqlForChildrenRemoteIds
          errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
       completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __block NSMutableSet *remoteChildrenIds = [NSMutableSet new];
    __block SFSyncDownTargetFetchCompleteBlock fetchBlockRecurse = ^(NSArray *records) {
    };
    SFSyncDownTargetFetchCompleteBlock fetchBlock = ^(NSArray *records) {
        if (records == nil) {
            completeBlock([remoteChildrenIds allObjects]);
            return;
        }
        [remoteChildrenIds unionSet:[self parseChildrenIdsFromResponse:records]];
        [self continueFetch:syncManager errorBlock:errorBlock completeBlock:fetchBlockRecurse];
    };
    fetchBlockRecurse = fetchBlock;
    [self startFetch:syncManager queryToRun:soqlForChildrenRemoteIds errorBlock:errorBlock completeBlock:fetchBlock];
}

- (NSSet<NSString*>*) parseChildrenIdsFromResponse:(NSArray*)records {
    NSMutableSet<NSString*>* remoteChildrenIds = [NSMutableSet new];
    for (NSDictionary * record in records) {
        [remoteChildrenIds unionSet:[super parseIdsFromResponse:record[self.childrenInfo.sobjectTypePlural]]];
    }
    return remoteChildrenIds;
}

- (NSArray<NSDictionary *> *)getRecordsFromResponse:(NSDictionary *)responseJson {
    NSMutableArray<NSDictionary *> * records = [NSMutableArray new];

    for (NSDictionary * originalRecord in responseJson[kResponseRecords]) {
        NSObject* children = originalRecord[self.childrenInfo.sobjectTypePlural];
        BOOL hasChildren = children && children != [NSNull null];
        NSArray<NSDictionary *> *childrenRecords = @[];
        if (hasChildren) {
            childrenRecords = originalRecord[self.childrenInfo.sobjectTypePlural][kResponseRecords];
        }
        // Cleaning up record
        NSMutableDictionary *record = [originalRecord mutableCopy];
        record[self.childrenInfo.sobjectTypePlural] = childrenRecords;
        // XXX what if not all children were fetched
        [records addObject:record];
    }

    return records;
}

- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
     return [SFParentChildrenSyncHelper getDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}


- (NSString*) getNonDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
    return [SFParentChildrenSyncHelper getNonDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}


@end
