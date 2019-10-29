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

#import "SFMobileSyncSyncManager.h"
#import <SmartStore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import "SFAdvancedSyncUpTarget.h"
#import "SFMobileSyncConstants.h"
#import "SFSyncUpTarget+Internal.h"
#import "SFSyncUpTask.h"
#import "SFSyncDownTask.h"
#import "SFAdvancedSyncUpTask.h"
#import "SFCleanSyncGhostsTask.h"


static NSString * const kSFAppFeatureMobileSync   = @"SY";

// dispatch queue
char * const kSyncManagerQueue = "com.salesforce.mobilesync.manager.syncmanager.QUEUE";

// block type
typedef void (^SyncUpdateBlock) (NSString* status, NSInteger progress, NSInteger totalSize, long long maxTimeStamp);
typedef void (^SyncFailBlock) (NSString* message, NSError* error);

// Possible value for state
NSString * const kSFSyncManagerStateAcceptingSyncs = @"accepting_syncs";
NSString * const kSFSyncManagerStateStopRequested = @"stop_requested";
NSString * const kSFSyncManagerStateStopped = @"stopped";

// Errors
NSString* const kSFMobileSyncErrorDomain = @"com.salesforce.MobileSync.ErrorDomain";
NSString* const kSFSyncManagerStoppedError = @"SyncManagerStoppedError";
NSString* const kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown = @"SyncManagerCanOnlyRunCleanGhostsForSyncDown";
NSString* const kSFSyncManagerCannotRestartError = @"SyncManagerCannotRestartError";
NSString* const kSFSyncAlreadyRunningError = @"SyncAlreadyRunningError";
NSString* const kSFSyncNotExistError = @"SyncNotExistError";

NSInteger const kSFSyncManagerStoppedErrorCode = 900;
NSInteger const kSFSyncManagerCannotRestartErrorCode = 901;
NSInteger const kSFSyncAlreadyRunningErrorCode = 902;
NSInteger const kSFSyncNotExistErrorCode = 903;
NSInteger const kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode = 904;

@interface SFMobileSyncSyncManager ()

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, SFSyncTask*>*activeSyncs;
@property (nonatomic) SFSyncManagerState state;

@end


@implementation SFMobileSyncSyncManager

static NSMutableDictionary *syncMgrList = nil;

#pragma mark - instance access / cleanup

+ (void)initialize {
    if (self == [SFMobileSyncSyncManager class]) {
        syncMgrList = [NSMutableDictionary new];
    }
}

+ (instancetype)sharedInstance:(SFUserAccount *)user {
    return [self sharedInstanceForUser:user storeName:nil];
}

+ (instancetype)sharedInstanceForUser:(SFUserAccount *)user storeName:(NSString *)storeName {
    return [self sharedInstanceForStore:storeName userAccount:user];
}

+ (instancetype)sharedInstanceForStore:(NSString *)storeName userAccount:(SFUserAccount*)userAccount {
    if (userAccount == nil) return nil;
    if (storeName.length == 0) storeName = kDefaultSmartStoreName;
    
    SFSmartStore *store = [SFSmartStore sharedStoreWithName:storeName user:userAccount];
    return [self sharedInstanceForStore:store];
}

+ (instancetype)sharedInstanceForStore:(SFSmartStore *)store {
    @synchronized ([SFMobileSyncSyncManager class]) {
        if (store == nil || store.storePath == nil) return nil;
        
        NSString *key = [SFMobileSyncSyncManager keyForStore:store];
        id syncMgr = [syncMgrList objectForKey:key];
        if (syncMgr == nil) {
            if (store.user && store.user.loginState != SFUserAccountLoginStateLoggedIn) {
                [SFSDKMobileSyncLogger w:[self class] format:@"%@ A user account must be in the  SFUserAccountLoginStateLoggedIn state in order to create a sync for a user store.", NSStringFromSelector(_cmd), store.storeName, NSStringFromClass(self)];
                return nil;
            }
            syncMgr = [[self alloc] initWithStore:store];
            syncMgrList[key] = syncMgr;
        }
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMobileSync];
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
    [self removeSharedInstanceForStore:storeName userAccount:user];
}

+ (void)removeSharedInstanceForStore:(nullable NSString*)storeName userAccount:(SFUserAccount*)userAccount {
    if (userAccount == nil) return;
    if (storeName.length == 0) storeName = kDefaultSmartStoreName;
    NSString* key = [SFMobileSyncSyncManager keyForUser:userAccount storeName:storeName];
    [SFMobileSyncSyncManager removeSharedInstanceForKey:key];
}

