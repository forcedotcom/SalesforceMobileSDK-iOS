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
#import <MobileSync/SFSyncState.h>
#import <MobileSync/SFSyncOptions.h>
#import <MobileSync/SFSyncUpTarget.h>
#import <MobileSync/SFSyncDownTarget.h>

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
extern NSString* const kSFMobileSyncErrorDomain;
extern NSString* const kSFSyncManagerStoppedError;
extern NSString* const kSFSyncManagerCannotRestartError;
extern NSString* const kSFSyncAlreadyRunningError;
extern NSString* const kSFSyncNotExistError;
extern NSString* const kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown;

extern NSInteger const kSFSyncManagerStoppedErrorCode;
extern NSInteger const kSFSyncManagerCannotRestartErrorCode;
extern NSInteger const kSFSyncAlreadyRunningErrorCode;
extern NSInteger const kSFSyncNotExistErrorCode;
extern NSInteger const kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode;


/**
 * This class provides methods for doing synching records to/from the server from/to the smartstore.
 */
NS_SWIFT_NAME(SyncManager)
@interface SFMobileSyncSyncManager : NSObject

@property (nonatomic, strong, readonly) SFSmartStore *store;

/**
 * Singleton method for accessing the sync manager instance for the given user. This instance uses the
 * default store.
 *
 * @param user User to which this manager instance's data is scoped.
 */
+ (instancetype)sharedInstance:(SFUserAccount*)user NS_SWIFT_NAME(sharedInstance(forUserAccount:));

/**
 * Singleton method for accessing a sync manager based on a user and store name. This instance uses the
 * store with the given name for the given user.
 *
 * @param user User associated with the store.
 * @param storeName Name of the requested store.
 */
+ (instancetype)sharedInstanceForUser:(SFUserAccount*)user storeName:(nullable NSString *)storeName  NS_SWIFT_UNAVAILABLE("");

/**
 * Singleton method for accessing a sync manager based on user and store name. This instance uses the store
 * with the given name for the given user.
 * @param storeName Name of the requested store.
 * @param userAccount User associated with the store.
 */
+ (instancetype)sharedInstanceForStore:(nullable NSString *)storeName userAccount:(SFUserAccount*)userAccount NS_SWIFT_NAME(sharedInstance(named:forUserAccount:));

/**
 * Singleton method for accessing sync manager instance by SmartStore store.
 *
 * @param store SmartStore instance whose sync manager is being requested.
 */
+ (nullable instancetype)sharedInstanceForStore:(SFSmartStore*)store NS_SWIFT_NAME(sharedInstance(store:));

/**
 * Remove the shared instance associated with the given user.
 *
 * @param user User associated with the store.
 */
+ (void)removeSharedInstance:(SFUserAccount*)user;

/**
 * Remove the shared instance associated with the given user and store name.
 *
 * @param storeName Name of the requested store.
 * @param user User associated with the store.
 **/
+ (void)removeSharedInstanceForUser:(SFUserAccount*)user storeName:(nullable NSString*)storeName NS_SWIFT_UNAVAILABLE("");

/**
 * Remove the shared instance associated with the given store name and user.
 * @param storeName Name of the requested store.
 * @param userAccount User associated with the store.
 */
+ (void)removeSharedInstanceForStore:(nullable NSString*)storeName userAccount:(SFUserAccount*)userAccount  NS_SWIFT_NAME(removeSharedInstance(named:forUserAccount:));
/**
 * Remove the shared instance associated with the specified store.
 *
 * @param store SmartStore instance whose sync manager is to be removed.
 */
+ (void)removeSharedInstanceForStore:(SFSmartStore*)store NS_SWIFT_NAME(removeSharedInstance(store:));

/**
 * Remove all shared instances.
 */
+ (void)removeSharedInstances;

/**
 * Stop the sync manager.
 * It can take a while for active syncs to actually stop.
 * Call `isStopped()` to see if the sync manager is fully paused.
 */
- (void)stop;

/**
 * @return YES if a stop was requested but some syncs are still active.
 */
- (BOOL)isStopping;

/**
 * @return YES if a stop was requested and no syncs are still active.
 */
- (BOOL)isStopped;

/**
 * Restart this sync manager.
 *
 * @param restartStoppedSyncs Pass YES to restart all stopped syncs.
 * @param updateBlock Block to be called with updates.
 * @param error Reports any error (optional).
 * @return YES if restarted successfully.
 */
- (BOOL)restart:(BOOL)restartStoppedSyncs updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(restart(restartStoppedSyncs:onUpdate:));

/**
 * Check whether a sync manager is running.
 *
 * @param error Reports any error (optional).
 * @return YES if the sync manager is running, or NO if it's stopping or stopped.
 */
- (BOOL) checkAcceptingSyncs:(NSError**)error;

/**
 * Return status of the sync with the given sync ID.
 *
 * @param syncId Sync ID.
 */
- (nullable SFSyncState*)getSyncStatus:(NSNumber*)syncId NS_SWIFT_NAME(syncStatus(forId:));

/**
 * Return status of the sync with the given name.
 *
 * @param syncName Sync name.
 */
- (nullable SFSyncState*)getSyncStatusByName:(NSString*)syncName NS_SWIFT_NAME(syncStatus(forName:));

