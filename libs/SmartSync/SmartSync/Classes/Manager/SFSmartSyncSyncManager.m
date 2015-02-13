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

#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncCacheManager.h"
#import "SFSmartSyncSoqlBuilder.h"
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>

// Will go away once we are done refactoring SFSyncTarget
#import "SFMruSyncTarget.h"
#import "SFSoqlSyncTarget.h"
#import "SFSoslSyncTarget.h"

// For user agent
NSString * const kUserAgent = @"User-Agent";
NSString * const kSmartSync = @"SmartSync";

// Page size
NSUInteger const kSyncManagerPageSize = 2000;

// Unchanged
NSInteger const kSyncManagerUnchanged = -1;

// soups and soup fields
NSString * const kSyncManagerLocal = @"__local__";
NSString * const kSyncManagerLocallyCreated = @"__locally_created__";
NSString * const kSyncManagerLocallyUpdated = @"__locally_updated__";
NSString * const kSyncManagerLocallyDeleted = @"__locally_deleted__";

// in options
NSString * const kSyncManagerOptionsFieldlist = @"fieldlist";

// in target
NSString * const kSyncManagerTargetQueryType = @"type";
NSString * const kSyncManagerTargetQuery = @"query";
NSString * const kSyncManagerTargetObjectType = @"sobjectType";
NSString * const kSyncManagerTargetFieldlist = @"fieldlist";

// query types
NSString * const kSyncManagerQueryTypeMru = @"mru";
NSString * const kSyncManagerQueryTypeSoql = @"soql";
NSString * const kSyncManagerQueryTypeSosl = @"sosl";

// response
NSString * const kSyncManagerObjectId = @"Id";
NSString * const kSyncManagerLObjectId = @"id"; // e.g. create response
NSString * const kSyncManagerObjectTypePath = @"attributes.type";
NSString * const kSyncManagerResponseRecords = @"records";
NSString * const kSyncManagerResponseTotalSize = @"totalSize";
NSString * const kSyncManagerResponseNextRecordsUrl = @"nextRecordsUrl";
NSString * const kSyncManagerRecentItems = @"recentItems";
NSString * const kSyncManagerLastModifiedDate = @"LastModifiedDate";

// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.smartsync.manager.syncmanager.QUEUE";

// block type
typedef void (^SyncUpdateBlock) (NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp);
typedef void (^SyncFailBlock) (NSString* message, NSError* error);


// action type
typedef enum {
    kSyncManagerActionNone,
    kSyncManagerActionCreate,
    kSyncManagerActionUpdate,
    kSyncManagerActionDelete
} SFSyncManagerAction;

// date formatter
static NSDateFormatter* isoDateFormatter;

@interface SFSmartSyncSyncManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, readonly) SFSmartStore *store;
@property (nonatomic, readonly) SFRestAPI *restClient;
@property (nonatomic, strong) dispatch_queue_t queue;

@end


@implementation SFSmartSyncSyncManager

static NSMutableDictionary *syncMgrList = nil;

#pragma mark - instance access / cleanup

+ (id)sharedInstance:(SFUserAccount *)user {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        syncMgrList = [[NSMutableDictionary alloc] init];
        
        // date formatter initialization
        if (!isoDateFormatter) {
            isoDateFormatter = [NSDateFormatter new];
            isoDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        }
    });
    @synchronized([SFSmartSyncSyncManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            id syncMgr = [syncMgrList objectForKey:key];
            if (!syncMgr) {
                syncMgr = [[SFSmartSyncSyncManager alloc] initWithUser:user];
                [syncMgrList setObject:syncMgr forKey:key];
            }
            return syncMgr;
        } else {
            return nil;
        }
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
    @synchronized([SFSmartSyncSyncManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            [syncMgrList removeObjectForKey:key];
        }
    }
}

#pragma mark - init / dealloc

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        self.queue = dispatch_queue_create(kSyncManagerQueue,  NULL);
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [SFSyncState setupSyncsSoupIfNeeded:self.store];
    }
    return self;
}


- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
}

- (SFRestAPI *) restClient {
    return [SFRestAPI sharedInstance];
}

- (SFSmartStore *)store {
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:self.user];
}

