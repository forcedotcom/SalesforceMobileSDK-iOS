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
#import "SFSmartSyncNetworkManager.h"
#import "SFSmartSyncCacheManager.h"
#import "SFSmartSyncSoqlBuilder.h"
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>

// soups and soup fields
NSString * const kSyncManagerSyncsSoupName = @"syncs_soup";
NSString * const kSyncManagerSyncsSoupType = @"type";
NSString * const kSyncManagerLocal = @"__local__";
NSString * const kSyncManagerLocallyCreated = @"__locally_created__";
NSString * const kSyncManagerLocallyUpdated = @"__locally_updated__";
NSString * const kSyncManagerLocallyDeleted = @"__locally_deleted__";

// sync attributes
NSString * const kSyncManagerSyncId = @"_soupEntryId";
NSString * const kSyncManagerSyncType = @"type";
NSString * const kSyncManagerSyncTarget = @"target";
NSString * const kSyncManagerSyncSoupName = @"soupName";
NSString * const kSyncManagerSyncOptions = @"options";
NSString * const kSyncManagerSyncStatus = @"status";
NSString * const kSyncManagerSyncProgress = @"progress";
NSString * const kSyncManagerSyncTotalSize = @"totalSize";

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

// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.smartsync.manager.syncmanager.QUEUE";

// block type
typedef void (^SyncUpdateBlock) (NSString* status, NSInteger progress, NSInteger totalSize);
typedef void (^SyncFailBlock) (NSString* message, NSError* error);


// action type
typedef enum {
    kSyncManagerActionNone,
    kSyncManagerActionCreate,
    kSyncManagerActionUpdate,
    kSyncManagerActionDelete
} SFSyncManagerAction;

/** Types of sync
 */
NSString * const kSyncManagerSyncTypeDown = @"syncDown";
NSString * const kSyncManagerSyncTypeUp = @"syncUp";

/** Possible status for a sync
 */
NSString * const kSyncManagerStatusNew = @"NEW";
NSString * const kSyncManagerStatusRunning = @"RUNNING";
NSString * const kSyncManagerStatusDone = @"DONE";
NSString * const kSyncManagerStatusFailed = @"FAILED";

@interface SFSmartSyncSyncManager ()

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFRestAPI *restClient;

@end


@implementation SFSmartSyncSyncManager

static NSMutableDictionary *syncMgrList = nil;
dispatch_queue_t queue;

+ (id)sharedInstance:(SFUserAccount *)user {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        syncMgrList = [[NSMutableDictionary alloc] init];
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

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:user];
        self.restClient = [SFRestAPI sharedInstance];
        queue = dispatch_queue_create(kSyncManagerQueue,  NULL);
        [self setupSyncsSoupIfNeeded];
    }
    return self;
}

/** Return details about a sync
 @param syncId
 */
- (NSDictionary*)getSyncStatus:(NSNumber*)syncId {
    NSArray* syncs = [self.store retrieveEntries:@[syncId] fromSoup:kSyncManagerSyncsSoupName];
    
    if (syncs==nil || [syncs count] == 0) {
        [self log:SFLogLevelError format:@"Sync %@ not found", syncId];
        return nil;
    }
    else {
        return syncs[0];
    }
}

/** Create/record a sync but don't start it yet
 */
- (NSDictionary*) recordSync:(NSString*)type target:(NSDictionary*)target soupName:(NSString*)soupName options:(NSDictionary*)options {
    
    NSDictionary* sync = @{
                           kSyncManagerSyncType: type,
                           kSyncManagerSyncTarget: target == nil ? @{} : target,
                           kSyncManagerSyncSoupName: soupName,
                           kSyncManagerSyncOptions: options == nil ? @{} : options,
                           kSyncManagerSyncStatus: kSyncManagerStatusNew };
    
    NSArray* syncs = [self.store upsertEntries:@[ sync ] toSoup:kSyncManagerSyncsSoupName];
    
    return syncs[0];
}

/** Run a previously created sync
 */
- (void) runSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    NSDictionary* sync = [self getSyncStatus:syncId];
    if (sync == nil) {
        return;
    }
    
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SyncUpdateBlock updateSync = ^(NSString* status, NSInteger progress, NSInteger totalSize) {
        [weakSelf log:SFLogLevelDebug format:@"Sync type:%@ id:%@ status: %@ progress:%d totalSize:%d", sync[kSyncManagerSyncType], sync[kSyncManagerSyncId], status, progress, totalSize];

        NSMutableDictionary* modifiedSync = [sync mutableCopy];
        if (status == nil) {
            status = (progress == 100 ? kSyncManagerStatusDone : kSyncManagerStatusRunning);
        }
        modifiedSync[kSyncManagerSyncStatus] = status;
        if (progress>=0)  modifiedSync[kSyncManagerSyncProgress] = [NSNumber numberWithInt:progress];
        if (totalSize>=0) modifiedSync[kSyncManagerSyncTotalSize] = [NSNumber numberWithInt:totalSize];
        NSArray* savedSyncs = [weakSelf.store upsertEntries:@[ modifiedSync ] toSoup:kSyncManagerSyncsSoupName];
        
        if (updateBlock && savedSyncs.count > 0) {
            updateBlock(savedSyncs[0]);
        }
    };
    
    SyncFailBlock failSync = ^(NSString* message, NSError* error) {
        [weakSelf log:SFLogLevelError format:@"Sync type:%@ id:%@ FAILED cause:%@ error:%@", sync[kSyncManagerSyncType], sync[kSyncManagerSyncId], message, error];
        updateSync(kSyncManagerStatusFailed, -1, -1);
    };
    
    updateSync(kSyncManagerStatusRunning, 0, -1);
    // Run on background thread
    dispatch_async(queue, ^{
        NSString* syncType = sync[kSyncManagerSyncType];
        if ([syncType isEqualToString:kSyncManagerSyncTypeDown]) {
            [weakSelf syncDown:sync updateSync:updateSync failSync:failSync];
        }
        else if ([syncType isEqualToString:kSyncManagerSyncTypeUp]) {
            [weakSelf syncUp:sync updateSync:updateSync failSync:failSync];
        }
        else {
            failSync(@"Invalid sync type", nil);
        }
    });
}

