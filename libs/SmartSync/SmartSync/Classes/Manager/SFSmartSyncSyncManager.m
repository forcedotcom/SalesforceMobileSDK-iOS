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

#import "SFSmartSyncSyncManager.h"
#import <SmartStore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import "SFAdvancedSyncUpTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSyncUpTarget+Internal.h"

// Unchanged
NSInteger const kSyncManagerUnchanged = -1;

static NSString * const kSFAppFeatureSmartSync   = @"SY";


// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.smartsync.manager.syncmanager.QUEUE";

// block type
typedef void (^SyncUpdateBlock) (NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp);
typedef void (^SyncFailBlock) (NSString* message, NSError* error);

@interface SFSmartSyncSyncManager ()

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableSet *runningSyncIds;

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
    return [self sharedInstanceForUser:user storeName:nil];
}

+ (instancetype)sharedInstanceForUser:(SFUserAccount *)user storeName:(NSString *)storeName {
    if (user == nil) return nil;
    if (storeName.length == 0) storeName = kDefaultSmartStoreName;
    
    SFSmartStore *store = [SFSmartStore sharedStoreWithName:storeName user:user];
    return [self sharedInstanceForStore:store];
}

+ (instancetype)sharedInstanceForStore:(SFSmartStore *)store {
    @synchronized ([SFSmartSyncSyncManager class]) {
        if (store == nil || store.storePath == nil) return nil;
        
        NSString *key = [SFSmartSyncSyncManager keyForStore:store];
        id syncMgr = [syncMgrList objectForKey:key];
        if (syncMgr == nil) {
            if (store.user && store.user.loginState != SFUserAccountLoginStateLoggedIn) {
                [SFSDKSmartSyncLogger w:[self class] format:@"%@ A user account must be in the  SFUserAccountLoginStateLoggedIn state in order to create a sync for a user store.", NSStringFromSelector(_cmd), store.storeName, NSStringFromClass(self)];
                return nil;
            }
            syncMgr = [[self alloc] initWithStore:store];
            syncMgrList[key] = syncMgr;
        }
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSmartSync];
        return syncMgr;
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
     for (NSString *key in [syncMgrList allKeys]) {
         // remove all user related sync managers
         if ([self isUserRelatedSync:key user:user]) {
             [self removeSharedInstanceForKey:key];
         }
     }
}

+ (void)removeSharedInstanceForUser:(SFUserAccount *)user storeName:(NSString *)storeName {
    if (user == nil) return;
    if (storeName.length == 0) storeName = kDefaultSmartStoreName;
    NSString* key = [SFSmartSyncSyncManager keyForUser:user storeName:storeName];
    [SFSmartSyncSyncManager removeSharedInstanceForKey:key];
}

+ (void)removeSharedInstanceForStore:(SFSmartStore*) store {
    NSString* key = [SFSmartSyncSyncManager keyForStore:store];
    [SFSmartSyncSyncManager removeSharedInstanceForKey:key];
}

+ (void)removeSharedInstanceForKey:(NSString*) key {
    @synchronized([SFSmartSyncSyncManager class]) {
        [syncMgrList removeObjectForKey:key];
    }
}

+ (void)removeSharedInstances {
    @synchronized (([SFSmartSyncSyncManager class])) {
        [syncMgrList removeAllObjects];
    }
}


+ (NSString*)keyForStore:(SFSmartStore*)store {
    return [SFSmartSyncSyncManager keyForUser:store.user storeName:store.storeName];
}

+ (NSString*)keyForUser:(SFUserAccount*)user storeName:(NSString*)storeName {
    NSString* keyPrefix = user == nil ? SFKeyForUserAndScope(nil, SFUserAccountScopeGlobal) : SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
    return [NSString  stringWithFormat:@"%@-%@", keyPrefix, storeName];
}

+ (BOOL)isUserRelatedSync:(NSString*)key user:(SFUserAccount*)user {
    NSString* userPrefix = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
    return ([key rangeOfString:userPrefix].location != NSNotFound );
}

#pragma mark - init / dealloc