#pragma mark - get sync / run sync methods

/** Return details about a sync
 @param syncId
 */
- (SFSyncState*)getSyncStatus:(NSNumber*)syncId {
    SFSyncState* sync = [SFSyncState newById:syncId store:self.store];
    
    if (sync == nil) {
        [self log:SFLogLevelError format:@"Sync %@ not found", syncId];
    }
    return sync;
}

/** Run a previously created sync
 */
- (void) runSync:(SFSyncState*) sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SyncUpdateBlock updateSync = ^(NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp) {
        if (status == nil) status = (progress == 100 ? kSFSyncStateStatusDone : kSFSyncStateStatusRunning);
        sync.status = [SFSyncState syncStatusFromString:status];
        if (progress>=0)  sync.progress = progress;
        if (totalSize>=0) sync.totalSize = totalSize;
        if (maxTimeStamp>=0) sync.maxTimeStamp = (sync.maxTimeStamp < maxTimeStamp ? maxTimeStamp : sync.maxTimeStamp);
        [sync save:weakSelf.store];
        
        [weakSelf log:SFLogLevelDebug format:@"Sync update:%@", sync];
        
        if (updateBlock)
            updateBlock(sync);
    };
    
    SyncFailBlock failSync = ^(NSString* message, NSError* error) {
        [weakSelf log:SFLogLevelError format:@"Sync type:%@ id:%d FAILED cause:%@ error:%@", [SFSyncState syncTypeToString:sync.type], sync.syncId, message, error];
        updateSync(kSFSyncStateStatusFailed, kSyncManagerUnchanged, kSyncManagerUnchanged, kSyncManagerUnchanged);
    };
    
    // Run on background thread
    dispatch_async(self.queue, ^{
        updateSync(kSFSyncStateStatusRunning, 0, kSyncManagerUnchanged, kSyncManagerUnchanged);
        switch (sync.type) {
            case SFSyncStateSyncTypeDown:
                [weakSelf syncDown:sync updateSync:updateSync failSync:failSync];
                break;
            case SFSyncStateSyncTypeUp:
                [weakSelf syncUp:sync updateSync:updateSync failSync:failSync];
                break;
        }
    });
}

#pragma mark - syncDown, reSync and supporting methods

/** Create and run a sync down
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite];
    return [self syncDownWithTarget:target options:options soupName:soupName updateBlock:updateBlock];
}


/** Create and run a sync down
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName store:self.store];
    [self runSync:sync updateBlock:updateBlock];
    return sync;
}

/** Resync
 */
- (SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState* sync = [self getSyncStatus:(NSNumber *)syncId];
    
    if (sync == nil) {
        [self log:SFLogLevelError format:@"Cannot run reSync:%@:no sync found", syncId];
         return nil;
    }
    if (sync.type != SFSyncStateSyncTypeDown) {
        [self log:SFLogLevelError format:@"Cannot run reSync:%@:wrong type:%@", syncId, [SFSyncState syncTypeToString:sync.type]];
        return nil;
    }
    if (sync.target.queryType != SFSyncTargetQueryTypeSoql) {
        [self log:SFLogLevelError format:@"Cannot run reSync:%@:wrong query type:%@", syncId, [SFSyncTarget queryTypeToString:sync.target.queryType]];
        return nil;
    }
    if (sync.status != SFSyncStateStatusDone) {
        [self log:SFLogLevelError format:@"Cannot run reSync:%@:not done:%@", syncId, [SFSyncState syncStatusToString:sync.status]];
        return nil;
    }
    
    sync.totalSize = -1;
    [sync save:self.store];
    
    [self runSync:sync updateBlock:updateBlock];
    return sync;
}


/** Run a sync down
 */
