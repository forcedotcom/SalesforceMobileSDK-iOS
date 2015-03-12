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
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSyncServerTarget.h"
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFQuerySpec.h>

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

// response
NSString * const kSyncManagerLObjectId = @"id"; // e.g. create response

// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.smartsync.manager.syncmanager.QUEUE";

// block type
typedef void (^SyncUpdateBlock) (NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp);
typedef void (^SyncFailBlock) (NSString* message, NSError* error);

@interface SFSmartSyncSyncManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) dispatch_queue_t queue;

@end


@implementation SFSmartSyncSyncManager

static NSMutableDictionary *syncMgrList = nil;

#pragma mark - instance access / cleanup

+ (void)initialize {
    if (self == [SFSmartSyncSyncManager class]) {
        syncMgrList = [NSMutableDictionary new];
    }
}

+ (instancetype)sharedInstance:(SFUserAccount *)user {
    if (user) {
        SFSmartStore *store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:user];
        return [self sharedInstanceForStore:store];
    } else {
        return nil;
    }
}

+ (instancetype)sharedInstanceForStore:(SFSmartStore *)store {
    @synchronized ([SFSmartSyncSyncManager class]) {
        if (store == nil || store.storePath == nil) return nil;
        
        NSString *storePath = store.storePath;
        id syncMgr = [syncMgrList objectForKey:storePath];
        if (syncMgr == nil) {
            syncMgr = [[self alloc] initWithStore:store];
            syncMgrList[storePath] = syncMgr;
        }
        return syncMgr;
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
    if (user) {
        SFSmartStore *store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:user];
        [self removeSharedInstanceForStore:store];
    }
}

+ (void)removeSharedInstanceForStore:(SFSmartStore *)store {
    @synchronized([SFSmartSyncSyncManager class]) {
        if (store && store.storePath.length > 0) {
            NSString *key = store.storePath;
            [syncMgrList removeObjectForKey:key];
        }
    }
}

#pragma mark - init / dealloc

- (instancetype)initWithStore:(SFSmartStore *)store {
    self = [super init];
    if (self) {
        self.store = store;
        self.queue = dispatch_queue_create(kSyncManagerQueue,  NULL);
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [SFSyncState setupSyncsSoupIfNeeded:self.store];
    }
    return self;
}


- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
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
    long long maxTimeStamp = sync.maxTimeStamp;

    void (^failBlock)(NSError *error) = ^(NSError *error) {
        failSync(@"Server call failed", error);
    };

    __block NSUInteger countFetched = 0;
    __block NSUInteger totalSize = 0;
    __block SFSyncTargetFetchCompleteBlock completeBlockRecurse = ^(NSArray *records) {};
    __weak SFSmartSyncSyncManager *weakSelf = self;
    
    SFSyncTargetFetchCompleteBlock completeBlock = ^(NSArray* records) {
        totalSize = target.totalSize;
        if (countFetched == 0) { // after first request only
            updateSync(nil, totalSize == 0 ? 100 : 0, totalSize, kSyncManagerUnchanged);
            if (totalSize == 0) {
                return;
            }
        }
        
        if (records == nil || records.count == 0) {
            // Shouldn't happen but custom target could be improperly coded
            return;
        }
        countFetched += [records count];
        NSUInteger progress = 100*countFetched / totalSize;
        long long maxTimeStampForFetched = [self getMaxTimeStamp:records];
        
        // Save records
        NSError *saveRecordsError = nil;
        [weakSelf saveRecords:records soup:soupName mergeMode:mergeMode error:&saveRecordsError];
        if (saveRecordsError) {
            failSync(@"Failed to save SmartStore records on syncDown", saveRecordsError);
        } else {
            // Update status
            updateSync(nil, progress, totalSize, maxTimeStampForFetched);
            
            // Fetch next records if any
            if (countFetched < totalSize) {
                [target continueFetch:self errorBlock:failBlock completeBlock:completeBlockRecurse];
            }
        }
    };
    // initialize the alias
    completeBlockRecurse = completeBlock;
    
    // Start fetch
    [target startFetch:self maxTimeStamp:maxTimeStamp errorBlock:failBlock completeBlock:completeBlock];
}

- (void) saveRecords:(NSArray*)records soup:(NSString*)soupName mergeMode:(SFSyncStateMergeMode)mergeMode error:(NSError **)error {
    NSMutableArray* recordsToSave = [NSMutableArray array];
    
    NSSet* idsToSkip = nil;
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged) {
        idsToSkip = [self getDirtyRecordIds:soupName idField:kId];
    }
    
    // Prepare for smartstore
    for (NSDictionary* record in records) {
        // Skip?
        if (idsToSkip != nil && [idsToSkip containsObject:record[kId]]) {
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
    NSError *upsertError = nil;
    [self.store upsertEntries:recordsToSave toSoup:soupName withExternalIdPath:kId error:&upsertError];
    if (upsertError && error) {
        *error = upsertError;
    }
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
        NSString* timeStampStr = record[kLastModifiedDate];
        if (!timeStampStr) {
            break; // LastModifiedDate field not present
        }
        long long timeStamp = [SFSmartSyncObjectUtils getMillisFromIsoString:timeStampStr];
        maxTimeStamp = (timeStamp > maxTimeStamp ? timeStamp : maxTimeStamp);
    }
    return maxTimeStamp;
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
    SFSyncServerTarget *defaultServerTarget = [[SFSyncServerTarget alloc] init];
    return [self syncUpWithTarget:defaultServerTarget options:options soupName:soupName updateBlock:updateBlock];
}

