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
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>

// soups and soup fields
NSString * const kSyncManagerSyncsSoupName = @"syncs_soup";
NSString * const kSyncManagerSyncsSoupType = @"type";
NSString * const kSyncManagerLocal = @"__local__";
NSString * const kSyncManagerLocallyCreated = @"__locally_created__";
NSString * const kSyncManagerLocallyUpdated = @"__locally_updated__";
NSString * const kSyncManagerLocallyDeleted = @"__locally_deleted__";

// sync attributes
NSString * const kSyncManagerSyncId = @"_soupEntryId"; // XXX
NSString * const kSyncManagerSyncType = @"type";
NSString * const kSyncManagerSyncTarget = @"target";
NSString * const kSyncManagerSyncSoupName = @"soupName";
NSString * const kSyncManagerSyncOptions = @"options";
NSString * const kSyncManagerSyncStatus = @"status";
NSString * const kSyncManagerSyncProgress = @"progress";

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
NSString * const kSyncManagerServerId = @"Id";
NSString * const kSyncManagerResponseRecords = @"records";
NSString * const kSyncManagerResponseTotalSize = @"totalSize";
NSString * const kSyncManagerResponseNextRecordsUrl = @"nextRecordsUrl";
NSString * const kSyncManagerRecentItems = @"recentItems";

// notification
NSString * const kSyncManagerNotification = @"com.salesforce.smartsync.manager.SyncManager.UPDATE_SYNC";

// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.smartsync.manager.syncmanager.QUEUE";

// block type
typedef void (^SFSyncManagerUpdateBlock) (NSUInteger progress);

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
    return (syncs == nil || [syncs count]) == 0 ? nil : syncs[0];
}

/** Create/record a sync but don't start it yet
 */
- (NSDictionary*) recordSync:(NSString*)type withTarget:(NSDictionary*)target withSoupName:(NSString*)soupName withOptions:(NSDictionary*)options {

    NSDictionary* sync = @{
                           kSyncManagerSyncType: type,
                           kSyncManagerSyncTarget: target,
                           kSyncManagerSyncSoupName: soupName,
                           kSyncManagerSyncOptions: options,
                           kSyncManagerSyncStatus: kSyncManagerStatusNew };

    NSArray* syncs = [self.store upsertEntries:@[ sync ] toSoup:kSyncManagerSyncsSoupName];
    
    return syncs[0];
}

/** Run a previously created sync
 */
- (void) runSync:(NSNumber*)syncId {
    NSArray* syncs = [self.store retrieveEntries:@[syncId] fromSoup:kSyncManagerSyncsSoupName];
    if (syncs==nil || [syncs count] == 0) {
        [self log:SFLogLevelError format:@"Sync %@ not found", syncId];
        return;
    }
    
    NSDictionary* sync = syncs[0];
    
    [self updateSync:sync withStatus:kSyncManagerStatusRunning withProgress:0];
    
    // Run on background thread
    __weak SFSmartSyncSyncManager *weakSelf = self;
    dispatch_async(queue, ^{
        NSString* syncType = sync[kSyncManagerSyncType];
        if ([syncType isEqualToString:kSyncManagerSyncTypeDown]) {
            [weakSelf syncDown:sync];
        }
        else if ([syncType isEqualToString:kSyncManagerSyncTypeUp]) {
            [weakSelf syncUp:sync];
        }
        else {
            [self log:SFLogLevelError format:@"Sync %@ failed unknown sync type:%@", sync[kSyncManagerSyncId], syncType];
            [weakSelf updateSync:sync withStatus:kSyncManagerStatusFailed withProgress:0];
        }
    });
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

/** Update sync status and progress
 */
- (void) updateSync:(NSDictionary*)sync withStatus:(NSString*)status withProgress:(NSUInteger)progress {
    [self log:SFLogLevelDebug format:@"Sync %@ status: %@ progress:%d", sync[kSyncManagerSyncId], status, progress];
    NSMutableDictionary* modifiedSync = [sync mutableCopy];
    modifiedSync[kSyncManagerSyncStatus] = status;
    modifiedSync[kSyncManagerSyncProgress] = [NSNumber numberWithInt:progress];
    
    [self.store upsertEntries:@[ modifiedSync ] toSoup:kSyncManagerSyncsSoupName];
    
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSyncManagerNotification object:modifiedSync]];
}