- (void) syncDown:(SFSyncState*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncTarget* target = sync.target;
    SFRestFailBlock failRest = ^(NSError *error) {
        failSync(@"REST call failed", error);
    };
    
    switch (target.queryType) {
        case SFSyncTargetQueryTypeMru:
            [self syncDownMru:mergeMode objectType:((SFMruSyncTarget*) target).objectType fieldlist:((SFMruSyncTarget*) target).fieldlist soup:soupName updateSync:updateSync failRest:failRest];
            break;
        case SFSyncTargetQueryTypeSoql:
            [self syncDownSoql:mergeMode query:((SFSoqlSyncTarget*) target).query soup:soupName updateSync:updateSync failRest:failRest maxTimeStamp:sync.maxTimeStamp];
            break;
        case SFSyncTargetQueryTypeSosl:
            [self syncDownSosl:mergeMode query:((SFSoslSyncTarget*) target).query soup:soupName updateSync:updateSync failRest:failRest];
            break;
    }
}

/** Run a sync down for a mru target
 */
- (void) syncDownMru:(SFSyncStateMergeMode)mergeMode objectType:(NSString*)sobjectType fieldlist:(NSArray*)fieldlist soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:sobjectType];
    [self sendRequestWithSmartSyncUserAgent:request failBlock:failRest completeBlock:^(NSDictionary* d) {
        NSArray* recentItems = [weakSelf pluck:d[kSyncManagerRecentItems] key:kSyncManagerObjectId];
        NSString* inPredicate = [@[ @"Id IN ('", [recentItems componentsJoinedByString:@"', '"], @"')"]
                                 componentsJoinedByString:@""];
        NSString* soql = [[[[SFSmartSyncSoqlBuilder withFieldsArray:fieldlist]
                            from:sobjectType]
                           where:inPredicate]
                          build];
        [weakSelf syncDownSoql:mergeMode query:soql soup:soupName updateSync:updateSync failRest:failRest maxTimeStamp:0L];
    }];
}

- (NSArray*) pluck:(NSArray*)arrayOfDictionaries key:(NSString*)key {
    NSMutableArray* result = [NSMutableArray array];
    for (NSDictionary* d in arrayOfDictionaries) {
        [result addObject:d[key]];
    }
    return result;
}

/** Run a sync down for a soql target
 */
- (void) syncDownSoql:(SFSyncStateMergeMode)mergeMode query:(NSString*)query soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest maxTimeStamp:(long long)maxTimeStamp {
    __block NSUInteger countFetched = 0;
    __block SFRestDictionaryResponseBlock completeBlockRecurse = ^(NSDictionary *d) {};
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestDictionaryResponseBlock completeBlockSOQL = ^(NSDictionary *d) {
        NSUInteger totalSize = [d[kSyncManagerResponseTotalSize] integerValue];
        if (countFetched == 0) { // after first request only
            updateSync(nil, totalSize == 0 ? 100 : 0, totalSize, kSyncManagerUnchanged);
            if (totalSize == 0) {
                return;
            }
        }

        NSArray* recordsFetched = d[kSyncManagerResponseRecords];
        countFetched += [recordsFetched count];
        NSUInteger progress = 100*countFetched / totalSize;
        long long maxTimeStampForFetched = [self getMaxTimeStamp:recordsFetched];
        
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName mergeMode:mergeMode];
        // Update status
        updateSync(nil, progress, totalSize, maxTimeStampForFetched);
        
        // Fetch next records if any
        NSString* nextRecordsUrl = d[kSyncManagerResponseNextRecordsUrl];
        if (nextRecordsUrl) {
            SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodGET path:nextRecordsUrl queryParams:nil];
            [weakSelf sendRequestWithSmartSyncUserAgent:request failBlock:failRest completeBlock:completeBlockRecurse];
        }
    };
    // initialize the alias
    completeBlockRecurse = completeBlockSOQL;
    
    // Resync?
    NSString* queryToRun = query;
    if (maxTimeStamp > 0) {
        queryToRun = [self addFilterForReSync:query maxTimeStamp:maxTimeStamp];
    }

    // Send request
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:queryToRun];
    [self sendRequestWithSmartSyncUserAgent:request failBlock:failRest completeBlock:completeBlockSOQL];
}

/** Run a sync down for a sosl target
 */
