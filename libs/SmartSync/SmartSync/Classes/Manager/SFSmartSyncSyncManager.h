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

#import <SalesforceSDKCore/SFRestAPI+Blocks.h>
#import "SFSyncState.h"
#import "SFSyncOptions.h"
#import "SFSyncUpTarget.h"
#import "SFSyncDownTarget.h"

NS_ASSUME_NONNULL_BEGIN

@class SFUserAccount;

// block type
typedef void (^SFSyncSyncManagerUpdateBlock) (SFSyncState* sync) NS_SWIFT_NAME(SyncUpdateBlock);
typedef void (^SFSyncSyncManagerCompletionStatusBlock) (SFSyncStateStatus syncStatus, NSUInteger numRecords) NS_SWIFT_NAME(SyncCompletionBlock);

// Possible value for sync manager state
typedef NS_ENUM(NSInteger, SFSyncManagerState) {
    SFSyncManagerStateAcceptingSyncs,
    SFSyncManagerStateStopRequested,
    SFSyncManagerStateStopped
} NS_SWIFT_NAME(SyncManagerState);

extern NSString * const kSFSyncManagerStateAcceptingSyncs;
extern NSString * const kSFSyncManagerStateStopRequested;
extern NSString * const kSFSyncManagerStateStopped;

// Errors
extern NSString* const kSFSmartSyncErrorDomain;
extern NSString* const kSFSyncManagerStoppedError;
extern NSString* const kSFSyncManagerCannotRestartError;
extern NSString* const kSFSyncAlreadyRunningError;
extern NSString* const kSFSyncNotExistError;

extern NSInteger const kSFSyncManagerStoppedErrorCode;
extern NSInteger const kSFSyncManagerCannotRestartErrorCode;
extern NSInteger const kSFSyncAlreadyRunningErrorCode;
extern NSInteger const kSFSyncNotExistErrorCode;

/**
 * This class provides methods for doing synching records to/from the server from/to the smartstore.
 */
NS_SWIFT_NAME(SyncManager)
@interface SFSmartSyncSyncManager : NSObject

@property (nonatomic, strong, readonly) SFSmartStore *store;

/**
 * Singleton method for accessing sync manager instance by user. Configured SmartStore store will be
 * the default store for the user.
 *
 * @param user A user that will scope this manager instance data.
 */
+ (instancetype)sharedInstance:(SFUserAccount*)user NS_SWIFT_NAME(sharedInstance(forUserAccount:));

/**
 * Singleton method for accessing a sync manager based on user and store name. Configured SmartStore
 * store will be the store with the given name for the given user.
 *
 * @param user The user associated with the store.
 * @param storeName The name of the SmartStore associated with the user.
 */
+ (instancetype)sharedInstanceForUser:(SFUserAccount*)user storeName:(nullable NSString *)storeName  NS_SWIFT_UNAVAILABLE("");

/**
 * Singleton method for accessing a sync manager based on user and store name. Configured SmartStore
 * store will be the store with the given name for the given user.
 * @param storeName The name of the SmartStore associated with the user.
 * @param userAccount The user associated with the store.
 */
+ (instancetype)sharedInstanceForStore:(nullable NSString *)storeName userAccount:(SFUserAccount*)userAccount NS_SWIFT_NAME(sharedInstance(named:forUserAccount:));

/**
 * Singleton method for accessing sync manager instance by SmartStore store.
 *
 * @param store The store instance to configure.
 */
+ (nullable instancetype)sharedInstanceForStore:(SFSmartStore*)store NS_SWIFT_NAME(sharedInstance(store:));

/**
 * Removes the shared instance associated with the specified user.
 *
 * @param user The user.
 */
+ (void)removeSharedInstance:(SFUserAccount*)user;

/**
 * Removes the shared instance associated with the given user and store name.
 *
 * @param user The user associated with the store.
 * @param storeName The name of the store associated with the given user.
 */
+ (void)removeSharedInstanceForUser:(SFUserAccount*)user storeName:(nullable NSString*)storeName NS_SWIFT_UNAVAILABLE("");