/** Run a sync down
 */
- (void) syncDown:(NSDictionary*)sync{
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    NSDictionary* target = sync[kSyncManagerSyncTarget];
    NSString* queryType = target[kSyncManagerTargetQueryType];
    NSString* query = target[kSyncManagerTargetQuery];
    
    SFRestFailBlock failBlock = ^(NSError *error) {
        [self log:SFLogLevelError format:@"Sync %@ failed rest call error:%@", sync[kSyncManagerSyncId], error];
    };
    
    SFSyncManagerUpdateBlock updateBlock = ^(NSUInteger progress) {
        [self updateSync:sync withStatus:(progress == 100 ? kSyncManagerStatusDone : kSyncManagerStatusRunning) withProgress:progress];
    };

    if ([queryType isEqualToString:kSyncManagerQueryTypeMru]) {
        NSString* sobjectType = target[kSyncManagerTargetObjectType];
        NSArray* fieldlist = target[kSyncManagerTargetFieldlist];
        [self syncDownMru:sobjectType fieldlist:fieldlist soup:soupName updateBlock:updateBlock failBlock:failBlock];
    }
    else if ([queryType isEqualToString:kSyncManagerQueryTypeSoql]) {
        [self syncDownSoql:query soup:soupName updateBlock:updateBlock failBlock:failBlock];
    }
    else if ([queryType isEqualToString:kSyncManagerQueryTypeSosl]) {
        [self syncDownSosl:query soup:soupName updateBlock:updateBlock failBlock:failBlock];
    }
    else {
        [self log:SFLogLevelError format:@"Sync %@ failed unknown query type:%@", sync[kSyncManagerSyncId], queryType];
    }
}

/** Run a sync down for a mru target
 */
