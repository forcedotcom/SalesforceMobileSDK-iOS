/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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
#import "SFSmartStore.h"

@class FMDatabase;
@class FMResultSet;

/**
 Enumeration of types of encryption used for the default encryption of stores.
 */
typedef enum {
    SFSmartStoreDefaultEncryptionTypeNone,
    SFSmartStoreDefaultEncryptionTypeMac,
    SFSmartStoreDefaultEncryptionTypeIdForVendor,
    SFSmartStoreDefaultEncryptionTypeBaseAppId
} SFSmartStoreDefaultEncryptionType;

@interface SFSmartStore ()

@property (nonatomic, strong) FMDatabase *storeDb;

- (id)initWithName:(NSString*)name;

/**
 Everything needed to setup the store db file when it doesn't yet exist.
 @return YES if the store setup was successful, NO otherwise.
 */
- (BOOL)firstTimeStoreDatabaseSetup;

/**
 Update the SOUP_INDEX_MAP_TABLE with new indexing columns.
 @param soupIndexMapInserts array of NSDictionary of columns and values to be inserted
 @return YES if the insert was successful, NO otherwise.
 */
- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts;

/**
 Simply open the db file.
 @param forCreation Whether the DB is to be created, or an existing DB should be opened.
 @return YES if we were able to open the DB file.
 */
- (BOOL)openStoreDatabase:(BOOL)forCreation;

/**
 Create soup index map table to keep track of soups' index specs (SOUP_INDEX_MAP_TABLE)
 Create soup names table to map arbitrary soup names to soup table names (SOUP_NAMES_TABLE)
 @return YES if we were able to create the meta tables, NO otherwise.
 */
- (BOOL)createMetaTables;

/**
 Register the new soup in SOUP_NAMES_TABLE.
 @return The table name associated with the new soup.
 */
- (NSString *)registerNewSoupName:(NSString*)soupName;

/**
 @return The soup table name from SOUP_NAMES_TABLE, based on soup name.
 */
- (NSString *)tableNameForSoup:(NSString*)soupName;

/**
 @return The soup table name from SOUP_NAMES_TABLE, based on soup ID.
 */
- (NSString *)tableNameBySoupId:(long)soupId;

/**
 @return All soup table names from SOUP_NAMES_TABLE.
 */
- (NSArray *)tableNamesForAllSoups;

/**
 Helper method to insert values into an arbitrary table.
 @param tableName The table to insert the data into.
 @param map A dictionary of key-value pairs to be inserted into table.
 @return YES if the insert was successful, NO otherwise.
 */
- (BOOL)insertIntoTable:(NSString *)tableName values:(NSDictionary *)map;

/**
 Helper method to update existing values in a table.
 @param tableName The name of the table to update.
 @param values The column name/value mapping to update.
 @param entryId The ID column used to determine what to update.
 @return YES if the update was successful, NO otherwise.
 */
- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId;

/**
 @return The map of an indexSpec path to a column name from SOUP_INDEX_MAP_TABLE.
 */
- (NSString *)columnNameForPath:(NSString *)path inSoup:(NSString *)soupName;

/**
 Upserts one entry into the soup.
 @param entry The entry to upsert.
 @param soupName The name of the soup to upsert into.
 @param indices The indices that define a unique entry in the soup.
 @param externalIdPath A path in the entry to an external ID that can define uniqueness in the data.
 @param error Will hold an output NSError value, if something goes wrong.
 @return The dictionary representing the updated entry.
 */
- (NSDictionary *)upsertOneEntry:(NSDictionary *)entry inSoup:(NSString*)soupName indices:(NSArray*)indices exteralIdPath:(NSString *)externalIdPath error:(NSError **)error;

/**
 Inserts one entry into the soup.
 @param entry The entry to insert.
 @param soupTableName The name of the table representing the soup, to insert into.
 @param indices The indices that define a unique entry in the soup.
 @return The dictionary representing the updated entry.
 */
- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices;

/**
 Updates one entry in the soup.
 @param entry The entry to update.
 @param entryId The unique entry ID associated with this item.
 @param soupTableName The name of the table representing the soup, to update.
 @param indices The indices that define a unique entry in the soup.
 @return The dictionary representing the updated entry.
 */
- (NSDictionary *)updateOneEntry:(NSDictionary*)entry withEntryId:(NSNumber *)entryId inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices;

/**
 Similar to System.currentTimeMillis: time in ms since Jan 1 1970
 Used for timestamping created and modified times.
 @return The current number of milliseconds since 1/1/1970.
 */