- (instancetype)initWithStore:(SFSmartStore *)store {
    self = [super init];
    if (self) {
        self.runningSyncIds = [NSMutableSet new];
        self.store = store;
        self.queue = dispatch_queue_create(kSyncManagerQueue,  DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserWillLogout:)  name:kSFNotificationUserWillLogout object:nil];
        [SFSyncState setupSyncsSoupIfNeeded:self.store];
    }
    return self;
}

#pragma mark - has / get sync methods

- (SFSyncState*)getSyncStatus:(NSNumber*)syncId {
    SFSyncState* sync = [SFSyncState byId:syncId store:self.store];
    
    if (sync == nil) {
        [SFSDKSmartSyncLogger d:[self class] format:@"Sync %@ not found", syncId];
    }
    return sync;
}

- (SFSyncState*)getSyncStatusByName:(NSString*)syncName {
    SFSyncState* sync = [SFSyncState byName:syncName store:self.store];

    if (sync == nil) {
        [SFSDKSmartSyncLogger d:[self class] format:@"Sync %@ not found", syncName];
    }
    return sync;
}

- (BOOL)hasSyncWithName:(NSString*)syncName {
    return [SFSyncState byName:syncName store:self.store] != nil;
}

#pragma mark - delete sync methods

- (void)deleteSyncById:(NSNumber *)syncId {
    [SFSyncState deleteById:syncId store:self.store];
}

- (void)deleteSyncByName:(NSString*)syncName {
    [SFSyncState deleteByName:syncName store:self.store];
}

#pragma mark - run sync methods

/** Run a previously created sync
 */
- (void) runSync:(SFSyncState*) sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    __weak typeof(self) weakSelf = self;
    SyncUpdateBlock updateSync = ^(NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (status == nil) status = (progress == 100 ? kSFSyncStateStatusDone : kSFSyncStateStatusRunning);
        sync.status = [SFSyncState syncStatusFromString:status];
        if (progress>=0)  sync.progress = progress;
        if (totalSize>=0) sync.totalSize = totalSize;
        if (maxTimeStamp>=0) sync.maxTimeStamp = (sync.maxTimeStamp < maxTimeStamp ? maxTimeStamp : sync.maxTimeStamp);
        [sync save:strongSelf.store];
        [SFSDKSmartSyncLogger d:[strongSelf class] format:@"Sync update:%@", sync];
        NSString *eventName = nil;
        switch (sync.type) {
            case SFSyncStateSyncTypeDown:
                eventName = @"syncDown";
                break;
            case SFSyncStateSyncTypeUp:
                eventName = @"syncUp";
                break;
        }
        NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
        attributes[@"numRecords"] = [NSNumber numberWithInteger:sync.totalSize];
        attributes[@"syncId"] = [NSNumber numberWithInteger:sync.syncId];
        attributes[@"syncTarget"] = NSStringFromClass([sync.target class]);
        attributes[kSFSDKEventBuilderHelperStartTime] = [NSNumber numberWithInteger:sync.startTime];
        attributes[kSFSDKEventBuilderHelperEndTime] = [NSNumber numberWithInteger:sync.endTime];
        switch (sync.status) {
            case SFSyncStateStatusNew:
                break; // should not happen
            case SFSyncStateStatusRunning:
                [strongSelf.runningSyncIds addObject:[NSNumber numberWithInteger:sync.syncId]];
                break;
            case SFSyncStateStatusDone:
            case SFSyncStateStatusFailed:
                [SFSDKEventBuilderHelper createAndStoreEvent:eventName userAccount:nil className:NSStringFromClass([strongSelf class]) attributes:attributes];
                [strongSelf.runningSyncIds removeObject:[NSNumber numberWithInteger:sync.syncId]];
                break;
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    };

    SyncFailBlock failSync = ^(NSString* failureMessage, NSError* error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [SFSDKSmartSyncLogger e:[strongSelf class] format:@"runSync failed:%@ cause:%@ error%@", sync, failureMessage, error];
        updateSync(kSFSyncStateStatusFailed, kSyncManagerUnchanged, kSyncManagerUnchanged, kSyncManagerUnchanged);
    };

    // Run on background thread
    updateSync(kSFSyncStateStatusRunning, 0, kSyncManagerUnchanged, kSyncManagerUnchanged);
    dispatch_async(self.queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        switch (sync.type) {
            case SFSyncStateSyncTypeDown:
                [strongSelf syncDown:sync updateSync:updateSync failSync:failSync];
                break;
            case SFSyncStateSyncTypeUp:
                [strongSelf syncUp:sync updateSync:updateSync failSync:failSync];
                break;
        }
    });
}

