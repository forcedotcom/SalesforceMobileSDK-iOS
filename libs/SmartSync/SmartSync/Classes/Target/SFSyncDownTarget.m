/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFSoupIndex.h>
#import "SFSyncTarget+Internal.h"
#import "SFMruSyncDownTarget.h"
#import "SFRefreshSyncDownTarget.h"
#import "SFSoqlSyncDownTarget.h"
#import "SFSoslSyncDownTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFParentChildrenSyncDownTarget.h"

// query types
NSString * const kSFSyncTargetQueryTypeMru = @"mru";
NSString * const kSFSyncTargetQueryTypeSoql = @"soql";
NSString * const kSFSyncTargetQueryTypeSosl = @"sosl";
NSString * const kSFSyncTargetQueryTypeRefresh = @"refresh";
NSString * const kSFSyncTargetQueryTypeParentChidlren = @"parentChildren";
NSString * const kSFSyncTargetQueryTypeCustom = @"custom";

@implementation SFSyncDownTarget

#pragma mark - Initialization and serialization methods

+ (SFSyncDownTarget*) newFromDict:(NSDictionary*)dict {
    // We should have an implementation class or a target type
    NSString* implClassName = dict[kSFSyncTargetiOSImplKey];
    if (implClassName.length > 0) {
        Class customSyncDownClass = NSClassFromString(implClassName);
        if (![customSyncDownClass isSubclassOfClass:[SFSyncDownTarget class]]) {
            [SFSDKSmartSyncLogger e:[self class] format:@"%@ Class '%@' is not a subclass of %@.", NSStringFromSelector(_cmd), implClassName, NSStringFromClass([SFSyncDownTarget class])];
            return nil;
        } else {
            return [[customSyncDownClass alloc] initWithDict:dict];
        }
    }
    // No implementation class - using query type
    else {
        switch ([SFSyncDownTarget queryTypeFromString:dict[kSFSyncTargetTypeKey]]) {
            case SFSyncDownTargetQueryTypeMru:
                return [[SFMruSyncDownTarget alloc] initWithDict:dict];
            case SFSyncDownTargetQueryTypeSosl:
                return [[SFSoslSyncDownTarget alloc] initWithDict:dict];
            case SFSyncDownTargetQueryTypeSoql:
                return [[SFSoqlSyncDownTarget alloc] initWithDict:dict];
            case SFSyncDownTargetQueryTypeRefresh:
                return [[SFRefreshSyncDownTarget alloc] initWithDict:dict];
            case SFSyncDownTargetQueryTypeParentChildren:
                return [[SFParentChildrenSyncDownTarget alloc] initWithDict:dict];
            case SFSyncDownTargetQueryTypeCustom:
                [SFSDKSmartSyncLogger e:[self class] format:@"%@ Custom class name not specified.", NSStringFromSelector(_cmd)];
                return nil;
        }
    }
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetTypeKey] = [[self class] queryTypeToString:self.queryType];
    return dict;
}

# pragma mark - Public sync down methods

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock
ABSTRACT_METHOD

- (void) continueFetch:(SFSmartSyncSyncManager*)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock {
    completeBlock(nil);
}

- (void) getRemoteIds:(SFSmartSyncSyncManager*)syncManager
        localIds:(NSArray *)localIds
      errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
   completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock ABSTRACT_METHOD

- (long long)getLatestModificationTimeStamp:(NSArray*)records {
    return [self getLatestModificationTimeStamp:records modificationDateFieldName:self.modificationDateFieldName];
}