/**
 * Return YES if a sync with the given name exists.
 * @param syncName Sync name.
 * @return YES a sync with the given name exists.
 */
- (BOOL)hasSyncWithName:(NSString*)syncName NS_SWIFT_NAME(hasSync(forName:));

/**
 * Delete the sync with the given ID.
 *
 * @param syncId Sync ID.
 */
- (void)deleteSyncById:(NSNumber*)syncId NS_SWIFT_NAME(deleteSync(forId:));

/**
 * Delete the sync with the given name.
 *
 * @param syncName Sync name.
 */
- (void)deleteSyncByName:(NSString*)syncName NS_SWIFT_NAME(deleteSync(forName:));


/**
 * Create a sync down without running it.
 * @param target Sync down target that will manage the sync down process.
 * @param options Options associated with this sync down.
 * @param soupName Soup name where the local entries are stored.
 * @param syncName Name for this sync (optional).
 * @return Sync state associated with this sync down.
 */
- (SFSyncState *)createSyncDown:(SFSyncDownTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(nullable NSString *)syncName;

/**
 * Create and run a sync down that overwrites modified records.
 * @param target Sync down target that will manage the sync down process.
 * @param soupName Soup name where the local entries are stored.
 * @param updateBlock Block to be called with updates.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncDown(target:soupName:onUpdate:));

/**
 * Create and run a sync down.
 * @param target Sync down target that manages the sync down process.
 * @param options Options associated with this sync down. Use this parameter to specify how the sync
 * should handle modified records in the store.
 * @param soupName Soup name where the local entries are stored.
 * @param updateBlock Block to be called with updates.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncDown(target:options:soupName:onUpdate:));

/**
 * Create and run a named sync down.
 * @param target Sync down target that will manage the sync down process.
 * @param options Options associated with this sync down. Use this parameter to specify how the sync
 * should handle modified records in the store.
 * @param soupName Soup name where the local entries are stored.
 * @param syncName Name for this sync.
 * @param updateBlock Block to be called with updates.
 * @param error Sets error if sync could not be created.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(nullable NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(syncDown(target:options:soupName:syncName:onUpdate:));

/**
 * Perform a resync.
 * @param syncId Sync ID.
 * @param updateBlock Block to be called with updates.
 * @param error Sets error if sync could not be started.
 * @return Sync state associated with this sync, or nil if it could not be started.
 */
- (nullable SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**) error NS_SWIFT_NAME(reSync(id:onUpdate:));

/**
 * Perform a resync by name.
 * @param syncName Sync name.
 * @param updateBlock Block to be called with updates.
 * @param error Sets error if sync could not be started.
 * @return Sync state associated with this sync, or nil if it could not be started.
 */
- (nullable SFSyncState*) reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error NS_SWIFT_NAME(reSync(named:onUpdate:));


/**
 * Create a sync up without running it.
 * @param target Sync up target that will manage the sync up process.
 * @param options Options associated with this sync up. Use this parameter to specify how the sync
 * should handle modified records on the server.
 * @param soupName Soup name where the local entries are stored.
 * @param syncName Name for this sync.
 * @return Sync state associated with this sync up.
 */
- (SFSyncState *)createSyncUp:(SFSyncUpTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(nullable NSString *)syncName;

/**
 * Create and run a sync up with the default SFSyncUpTarget.
 *
 * @param options Options associated with this sync up. Use this parameter to specify how the sync
 * should handle modified records on the server.
 * @param soupName Soup name where the local entries are stored.
 * @param updateBlock Block to be called with updates.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncUp(options:soupName:onUpdate:));

/**
 * Create and run a sync up with the configured SFSyncUpTarget.
 *
 * @param target Sync up target that will manage the sync up process.
 * @param options Options associated with this sync up. Use this parameter to specify how the sync
 * should handle modified records on the server.
 * @param soupName Soup name where the local entries are stored.
 * @param updateBlock Block to be called with updates.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                                   options:(SFSyncOptions*)options
                                  soupName:(NSString*)soupName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock NS_SWIFT_NAME(syncUp(target:options:soupName:onUpdate:));

/**
 * Create and run a named sync up.
 *
 * @param target Sync up target that will manage the sync up process.
 * @param options Options associated with this sync up. Use this parameter to specify how the sync
 * should handle modified records on the server.
 * @param soupName Soup name where the local entries are stored.
 * @param syncName Name for this sync.
 * @param updateBlock Block to be called with updates.
 * @param error Sets error if sync could not be created.
 * @return Sync state associated with this sync, or nil if it could not be created.
 */
- (nullable SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                                   options:(SFSyncOptions*)options
                                  soupName:(NSString*)soupName
                                  syncName:(nullable NSString*)syncName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                     error:(NSError**)error NS_SWIFT_NAME(syncUp(target:options:soupName:syncName:onUpdate:));

/**
 * Remove local copies of records that have been deleted on the server
 * or do not match the query results on the server anymore.
 *
 * @param syncId Sync ID.
 * @param completionStatusBlock Completion status block.
 * @param error Sets error if clean operation could not be started.
 * @return YES if cleanResyncGhosts started successfully.
 */
- (BOOL) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock error:(NSError**)error NS_SWIFT_NAME(cleanResyncGhosts(forId:onComplete:));

/**
 * Remove local copies of records that have been deleted on the server
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