#pragma mark - syncDown, reSync and supporting methods

/** Create and run a sync down
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite];
    return [self syncDownWithTarget:target options:options soupName:soupName updateBlock:updateBlock];
}

- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
   return [self syncDownWithTarget:target options:options soupName:soupName syncName:nil updateBlock:updateBlock];
}

- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState *sync = [self createSyncDown:target options:options soupName:soupName syncName:syncName];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState *)createSyncDown:(SFSyncDownTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName name:syncName store:self.store];
    [SFSDKSmartSyncLogger d:[self class] format:@"Created syncDown:%@", sync];
    return sync;
}

/** Resync
 */
- (SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    if ([self.runningSyncIds containsObject:syncId]) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run reSync:%@:still running", syncId];
        return nil;
    }
    SFSyncState* sync = [self getSyncStatus:(NSNumber *)syncId];
    if (sync == nil) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run reSync:%@:no sync found", syncId];
         return nil;
    }
    sync.totalSize = -1;
    [sync save:self.store];
    [SFSDKSmartSyncLogger d:[self class] format:@"reSync:%@", sync];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState*) reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState *sync = [self getSyncStatusByName:syncName];
    if (sync == nil) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run reSync:%@:no sync found", syncName];
        return nil;
    }
    else {
        return [self reSync:[NSNumber numberWithInteger:sync.syncId] updateBlock:updateBlock];
    }
}


/** Run a sync down
 */
- (void) syncDown:(SFSyncState*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncDownTarget* target = (SFSyncDownTarget*) sync.target;
    long long maxTimeStamp = sync.maxTimeStamp;
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];

    __block NSUInteger countFetched = 0;
    __block NSUInteger totalSize = 0;
    __block NSUInteger progress = 0;
    __block SFSyncDownTargetFetchCompleteBlock continueFetchBlockRecurse = ^(NSArray *records) {};

    __block NSOrderedSet* idsToSkip = nil;
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged) {
        idsToSkip = [target getIdsToSkip:self soupName:soupName];
    }
   
    SFSyncDownTargetFetchErrorBlock failBlock = ^(NSError *error) {
        failSync(@"Server call for sync down failed", error);
        continueFetchBlockRecurse = nil;
    };
    
    SFSyncDownTargetFetchCompleteBlock startFetchBlock = ^(NSArray* records) {
        totalSize = target.totalSize;
        updateSync(nil, totalSize == 0 ? 100 : 0, target.totalSize, kSyncManagerUnchanged);
        if (totalSize != 0)
            continueFetchBlockRecurse(records);
        else
            continueFetchBlockRecurse = nil;
    };
    
    __weak typeof (self) weakSelf = self;
    SFSyncDownTargetFetchCompleteBlock continueFetchBlock = ^(NSArray* records) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if (records != nil) {
            // Figure out records to save
            NSArray* recordsToSave = idsToSkip && idsToSkip.count > 0 ? [strongSelf  removeWithIds:records idsToSkip:idsToSkip idField:target.idFieldName] : records;

            // Save to smartstore.
            [target cleanAndSaveRecordsToLocalStore:strongSelf soupName:soupName records:recordsToSave syncId:syncId];
            countFetched += [records count];
            progress = 100*countFetched / totalSize;

            long long maxTimeStampForFetched = [target getLatestModificationTimeStamp:records];

            // Update sync status.
            updateSync(nil, progress, totalSize, maxTimeStampForFetched);

            // Fetch next records, if any.
            [target continueFetch:self errorBlock:failBlock completeBlock:continueFetchBlockRecurse];
        }
        else {
            // In some cases (e.g. resync for refresh sync down), the totalSize is just an (over)estimation
            // As a result progress might not get to 100 and therefore a DONE would never be sent
            if (progress < 100) {
                updateSync(nil, 100, -1 /*unchanged*/, -1 /*unchanged*/);
            }
            continueFetchBlockRecurse = nil;
        }
    };
    
    // initialize the alias
    continueFetchBlockRecurse = continueFetchBlock;
    
    // Start fetch
    [target startFetch:self maxTimeStamp:maxTimeStamp errorBlock:failBlock completeBlock:startFetchBlock];
}