/**
 * Removes the shared instance associated with the given user and store name.
 * @param storeName The name of the store associated with the given user.
 * @param userAccount The user associated with the store.
 */
+ (void)removeSharedInstanceForStore:(nullable NSString*)storeName userAccount:(SFUserAccount*)userAccount  NS_SWIFT_NAME(removeSharedInstance(named:forUserAccount:));
/**
 * Removes the shared instance associated with the specified store.
 *
 * @param store The store instance.
 */
+ (void)removeSharedInstanceForStore:(SFSmartStore*)store NS_SWIFT_NAME(removeSharedInstance(store:));

/**
 * Removes all shared instances
 */
+ (void)removeSharedInstances;

/**
 * Stop the sync manager
 * It might take a while for active syncs to actually get stopped
 * Call isStopped() to see if syncManager is fully paused
 */
- (void)stop;

/**
 * @return YES if stop was requested but there are still active syncs
 */
- (BOOL)isStopping;

/**
 * @return YES if stop was requested and there no syncs are active anymore
 */
- (BOOL)isStopped;

/**
 * Restart this sync manager
 *
 * @param restartStoppedSyncs Pass YES to restart all stopped sync.
 * @param updateBlock The block to be called with updates.
 * @param error To get an error back (optional).
 * @return YES if restarted successfully.
 */
- (BOOL)restart:(BOOL)restartStoppedSyncs updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(restart(restartStoppedSyncs:onUpdate:));

/**
 * Check if sync manager is running
 *
 * @param error To get an error back (optional).
 * @return YES if running and NO if stopping or stopped
 */
- (BOOL) checkAcceptingSyncs:(NSError**)error;

/**
 * Returns details about a sync.
 *
 * @param syncId Sync ID.
 */
- (nullable SFSyncState*)getSyncStatus:(NSNumber*)syncId NS_SWIFT_NAME(syncStatus(forId:));

/**
 * Returns details about a sync by name.
 *
 * @param syncName Sync name.
 */
- (nullable SFSyncState*)getSyncStatusByName:(NSString*)syncName NS_SWIFT_NAME(syncStatus(forName:));

/**
 * Returns YES if a sync with the given name exists.
 * @param syncName Sync name.
 * @return YES a sync with the given name exists.
 */
- (BOOL)hasSyncWithName:(NSString*)syncName NS_SWIFT_NAME(hasSync(forName:));

/**
 * Delete a sync.
 *
 * @param syncId Sync ID.
 */
- (void)deleteSyncById:(NSNumber*)syncId NS_SWIFT_NAME(deleteSync(forId:));

/**
 * Delete a sync by name.
 *
 * @param syncName Sync name.
 */
- (void)deleteSyncByName:(NSString*)syncName NS_SWIFT_NAME(deleteSync(forName:));


/**
 * Creates a sync down without running it.
 * @param target The sync down target that will manage the sync down process.
 * @param options The options associated with this sync down.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @return The sync state associated with this sync down.
 */