+ (void)removeSharedInstanceForStore:(SFSmartStore*) store {
    NSString* key = [SFMobileSyncSyncManager keyForStore:store];
    [SFMobileSyncSyncManager removeSharedInstanceForKey:key];
}

+ (void)removeSharedInstanceForKey:(NSString*) key {
    @synchronized([SFMobileSyncSyncManager class]) {
        [syncMgrList removeObjectForKey:key];
    }
}

+ (void)removeSharedInstances {
    @synchronized (([SFMobileSyncSyncManager class])) {
        [syncMgrList removeAllObjects];
    }
}


+ (NSString*)keyForStore:(SFSmartStore*)store {
    return [SFMobileSyncSyncManager keyForUser:store.user storeName:store.storeName];
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
        self.activeSyncs = [NSMutableDictionary new];
        self.store = store;
        self.queue = dispatch_queue_create(kSyncManagerQueue,  DISPATCH_QUEUE_SERIAL);
        self.state = SFSyncManagerStateAcceptingSyncs;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserWillLogout:)  name:kSFNotificationUserWillLogout object:nil];
        [SFSyncState setupSyncsSoupIfNeeded:self.store];
        [SFSyncState cleanupSyncsSoupIfNeeded:self.store];
    }
    return self;
}

#pragma mark - stop / restart methods

- (void) setState:(SFSyncManagerState)state {
    if (_state != state) {
        [SFSDKMobileSyncLogger d:[self class] format:@"state changing from %@ to %@",
         [SFMobileSyncSyncManager stateToString:_state],
         [SFMobileSyncSyncManager stateToString:state]];
        _state = state;
    }
}

- (void) stop {
    @synchronized(self) {
        if (self.activeSyncs.count == 0) {
            self.state = SFSyncManagerStateStopped;
        } else {
            self.state = SFSyncManagerStateStopRequested;
        }
    }
}

- (BOOL) isStopping {
    return self.state == SFSyncManagerStateStopRequested;
}

- (BOOL) isStopped {
    return self.state == SFSyncManagerStateStopped;
}

- (BOOL) restart:(BOOL)restartStoppedSyncs updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    @synchronized (self) {
        if ([self isStopped] || [self isStopping]) {
            self.state = SFSyncManagerStateAcceptingSyncs;
            if (restartStoppedSyncs) {
                NSArray* stoppedSyncs = [SFSyncState getSyncsWithStatus:self.store status:SFSyncStateStatusStopped];
                for (SFSyncState* sync in stoppedSyncs) {
                    [SFSDKMobileSyncLogger d:[self class] format:@"restarting %@", @(sync.syncId)];
                    [self reSync:@(sync.syncId) updateBlock:updateBlock error:nil];
                }
            }
            return YES;
        } else {
            if (error) {
                NSString* description = [NSString stringWithFormat:@"restart() called on a sync manager that has state: %@", [SFMobileSyncSyncManager stateToString:self.state]];
                *error = [self errorWithType:kSFSyncManagerCannotRestartError code:kSFSyncManagerCannotRestartErrorCode description:description];
            }
            return NO;
        }
    }
}

- (void) addToActiveSyncs:(SFSyncTask*)syncTask {
    @synchronized(self) {
        self.activeSyncs[syncTask.syncId] = syncTask;
    }
}

- (void) removeFromActiveSyncs:(SFSyncTask*)syncTask {
    @synchronized(self) {
        [self.activeSyncs removeObjectForKey:syncTask.syncId];
        if (self.state == SFSyncManagerStateStopRequested && self.activeSyncs.count == 0) {
            self.state = SFSyncManagerStateStopped;
        }
    }
}

# pragma mark - check* methods

- (BOOL) checkAcceptingSyncs:(NSError**)error {
    if (self.state != SFSyncManagerStateAcceptingSyncs) {
        NSString* message = [NSString stringWithFormat:@"sync manager has state %@", [SFMobileSyncSyncManager stateToString:self.state]];
        if (error) {
            *error = [self errorWithType:kSFSyncManagerStoppedError code:kSFSyncManagerStoppedErrorCode description:message];
        }
        return NO;
    } else {
        return YES;
    }
}