- (void) syncDownMru:(NSString*)sobjectType fieldlist:(NSArray*)fieldlist soup:(NSString*)soupName updateBlock:(SFSyncManagerUpdateBlock)updateBlock failBlock:(SFRestFailBlock)failBlock {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    [self.restClient performMetadataWithObjectType:sobjectType failBlock:failBlock completeBlock:^(NSDictionary* d) {
        NSArray* recentItems = [weakSelf pluck:d[kSyncManagerRecentItems] key:kSyncManagerServerId];
        NSString* soql = [
            @[@"SELECT ",
              [fieldlist componentsJoinedByString:@", "],
              @" FROM ",
              sobjectType,
              @" WHERE Id IN ('",
              [recentItems componentsJoinedByString:@"', '"],
              @"')"
              ]
             componentsJoinedByString:@""];
        [weakSelf syncDownSoql:soql soup:soupName updateBlock:updateBlock failBlock:failBlock];
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
- (void) syncDownSoql:(NSString*)query soup:(NSString*)soupName updateBlock:(SFSyncManagerUpdateBlock)updateBlock failBlock:(SFRestFailBlock)failBlock {
    __block NSUInteger countFetched = 0;
    __block SFRestDictionaryResponseBlock completeBlockRecurse = ^(NSDictionary *d) {};
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestDictionaryResponseBlock completeBlockSOQL = ^(NSDictionary *d) {
        
        NSArray* recordsFetched = d[kSyncManagerResponseRecords];
        if ([recordsFetched count] == 0)
            return; // done
        
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName];
        
        // Update status
        countFetched += [recordsFetched count];
        NSUInteger totalSize = [d[kSyncManagerResponseTotalSize] integerValue];
        NSUInteger progress = 100*countFetched / totalSize;
        updateBlock(progress);
        
        // Fetch next records if any
        NSString* nextRecordsUrl = d[kSyncManagerResponseNextRecordsUrl];
        if (nextRecordsUrl) {
            [weakSelf.restClient performRequestWithMethod:SFRestMethodGET path:nextRecordsUrl queryParams:nil failBlock:failBlock completeBlock:completeBlockRecurse];
        }
    };
    // initialize the alias
    completeBlockRecurse = completeBlockSOQL;
    
    [self.restClient performSOQLQuery:query failBlock:failBlock completeBlock:completeBlockSOQL];
}

/** Run a sync down for a sosl target
 */
- (void) syncDownSosl:(NSString*)query soup:(NSString*)soupName updateBlock:(SFSyncManagerUpdateBlock)updateBlock failBlock:(SFRestFailBlock)failBlock {
    __weak SFSmartSyncSyncManager *weakSelf = self;
    SFRestArrayResponseBlock completeBlockSOSL = ^(NSArray *recordsFetched) {
        if ([recordsFetched count] == 0)
            return; // done
        
        // Save records
        [weakSelf saveRecords:recordsFetched soup:soupName];
        
        // Update status
        updateBlock(100);
    };
    
    [self.restClient performSOSLSearch:query failBlock:failBlock completeBlock:completeBlockSOSL];
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
    [self.store upsertEntries:recordsToSave toSoup:soupName withExternalIdPath:kSyncManagerServerId error:nil];
}

/** Run a sync up
 */
- (void) syncUp:(NSDictionary*)sync{
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    NSDictionary* options = sync[kSyncManagerSyncOptions];
    NSArray* fieldlist = (NSArray*) options[kSyncManagerOptionsFieldlist];
    
    /*
    String soupName = sync.getString(SYNC_SOUP_NAME);
    JSONObject options = sync.getJSONObject(SYNC_OPTIONS);
    JSONArray fieldlist = options.getJSONArray(SYNC_FIELDLIST);
    QuerySpec querySpec = QuerySpec.buildExactQuerySpec(soupName, LOCAL, "true", 2000); // XXX that could use a lot of memory
    
    // Call smartstore
    JSONArray records = smartStore.query(querySpec, 0); // TBD deal with more than 2000 locally modified records
    for (int i = 0; i <records.length(); i++) {
        JSONObject record = records.getJSONObject(i);
        
        // Do we need to do a create, update or delete
        Action action = null;
        if (record.getBoolean(LOCALLY_DELETED))
            action = Action.delete;
        else if (record.getBoolean(LOCALLY_CREATED))
            action = Action.create;
        else if (record.getBoolean(LOCALLY_UPDATED))
            action = Action.update;
        
        if (action == null) {
            // Nothing to do for this record
            continue;
        }
        
        // Getting type and id
        String objectType = (String) SmartStore.project(record, Constants.SOBJECT_TYPE);
        String objectId = record.getString(Constants.ID);
        
        // Fields to save (in the case of create or update)
        Map<String, Object> fields = new HashMap<String, Object>();
        if (action == Action.create || action == Action.update) {
            for (int j=0; j<fieldlist.length(); j++) {
                String fieldName = fieldlist.getString(j);
                if (!fieldName.equals(Constants.ID)) {
                    fields.put(fieldName, record.get(fieldName));
                }
            }
        }
        
        // Building create/update/delete request
        RestRequest request = null;
        switch (action) {
            case create: request = RestRequest.getRequestForCreate(apiVersion, objectType, fields); break;
            case delete: request = RestRequest.getRequestForDelete(apiVersion, objectType, objectId); break;
            case update: request = RestRequest.getRequestForUpdate(apiVersion, objectType, objectId, fields); break;
            default:
                break;
                
        }
        
        // Call server
        RestResponse response = restClient.sendSync(request);
        // Update smartstore
        if (response.isSuccess()) {
            // Replace id with server id during create
            if (action == Action.create) {
                record.put(Constants.ID, response.asJSONObject().get(Constants.LID));
            }
            // Set local flags to false
            record.put(LOCAL, false);
            record.put(LOCALLY_CREATED, false);
            record.put(LOCALLY_UPDATED, false);
            record.put(LOCALLY_DELETED, false);
            
            // Remove entry on delete
            if (action == Action.delete) {
                smartStore.delete(soupName, record.getLong(SmartStore.SOUP_ENTRY_ID));				
            }
            // Update entry otherwise
            else {
                smartStore.update(soupName, record, record.getLong(SmartStore.SOUP_ENTRY_ID));				
            }
        }
        
        
        // Updating status
        int progress = (i+1)*100 / records.length();
        if (progress < 100) {
            this.updateSync(sync, Status.RUNNING, progress);
        }			
    }
     */
}
@end