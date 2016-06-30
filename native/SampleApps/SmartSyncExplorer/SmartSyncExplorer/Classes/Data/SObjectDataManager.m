/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SObjectDataManager.h"
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>

// Will go away once we are done refactoring SFSyncTarget
#import <SmartSync/SFSoqlSyncDownTarget.h>

static NSUInteger kMaxQueryPageSize = 1000;
static NSUInteger kSyncLimit = 10000;
static char* const kSearchFilterQueueName = "com.salesforce.smartSyncExplorer.searchFilterQueue";

@interface SObjectDataManager ()
{
    dispatch_queue_t _searchFilterQueue;
}

@property (nonatomic, strong) SFSmartSyncSyncManager *syncMgr;
@property (nonatomic, strong) SObjectDataSpec *dataSpec;
@property (nonatomic, strong) NSArray *fullDataRowList;
@property (nonatomic, copy) SFSyncSyncManagerUpdateBlock syncCompletionBlock;
@property (nonatomic) NSInteger syncDownId;

@end

@implementation SObjectDataManager

- (id)initWithDataSpec:(SObjectDataSpec *)dataSpec {
    self = [super init];
    if (self) {
        self.syncMgr = [SFSmartSyncSyncManager sharedInstance:[SFUserAccountManager sharedInstance].currentUser];
        self.dataSpec = dataSpec;
        _searchFilterQueue = dispatch_queue_create(kSearchFilterQueueName, NULL);
    }
    return self;
}

- (void)dealloc {
}

