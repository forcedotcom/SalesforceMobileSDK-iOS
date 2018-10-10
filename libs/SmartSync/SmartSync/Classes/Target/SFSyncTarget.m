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

#import "SFSyncTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncSyncManager.h"
#import <SmartStore/SFQuerySpec.h>
#import <SmartStore/SFSmartStore.h>

// Page size
NSUInteger const kSyncTargetPageSize = 2000;

// soups and soup fields
NSString * const kSyncTargetLocal = @"__local__";
NSString * const kSyncTargetLocallyCreated = @"__locally_created__";
NSString * const kSyncTargetLocallyUpdated = @"__locally_updated__";
NSString * const kSyncTargetLocallyDeleted = @"__locally_deleted__";
NSString * const kSyncTargetSyncId = @"__sync_id__";
NSString * const kSyncTargetLastError = @"__last_error__";

@implementation SFSyncTarget

- (instancetype)init {
    self = [super init];
    if (self) {
        self.idFieldName = kId;
        self.modificationDateFieldName = kLastModifiedDate;
    }
    return self;
}

#pragma mark - From/to dictionary

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (dict == nil) return nil;
    
    self = [super init];
    if (self) {
        NSString *idFieldName = dict[kSFSyncTargetIdFieldNameKey];
        NSString *modificationDateFieldName = dict[kSFSyncTargetModificationDateFieldNameKey];
        self.idFieldName = (idFieldName.length > 0 ? idFieldName : kId);
        self.modificationDateFieldName = (modificationDateFieldName.length > 0 ? modificationDateFieldName : kLastModifiedDate);
    }
    return self;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kSFSyncTargetiOSImplKey] = NSStringFromClass([self class]);
    dict[kSFSyncTargetIdFieldNameKey] = self.idFieldName;
    dict[kSFSyncTargetModificationDateFieldNameKey] = self.modificationDateFieldName;
    return dict;
}

#pragma mark - Public methods

- (void) cleanAndSaveInLocalStore:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName record:(NSDictionary*)record {
    [SFSDKSmartSyncLogger d:[self class] format:@"cleanAndSaveInLocalStore:%@", record];
    [self saveInSmartStore:syncManager.store soupName:soupName records:@[record] idFieldName:self.idFieldName syncId:nil lastError:nil cleanFirst:YES /* method called from sync up - not setting syncId field then */];
}

- (void)cleanAndSaveRecordsToLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName records:(NSArray *)records syncId:(NSNumber *)syncId {
    [self saveInSmartStore:syncManager.store soupName:soupName records:records idFieldName:self.idFieldName syncId:syncId lastError:nil cleanFirst:YES];
}

- (void) deleteRecordsFromLocalStore:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName ids:(NSArray*)ids idField:(NSString*)idField {
    if (ids.count > 0) {
        NSString *smartSql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} IN ('%@')",
                                                        soupName, SOUP_ENTRY_ID, soupName, soupName, idField,
                                                        [ids componentsJoinedByString:@"','"]];

        SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
        [syncManager.store removeEntriesByQuery:querySpec fromSoup:soupName];
    }
}


- (BOOL) isLocallyCreated:(NSDictionary*)record {
    return [record[kSyncTargetLocallyCreated] boolValue];
}

- (BOOL) isLocallyUpdated:(NSDictionary*)record {
    return [record[kSyncTargetLocallyUpdated] boolValue];
}

- (BOOL) isLocallyDeleted:(NSDictionary*)record {
    return [record[kSyncTargetLocallyDeleted] boolValue];
}

- (BOOL) isDirty:(NSDictionary*)record {
    return [record[kSyncTargetLocal] boolValue];
}

- (NSOrderedSet*) getDirtyRecordIds:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName idField:(NSString*)idField {
    NSString* dirtyRecordSql = [self getDirtyRecordIdsSql:soupName idField:idField];
    return [self getIdsWithQuery:dirtyRecordSql syncManager:syncManager];

}