- (SFSyncState *)createSyncDown:(SFSyncDownTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(nullable NSString *)syncName;

/**
 * Creates and runs a sync down that will overwrite any modified records.
 * @param target The sync down target that will manage the sync down process.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncDown(target:soupName:onUpdate:));

/**
 * Creates and runs a sync down.
 * @param target The sync down target that will manage the sync down process.
 * @param options The options associated with this sync down.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncDown(target:options:soupName:onUpdate:));

/**
 * Creates and runs a named sync down.
 * @param target The sync down target that will manage the sync down process.
 * @param options The options associated with this sync down.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(nullable NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock SFSDK_DEPRECATED(7.1, 8.0, "Use syncDownWithTarget:options:soupName:syncName:updateBlock:error instead");

/**
 * Creates and runs a named sync down.
 * @param target The sync down target that will manage the sync down process.
 * @param options The options associated with this sync down.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @param updateBlock The block to be called with updates.
 * @param error Sets error if sync could not be created.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(nullable NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(syncDown(target:options:soupName:syncName:onUpdate:));

/**
 * Performs a resync.
 * @param syncId Sync ID.
 * @param updateBlock The block to be called with updates.
 */
- (nullable SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock SFSDK_DEPRECATED(7.1, 8.0, "Use reSync:updateBlock:error instead");

/**
 * Performs a resync.
 * @param syncId Sync ID.
 * @param updateBlock The block to be called with updates.
 * @param error Sets error if sync could not be started.
 * @return The sync state associated with this sync or nil if it could not be started.
 */
- (nullable SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**) error NS_SWIFT_NAME(reSync(id:onUpdate:));

/**
 * Performs a resync by name.
 * @param syncName Sync name.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be started.
 */
- (nullable SFSyncState*) reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock SFSDK_DEPRECATED(7.1, 8.0, "Use reSyncByName:updateBlock:error instead");

/**
 * Performs a resync by name.
 * @param syncName Sync name.
 * @param updateBlock The block to be called with updates.
 * @param error Sets error if sync could not be started.
 * @return The sync state associated with this sync or nil if it could not be started.
 */
- (nullable SFSyncState*) reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(reSync(named:onUpdate:));


/**
 * Create a sync up without running it.
 * @param target The sync up target that will manage the sync up process.
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @return The sync state associated with this sync up.
 */
- (SFSyncState *)createSyncUp:(SFSyncUpTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(nullable NSString *)syncName;

/**
 * Creates and runs a sync up with the default SFSyncUpTarget.
 *
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncUp(options:soupName:onUpdate:));

/**
 * Creates and runs a sync up with the configured SFSyncUpTarget.
 *
 * @param target The sync up target that will manage the sync up process.
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                                   options:(SFSyncOptions*)options
                                  soupName:(NSString*)soupName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncUp(target:options:soupName:onUpdate:));

/**
 * Creates and runs a named sync up.
 *
 * @param target The sync up target that will manage the sync up process.
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                                   options:(SFSyncOptions*)options
                                  soupName:(NSString*)soupName
                                  syncName:(nullable NSString*)syncName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock SFSDK_DEPRECATED(7.1, 8.0, "Use syncUpWithTarget:options:soupName:syncName:updateBlock:error instead");

/**
 * Creates and runs a named sync up.
 *
 * @param target The sync up target that will manage the sync up process.
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param syncName The name for this sync.
 * @param updateBlock The block to be called with updates.
 * @param error Sets error if sync could not be created.
 * @return The sync state associated with this sync or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                                   options:(SFSyncOptions*)options
                                  soupName:(NSString*)soupName
                                  syncName:(nullable NSString*)syncName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                     error:(NSError**)error NS_SWIFT_NAME(syncUp(target:options:soupName:syncName:onUpdate:));


/**
 * Removes local copies of records that have been deleted on the server
 * or do not match the query results on the server anymore.
 *
 * @param syncId Sync ID.
 * @param completionStatusBlock Completion status block.
 * @return YES if cleanResyncGhosts started successfully.
 */
- (BOOL) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock
    SFSDK_DEPRECATED(7.1, 8.0, "Use cleanResyncGhosts:completionStatusBlock:error instead");

/**
 * Removes local copies of records that have been deleted on the server
 * or do not match the query results on the server anymore.
 *
 * @param syncId Sync ID.
 * @param completionStatusBlock Completion status block.
 * @param error Sets error if clean operation could not be started.
 * @return YES if cleanResyncGhosts started successfully.
 */
- (BOOL) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error NS_SWIFT_NAME(cleanResyncGhosts(forId:onComplete:));

/**
 * Removes local copies of records that have been deleted on the server
 * or do not match the query results on the server anymore.
 *
 * @param syncName Sync Name.
 * @param completionStatusBlock Completion status block.
 * @param error Sets error if clean operation could not be started.
 * @return YES if cleanResyncGhosts started successfully.
 */
- (BOOL) cleanResyncGhostsByName:(NSString*)syncName completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error NS_SWIFT_NAME(cleanResyncGhosts(forName:onComplete:));

@end

NS_ASSUME_NONNULL_END