- (SFSmartStore *)store {
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (void)refreshRemoteData:(void (^)(void))completionBlock {
    if (![self.store soupExists:self.dataSpec.soupName]) {
        [self registerSoup];
    }
    
    __weak SObjectDataManager *weakSelf = self;
    SFSyncSyncManagerUpdateBlock updateBlock = ^(SFSyncState* sync) {
        if ([sync isDone] || [sync hasFailed]) {
            weakSelf.syncDownId = sync.syncId;
            [weakSelf refreshLocalData:completionBlock];
        }
    };

    
    if (self.syncDownId == 0) {
        // first time
        NSString *soqlQuery = [NSString stringWithFormat:@"SELECT %@ FROM %@ LIMIT %lu", [self.dataSpec.fieldNames componentsJoinedByString:@","], self.dataSpec.objectType, (unsigned long)kSyncLimit];
        SFSyncOptions *syncOptions = [SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged];
        SFSyncDownTarget *syncTarget = [SFSoqlSyncDownTarget newSyncTarget:soqlQuery];
        [self.syncMgr syncDownWithTarget:syncTarget options:syncOptions soupName:self.dataSpec.soupName updateBlock:updateBlock];
    }
    else {
        // subsequent times
        [self.syncMgr reSync:[NSNumber numberWithInteger:self.syncDownId] updateBlock:updateBlock];
    }
}

- (void)updateRemoteData:(SFSyncSyncManagerUpdateBlock)completionBlock {
    SFSyncOptions *syncOptions = [SFSyncOptions newSyncOptionsForSyncUp:self.dataSpec.fieldNames mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    [self.syncMgr syncUpWithOptions:syncOptions soupName:self.dataSpec.soupName updateBlock:^(SFSyncState* sync) {
        if ([sync isDone] || [sync hasFailed]) {
            completionBlock(sync);
        }
    }];
}

- (void)filterOnSearchTerm:(NSString *)searchTerm completion:(void (^)(void))completionBlock {
    dispatch_async(_searchFilterQueue, ^{
        self.dataRows = self.fullDataRowList;
        if (self.dataRows == nil) {
            // No data yet.
            return;
        }
        
        if ([searchTerm length] > 0) {
            NSMutableArray *matchingDataRows = [NSMutableArray array];
            for (SObjectData *data in [self.fullDataRowList copy]) {
                SObjectDataSpec *dataSpec = [[data class] dataSpec];
                for (SObjectDataFieldSpec *fieldSpec in dataSpec.objectFieldSpecs) {
                    if (fieldSpec.isSearchable) {
                        // TODO: Generalize field value type, abstract search through a search protocol.
                        NSString *fieldValue = [data fieldValueForFieldName:fieldSpec.fieldName];
                        if (fieldValue != nil && [fieldValue rangeOfString:searchTerm options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location != NSNotFound) {
                            [matchingDataRows addObject:data];
                            break;
                        }
                    }
                }
            }
            
            self.dataRows = matchingDataRows;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), completionBlock);
        }
    });
}

#pragma mark - Private methods

- (void)registerSoup {
    NSString *soupName = self.dataSpec.soupName;
    NSArray *indexSpecs = self.dataSpec.indexSpecs;
    [self.store registerSoup:soupName withIndexSpecs:indexSpecs error:nil];
}

- (void)refreshLocalData:(void (^)(void))completionBlock {
    if (![self.store soupExists:self.dataSpec.soupName]) {
        [self registerSoup];
    }
    
    SFQuerySpec *sobjectsQuerySpec = [SFQuerySpec newAllQuerySpec:self.dataSpec.soupName withOrderPath:self.dataSpec.orderByFieldName withOrder:kSFSoupQuerySortOrderAscending withPageSize:kMaxQueryPageSize];
    NSError *queryError = nil;
    NSArray *queryResults = [self.store queryWithQuerySpec:sobjectsQuerySpec pageIndex:0 error:&queryError];
    [self log:SFLogLevelDebug msg:@"Got local query results.  Populating data rows."];
    if (queryError) {
        [self log:SFLogLevelError format:@"Error retrieving '%@' data from SmartStore: %@", self.dataSpec.objectType, [queryError localizedDescription]];
        return;
    }
    
    self.fullDataRowList = [self populateDataRows:queryResults];
    [self log:SFLogLevelDebug format:@"Finished generating data rows.  Number of rows: %d.  Refreshing view.", [self.fullDataRowList count]];
    self.dataRows = [self.fullDataRowList copy];
    if (completionBlock) completionBlock();
}

- (void)createLocalData:(SObjectData *)newData {
    [newData updateSoupForFieldName:kSyncManagerLocal fieldValue:@YES];
    [newData updateSoupForFieldName:kSyncManagerLocallyCreated fieldValue:@YES];
    [self.store upsertEntries:@[ newData.soupDict ] toSoup:[[newData class] dataSpec].soupName];
}

- (void)updateLocalData:(SObjectData *)updatedData {
    [updatedData updateSoupForFieldName:kSyncManagerLocal fieldValue:@YES];
    [updatedData updateSoupForFieldName:kSyncManagerLocallyUpdated fieldValue:@YES];
    [self.store upsertEntries:@[ updatedData.soupDict ] toSoup:[[updatedData class] dataSpec].soupName withExternalIdPath:kSObjectIdField error:nil];
}

- (void)deleteLocalData:(SObjectData *)dataToDelete {
    [dataToDelete updateSoupForFieldName:kSyncManagerLocal fieldValue:@YES];
    [dataToDelete updateSoupForFieldName:kSyncManagerLocallyDeleted fieldValue:@YES];
    [self.store upsertEntries:@[ dataToDelete.soupDict ] toSoup:[[dataToDelete class] dataSpec].soupName withExternalIdPath:kSObjectIdField error:nil];
}

- (void)undeleteLocalData:(SObjectData *)dataToUnDelete {
    [dataToUnDelete updateSoupForFieldName:kSyncManagerLocallyDeleted fieldValue:@NO];
    NSNumber* locallyCreatedOrUpdated = [NSNumber numberWithBool:[self dataLocallyCreated:dataToUnDelete] || [self dataLocallyUpdated:dataToUnDelete]];
    [dataToUnDelete updateSoupForFieldName:kSyncManagerLocal fieldValue:locallyCreatedOrUpdated];
    [self.store upsertEntries:@[ dataToUnDelete.soupDict ] toSoup:[[dataToUnDelete class] dataSpec].soupName withExternalIdPath:kSObjectIdField error:nil];
}

- (BOOL)dataHasLocalChanges:(SObjectData *)data {
    return [[data fieldValueForFieldName:kSyncManagerLocal] boolValue];
}

- (BOOL)dataLocallyCreated:(SObjectData *)data {
    return [[data fieldValueForFieldName:kSyncManagerLocallyCreated] boolValue];
}

- (BOOL)dataLocallyUpdated:(SObjectData *)data {
    return [[data fieldValueForFieldName:kSyncManagerLocallyUpdated] boolValue];
}

- (BOOL)dataLocallyDeleted:(SObjectData *)data {
    return [[data fieldValueForFieldName:kSyncManagerLocallyDeleted] boolValue];
}

- (NSArray *)populateDataRows:(NSArray *)queryResults {
    NSMutableArray *mutableDataRows = [NSMutableArray arrayWithCapacity:[queryResults count]];
    for (NSDictionary *soup in queryResults) {
        [mutableDataRows addObject:[[self.dataSpec class] createSObjectData:soup]];
    }
    return mutableDataRows;
}

@end