- (NSArray*) removeWithIds:(NSArray*)records idsToSkip:(NSOrderedSet*)idsToSkip idField:(NSString*)idField {
    NSMutableArray * arr = [NSMutableArray new];
    for (NSDictionary* record in records) {
        // Keep ?
        NSString* id = record[idField];
        if (!id || ![idsToSkip containsObject:id]) {
            [arr addObject:record];
        }
    }
    return arr;
}

#pragma mark - syncUp and supporting methods

/** Create and run a sync up
 */
- (SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState *sync = [self createSyncUp:[[SFSyncUpTarget alloc] init] options:options soupName:soupName syncName:nil];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState*) syncUpWithTarget:(SFSyncUpTarget *)target
                         options:(SFSyncOptions *)options
                        soupName:(NSString *)soupName
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [self syncUpWithTarget:target options:options soupName:soupName syncName:nil updateBlock:updateBlock];
}

- (SFSyncState*) syncUpWithTarget:(SFSyncUpTarget *)target
                         options:(SFSyncOptions *)options
                        soupName:(NSString *)soupName
                        syncName:(NSString*)syncName
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncState *sync = [self createSyncUp:target options:options soupName:soupName syncName:syncName];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState *)createSyncUp:(SFSyncUpTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:target soupName:soupName name:syncName store:self.store];
    [SFSDKSmartSyncLogger d:[self class] format:@"Created syncUp:%@", sync];
    return sync;
}

/** Run a sync up
 */
- (void) syncUp:(SFSyncState*)sync updateSync:(SyncUpdateBlock)updateSync failSync:(SyncFailBlock)failSync {
    NSString* soupName = sync.soupName;
    SFSyncUpTarget* target = (SFSyncUpTarget*) sync.target;

    // Call smartstore
    NSArray* dirtyRecordIds = [target getIdsOfRecordsToSyncUp:self soupName:soupName];
    NSUInteger totalSize = dirtyRecordIds.count;
    if (totalSize == 0) {
        updateSync(nil, 100, totalSize, kSyncManagerUnchanged);
        return;
    }
    
    // Fail block for rest call
    SFSyncUpTargetErrorBlock failBlock = ^(NSError *error) {
        failSync(@"Server call for sync up failed", error);
    };

    // Otherwise, there's work to do.
    [self syncUpOneEntry:sync recordIds:dirtyRecordIds index:0 updateSync:updateSync failBlock:failBlock];
}

- (void) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock {
    if ([self.runningSyncIds containsObject:syncId]) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run cleanResyncGhosts:%@:still running", syncId];
        return;
    }
    SFSyncState* sync = [self getSyncStatus:(NSNumber *)syncId];
    if (sync == nil) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run cleanResyncGhosts:%@:no sync found", syncId];
        return;
    }
    if (sync.type != SFSyncStateSyncTypeDown) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Cannot run cleanResyncGhosts:%@:wrong type:%@", syncId, [SFSyncState syncTypeToString:sync.type]];
        return;
    }
    [SFSDKSmartSyncLogger d:[self class] format:@"cleanResyncGhosts:%@", sync];
    NSString* soupName = [sync soupName];
    Class currentClass = [self class];
    
    // Run on background thread
    __weak typeof(self) weakSelf = self;

    // Preparing event for SFSDKEventBuilderHelper
    NSMutableDictionary *eventAttrs = [[NSMutableDictionary alloc] init];
    eventAttrs[@"syncId"] = [NSNumber numberWithInteger:sync.syncId];
    eventAttrs[@"syncTarget"] = NSStringFromClass([sync.target class]);
    
    dispatch_async(self.queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        [(SFSyncDownTarget *) sync.target cleanGhosts:strongSelf
                                             soupName:soupName
                                               syncId:syncId
                                           errorBlock:^(NSError *e) {
                                               [SFSDKSmartSyncLogger e:currentClass format:@"Failed to get list of remote IDs, %@", [e localizedDescription]];
                                               [SFSDKEventBuilderHelper createAndStoreEvent:@"cleanResyncGhosts" userAccount:nil className:NSStringFromClass(currentClass) attributes:eventAttrs];
                                               completionStatusBlock(SFSyncStateStatusFailed, 0);
                                           }
                                        completeBlock:^(NSArray *localIds) {
                                            eventAttrs[@"numRecords"] = [NSNumber numberWithInteger:localIds.count];
                                            [SFSDKEventBuilderHelper createAndStoreEvent:@"cleanResyncGhosts" userAccount:nil className:NSStringFromClass(currentClass) attributes:eventAttrs];

                                            completionStatusBlock(SFSyncStateStatusDone, localIds.count);
                                        }];
    });
}

