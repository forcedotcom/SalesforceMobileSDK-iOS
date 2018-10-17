/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SFEncryptionKey;
@class SFSoupIndex;

/**
 The default store name used by the SFSmartStorePlugin: native code may choose
 to use separate stores.
 */
extern NSString *const kDefaultSmartStoreName NS_SWIFT_NAME(SmartStore.defaultStoreName);

/**
 The NSError domain for SmartStore errors.
 */
extern NSString * const kSFSmartStoreErrorDomain;

/**
 The NSError exceptionName for errors loading external Soups.
 */
extern NSString * const kSFSmartStoreErrorLoadExternalSoup;

/**
 The label used to interact with the encryption key.
 */
extern NSString * const kSFSmartStoreEncryptionKeyLabel;

/**
 Block typedef for generating an encryption key.
 */
typedef SFEncryptionKey*  _Nullable (^SFSmartStoreEncryptionKeyBlock)(void) NS_SWIFT_NAME(EncryptionKeyBlock);

/**
 The columns of a soup table
 */
extern NSString *const ID_COL;
extern NSString *const CREATED_COL;
extern NSString *const LAST_MODIFIED_COL;
extern NSString *const SOUP_COL;

/**
 The columns of a soup fts table
 */
extern NSString *const ROWID_COL;

/**
 Soup index map table
 */
extern NSString *const SOUP_INDEX_MAP_TABLE;

/**
 Soup attributes table
 */
extern NSString *const SOUP_ATTRS_TABLE;

/**
 Table to keep track of status of long operations in flight
*/
extern NSString *const LONG_OPERATIONS_STATUS_TABLE;

/*
 Columns of the soup index map table
 */
extern NSString *const SOUP_NAME_COL;
extern NSString *const PATH_COL;
extern NSString *const COLUMN_NAME_COL;
extern NSString *const COLUMN_TYPE_COL;

/*
 Columns of the long operations status table
 */
extern NSString *const TYPE_COL;
extern NSString *const DETAILS_COL;
extern NSString *const STATUS_COL;

/*
 JSON fields added to soup element on insert/update
*/
extern NSString *const SOUP_ENTRY_ID;
extern NSString *const SOUP_LAST_MODIFIED_DATE;

/*
 Support for explain query plan
 */
extern NSString *const EXPLAIN_SQL;
extern NSString *const EXPLAIN_ARGS;
extern NSString *const EXPLAIN_ROWS;

@class FMDatabaseQueue;
@class SFQuerySpec;
@class SFSoupSpec;
@class SFUserAccount;

NS_SWIFT_NAME(SmartStore)
@interface SFSmartStore : NSObject {

    //used for monitoring the status of file data protection
    BOOL    _dataProtectionKnownAvailable;
    id      _dataProtectAvailObserverToken;
    id      _dataProtectUnavailObserverToken;
    
    FMDatabaseQueue *_storeQueue;
    NSString *_storeName;

    NSMutableDictionary *_soupNameToTableName;
    NSMutableDictionary *_attrSpecBySoup;
    NSMutableDictionary *_indexSpecsBySoup;
    NSMutableDictionary *_smartSqlToSql;
}

/**
 The name of this store. 
 */
@property (nonatomic, readonly, strong) NSString *storeName;

/**
 The full path to the store database.
 */
@property (nonatomic, readonly, strong, nullable) NSString *storePath;

/**
 User for this store - nil for global stores
 */
@property (nonatomic, strong, nullable) SFUserAccount *user;

/**
 Flag to cause explain plan to be captured for every query
 */
@property (nonatomic, assign) BOOL captureExplainQueryPlan;

/**
 Dictionary with results of last explain query plan
 */
@property (nonatomic, strong) NSDictionary *lastExplainQueryPlan;

/**
 Use this method to obtain a shared store instance with a particular name for the current user.
 
 @param storeName The name of the store.  If in doubt, use kDefaultSmartStoreName.
 @return A shared instance of a store with the given name.
 */
+ (nullable instancetype)sharedStoreWithName:(NSString*)storeName NS_SWIFT_NAME(sharedStore(name:));

/**
 Use this method to obtain a shared store instance with the given name for the given user.
 @param storeName The name of the store.  If in doubt, use kDefaultSmartStoreName.
 @param user The user associated with the store.
 */
+ (nullable instancetype)sharedStoreWithName:(NSString*)storeName user:(SFUserAccount *)user NS_SWIFT_NAME(sharedStore(name:user:));

/**
 Use this method to obtain a shared global store instance with the given name.  This store will
 not be specific to a particular user.
 @param storeName The name of the global store to retrieve.
 */