- (NSNumber*)currentTimeInMilliseconds;

/**
 Determines the soup entry ID for a given field path and value, if it exists.
 @param soupName The name of the soup to query.
 @param soupTableName The name of the soup table to query.
 @param fieldPath The field path associated with the entry.
 @param fieldValue The field value returned for the field path.
 @param error Will set an error object, if an unexpected error occurs.
 @return The soup entry ID associated with the fieldPath/fieldValue combination, or nil if that
 entry does not exist.
 */
- (NSNumber *)lookupSoupEntryIdForSoupName:(NSString *)soupName
                             soupTableName:(NSString *)soupTableName
                              forFieldPath:(NSString *)fieldPath
                                fieldValue:(NSString *)fieldValue
                                     error:(NSError **)error;

/**
 @return The key used to encrypt the store.
 */
+ (NSString *)encKey;

/**
 @return The default key to use, if no encryption key exists.
 */
+ (NSString *)defaultKey;

/**
 @return The default key, based on the MAC address.
 */
+ (NSString *)defaultKeyMac;

/**
 @return The default key, based on the idForVendor value.
 */
+ (NSString *)defaultKeyIdForVendor;

/**
 @return The default key, based on the base app id.
 */
+ (NSString *)defaultKeyBaseAppId;

/**
 Creates a default key with the given seed.
 @param seed The seed for creating the default key.
 @return The default key, based on the seed.
 */
+ (NSString *)defaultKeyWithSeed:(NSString *)seed;

/**
 Gets the default encryption type for the given store.
 @param storeName The name of the story to query for its default encryption type.
 @return An SFSmartStoreDefaultEncryptionType enumerated value specifying the default encryption type.
 */
+ (SFSmartStoreDefaultEncryptionType)defaultEncryptionTypeForStore:(NSString *)storeName;

/**
 Sets the default encryption type for the given store.
 @param encType The type of default encryption being used for the store.
 @param storeName The name of the store to set the value for.
 */
+ (void)setDefaultEncryptionType:(SFSmartStoreDefaultEncryptionType)encType forStore:(NSString *)storeName;

/**
 Updates the default encryption of all the stores utilizing default encryption, to the preferred default encryption method.
 */
+ (void)updateDefaultEncryption;

/**
 Updates the default encryption method for a given store, assuming it's using default encryption.
 @param storeName The name of the store to update.
 @return YES if the update was successful, NO otherwise.
 */
+ (BOOL)updateDefaultEncryptionForStore:(NSString *)storeName;

/**
 Sets a property specifying whether the given store uses a default key for encryption.
 @param usesDefault Whether the store uses a default key.
 @param storeName The store for which the setting applies.
 */
+ (void)setUsesDefaultKey:(BOOL)usesDefault forStore:(NSString *)storeName;

/**
 Determines whether the given store uses a default key for encryption.
 @param storeName The store associated with the setting.
 @return YES if it does, NO if it doesn't.
 */
+ (BOOL)usesDefaultKey:(NSString *)storeName;

/**
 Change the encryption key for a database.
 @param db The DB associated with the encryption.
 @param storeName The store name associated with the request.
 @param oldKey The original key for the encryption.
 @param newKey The new key to re-encrypt with.
 @return The updated database, post encryption action.  Note: This may be a new instance of
 FMDatabase, depending on the action.
 */
+ (FMDatabase *)changeKeyForDb:(FMDatabase *)db name:(NSString *)storeName oldKey:(NSString *)oldKey newKey:(NSString *)newKey;

/**
 FOR UNIT TESTING.  Removes all of the shared smart store objects from memory (persisted stores remain).
 */
+ (void)clearSharedStoreMemoryState;

/**
 Queries a table for the given column data, based on the given clauses.
 @param table The table to query.
 @param columns The columns to return.
 @param orderBy The column to order by.
 @param limit The limit on number of rows to return.
 @param whereClause The WHERE clause limiting the query.
 @param whereArgs The arguments associated with the WHERE clause.
 
 @return An FMResultSet with the rows matching the query.
*/
- (FMResultSet *)queryTable:(NSString*)table
forColumns:(NSArray*)columns
orderBy:(NSString*)orderBy
limit:(NSString*)limit
whereClause:(NSString*)whereClause
whereArgs:(NSArray*)whereArgs;

/**
 Convert smart sql to sql.
 @param smartSql The smart sql to convert.
 @return The sql.
 */
- (NSString*) convertSmartSql:(NSString*)smartSql;

@end