- (BOOL) checkNotRunning:(NSNumber*)syncId error:(NSError**)error {
    if (self.activeSyncs[syncId]) {
        NSString* message = [NSString stringWithFormat:@"sync %@ is still running", syncId];
        if (error) {
            *error = [self errorWithType:kSFSyncAlreadyRunningError code:kSFSyncAlreadyRunningErrorCode description:message];
        }
        return NO;
    } else {
        return YES;
    }
}

- (SFSyncState*) checkExistsById:(NSNumber*)syncId error:(NSError**)error {
    SFSyncState* sync = [self getSyncStatus:syncId];
    if (sync == nil) {
        NSString* message = [NSString stringWithFormat:@"Sync %@ does not exist", syncId];
        if (error) {
            *error = [self errorWithType:kSFSyncNotExistError code:kSFSyncNotExistErrorCode description:message];
        }
    }
    return sync;
}

- (SFSyncState*) checkExistsByName:(NSString*)syncName error:(NSError**)error {
    SFSyncState* sync = [self getSyncStatusByName:syncName];
    if (sync == nil) {
        NSString* message = [NSString stringWithFormat:@"Sync %@ does not exist", syncName];
        if (error) {
            *error = [self errorWithType:kSFSyncNotExistError code:kSFSyncNotExistErrorCode description:message];
        }
    }
    return sync;
}

- (NSError*) errorWithType:(NSString*)type code:(NSInteger)code description:(NSString*)description {
    [SFSDKMobileSyncLogger e:[self class] format:@"%@: %@", type, description];
    return [NSError errorWithDomain:kSFMobileSyncErrorDomain
                               code:code
                           userInfo:@{@"error": type,
                                      @"description": description}];
}

#pragma mark - has / get sync methods

- (SFSyncState*)getSyncStatus:(NSNumber*)syncId {
    SFSyncState* sync = [SFSyncState byId:syncId store:self.store];
    
    if (sync == nil) {
        [SFSDKMobileSyncLogger d:[self class] format:@"Sync %@ not found", syncId];
    }
    return sync;
}

- (SFSyncState*)getSyncStatusByName:(NSString*)syncName {
    SFSyncState* sync = [SFSyncState byName:syncName store:self.store];

    if (sync == nil) {
        [SFSDKMobileSyncLogger d:[self class] format:@"Sync %@ not found", syncName];
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
    SFSyncTask* task;
    switch (sync.type) {
        case SFSyncStateSyncTypeDown:
            task = [[SFSyncDownTask alloc] init:self sync:sync updateBlock:updateBlock];
            break;
        case SFSyncStateSyncTypeUp:
            if ([sync.target conformsToProtocol:@protocol(SFAdvancedSyncUpTarget)]) {
                task = [[SFAdvancedSyncUpTask alloc] init:self sync:sync updateBlock:updateBlock];
            } else {
                task = [[SFSyncUpTask alloc] init:self sync:sync updateBlock:updateBlock];
            }
    }
    
    // Run on background thread
    dispatch_async(self.queue, ^{
        [task run];
    });
}

#pragma mark - syncDown and supporting methods

/** Create and run a sync down
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite];
    return [self syncDownWithTarget:target options:options soupName:soupName updateBlock:updateBlock];
}

- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [self syncDownWithTarget:target options:options soupName:soupName syncName:nil updateBlock:updateBlock error:nil];
}

- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    if (![self checkAcceptingSyncs:error]) {
        return nil;
    }

    SFSyncState *sync = [self createSyncDown:target options:options soupName:soupName syncName:syncName];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState *)createSyncDown:(SFSyncDownTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName name:syncName store:self.store];
    [SFSDKMobileSyncLogger d:[self class] format:@"Created syncDown:%@", sync];
    return sync;
}

#pragma mark - reSync methods

/** Resync
 */
- (SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    SFSyncState* sync = [self checkExistsById:syncId error:error];
    if (sync) {
        return [self reSyncWithSync:sync updateBlock:updateBlock error:error];
    } else {
        return nil;
    }
}

- (SFSyncState*) reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    SFSyncState* sync = [self checkExistsByName:syncName error:error];
    if (sync) {
        return [self reSyncWithSync:sync updateBlock:updateBlock error:error];
    } else {
        return nil;
    }
}