+ (instancetype)sharedGlobalStoreWithName:(NSString *)storeName NS_SWIFT_NAME(sharedGlobalStore(name:));

/**
 You may use this method to completely remove a persistent shared store with
 the given name for the current user.
 
 @param storeName The name of the store. 
 */
+ (void)removeSharedStoreWithName:(NSString *)storeName NS_SWIFT_NAME(removeSharedStore(name:));

/**
 You may use this method to completely remove a persisted shared store with the given name
 for the given user.
 @param storeName The name of the store to remove.
 @param user The user associated with the store.
 */
+ (void)removeSharedStoreWithName:(NSString *)storeName forUser:(SFUserAccount *)user NS_SWIFT_NAME(removeSharedStore(name:user:));

/**
 You may use this method to completely remove a persisted global store with the given name.
 @param storeName The name of the global store to remove.
 */
+ (void)removeSharedGlobalStoreWithName:(NSString *)storeName NS_SWIFT_NAME(removeSharedGlobalStore(name:));

/**
 Removes all of the stores for the current user from this app.
 */
+ (void)removeAllStores;

/**
 Removes all of the store for the given user from this app.
 @param user The user associated with the stores to remove.
 */
+ (void)removeAllStoresForUser:(SFUserAccount *)user NS_SWIFT_NAME(removeAllStores(user:));

/**
 Removes all of the global stores from this app.
 */
+ (void)removeAllGlobalStores;

/**
 Get all of the store names for the current user from this app.
 */
+ (NSArray *)allStoreNames;

/**
 Get all of the the global store names from this app.
 */
+ (NSArray *)allGlobalStoreNames;

/**
 @return The block used to generate the encryption key.  Sticking with the default encryption
 key derivation is recommended.
 */
+ (SFSmartStoreEncryptionKeyBlock)encryptionKeyBlock;

/**
 Sets a custom block for deriving the encryption key used to encrypt stores.
 
 ** WARNING: **
 If you choose to override the encryption key derivation, you must set
 this value before opening any stores.  Setting the value after stores have been opened
 will result in the corruption and loss of existing data.
 Also, SmartStore does not use initialization vectors.
 ** WARNING **
 
 @param newEncryptionKeyBlock The new encryption key derivation block to use with SmartStore.
 */
+ (void)setEncryptionKeyBlock:(SFSmartStoreEncryptionKeyBlock)newEncryptionKeyBlock;

#pragma mark - Soup manipulation methods

/**
 *  @param soupName Name of the soup.
 *  @return Specs of the soup if it exists.
 */
- (SFSoupSpec*)attributesForSoup:(NSString*)soupName NS_SWIFT_NAME(attributes(soupName:));

/**
 @param soupName Name of the soup.
 @return NSArray of SFSoupIndex for the given soup.
 */
- (NSArray<SFSoupIndex*>*)indicesForSoup:(NSString*)soupName NS_SWIFT_NAME(indices(soupName:));

/**
 @param soupName Name of the soup.
 @return YES if a soup with the given name already exists.
 */
- (BOOL)soupExists:(NSString*)soupName;

/**
 Creates a new soup or confirms the existence of an existing soup.
 @param soupName Name of the soup to register.
 @param indexSpecs Array of one or more SFSoupIndex objects.
 @param error Sets/returns any error generated as part of the process.
 @return YES if the soup is registered or already exists.
 */
- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs error:(NSError**)error NS_SWIFT_NAME(registerSoup(soupName:indexSpecs:));

/**
 Creates a new soup or confirms the existence of an existing soup.
 @warning Deprecated. Use registerSoup:withIndexSpecs:error: instead.

 @param soupName The name of the soup to register.
 @param indexSpecs Array of one or more SFSoupIndex objects.
 @return YES if the soup is registered or already exists.
 */
- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs
    __attribute__((deprecated("Use -registerSoup:withIndexSpecs:error:")));

/**
 Creates a new soup or confirms the existence of an existing soup.
 
 @param soupSpec Soup specs of the soup to register.
 @param indexSpecs Array of one or more SFSoupIndex objects.
 @param error Sets/returns any error generated as part of the process.
 @return YES if the soup is registered or already exists.

 */
- (BOOL)registerSoupWithSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs error:(NSError**)error NS_SWIFT_NAME(registerSoup(soupSpec:indexSpecs:));

/**
 Get the number of entries that would be returned with the given query spec
 
 @param querySpec A native query spec.
 @param error Sets/returns any error generated as part of the process.
 */
