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
#import "SFParentChildrenSyncHelper.h"
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>

static NSString * const kSFAppFeatureRelatedRecords = @"RR";

@implementation SFParentChildrenSyncHelper

NSString * const kSFParentChildrenSyncTargetParent = @"parent";
NSString * const kSFParentChildrenSyncTargetChildren = @"children";
NSString * const kSFParentChildrenSyncTargetRelationshipType = @"relationshipType";
NSString * const kSFParentChildrenSyncTargetParentFieldlist = @"parentFieldlist";
NSString * const kSFParentChildrenSyncTargetParentCreateFieldlist = @"parentCreateFieldlist";
NSString * const kSFParentChildrenSyncTargetParentUpdateFieldlist = @"parentUpdateFieldlist";
NSString * const kSFParentChildrenSyncTargetParentSoqlFilter = @"parentSoqlFilter";
NSString * const kSFParentChildrenSyncTargetChildrenFieldlist = @"childrenFieldlist";
NSString * const kSFParentChildrenSyncTargetChildrenCreateFieldlist = @"childrenCreateFieldlist";
NSString * const kSFParentChildrenSyncTargetChildrenUpdateFieldlist = @"childrenUpdateFieldlist";
NSString * const kSFParentChildrenRelationshipMasterDetail = @"MASTER_DETAIL";
NSString * const kSFParentChildrenRelationshipLookup = @"LOOKUP";

#pragma mark - App feature registration
+ (void) registerAppFeature {
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureRelatedRecords];
}

#pragma mark - String to/from enum for query type

+ (SFParentChildrenRelationshipType) relationshipTypeFromString:(NSString*)relationshipType {
    if ([relationshipType isEqualToString:kSFParentChildrenRelationshipMasterDetail]) {
        return SFParentChildrenRelationpshipMasterDetail;
    } else {
        return SFParentChildrenRelationpshipLookup;
    }
}

+ (NSString*) relationshipTypeToString:(SFParentChildrenRelationshipType)relationshipType {
    switch (relationshipType) {
        case SFParentChildrenRelationpshipMasterDetail:  return kSFParentChildrenRelationshipMasterDetail;
        case SFParentChildrenRelationpshipLookup: return kSFParentChildrenRelationshipLookup;
    }
    return nil;
}

#pragma mark - Other methods

+ (NSString*) getDirtyRecordIdsSql:(SFParentInfo*)parentInfo childrenInfo:(SFChildrenInfo*)childrenInfo parentFieldToSelect:(NSString*)parentFieldToSelect {
    return [NSString stringWithFormat:@"SELECT DISTINCT {%@:%@} FROM {%@} WHERE {%@:%@} = 1 OR EXISTS (SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = {%@:%@} AND {%@:%@} = 1)",
            parentInfo.soupName, parentFieldToSelect, parentInfo.soupName, parentInfo.soupName, kSyncTargetLocal,
            childrenInfo.soupName, childrenInfo.idFieldName, childrenInfo.soupName, childrenInfo.soupName, childrenInfo.parentIdFieldName, parentInfo.soupName, parentInfo.idFieldName, childrenInfo.soupName, kSyncTargetLocal
    ];
}

+ (NSString *)getNonDirtyRecordIdsSql:(SFParentInfo *)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo parentFieldToSelect:(NSString *)parentFieldToSelect additionalPredicate:(NSString *)additionalPredicate {
    return [NSString stringWithFormat:@"SELECT DISTINCT {%@:%@} FROM {%@} WHERE {%@:%@} = 0 %@ AND NOT EXISTS (SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = {%@:%@} AND {%@:%@} = 1)",
            parentInfo.soupName, parentFieldToSelect, parentInfo.soupName, parentInfo.soupName, kSyncTargetLocal,
            additionalPredicate,
            childrenInfo.soupName, childrenInfo.idFieldName, childrenInfo.soupName, childrenInfo.soupName, childrenInfo.parentIdFieldName, parentInfo.soupName, parentInfo.idFieldName, childrenInfo.soupName, kSyncTargetLocal
    ];
}

+ (void)saveRecordTreesToLocalStore:(SFSmartSyncSyncManager *)syncManager target:(SFSyncTarget *)target parentInfo:(SFParentInfo *)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo recordTrees:(NSArray *)recordTrees syncId:(NSNumber *)syncId {
    NSMutableArray * parentRecords = [NSMutableArray new];
    NSMutableArray * childrenRecords = [NSMutableArray new];
    for (NSDictionary * recordTree  in recordTrees) {

        NSMutableDictionary * parent = [recordTree mutableCopy];

        // Separating parent from children
        NSArray * children = parent[childrenInfo.sobjectTypePlural];
        [parent removeObjectForKey:childrenInfo.sobjectTypePlural];
        [parentRecords addObject:parent];

        // Put server id of parent in children
        if (children) {
            for (NSDictionary * child in children) {
                NSMutableDictionary * updatedChild = [child mutableCopy];
                updatedChild[childrenInfo.parentIdFieldName] = parent[parentInfo.idFieldName];
                [childrenRecords addObject:updatedChild];
            }
        }
    }

    // Saving parents
    [target saveInLocalStore:syncManager soupName:parentInfo.soupName records:parentRecords idFieldName:parentInfo.idFieldName syncId:syncId lastError:nil cleanFirst:YES];
    
    // Saving children
    [target saveInLocalStore:syncManager soupName:childrenInfo.soupName records:childrenRecords idFieldName:childrenInfo.idFieldName syncId:syncId lastError:nil cleanFirst:YES];
}

+ (NSArray<NSMutableDictionary*> *)getMutableChildrenFromLocalStore:(SFSmartStore *)store parentInfo:(SFParentInfo *)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo parent:(NSDictionary *)parent {
    SFQuerySpec*  querySpec = [self getQueryForChildren:parentInfo childrenInfo:childrenInfo childFieldToSelect:@"_soup" parentIds:@[parent[parentInfo.idFieldName]]];
    NSArray<NSMutableDictionary *>* rows = [store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    NSMutableArray * children = [NSMutableArray new];
    for (NSArray* row in rows) {
        [children addObject:[((NSDictionary *)row[0]) mutableCopy]];
    }
    return children;
}

+ (void)deleteChildrenFromLocalStore:(SFSmartStore *)store parentInfo:(SFParentInfo *)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo parentIds:(NSArray *)parentIds {
    SFQuerySpec *querySpec = [self getQueryForChildren:parentInfo childrenInfo:childrenInfo childFieldToSelect:SOUP_ENTRY_ID parentIds:parentIds];
    [store removeEntriesByQuery:querySpec fromSoup:childrenInfo.soupName];
}

+ (SFQuerySpec*) getQueryForChildren:(SFParentInfo*)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo childFieldToSelect:(NSString*)childFieldToSelect parentIds:(NSArray*)parentIds {
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@},{%@} WHERE {%@:%@} = {%@:%@} AND {%@:%@} IN (%@)",
                                                    childrenInfo.soupName, childFieldToSelect,
                                                    childrenInfo.soupName, parentInfo.soupName,
                                                    childrenInfo.soupName, childrenInfo.parentIdFieldName,
                                                    parentInfo.soupName, parentInfo.idFieldName,
                                                    parentInfo.soupName, parentInfo.idFieldName,
                                                    [NSString stringWithFormat:@"('%@')", [parentIds componentsJoinedByString:@"', '"]]
                          ];

    return [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:INT_MAX];
}

@end
