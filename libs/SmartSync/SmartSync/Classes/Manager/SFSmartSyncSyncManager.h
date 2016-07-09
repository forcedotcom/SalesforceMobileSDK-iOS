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

#import <SalesforceRestAPI/SFRestAPI+Blocks.h>
#import "SFSyncState.h"
#import "SFSyncOptions.h"
#import "SFSyncUpTarget.h"
#import "SFSyncDownTarget.h"

@class SFUserAccount;

extern NSString * const kSyncManagerTargetQueryType;
extern NSString * const kSyncManagerTargetQuery;
extern NSString * const kSyncManagerTargetObjectType;
extern NSString * const kSyncManagerTargetFieldlist;
extern NSString * const kSyncManagerQueryTypeMru;
extern NSString * const kSyncManagerQueryTypeSoql;
extern NSString * const kSyncManagerQueryTypeSosl;

extern NSString * const kSyncManagerLocal;
extern NSString * const kSyncManagerLocallyCreated;
extern NSString * const kSyncManagerLocallyUpdated;
extern NSString * const kSyncManagerLocallyDeleted;

// block type
typedef void (^SFSyncSyncManagerUpdateBlock) (SFSyncState* sync);
typedef void (^SFSyncSyncManagerCompletionStatusBlock) (SFSyncStateStatus syncStatus);

/**
 * This class provides methods for doing synching records to/from the server from/to the smartstore.
 */
@interface SFSmartSyncSyncManager : NSObject

/**
 * Singleton method for accessing sync manager instance by user. Configured SmartStore store will be
 * the default store for the user.
 *
 * @param user A user that will scope this manager instance data.
 */
+ (instancetype)sharedInstance:(SFUserAccount*)user;

/**
 * Singleton method for accessing a sync manager based on user and store name. Configured SmartStore
 * store will be the store with the given name for the given user.
 *
 * @param user The user associated with the store.
 * @param storeName The name of the SmartStore associated with the user.
 */
+ (instancetype)sharedInstanceForUser:(SFUserAccount*)user storeName:(NSString *)storeName;

/**
 * Singleton method for accessing sync manager instance by SmartStore store.
 *
 * @param store The store instance to configure.
 */
+ (instancetype)sharedInstanceForStore:(SFSmartStore*)store;

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
+ (void)removeSharedInstanceForUser:(SFUserAccount*)user storeName:(NSString*)storeName;

/**
 * Removes the shared instance associated with the specified store.
 *
 * @param store The store instance.
 */
+ (void)removeSharedInstanceForStore:(SFSmartStore*)store;

/**
 * Returns details about a sync.
 *
 * @param syncId Sync ID.
 */
- (SFSyncState*)getSyncStatus:(NSNumber*)syncId;

/**
 * Creates and runs a sync down that will overwrite any modified records.
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;

/**
 * Creates and runs a sync down.
 */
- (SFSyncState*) syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;

/**
 * Performs a resync.
 */
- (SFSyncState*) reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;

/**
 * Creates and runs a sync up with the default SFSyncUpTarget.
 *
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync up.
 */
- (SFSyncState*) syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;

/**
 * Creates and runs a sync up with the configured SFSyncUpTarget.
 *
 * @param target The sync up target that will manage the sync up process.
 * @param options The options associated with this sync up.
 * @param soupName The soup name where the local entries are stored.
 * @param updateBlock The block to be called with updates.
 * @return The sync state associated with this sync up.
 */
- (SFSyncState*) syncUpWithTarget:(SFSyncUpTarget*)target
                          options:(SFSyncOptions*)options
                         soupName:(NSString*)soupName
                      updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock;

/**
 * Removes local copies of records that have been deleted on the server
 * or do not match the query results on the server anymore.
 *
 * @param syncId Sync ID.
 * @param completionStatusBlock Completion status block.
 */
- (void) cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock;

/**
 * Returns IDs (specified ID field) from dirty records in the given soup.
 *
 * @param soupName The name of the soup to look into.
 * @param idField The field to return.
 */
- (NSOrderedSet*) getDirtyRecordIds:(NSString*)soupName idField:(NSString*)idField;

@end