/** Create and run a sync down
 */
- (NSDictionary*) syncDownWithTarget:(NSDictionary*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    NSDictionary* sync = [self recordSync:kSyncManagerSyncTypeDown target:target soupName:soupName options:nil];
    NSNumber* syncId = sync[kSyncManagerSyncId];
    [self runSync:syncId updateBlock:updateBlock];
    return [self getSyncStatus:syncId];
}

/** Create and run a sync up
 */
- (NSDictionary*) syncUpWithOptions:(NSDictionary*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    NSDictionary* sync = [self recordSync:kSyncManagerSyncTypeUp target:nil soupName:soupName options:options];
    NSNumber* syncId = sync[kSyncManagerSyncId];
    [self runSync:syncId updateBlock:updateBlock];
    return [self getSyncStatus:syncId];
}


/** Create master syncs soup if needed
 */
- (void) setupSyncsSoupIfNeeded {
    if ([self.store soupExists:kSyncManagerSyncsSoupName])
        return;
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:kSyncManagerSyncsSoupType indexType:kSoupIndexTypeString columnName:nil]
                            ];
    
    [self.store registerSoup:kSyncManagerSyncsSoupName withIndexSpecs:indexSpecs];
}

/** Run a sync down
 */
- (void) syncDown:(NSDictionary*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    NSDictionary* target = sync[kSyncManagerSyncTarget];
    NSString* queryType = target[kSyncManagerTargetQueryType];
    NSString* query = target[kSyncManagerTargetQuery];
    
    SFRestFailBlock failRest = ^(NSError *error) {
        failSync(@"REST call failed", error);
    };
    
    if ([queryType isEqualToString:kSyncManagerQueryTypeMru]) {
        NSString* sobjectType = target[kSyncManagerTargetObjectType];
        NSArray* fieldlist = target[kSyncManagerTargetFieldlist];
        [self syncDownMru:sobjectType fieldlist:fieldlist soup:soupName updateSync:updateSync failRest:failRest];
    }
    else if ([queryType isEqualToString:kSyncManagerQueryTypeSoql]) {
        [self syncDownSoql:query soup:soupName updateSync:updateSync failRest:failRest];
    }
    else if ([queryType isEqualToString:kSyncManagerQueryTypeSosl]) {
        [self syncDownSosl:query soup:soupName updateSync:updateSync failRest:failRest];
    }
    else {
        failSync([NSString stringWithFormat:@"Unknown query type %@", queryType], nil);
    }
}

/** Run a sync down for a mru target
 */
- (void) syncDownMru:(NSString*)sobjectType fieldlist:(NSArray*)fieldlist soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    
    [self.restClient performMetadataWithObjectType:sobjectType failBlock:failRest completeBlock:^(NSDictionary* d) {
        NSArray* recentItems = [weakSelf pluck:d[kSyncManagerRecentItems] key:kSyncManagerObjectId];
        NSString* inPredicate = [@[ @"Id IN ('", [recentItems componentsJoinedByString:@"', '"], @"')"]
                                 componentsJoinedByString:@""];
        NSString* soql = [[[[SFSmartSyncSoqlBuilder withFieldsArray:fieldlist]
                            from:sobjectType]
                           where:inPredicate]
                          build];
        [weakSelf syncDownSoql:soql soup:soupName updateSync:updateSync failRest:failRest];
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
- (void) syncDownSoql:(NSString*)query soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    __block NSUInteger countFetched = 0;
    __block SFRestDictionaryResponseBlock completeBlockRecurse = ^(NSDictionary *d) {};
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestDictionaryResponseBlock completeBlockSOQL = ^(NSDictionary *d) {
        NSUInteger totalSize = [d[kSyncManagerResponseTotalSize] integerValue];
        if (countFetched == 0) { // after first request only
            updateSync(nil, totalSize == 0 ? 100 : 0, totalSize);
            if (totalSize == 0) {
                return;
            }
        }
        
        NSArray* recordsFetched = d[kSyncManagerResponseRecords];
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName];
        // Update status
        countFetched += [recordsFetched count];
        NSUInteger progress = 100*countFetched / totalSize;
        updateSync(nil, progress, totalSize);
        
        // Fetch next records if any
        NSString* nextRecordsUrl = d[kSyncManagerResponseNextRecordsUrl];
        if (nextRecordsUrl) {
            [weakSelf.restClient performRequestWithMethod:SFRestMethodGET path:nextRecordsUrl queryParams:nil failBlock:failRest completeBlock:completeBlockRecurse];
        }
    };
    // initialize the alias
    completeBlockRecurse = completeBlockSOQL;
    
    [self.restClient performSOQLQuery:query failBlock:failRest completeBlock:completeBlockSOQL];
}