- (void) syncDownSosl:(SFSyncStateMergeMode)mergeMode  query:(NSString*)query soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestArrayResponseBlock completeBlockSOSL = ^(NSArray *recordsFetched) {
        NSUInteger totalSize = [recordsFetched count];
        updateSync(nil, totalSize == 0 ? 100 : 0, totalSize, kSyncManagerUnchanged);
        if (totalSize == 0) {
            return;
        }
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName mergeMode:mergeMode];
        // Update status
        updateSync(kSFSyncStateStatusRunning, 100, totalSize, kSyncManagerUnchanged);
    };
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearch:query];
    [self sendRequestWithSmartSyncUserAgent:request failBlock:failRest completeBlock:completeBlockSOSL];

}

- (void) saveRecords:(NSArray*)records soup:(NSString*)soupName mergeMode:(SFSyncStateMergeMode)mergeMode{
    NSMutableArray* recordsToSave = [NSMutableArray array];
    
    NSSet* idsToSkip = nil;
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged) {
        idsToSkip = [self getDirtyRecordIds:soupName idField:kSyncManagerObjectId];
    }
    
    // Prepare for smartstore
    for (NSDictionary* record in records) {
        // Skip?
        if (idsToSkip != nil && [idsToSkip containsObject:record[kSyncManagerObjectId]]) {
            continue;
        }
        
        NSMutableDictionary* udpatedRecord = [record mutableCopy];
        udpatedRecord[kSyncManagerLocal] = @NO;
        udpatedRecord[kSyncManagerLocallyCreated] = @NO;
        udpatedRecord[kSyncManagerLocallyUpdated] = @NO;
        udpatedRecord[kSyncManagerLocallyDeleted] = @NO;
        [recordsToSave addObject:udpatedRecord];
    }
    
    // Save to smartstore
    [self.store upsertEntries:recordsToSave toSoup:soupName withExternalIdPath:kSyncManagerObjectId error:nil];
}

- (NSSet*) getDirtyRecordIds:(NSString*)soupName idField:(NSString*)idField {
    NSMutableSet* ids = [NSMutableSet new];
    
    NSString* dirtyRecordSql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = '1'", soupName, idField, soupName, soupName, kSyncManagerLocal];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:dirtyRecordSql withPageSize:kSyncManagerPageSize];
    
    BOOL hasMore = YES;
    for (NSUInteger pageIndex=0; hasMore; pageIndex++) {
        NSArray* results = [self.store queryWithQuerySpec:querySpec pageIndex:pageIndex error:nil];
        hasMore = (results.count == kSyncManagerPageSize);
        [ids addObjectsFromArray:[self flatten:results]];
    }
    return ids;
}

- (long long) getMaxTimeStamp:(NSArray*)records {
    long long maxTimeStamp = -1L;
    for(NSDictionary* record in records) {
        NSString* timeStampStr = record[kSyncManagerLastModifiedDate];
        if (!timeStampStr) {
            break; // LastModifiedDate field not present
        }
        long long timeStamp = [self getTimeMillisFromString:timeStampStr];
        maxTimeStamp = (timeStamp > maxTimeStamp ? timeStamp : maxTimeStamp);
    }
    return maxTimeStamp;
}

- (long long) getTimeMillisFromString:(NSString*)dateStr {
    long long millis = -1;
    NSDate* date = [isoDateFormatter dateFromString:dateStr];
    if (date) {
        millis = (long long) (date.timeIntervalSince1970 * 1000.0);
    }
    return millis;
}

- (NSString*) addFilterForReSync:(NSString*)query maxTimeStamp:(long long)maxTimeStamp {
    NSString* queryToRun = query;
    if (maxTimeStamp > 0) {
        NSDate* maxTimeStampDate = [NSDate dateWithTimeIntervalSince1970:((double)maxTimeStamp)/1000.0];
        NSString* extraPredicate = [@[kSyncManagerLastModifiedDate, @">", [isoDateFormatter stringFromDate:maxTimeStampDate]] componentsJoinedByString:@" "];
        if ([[query lowercaseString] rangeOfString:@" where "].location != NSNotFound) {
            queryToRun = [self appendToFirstOccurence:query pattern:@" where " stringToAppend:[@[extraPredicate, @" and "] componentsJoinedByString:@""]];
        }
        else {
            queryToRun = [self appendToFirstOccurence:query pattern:@" from[ ]+[^ ]*" stringToAppend:[@[@" where ", extraPredicate] componentsJoinedByString:@""]];
        }
    }
    return queryToRun;
}