- (SFSyncState*)syncUpWithTarget:(SFSyncServerTarget *)serverTarget
                         options:(SFSyncOptions *)options
                        soupName:(NSString *)soupName
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:serverTarget soupName:soupName store:self.store];
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
    void (^failBlock)(NSError *error) = ^(NSError *error) {
        failSync(@"Server call failed", error);
    };

    // Otherwise, there's work to do.
    [self syncUpOneEntry:sync recordIds:dirtyRecordIds index:0 updateSync:updateSync failBlock:failBlock];
}

- (void)syncUpOneEntry:(SFSyncState*)sync
             recordIds:(NSArray*)recordIds
                 index:(NSUInteger)i
            updateSync:(SyncUpdateBlock)updateSync
             failBlock:(void (^)(NSError *))failBlock {
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
    SFSyncServerTargetAction action = SFSyncServerTargetActionNone;
    if ([record[kSyncManagerLocallyDeleted] boolValue])
        action = SFSyncServerTargetActionDelete;
    else if ([record[kSyncManagerLocallyCreated] boolValue])
        action = SFSyncServerTargetActionCreate;
    else if ([record[kSyncManagerLocallyUpdated] boolValue])
        action = SFSyncServerTargetActionUpdate;
    
    if (action == SFSyncServerTargetActionNone) {
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failBlock:failBlock];
        return;
    }
    
    /*
     * Checks if we are attempting to update a record that has been updated
     * on the server AFTER the client's last sync down. If the merge mode
     * passed in tells us to leave the record alone under these
     * circumstances, we will do nothing and return here.
     */
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged &&
        (action == SFSyncServerTargetActionUpdate || action == SFSyncServerTargetActionDelete)) {
        // Need to check the modification date on the server, against the local date.
        [sync.serverTarget fetchRecordModificationDates:record
                                modificationResultBlock:^(NSDate *localDate, NSDate *serverDate, NSError *error) {
                                    if ([localDate compare:serverDate] != NSOrderedAscending) {
                                        // Local date is newer than or the same as the server date.
                                        [self resumeSyncUpOneEntry:sync
                                                         recordIds:recordIds
                                                             index:i
                                                            record:record
                                                            action:action
                                                        updateSync:updateSync
                                                         failBlock:failBlock];
                                    } else {
                                        // Server date is newer than the local date.  Skip this update.
                                        [self syncUpOneEntry:sync
                                                   recordIds:recordIds
                                                       index:i+1
                                                  updateSync:updateSync
                                                   failBlock:failBlock];
                                    }
                                }];
    } else {
        // State is such that we can simply update the record directly.
        [self resumeSyncUpOneEntry:sync recordIds:recordIds index:i record:record action:action updateSync:updateSync failBlock:failBlock];
    }
}

- (void)resumeSyncUpOneEntry:(SFSyncState*)sync
                   recordIds:(NSArray*)recordIds
                       index:(NSUInteger)i
                      record:(NSMutableDictionary*)record
                      action:(SFSyncServerTargetAction)action
                  updateSync:(SyncUpdateBlock)updateSync
                   failBlock:(void (^)(NSError *))failBlock {
    
    NSString* soupName = sync.soupName;
    NSNumber* soupEntryId = record[SOUP_ENTRY_ID];
    
    // Delete handler
    void (^completeBlockDelete)(NSDictionary *) = ^(NSDictionary *d) {
        // Remove entry on delete
        [self.store removeEntries:@[soupEntryId] fromSoup:soupName];
        
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failBlock:failBlock];
    };
    
    // Update handler
    void (^completeBlockUpdate)(NSDictionary *) = ^(NSDictionary *d) {
        // Set local flags to false
        record[kSyncManagerLocal] = @NO;
        record[kSyncManagerLocallyCreated] = @NO;
        record[kSyncManagerLocallyUpdated] = @NO;
        record[kSyncManagerLocallyDeleted] = @NO;
        
        // Update smartstore
        [self.store upsertEntries:@[record] toSoup:soupName];
        
        // Next
        [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failBlock:failBlock];
    };
    
    // Create handler
    void (^completeBlockCreate)(NSDictionary *) = ^(NSDictionary *d) {
        // Replace id with server id during create
        record[kId] = d[kSyncManagerLObjectId];
        completeBlockUpdate(d);
    };
    
    void (^completeBlock)(NSDictionary *);
    switch(action) {
        case SFSyncServerTargetActionCreate:
            completeBlock = completeBlockCreate;
            break;
        case SFSyncServerTargetActionUpdate:
            completeBlock = completeBlockUpdate;
            break;
        case SFSyncServerTargetActionDelete:
            completeBlock = completeBlockDelete;
            break;
        default:
            // Action is unsupported here.  Move on.
            [self log:SFLogLevelInfo format:@"%@ unsupported action with value %d.  Moving to the next record.", NSStringFromSelector(_cmd), action];
            [self syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failBlock:failBlock];
            return;
    }
    
    SFSyncServerTarget *target = sync.serverTarget;
    NSArray *fieldList = sync.options.fieldlist;
    [target syncUpRecord:record fieldList:fieldList action:action completionBlock:completeBlock failBlock:failBlock];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}

@end