- (void)syncUpOneEntry:(SFSyncState*)sync
             recordIds:(NSArray*)recordIds
                 index:(NSUInteger)i
            updateSync:(SyncUpdateBlock)updateSync
             failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    NSUInteger totalSize = recordIds.count;
    NSUInteger progress = i*100 / totalSize;
    updateSync(nil, progress, totalSize, kSyncManagerUnchanged);
    
    if (progress == 100) {
        // Done
        return;
    }
    
    NSMutableDictionary* record = [[target getFromLocalStore:self soupName:soupName storeId:recordIds[i]] mutableCopy];
    [SFSDKSmartSyncLogger d:[self class] format:@"syncUpOneRecord:%@", record];

    // Do we need to do a create, update or delete
    BOOL locallyCreated = [target isLocallyCreated:record];
    BOOL locallyUpdated = [target isLocallyUpdated:record];
    BOOL locallyDeleted = [target isLocallyDeleted:record];
    
    SFSyncUpTargetAction action = SFSyncUpTargetActionNone;
    if (locallyDeleted)
        action = SFSyncUpTargetActionDelete;
    else if (locallyCreated)
        action = SFSyncUpTargetActionCreate;
    else if (locallyUpdated)
        action = SFSyncUpTargetActionUpdate;
    
    /*
     * Checks if we are attempting to update a record that has been updated
     * on the server AFTER the client's last sync down. If the merge mode
     * passed in tells us to leave the record alone under these
     * circumstances, we will do nothing.
     */
    if (mergeMode == SFSyncStateMergeModeLeaveIfChanged && !locallyCreated) {
        // Need to check the modification date on the server, against the local date.
        __weak typeof(self) weakSelf = self;
        [target isNewerThanServer:self record:record resultBlock:^(BOOL isNewerThanServer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (isNewerThanServer) {
                [strongSelf resumeSyncUpOneEntry:sync
                                       recordIds:recordIds
                                           index:i
                                          record:record
                                          action:action
                                      updateSync:updateSync
                                       failBlock:failBlock];
            }
            else {
                // Server date is newer than the local date.  Skip this update.
                [SFSDKSmartSyncLogger d:[strongSelf class] format:@"syncUpOneRecord: Record not synced since client does not have the latest from server:%@", record];
                [strongSelf syncUpOneEntry:sync
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
                      action:(SFSyncUpTargetAction)action
                  updateSync:(SyncUpdateBlock)updateSync
                   failBlock:(SFSyncUpTargetErrorBlock)failBlock {
    
    SFSyncStateMergeMode mergeMode = sync.mergeMode;
    SFSyncUpTarget *target = (SFSyncUpTarget *)sync.target;
    NSString* soupName = sync.soupName;
    __weak typeof(self) weakSelf = self;
    // Next
    void (^nextBlock)(void)=^() {
        [weakSelf syncUpOneEntry:sync recordIds:recordIds index:i+1 updateSync:updateSync failBlock:failBlock];
    };

    // Advanced sync up target take it from here
    if ([target conformsToProtocol:@protocol(SFAdvancedSyncUpTarget)]) {
        SFSyncUpTarget<SFAdvancedSyncUpTarget>* advancedTarget = (SFSyncUpTarget<SFAdvancedSyncUpTarget>*) target;
        [advancedTarget syncUpRecord:self
                              record:record
                           fieldlist:sync.options.fieldlist
                           mergeMode:sync.options.mergeMode
                     completionBlock:^(NSDictionary *syncUpResult) { nextBlock();}
                           failBlock:^(NSError *error) { failBlock(error);}
        ];
        return;
    }

    // If it is not a advanced sync up target and there is no changes on the record, go to next
    if (action == SFSyncUpTargetActionNone) {
        // Next
        nextBlock();
        return;
    }
    // Delete handler
    SFSyncUpTargetCompleteBlock completeBlockDelete = ^(NSDictionary *d) {
        // Remove entry on delete
        [target deleteFromLocalStore:weakSelf soupName:soupName record:record];

        // Next
        nextBlock();
    };
    
    // Update handler
    SFSyncUpTargetCompleteBlock completeBlockUpdate = ^(NSDictionary *d) {
        [target cleanAndSaveInLocalStore:weakSelf soupName:soupName record:record];

        // Next
        nextBlock();
    };
    
    // Create handler
    NSString *fieldName = target.idFieldName;
    SFSyncUpTargetCompleteBlock completeBlockCreate = ^(NSDictionary *d) {
        // Replace id with server id during create
        record[fieldName] = d[kCreatedId];
        completeBlockUpdate(d);
    };

    // Create failure handler
    SFSyncUpTargetErrorBlock failBlockCreate = ^ (NSError* err){
        if ([SFRestRequest isNetworkError:err]) {
            failBlock(err);
        }
        else {
            [target saveRecordToLocalStoreWithLastError:self soupName:soupName record:record];

            // Next
            nextBlock();
        }
    };
    
    // Update failure handler
    SFSyncUpTargetErrorBlock failBlockUpdate = ^ (NSError* err){
        // Handling remotely deleted records
        if (err.code == 404) {
            if (mergeMode == SFSyncStateMergeModeOverwrite) {
                [target createOnServer:weakSelf record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockCreate failBlock:failBlockCreate];
            }
            else {
                // Next
                nextBlock();
            }
        }
        else if ([SFRestRequest isNetworkError:err]) {
            failBlock(err);
        }
        else {
            [target saveRecordToLocalStoreWithLastError:self soupName:soupName record:record];

            // Next
            nextBlock();
        }
    };
    
    // Delete failure handler
    SFSyncUpTargetErrorBlock failBlockDelete = ^ (NSError* err){
        // Handling remotely deleted records
        if (err.code == 404) {
            completeBlockDelete(nil);
        }
        else if ([SFRestRequest isNetworkError:err]) {
            failBlock(err);
        }
        else {
            [target saveRecordToLocalStoreWithLastError:self soupName:soupName record:record];

            // Next
            nextBlock();
        }
    };
    
    switch(action) {
        case SFSyncUpTargetActionCreate:
            [target createOnServer:self record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockCreate failBlock:failBlockCreate];
            break;
        case SFSyncUpTargetActionUpdate:
            [target updateOnServer:self record:record fieldlist:sync.options.fieldlist completionBlock:completeBlockUpdate failBlock:failBlockUpdate];
            break;
        case SFSyncUpTargetActionDelete:
            // if locally created it can't exist on the server - we don't need to actually do the deleteOnServer call
            if ([target isLocallyCreated:record]) {
                completeBlockDelete(record);
            }
            else {
                [target deleteOnServer:self record:record completionBlock:completeBlockDelete failBlock:failBlockDelete];
            }
            break;
        default:
            // Action is unsupported here.  Move on.
            [SFSDKSmartSyncLogger i:[self class] format:@"%@ unsupported action with value %lu.  Moving to the next record.", NSStringFromSelector(_cmd), (unsigned long) action];
            nextBlock();
            return;
    }
}

- (void)handleUserWillLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
     [[self class] removeSharedInstance:user];
}

@end