- (NSString*) appendToFirstOccurence:(NSString*)str pattern:(NSString*)pattern stringToAppend:(NSString*)stringToAppend {
    NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSRange rangeFirst = [regexp rangeOfFirstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
    NSString* firstMatch = [str substringWithRange:rangeFirst];
    NSString* modifiedStr = [str stringByReplacingCharactersInRange:rangeFirst withString:[@[firstMatch, stringToAppend] componentsJoinedByString:@""]];
    return modifiedStr;
}


- (NSArray*) flatten:(NSArray*)results {
    NSMutableArray* flatArray = [NSMutableArray new];
    for (NSArray* row in results) {
        [flatArray addObjectsFromArray:row];
    }
    return flatArray;
}

#pragma mark - syncUp and supporting methods

/** Create and run a sync up
 */
- (SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState* sync = [SFSyncState newSyncUpWithOptions:options soupName:soupName store:self.store];
    [self runSync:sync updateBlock:updateBlock];
    return sync;
}

/** Run a sync up
 */
- (void) syncUp:(SFSyncState*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync.soupName;
    
    // Call smartstore
    NSArray* dirtyRecordIds = [[self getDirtyRecordIds:soupName idField:SOUP_ENTRY_ID] allObjects];
    NSUInteger totalSize = [dirtyRecordIds count];
    if (totalSize == 0) {
        return;
    }
    
    // Fail block for rest call
    SFRestFailBlock failRest = ^(NSError *error) {
        failSync(@"REST call failed", error);
    };

    // Otherwise, there's work to do.
    [self syncUpOneEntry:sync recordIds:dirtyRecordIds index:0 updateSync:updateSync failRest:failRest];
}

- (void) syncUpOneEntry:(SFSyncState*)sync recordIds:(NSArray*)recordIds index:(NSUInteger)i updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    NSUInteger totalSize = recordIds.count;
    NSUInteger progress = i*100 / totalSize;
    updateSync(nil, progress, totalSize, kSyncManagerUnchanged);
    
    if (progress == 100) {
        // Done
        return;
    }
    
    NSString* idStr = [(NSNumber*) recordIds[i] stringValue];
    NSMutableDictionary* record = [[self.store retrieveEntries:@[idStr] fromSoup:soupName][0] mutableCopy];
    
    // Do we need to do a create, update or delete
    SFSyncManagerAction action = kSyncManagerActionNone;
    if ([record[kSyncManagerLocallyDeleted] boolValue])
        action = kSyncManagerActionDelete;
    else if ([record[kSyncManagerLocallyCreated] boolValue])
        action = kSyncManagerActionCreate;
    else if ([record[kSyncManagerLocallyUpdated] boolValue])
        action = kSyncManagerActionUpdate;
    
    if (action == kSyncManagerActionNone) {
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failRest:failRest];
        return;
    }

    /*
     * Checks if we are attempting to update a record that has been updated
     * on the server AFTER the client's last sync down. If the merge mode
     * passed in tells us to leave the record alone under these
     * circumstances, we will do nothing and return here.
     */
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged &&
        (action == kSyncManagerActionUpdate || action == kSyncManagerActionDelete)) {
        [self isNewerThanServer:(SFSyncState*)sync recordIds:(NSArray*)recordIds index:(NSUInteger)i record:(NSMutableDictionary*)record action:(SFSyncManagerAction)action updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest];
    } else {
        [self resumeSyncUpOneEntry:sync recordIds:recordIds index:i record:record action:action updateSync:updateSync failRest:failRest];
    }
}