- (NSNumber* __nullable) countWithQuerySpec:(SFQuerySpec*)querySpec error:(NSError **)error NS_SWIFT_NAME(count(querySpec:));

/**
 Search for entries matching the given query spec.
 
 @param querySpec A native query spec.
 @param pageIndex The page index to start the entries at (this supports paging).
 @param error Sets/returns any error generated as part of the process.
 
 @return A set of entries given the pageSize provided in the querySpec.
 */
- (NSArray * __nullable)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error NS_SWIFT_NAME(query(querySpec:pageIndex:));

/**
 Search for entries matching the given query spec without deserializing any JSON
 
 @param resultString A mutable string to which the result (serialized) is appended
 @param querySpec A native query spec.
 @param pageIndex The page index to start the entries at (this supports paging).
 @param error Sets/returns any error generated as part of the process.
 
 @return YES if successful
 */
- (BOOL) queryAsString:(NSMutableString*)resultString querySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error NS_SWIFT_NAME(query(result:querySpec:pageIndex:));


/**
 * Run a query given by its query Spec, only returned results from selected page
 * without deserializing any JSON
 *
 * @param resultBuilder string builder to which results are appended
 * @param querySpec
 * @param pageIndex
 */

/**
 Search soup for entries exactly matching the soup entry IDs.
 
 @param soupName The name of the soup to query.
 @param soupEntryIds An array of opaque soup entry IDs.
 
 @return An array with zero or more entries matching the input IDs. Order is not guaranteed.
 */
- (NSArray<NSDictionary*>*)retrieveEntries:(NSArray<NSNumber*>*)soupEntryIds fromSoup:(NSString*)soupName NS_SWIFT_NAME(retrieve(soupEntryIds:soupName:));

/**
 Insert/update entries to the soup.  Insert vs. update will be determined by the internal
 soup entry ID generated from intial entry.  If you want to specify a different identifier
 for determining existing entries, use upsertEntries:toSoup:withExternalIdPath:
 
 @param entries The entries to insert or update.
 @param soupName The name of the soup to update.
 
 @return The array of updated entries in the soup.
 */
- (NSArray<NSDictionary*>*)upsertEntries:(NSArray<NSDictionary*>*)entries toSoup:(NSString*)soupName NS_SWIFT_NAME(upsert(entries:soupName:));

/**
 Insert/update entries to the soup.  Insert vs. update will be determined by the specified
 external ID path argument.
 
 @param entries The entries to insert or update.
 @param soupName The name of the soup to update.
 @param externalIdPath The user-defined query spec path used to determine insert vs. update.
 @param error Sets/returns any error generated as part of the process.
 
 @return The array of updated entries in the soup.
 */
- (NSArray * _Nullable)upsertEntries:(NSArray *)entries toSoup:(NSString *)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error  NS_SWIFT_NAME(upsert(entries:soupName:externalIdPath:));

/**
 Look up the ID for an entry in a soup.
 
 @param soupName Soup name.
 @param fieldPath Field path.
 @param fieldValue Field value.
 @param error Sets/returns any error generated as part of the process.
 @return The ID of the specified soup entry.
 */
- (NSNumber * __nullable)lookupSoupEntryIdForSoupName:(NSString *)soupName
                              forFieldPath:(NSString *)fieldPath
                                fieldValue:(NSString *)fieldValue
                                                error:(NSError **)error NS_SWIFT_NAME(lookupSoupEntryId(soupName:fieldPath:fieldValue:));

/**
 Remove soup entries exactly matching the soup entry IDs.
 
 @param entryIds An array of opaque soup entry IDs from _soupEntryId.
 @param soupName The name of the soup from which to remove the soup entries.
 @param error Sets/returns any error generated as part of the process.
 @return YES if no error occurs
 */
- (BOOL) removeEntries:(NSArray<NSNumber*>*)entryIds fromSoup:(NSString*)soupName error:(NSError **)error NS_SWIFT_NAME(remove(entryIds:soupName:));

/**
 Remove soup entries exactly matching the soup entry IDs.

 @param entryIds An array of opaque soup entry IDs from _soupEntryId.
 @param soupName The name of the soup from which to remove the soup entries.
 */
- (void)removeEntries:(NSArray<NSNumber*>*)entryIds fromSoup:(NSString*)soupName NS_SWIFT_UNAVAILABLE("Use removeEntries");

/**
 Remove soup entries returned by the given query spec.
 NB: A single SQL call is executed to improve performance.

 @param querySpec Query returning entries to delete (if querySpec uses smartSQL, it must select soup entry ids).
 @param soupName The name of the soup from which to remove the soup entries.
 @param error Sets/returns any error generated as part of the process.
 @return YES if no error occurs
 */
