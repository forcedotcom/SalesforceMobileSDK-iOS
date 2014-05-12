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

@property (nonatomic, strong) FMDatabaseQueue *storeQueue;

- (id)initWithName:(NSString*)name;

/**
 Simply open the db file.
 @param forCreation Whether the DB is to be created, or an existing DB should be opened.
 @return YES if we were able to open the DB file.
 */
- (BOOL)openStoreDatabase:(BOOL)forCreation;

/**
 @param db This method is expected to be called from [fmdbqueue inDatabase:^(){ ... }]
 @return The soup table name from SOUP_NAMES_TABLE, based on soup name.
 */
- (NSString *)tableNameForSoup:(NSString*)soupName withDb:(FMDatabase*) db;

/**
 Helper method to insert values into an arbitrary table.
 @param tableName The table to insert the data into.
 @param map A dictionary of key-value pairs to be inserted into table.
 @param db This method is expected to be called from [fmdbqueue inDatabase:^(){ ... }]
 @return YES if the insert was successful, NO otherwise.
 */
- (BOOL)insertIntoTable:(NSString *)tableName values:(NSDictionary *)map withDb:(FMDatabase*)db;

/**
 Helper method to update existing values in a table.
 @param tableName The name of the table to update.
 @param values The column name/value mapping to update.
 @param entryId The ID column used to determine what to update.
 @param db This method is expected to be called from [fmdbqueue inDatabase:^(){ ... }]
 @return YES if the update was successful, NO otherwise.
 */
- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId withDb:(FMDatabase*)db;

/**
 @param db This method is expected to be called from [fmdbqueue inDatabase:^(){ ... }]
 @return The map of an indexSpec path to a column name from SOUP_INDEX_MAP_TABLE.
 */
- (NSString *)columnNameForPath:(NSString *)path inSoup:(NSString *)soupName withDb:(FMDatabase*)db;

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
 Convert smart sql to sql.
 @param smartSql The smart sql to convert.
 @return The sql.
 */
- (NSString*) convertSmartSql:(NSString*)smartSql;

@end