- (void)resumeSyncUpOneEntry:(SFSyncState*)sync recordIds:(NSArray*)recordIds index:(NSUInteger)i record:(NSMutableDictionary*)record action:(SFSyncManagerAction)action updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    SFSyncOptions* options = sync.options;
    NSString* soupName = sync.soupName;
    NSNumber* soupEntryId = record[SOUP_ENTRY_ID];

    // Getting type and id
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kSyncManagerObjectTypePath];
    NSString* objectId = record[kSyncManagerObjectId];

    // Fields to save (in the case of create or update)
    NSMutableDictionary* fields = [NSMutableDictionary dictionary];
    if (action == kSyncManagerActionCreate || action == kSyncManagerActionUpdate) {
        for (NSString* fieldName in options.fieldlist) {
            if (![fieldName isEqualToString:kSyncManagerObjectId]) {
                if (record[fieldName] != nil)
                    fields[fieldName] = record[fieldName];
            }
        }
    }

    // Delete handler
    SFRestDictionaryResponseBlock completeBlockDelete = ^(NSDictionary *d) {
        // Remove entry on delete
        [self.store removeEntries:@[soupEntryId] fromSoup:soupName];
        
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failRest:failRest];
    };

    // Update handler
    SFRestDictionaryResponseBlock completeBlockUpdate = ^(NSDictionary *d) {
        // Set local flags to false
        record[kSyncManagerLocal] = @NO;
        record[kSyncManagerLocallyCreated] = @NO;
        record[kSyncManagerLocallyUpdated] = @NO;
        record[kSyncManagerLocallyDeleted] = @NO;
        
        // Update smartstore
        [self.store upsertEntries:@[record] toSoup:soupName];
        
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failRest:failRest];
    };

    // Create handler
    SFRestDictionaryResponseBlock completeBlockCreate = ^(NSDictionary *d) {
        // Replace id with server id during create
        record[kSyncManagerObjectId] = d[kSyncManagerLObjectId];
        completeBlockUpdate(d);
    };

    SFRestRequest* request;
    id completeBlock;
    switch(action) {
        case kSyncManagerActionCreate:
            request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
            completeBlock = completeBlockCreate;
            break;
        case kSyncManagerActionUpdate:
            request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
            completeBlock = completeBlockUpdate;
            break;
        case kSyncManagerActionDelete:
            request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
            completeBlock = completeBlockDelete;
            break;
        case kSyncManagerActionNone: /* caught by if (action == kSyncManagerActionNone) above */ break;
    }

    // Send request
    [self sendRequestWithSmartSyncUserAgent:request failBlock:failRest completeBlock:completeBlock];
}

- (void)sendRequestWithSmartSyncUserAgent:(SFRestRequest *)request failBlock:(SFRestFailBlock)failBlock completeBlock:(id)completeBlock {
    [request setHeaderValue:[SFRestAPI userAgentString:kSmartSync] forHeaderName:kUserAgent];
    [self.restClient sendRESTRequest:request failBlock:failBlock completeBlock:completeBlock];
}

- (void)isNewerThanServer:(SFSyncState*)sync recordIds:(NSArray*)recordIds index:(NSUInteger)i record:(NSMutableDictionary*)record action:(SFSyncManagerAction)action updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kSyncManagerObjectTypePath];
    NSString* objectId = record[kSyncManagerObjectId];
    NSString* lastModifiedDateString = record[kSyncManagerLastModifiedDate];
    long long lastModifiedDate = [self getTimeMillisFromString:lastModifiedDateString];
    __block long long serverLastModified = -1;
    SFSmartSyncSoqlBuilder *soqlBuilder = [SFSmartSyncSoqlBuilder withFields:kSyncManagerLastModifiedDate];
    [soqlBuilder from:objectType];
    [soqlBuilder where:[NSString stringWithFormat:@"Id = '%@'", objectId]];
    NSString *query = [soqlBuilder build];
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:query];
    [self sendRequestWithSmartSyncUserAgent:request
        failBlock:^(NSError *error) {
            [self log:SFLogLevelError format:@"REST request failed with error: %@", error];
            [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failRest:failRest];
        }
        completeBlock:^(NSDictionary* d) {
            if (nil != d) {
                NSDictionary *record = d[@"records"][0];
                if (nil != record) {
                    NSString *serverLastMod = record[kSyncManagerLastModifiedDate];
                    if (nil != serverLastMod) {
                        serverLastModified = [self getTimeMillisFromString:serverLastMod];
                    }
                }
            }
            if (serverLastModified <= lastModifiedDate) {
                [self resumeSyncUpOneEntry:sync recordIds:recordIds index:i record:record action:action updateSync:updateSync failRest:failRest];
            } else {
                [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failRest:failRest];
            }
        }
     ];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}

@end