/** Run a sync down for a sosl target
 */
- (void) syncDownSosl:(NSString*)query soup:(NSString*)soupName updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestArrayResponseBlock completeBlockSOSL = ^(NSArray *recordsFetched) {
        NSUInteger totalSize = [recordsFetched count];
        updateSync(nil, totalSize == 0 ? 100 : 0, totalSize);
        if (totalSize == 0) {
            return;
        }
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName];
        // Update status
        updateSync(kSyncManagerStatusRunning, 100, totalSize);
    };
    
    [self.restClient performSOSLSearch:query failBlock:failRest completeBlock:completeBlockSOSL];
}

- (void) saveRecords:(NSArray*)records soup:(NSString*)soupName {
    NSMutableArray* recordsToSave = [NSMutableArray array];
    
    // Prepare for smartstore
    for (NSDictionary* record in records) {
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

/** Run a sync up
 */
- (void) syncUp:(NSDictionary*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    SFQuerySpec* querySpec = [SFQuerySpec newExactQuerySpec:soupName withPath:kSyncManagerLocal withMatchKey:@"1" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2000];
    
    // Call smartstore
    NSArray* records = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    NSUInteger totalSize = [records count];
    updateSync(nil, totalSize == 0 ? 100 : 0, totalSize);
    if (totalSize == 0) {
        return;
    }
    
    // Fail block for rest call
    SFRestFailBlock failRest = ^(NSError *error) {
        failSync(@"REST call failed", error);
    };
    
    // Otherwise, there's work to do.
    [self syncUpOneEntry:sync records:records index:0 updateSync:updateSync failRest:failRest];
}

- (void) syncUpOneEntry:(NSDictionary*)sync records:(NSArray*)records index:(NSUInteger)i updateSync:(SyncUpdateBlock)updateSync failRest:(SFRestFailBlock)failRest {
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    NSDictionary* options = sync[kSyncManagerSyncOptions];
    NSArray* fieldlist = (NSArray*) options[kSyncManagerOptionsFieldlist];
    NSUInteger totalSize = records.count;
    NSUInteger progress = i*100 / totalSize;
    updateSync(nil, progress, totalSize);
    
    if (progress == 100) {
        // Done
        return;
    }
    
    NSMutableDictionary* record = [records[i] mutableCopy];
    
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
        [self syncUpOneEntry:sync records:records index:i+1 updateSync:updateSync failRest:failRest];
    }
    
    // Getting type and id
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kSyncManagerObjectTypePath];
    NSString* objectId = record[kSyncManagerObjectId];
    NSNumber* soupEntryId = record[SOUP_ENTRY_ID];
    
    // Fields to save (in the case of create or update)
    NSMutableDictionary* fields = [NSMutableDictionary dictionary];
    if (action == kSyncManagerActionCreate || action == kSyncManagerActionUpdate) {
        for (NSString* fieldName in fieldlist) {
            if (![fieldName isEqualToString:kSyncManagerObjectId]) {
                fields[fieldName] = record[fieldName];
            }
        }
    }
    
    // Delete handler
    SFRestDictionaryResponseBlock completeBlockDelete = ^(NSDictionary *d) {
        // Remove entry on delete
        [self.store removeEntries:@[soupEntryId] fromSoup:soupName];
        
        // Next
        [self syncUpOneEntry:sync records:records index:i+1 updateSync:updateSync failRest:failRest];
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
        [self syncUpOneEntry:sync records:records index:i+1 updateSync:updateSync failRest:failRest];
    };
    
    // Create handler
    SFRestDictionaryResponseBlock completeBlockCreate = ^(NSDictionary *d) {
        // Replace id with server id during create
        record[kSyncManagerObjectId] = d[kSyncManagerLObjectId];
        completeBlockUpdate(d);
    };
    
    switch(action) {
        case kSyncManagerActionCreate: [self.restClient performCreateWithObjectType:objectType fields:fields failBlock:failRest completeBlock:completeBlockCreate]; break;
        case kSyncManagerActionUpdate: [self.restClient performUpdateWithObjectType:objectType objectId:objectId fields:fields failBlock:failRest completeBlock:completeBlockUpdate]; break;
        case kSyncManagerActionDelete: [self.restClient performDeleteWithObjectType:objectType objectId:objectId failBlock:failRest completeBlock:completeBlockDelete]; break;
        case kSyncManagerActionNone: /* caught by if (action == kSyncManagerActionNone) above */ break;
    }
    
}
@end