- (NSDictionary*) getFromLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString*)soupName storeId:(NSNumber*)storeId {
    return [syncManager.store retrieveEntries:@[storeId] fromSoup:soupName][0];
}

- (void) deleteFromLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString*)soupName record:(NSDictionary*)record {
    [SFSDKSmartSyncLogger d:[self class] format:@"deleteFromLocalStore:%@", record];
    [syncManager.store removeEntries:@[record[SOUP_ENTRY_ID]] fromSoup:soupName];
}

#pragma mark - Helper methods

- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
    return [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = '1' ORDER BY {%@:%@} ASC",
                                      soupName, idField, soupName, soupName, kSyncTargetLocal, soupName, idField];
}

- (NSOrderedSet *)getIdsWithQuery:idsSql syncManager:(SFSmartSyncSyncManager *)syncManager {
    NSMutableOrderedSet* ids = [NSMutableOrderedSet new];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:idsSql withPageSize:kSyncTargetPageSize];

    BOOL hasMore = YES;
    for (NSUInteger pageIndex=0; hasMore; pageIndex++) {
        NSArray* results = [syncManager.store queryWithQuerySpec:querySpec pageIndex:pageIndex error:nil];
        hasMore = (results.count == kSyncTargetPageSize);
        [ids addObjectsFromArray:[self flatten:results]];
    }
    return ids;
}

- (void)saveInLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName records:(NSArray *)records idFieldName:(NSString *)idFieldName syncId:(NSNumber *)syncId lastError:(NSString *)lastError cleanFirst:(BOOL)cleanFirst {
    [self saveInSmartStore:syncManager.store soupName:soupName records:records idFieldName:idFieldName syncId:syncId lastError:lastError cleanFirst:cleanFirst];
}

- (void)saveInSmartStore:(SFSmartStore *)smartStore soupName:(NSString *)soupName records:(NSArray *)records idFieldName:(NSString *)idFieldName syncId:(NSNumber *)syncId lastError:(NSString *)lastError cleanFirst:(BOOL)cleanFirst  {

    NSMutableArray* recordsFromSmartStore = [NSMutableArray new];
    NSMutableArray* recordsFromServer = [NSMutableArray new];

    for (NSDictionary * record in records) {
        NSMutableDictionary *mutableRecord = [record mutableCopy];
        if (cleanFirst) {
            [self cleanRecord:mutableRecord];
        }
        [self addSyncId:mutableRecord syncId:syncId];
        [self addLastError:mutableRecord lastError:lastError];
        if (mutableRecord[SOUP_ENTRY_ID]) {
            // Record came from smartstore
            [recordsFromSmartStore addObject:mutableRecord];
        } else {
            // Record came from server
            [recordsFromServer addObject:mutableRecord];
        }
    }

    // Saving in bulk
    [smartStore upsertEntries:recordsFromSmartStore toSoup:soupName];
    [smartStore upsertEntries:recordsFromServer toSoup:soupName withExternalIdPath:idFieldName error:nil];

}

- (void) addSyncId:(NSMutableDictionary*)record syncId:(NSNumber*)syncId {
    if (syncId) {
        record[kSyncTargetSyncId] = syncId;
    }
}

- (void) addLastError:(NSMutableDictionary*)record lastError:(NSString*)lastError {
    if (lastError) {
        record[kSyncTargetLastError] = lastError;
    }
}

- (void) cleanRecord:(NSMutableDictionary*)record {
    record[kSyncTargetLocal] = @NO;
    record[kSyncTargetLocallyCreated] = @NO;
    record[kSyncTargetLocallyUpdated] = @NO;
    record[kSyncTargetLocallyDeleted] = @NO;
    record[kSyncTargetLastError] = nil;
}

- (NSArray*) flatten:(NSArray*)results {
    NSMutableArray* flatArray = [NSMutableArray new];
    for (NSArray* row in results) {
        [flatArray addObjectsFromArray:row];
    }
    return flatArray;
}

@end
