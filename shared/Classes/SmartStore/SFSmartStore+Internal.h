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

@interface SFSmartStore ()

@property (nonatomic, strong) FMDatabase *storeDb;

- (id)initWithName:(NSString*)name;

/**
 Everything needed to setup the store db file when it doesn't yet exist.
 
 @return Success ?
 */
- (BOOL)firstTimeStoreDatabaseSetup;


/**
 
 Update the SOUP_INDEX_MAP_TABLE with new indexing columns
 
 @param soupIndexMapInserts array of NSDictionary of columns and values to be inserted
 @return Insert a new set of indices into the soupe index map.
 */
- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts;



/**
 Simply open the db file.
 
 @return YES if we were able to open the db file
 */
- (BOOL)openStoreDatabase:(BOOL)forCreation;

/**
 Create soup index map table to keep track of soups' index specs (SOUP_INDEX_MAP_TABLE)
 Create soup names table to map arbitrary soup names to soup table names (SOUP_NAMES_TABLE)
 
 @return YES if we were able to create the meta tables OK
 */
- (BOOL)createMetaTables;


/**
 Register the new soup in SOUP_NAMES_TABLE
 */
- (NSString *)registerNewSoupName:(NSString*)soupName;
/**
 Obtain soup table name from SOUP_NAMES_TABLE
 */
- (NSString *)tableNameForSoup:(NSString*)soupName;
- (NSString *)tableNameBySoupId:(long)soupId;

/**
 Obtain all soup table names from SOUP_NAMES_TABLE
 */
- (NSArray *)tableNamesForAllSoups;

/**
 Helper method to insert values into an arbitrary table
 
 @param map A dictionary of key-value pairs to be inserted into table.
 */
- (BOOL)insertIntoTable:(NSString *)tableName values:(NSDictionary *)map;

/**
 Helper method to update existing values in a table.
 @param tableName The name of the table to update.
 @param values The column name/value mapping to update.
 @param entryId The id column to determine what to update.
 
 @return YES if the update was successful, NO otherwise.
 */
- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId;


/**
 Maps an indexSpec path to a column name using SOUP_INDEX_MAP_TABLE
 */
- (NSString *)columnNameForPath:(NSString *)path inSoup:(NSString *)soupName;

/**
 Generates range predicate from beginKey/endKey,likeKey etc
 */
- (NSString *)keyRangePredicateForQuerySpec:(SFSoupQuerySpec*)querySpec columnName:(NSString *)columnName;
- (NSArray *)bindsForQuerySpec:(SFSoupQuerySpec *)querySpec;


/// Convenience methods for upserting individual entries: should generally be wrapped with beginTransaction/endTransaction
- (NSDictionary *)upsertOneEntry:(NSDictionary *)entry inSoup:(NSString*)soupName indices:(NSArray*)indices exteralIdPath:(NSString *)externalIdPath error:(NSError **)error;
- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices;
- (NSDictionary *)updateOneEntry:(NSDictionary*)entry withEntryId:(NSNumber *)entryId inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices;


/**
 Similar to System.currentTimeMillis: time in ms since Jan 1 1970
 Used for timestamping created and modified times.
 */
- (NSNumber*)currentTimeInMilliseconds;

/**
 Determines the soup entry ID for a given field path and value, if it exists.
 @param soupName The name of the soup to query.
 @param soupTableName The name of the soup table to query.
 @param fieldPath The field path associated with the entry.
 @param fieldValue The field value returned for the field path.
 @error Will set an error object, if an unexpected error occurs.
 @return The soup entry ID associated with the fieldPath/fieldValue combination, or nil if that
 entry does not exist.
 */
- (NSNumber *)lookupSoupEntryIdForSoupName:(NSString *)soupName
                             soupTableName:(NSString *)soupTableName
                              forFieldPath:(NSString *)fieldPath
                                fieldValue:(NSString *)fieldValue
                                     error:(NSError **)error;

+ (NSString *)encKey;
+ (NSString *)defaultKey;
+ (void)setUsesDefaultKey:(BOOL)usesDefault forStore:(NSString *)storeName;
+ (BOOL)usesDefaultKey:(NSString *)storeName;
+ (void)changeKeyForDb:(FMDatabase *)db name:(NSString *)storeName oldKey:(NSString *)oldKey newKey:(NSString *)newKey;
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

@end