- (BOOL)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName  error:(NSError **)error NS_SWIFT_NAME(removeByQuery(querySpec:soupName:));

/**
 Remove soup entries returned by the given query spec.
 NB: A single SQL call is executed to improve performance.

 @param querySpec Query returning entries to delete (if querySpec uses smartSQL, it must select soup entry ids).
 @param soupName The name of the soup from which to remove the soup entries.
 */
- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName NS_SWIFT_UNAVAILABLE("Use removeEntriesByQuery");

/**
 Remove all elements from soup.
 
 @param soupName The name of the soup to clear.
 */
- (void)clearSoup:(NSString*)soupName;

/**
 Remove soup completely from the store.
 
 @param soupName The name of the soup to remove from the store.
 */
- (void)removeSoup:(NSString*)soupName;

/**
 Remove all soups from the store.
 */
- (void)removeAllSoups;

/**
 Return database file size.
 @return Database size, in bytes.
 */
- (unsigned long long)getDatabaseSize;

/**
 Returns sum of all external file sizes for a given soup.
 
 @param soupName Name of the soup.
 @return External file storage size, in bytes.
 */
- (unsigned long long)getExternalFileStorageSizeForSoup:(NSString*)soupName NS_SWIFT_NAME(getExternalFileStorageSize(soupName:));

/**
 Return the number of external storage files for a given soup.
 
 @param soupName The name of the soup.
 @return Number of external files.
 */
- (NSUInteger)getExternalFilesCountForSoup:(NSString*)soupName NS_SWIFT_NAME(getExternalFilesCount(soupName:));

/**
 Alter soup indexes.

 @param soupName The name of the soup to alter.
 @param indexSpecs Array of one ore more SFSoupIndex objects to replace existing index specs.
 @param reIndexData pass true if you want existing records to be re-indexed for new index specs.
 @return YES if the soup was altered successfully.
 */
- (BOOL) alterSoup:(NSString*)soupName withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs reIndexData:(BOOL)reIndexData NS_SWIFT_NAME(alterSoup(soupName:indexSpecs:reIndexData:));

/**
 Alter soup indexes.
 
 @param soupName The name of the soup to alter.
 @param soupSpec The new soup spec to convert. (e.g. convert internal storage soup to external storage soup).
 @param indexSpecs Array of one ore more SFSoupIndex objects to replace existing index specs.
 @param reIndexData Pass YES if you want existing records to be re-indexed for new index specs.
 @return YES if the soup was altered successfully.
 */
- (BOOL) alterSoup:(NSString*)soupName withSoupSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs reIndexData:(BOOL)reIndexData NS_SWIFT_NAME(alterSoup(soupName:soupSpec:indexSpecs:reIndexData:));


/**
 Reindex a soup.
 
 @param soupName The name of the soup to alter.
 @param indexPaths Array of on ore more paths to be reindexed.
 @return YES if soup reindexing succeeded.
 */
- (BOOL) reIndexSoup:(NSString*)soupName withIndexPaths:(NSArray<NSString*>*)indexPaths NS_SWIFT_NAME(reIndexSoup(soupName:indexPaths:));

/**
 * Return compile options
 * @return An array with all the compile options used to build SQL Cipher.
 */
- (NSArray *)getCompileOptions;

/**
 * Return sqlcipher version
 * @return The version of SQL Cipher in use.
 */
- (NSString *)getSQLCipherVersion;

#pragma mark - Long operations recovery methods

/**
 Complete long operations that were interrupted.
 */
- (void) resumeLongOperations;


#pragma mark - Utility methods

/**
 This property is updated when notifications are received for
 UIApplicationProtectedDataDidBecomeAvailable and UIApplicationProtectedDataWillBecomeUnavailable events.
 Note that on the simulator currently, data protection is NEVER active.
 
 @return YES if file data protection (full passcode-based encryption) is available.
 */
- (BOOL)isFileDataProtectionActive;


/**
 Return all soup names.
 @return Array containing all soup names.
 */
- (NSArray<NSString*>*) allSoupNames;

/**
 Creates a date object from the last modified date column value, which is numeric.
 @param lastModifiedValue The numeric value of the date stored in the soup entry.
 @return The NSDate representation of the last modified date.
 */
+ (NSDate *)dateFromLastModifiedValue:(NSNumber *)lastModifiedValue NS_SWIFT_NAME(date(lastModifiedValue:));

@end

NS_ASSUME_NONNULL_END