- (SFSyncState*) reSyncWithSync:(SFSyncState*)sync updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    if (![self checkAcceptingSyncs:error] || ![self checkNotRunning:@(sync.syncId) error:error]) {
        return nil;
    }
    
    // Reset total size
    sync.totalSize = -1;
    
    // Adjust maxTimeStamp if sync was stopped
    if ([sync isStopped]) {
        sync.maxTimeStamp = sync.maxTimeStamp == -1 ? -1 : sync.maxTimeStamp - 1;
    }

    [SFSDKMobileSyncLogger d:[self class] format:@"reSync:%@", sync];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}


#pragma mark - syncUp and supporting methods

/** Create and run a sync up
 */
- (SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [self syncUpWithTarget:[SFSyncUpTarget newFromDict:nil] options:options soupName:soupName updateBlock:updateBlock];
}

- (SFSyncState*) syncUpWithTarget:(SFSyncUpTarget *)target
                         options:(SFSyncOptions *)options
                        soupName:(NSString *)soupName
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    return [self syncUpWithTarget:target options:options soupName:soupName syncName:nil updateBlock:updateBlock error:nil];
}

- (SFSyncState*) syncUpWithTarget:(SFSyncUpTarget *)target
                         options:(SFSyncOptions *)options
                        soupName:(NSString *)soupName
                        syncName:(NSString*)syncName
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                            error:(NSError**)error {
    if (![self checkAcceptingSyncs:error]) {
        return nil;
    }

    SFSyncState *sync = [self createSyncUp:target options:options soupName:soupName syncName:syncName];
    [self runSync:sync updateBlock:updateBlock];
    return [sync copy];
}

- (SFSyncState *)createSyncUp:(SFSyncUpTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:target soupName:soupName name:syncName store:self.store];
    [SFSDKMobileSyncLogger d:[self class] format:@"Created syncUp:%@", sync];
    return sync;
}

#pragma mark - cleanResyncGhosts methods

- (BOOL) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error {
    SFSyncState* sync = [self checkExistsById:syncId error:error];
    if (sync) {
        return [self cleanResyncGhostsWithSync:sync completionStatusBlock:completionStatusBlock error:error];
    } else {
        return NO;
    }
}

- (BOOL) cleanResyncGhostsByName:(NSString*)syncName completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error  {
    SFSyncState* sync = [self checkExistsByName:syncName error:error];
    if (sync) {
        return [self cleanResyncGhostsWithSync:sync completionStatusBlock:completionStatusBlock error:error];
    } else {
        return NO;
    }
}


- (BOOL) cleanResyncGhostsWithSync:(SFSyncState*)sync completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error {
    if (![self checkAcceptingSyncs:error] || ![self checkNotRunning:@(sync.syncId) error:error]) {
        return NO;
    }
    
    if (sync.type != SFSyncStateSyncTypeDown) {
        if (error) {
            NSString* description = [NSString stringWithFormat:@"Cannot run cleanResyncGhosts:%@:wrong type:%@", @(sync.syncId), [SFSyncState syncTypeToString:sync.type]];
            *error = [self errorWithType:kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown code:kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode description:description];
        }
        return NO;
    }

    [SFSDKMobileSyncLogger d:[self class] format:@"cleanResyncGhosts:%@", sync];
    
    // Run on background thread
    SFCleanSyncGhostsTask* task = [[SFCleanSyncGhostsTask alloc] init:self sync:sync completionStatusBlock:completionStatusBlock];
    
    dispatch_async(self.queue, ^{
        [task run];
    });
    
    return YES;
}

#pragma mark - logout handling

- (void)handleUserWillLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
     [[self class] removeSharedInstance:user];
}


#pragma mark - string to/from enum for state

+ (SFSyncManagerState) stateFromString:(NSString*)state {
    if ([state isEqualToString:kSFSyncManagerStateAcceptingSyncs]) {
        return SFSyncManagerStateAcceptingSyncs;
    } else if ([state isEqualToString:kSFSyncManagerStateStopRequested]) {
        return SFSyncManagerStateStopRequested;
    }
    return SFSyncManagerStateStopped;
}

+ (NSString*) stateToString:(SFSyncManagerState)state {
    switch (state) {
        case SFSyncManagerStateAcceptingSyncs: return kSFSyncManagerStateAcceptingSyncs;
        case SFSyncManagerStateStopRequested: return kSFSyncManagerStateStopRequested;
        case SFSyncManagerStateStopped: return kSFSyncManagerStateStopped;
    }
}

@end

