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
#import <SmartSync/SFSmartSyncSyncManager.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>

static NSUInteger kMaxQueryPageSize = 10000;
static NSUInteger kSyncLimit = 10000;
static char* const kSearchFilterQueueName = "com.salesforce.smartSyncExplorer.searchFilterQueue";

@interface SObjectDataManager ()
{
    dispatch_queue_t _searchFilterQueue;
}

@property (nonatomic, weak) UITableViewController *parentVc;
@property (nonatomic, strong) SFSmartSyncSyncManager *syncMgr;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SObjectDataSpec *dataSpec;
@property (nonatomic, strong) NSDictionary *sync;
@property (nonatomic, strong) NSArray *fullDataRowList;

@end

@implementation SObjectDataManager

- (id)initWithViewController:(UITableViewController *)parentVc
                    dataSpec:(SObjectDataSpec *)dataSpec {
    self = [super init];
    if (self) {
        self.parentVc = parentVc;
        self.syncMgr = [SFSmartSyncSyncManager sharedInstance:[SFUserAccountManager sharedInstance].currentUser];
        self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
        self.dataSpec = dataSpec;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSyncProgress:) name:kSyncManagerNotification object:nil];
        _searchFilterQueue = dispatch_queue_create(kSearchFilterQueueName, NULL);
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSyncManagerNotification object:nil];
}

- (void)refreshRemoteData {
    if (![self.store soupExists:self.dataSpec.soupName]) {
        [self registerSoup];
    }
    
    NSString *soqlQuery = [NSString stringWithFormat:@"SELECT %@ FROM %@ LIMIT %d", [self.dataSpec.fieldNames componentsJoinedByString:@","], self.dataSpec.objectType, kSyncLimit];
    NSDictionary *syncTarget = @{ kSyncManagerTargetQueryType: kSyncManagerQueryTypeSoql, kSyncManagerTargetQuery: soqlQuery };
    self.sync = [self.syncMgr recordSync:kSyncManagerSyncTypeDown target:syncTarget soupName:self.dataSpec.soupName options:nil];
    NSNumber *syncId = self.sync[kSyncManagerSyncId];
    [self.syncMgr runSync:syncId];
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

- (void)resetDataRows {
    self.dataRows = [self.fullDataRowList copy];
    __weak SObjectDataManager *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.parentVc.tableView reloadData];
    });
}

#pragma mark - Private methods

- (void)registerSoup {
    NSString *soupName = self.dataSpec.soupName;
    NSArray *indexSpecs = self.dataSpec.indexSpecs;
    [self.store registerSoup:soupName withIndexSpecs:indexSpecs];
}

- (void)handleSyncProgress:(NSNotification *)notification {
    NSDictionary *updatedSync = notification.object;
    if (![updatedSync[kSyncManagerSyncId] isEqual:self.sync[kSyncManagerSyncId]]) {
        return;
    }
    
    if ([updatedSync[kSyncManagerSyncStatus] isEqualToString:kSyncManagerStatusDone]) {
        self.sync = nil;
        [self refreshLocalData];
    }
}

- (void)refreshLocalData {
    if (![self.store soupExists:self.dataSpec.soupName]) {
        [self registerSoup];
    }
    
    SFQuerySpec *sobjectsQuerySpec = [SFQuerySpec newAllQuerySpec:self.dataSpec.soupName withPath:self.dataSpec.orderByFieldName withOrder:kSFSoupQuerySortOrderAscending withPageSize:kMaxQueryPageSize];
    NSError *queryError = nil;
    NSArray *queryResults = [self.store queryWithQuerySpec:sobjectsQuerySpec pageIndex:0 error:&queryError];
    if (queryError) {
        [self log:SFLogLevelError format:@"Error retrieving '%@' data from SmartStore: %@", self.dataSpec.objectType, [queryError localizedDescription]];
        return;
    }
    
    self.fullDataRowList = [self populateDataRows:queryResults];
    [self resetDataRows];
}

- (NSArray *)populateDataRows:(NSArray *)queryResults {
    NSMutableArray *mutableDataRows = [NSMutableArray arrayWithCapacity:[queryResults count]];
    for (NSDictionary *soup in queryResults) {
        [mutableDataRows addObject:[[self.dataSpec class] createSObjectData:soup]];
    }
    return mutableDataRows;
}

@end
