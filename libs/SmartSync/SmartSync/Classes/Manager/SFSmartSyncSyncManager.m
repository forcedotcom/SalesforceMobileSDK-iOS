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
#import <SalesforceRestAPI/SFRestAPI.h>

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

// query types
NSString * const kSyncManagerQueryTypeSoql = @"soql";
NSString * const kSyncManagerQueryTypeSosl = @"sosl";


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
        self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
        self.restClient = [SFRestAPI sharedInstance];
        queue = dispatch_queue_create("com.salesforce.smartsync.syncmanager",  NULL);
        [self setupSyncsSoupIfNeeded];
    }
    return self;
}

/** Return details about a sync
 @param syncId
 */
- (NSDictionary*)getSyncStatus:(long)syncId {
    return nil;
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
- (void) runSync:(long)syncId {
    NSArray* syncs = [self.store retrieveEntries:@[[NSNumber numberWithLong:syncId]] fromSoup:kSyncManagerSyncsSoupName];
    if (syncs==nil || [syncs count])
        return; // TBD throw error
    
    NSDictionary* sync = syncs[0];
    
    [self updateSync:sync withStatus:kSyncManagerStatusRunning withProgress:0];
    
    // Run on background thread
    dispatch_async(queue, ^{
        NSString* syncType = sync[kSyncManagerSyncType];
        if ([syncType isEqualToString:kSyncManagerSyncTypeDown]) {
            [self syncDown:sync];
        }
        else if ([syncType isEqualToString:kSyncManagerSyncTypeUp]) {
            [self syncUp:sync];
        }
        else {
            [self updateSync:sync withStatus:kSyncManagerStatusFailed withProgress:0];
            return;
        }
        [self updateSync:sync withStatus:kSyncManagerStatusDone withProgress:100];
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
    NSMutableDictionary* modifiedSync = [sync mutableCopy];
    modifiedSync[kSyncManagerSyncStatus] = status;
    modifiedSync[kSyncManagerSyncProgress] = [NSNumber numberWithInt:progress];
    
    [self.store upsertEntries:@[ modifiedSync ] toSoup:kSyncManagerSyncsSoupName];
}

/** Run a sync down
 */
- (void) syncDown:(NSDictionary*)sync{
    NSString* soupName = sync[kSyncManagerSyncSoupName];
    NSDictionary* target = sync[kSyncManagerSyncTarget];
    NSString* queryType = target[kSyncManagerTargetQueryType];
    SFRestRequest* request;
    
    if ([queryType isEqualToString:kSyncManagerQueryTypeSoql]) {

    }
    else if ([queryType isEqualToString:kSyncManagerQueryTypeSosl]) {
        
    }
    else {
        // TBD throw error
    }
    
    /*
    JSONObject target = sync.getJSONObject(SYNC_TARGET);
    String soupName = sync.getString(SYNC_SOUP_NAME);
    
    QueryType queryType = QueryType.valueOf(target.getString(QUERY_TYPE));
    String query = target.getString(QUERY);
    RestRequest request = null;
    
    switch(queryType) {
        case soql:
            request = RestRequest.getRequestForQuery(apiVersion, query);
            break;
        case sosl:
            request = RestRequest.getRequestForSearch(apiVersion, query);
            break;
        default:
            throw new SmartSyncException("Unknown query type: " + queryType);
    }
    
    // Call server
    RestResponse response = restClient.sendSync(request);
    
    // Counting records
    int countFetched = 0;
    
    while(response != null) {
        // Parse response
        JSONObject responseJson = response.asJSONObject();
        JSONArray records = responseJson.getJSONArray(Constants.RECORDS);
        int totalSize = responseJson.getInt(Constants.TOTAL_SIZE);
        
        // No records returned
        if (totalSize == 0)
            break;
        
        // Save to SmartStore
        smartStore.beginTransaction();
        for (int i = 0; i < records.length(); i++) {
            JSONObject record = records.getJSONObject(i);
            record.put(LOCAL, false);
            record.put(LOCALLY_CREATED, false);
            record.put(LOCALLY_UPDATED, false);
            record.put(LOCALLY_DELETED, false);
            smartStore.upsert(soupName, records.getJSONObject(i), Constants.ID, false);
        }
        smartStore.setTransactionSuccessful();
        smartStore.endTransaction();
        
        // Updating count fetched
        countFetched += records.length();
        
        // Updating status
        int progress = countFetched*100/totalSize;
        if (progress < 100) {
            updateSync(sync, Status.RUNNING, progress);
        }
        
        // Fetch next records if any
        String nextRecordsUrl = responseJson.optString(Constants.NEXT_RECORDS_URL, null);
        response = nextRecordsUrl == null ? null : restClient.sendSync(RestMethod.GET, nextRecordsUrl, null);
    }
    */
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