- (void)cleanGhosts:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName syncId:(NSNumber *)syncId errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    // Fetches list of IDs present in local soup that have not been modified locally.
    NSMutableOrderedSet *localIds = [NSMutableOrderedSet orderedSetWithOrderedSet:[self getNonDirtyRecordIds:syncManager
                                                                                                    soupName:soupName
                                                                                                     idField:self.idFieldName
                                                                                         additionalPredicate:[self buildSyncIdPredicateIfIndexed:syncManager soupName:soupName syncId:syncId]]];

    // Fetches list of IDs still present on the server from the list of local IDs
    // and removes the list of IDs that are still present on the server.
    NSArray *localIdsArr = [localIds array];
    [self getRemoteIds:syncManager
              localIds:localIdsArr
            errorBlock:errorBlock
         completeBlock:^(NSArray *remoteIds) {
             [localIds removeObjectsInArray:remoteIds];

             // Deletes extra IDs from SmartStore.
             [self deleteRecordsFromLocalStore:syncManager soupName:soupName ids:localIdsArr idField:self.idFieldName];
             completeBlock(localIdsArr);
         }];
}

- (NSString*) buildSyncIdPredicateIfIndexed:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName syncId:(NSNumber *)syncId {
    NSArray *indexSpecs = [syncManager.store indicesForSoup:soupName];
    for (SFSoupIndex* indexSpec in indexSpecs) {
        if ([indexSpec.path isEqualToString:kSyncTargetSyncId]) {
            return [NSString stringWithFormat:@"AND {%@:%@} = %@", soupName, kSyncTargetSyncId, [syncId stringValue]];
        }
    }
    return @"";
}

- (NSOrderedSet*) getIdsToSkip:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName {
    return [self getDirtyRecordIds:syncManager soupName:soupName idField:self.idFieldName];
}


#pragma mark - String to/from enum for query type

+ (SFSyncDownTargetQueryType) queryTypeFromString:(NSString*)queryType {
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeSoql]) {
        return SFSyncDownTargetQueryTypeSoql;
    }
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeMru]) {
        return SFSyncDownTargetQueryTypeMru;
    }
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeSosl]) {
        return SFSyncDownTargetQueryTypeSosl;
    }
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeRefresh]) {
        return SFSyncDownTargetQueryTypeRefresh;
    }
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeParentChidlren]) {
        return SFSyncDownTargetQueryTypeParentChildren;
    }
    // Must be custom
    return SFSyncDownTargetQueryTypeCustom;
}

+ (NSString*) queryTypeToString:(SFSyncDownTargetQueryType)queryType {
    switch (queryType) {
        case SFSyncDownTargetQueryTypeMru:  return kSFSyncTargetQueryTypeMru;
        case SFSyncDownTargetQueryTypeSosl: return kSFSyncTargetQueryTypeSosl;
        case SFSyncDownTargetQueryTypeSoql: return kSFSyncTargetQueryTypeSoql;
        case SFSyncDownTargetQueryTypeRefresh: return kSFSyncTargetQueryTypeRefresh;
        case SFSyncDownTargetQueryTypeParentChildren: return kSFSyncTargetQueryTypeParentChidlren;
        case SFSyncDownTargetQueryTypeCustom: return kSFSyncTargetQueryTypeCustom;
    }
}

#pragma mark - Helper methods

- (long long)getLatestModificationTimeStamp:(NSArray*)records modificationDateFieldName:(NSString*)modificationDateFieldName {
    long long maxTimeStamp = -1L;
    for(NSDictionary* record in records) {
        NSString* timeStampStr = record[modificationDateFieldName];
        if (!timeStampStr) {
            break; // LastModifiedDate field not present
        }
        long long timeStamp = [SFSmartSyncObjectUtils getMillisFromIsoString:timeStampStr];
        maxTimeStamp = (timeStamp > maxTimeStamp ? timeStamp : maxTimeStamp);
    }
    return maxTimeStamp;
}


- (NSOrderedSet *)getNonDirtyRecordIds:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate {
    NSString* nonDirtyRecordsSql = [self getNonDirtyRecordIdsSql:soupName idField:idField additionalPredicate:additionalPredicate];
    return [self getIdsWithQuery:nonDirtyRecordsSql syncManager:syncManager];
}

- (NSString *)getNonDirtyRecordIdsSql:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate {
    return [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = '0' %@ ORDER BY {%@:%@} ASC",
                                      soupName, idField, soupName, soupName, kSyncTargetLocal, additionalPredicate, soupName, idField];
}

@end
