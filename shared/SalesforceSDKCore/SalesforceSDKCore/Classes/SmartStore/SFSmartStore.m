/*
 Copyright (c) 2011-2012, salesforce.com, inc. All rights reserved.
 
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

//required for UIApplicationProtectedDataDidBecomeAvailable
#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "SFJsonUtils.h"
#import "SFSmartStore+Internal.h"
#import "SFSmartStoreUpgrade.h"
#import "SFSmartStoreUtils.h"
#import "SFSmartSqlHelper.h"
#import "SFStoreCursor.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFKeyStoreManager.h>
#import <SalesforceSecurity/SFEncryptionKey.h>
#import "SFUserAccountManager.h"

static NSMutableDictionary *_allSharedStores;


// The name of the store name used by the SFSmartStorePlugin for hybrid apps
NSString * const kDefaultSmartStoreName   = @"defaultStore";

// NSError constants  (TODO: We should move this stuff into a framework where errors can be configurable
// in a plist, once we start delivering a bundle.
NSString *        const kSFSmartStoreErrorDomain                = @"com.salesforce.smartstore.error";
static NSInteger  const kSFSmartStoreTooManyEntriesCode         = 1;
static NSString * const kSFSmartStoreTooManyEntriesDescription  = @"Cannot update entry: the value '%@' for path '%@' does not represent a unique entry!";
static NSInteger  const kSFSmartStoreIndexNotDefinedCode        = 2;
static NSString * const kSFSmartStoreIndexNotDefinedDescription = @"No index column defined for field '%@'.";
static NSInteger  const kSFSmartStoreExternalIdNilCode          = 3;
static NSString * const kSFSmartStoreExternalIdNilDescription   = @"For upsert with external ID path '%@', value cannot be empty for any entries.";
static NSString * const kSFSmartStoreExtIdLookupError           = @"There was an error retrieving the soup entry ID for path '%@' and value '%@': %@";

// Encryption constants
static NSString * const kSFSmartStoreEncryptionKeyLabel = @"com.salesforce.smartstore.encryption.keyLabel";

// Table to keep track of soup names
static NSString *const SOUP_NAMES_TABLE = @"soup_names";

// Table to keep track of soup's index specs
static NSString *const SOUP_INDEX_MAP_TABLE = @"soup_index_map";

// Columns of the soup index map table
static NSString *const SOUP_NAME_COL = @"soupName";

static NSString *const PATH_COL = @"path";
static NSString *const COLUMN_NAME_COL = @"columnName";
static NSString *const COLUMN_TYPE_COL = @"columnType";

// Columns of a soup table
static NSString *const ID_COL = @"id";
static NSString *const CREATED_COL = @"created";
static NSString *const LAST_MODIFIED_COL = @"lastModified";
static NSString *const SOUP_COL = @"soup";

// JSON fields added to soup element on insert/update
static NSString *const SOUP_ENTRY_ID = @"_soupEntryId";
static NSString *const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";

@implementation SFSmartStore

@synthesize storeQueue = _storeQueue;
@synthesize storeName = _storeName;
@synthesize user = _user;
@synthesize dbMgr = _dbMgr;

+ (void)initialize
{
    // We do store upgrades as the very first thing, because there are so many class methods that access
    // the data stores without initializing an SFSmartStore instance.
    [SFSmartStoreUpgrade updateStoreLocations];
    [SFSmartStoreUpgrade updateEncryption];
}

- (id) initWithName:(NSString*)name user:(SFUserAccount *)user {
    self = [super init];
    
    if (nil != self)  {
        [self log:SFLogLevelDebug format:@"SFSmartStore initWithName: %@, user: %@", name, [SFSmartStoreUtils userKeyForUser:user]];
        
        _storeName = name;
        if ([user isEqual:[SFUserAccountManager sharedInstance].temporaryUser]) {
            _user = nil;
        } else {
            _user = user;
        }
        
        _dbMgr = [SFSmartStoreDatabaseManager sharedManagerForUser:_user];
        
        // Setup listening for data protection available / unavailable
        _dataProtectionKnownAvailable = NO;
        //we use this so that addObserverForName doesn't retain us
        __strong SFSmartStore *this = self;
        _dataProtectAvailObserverToken = [[NSNotificationCenter defaultCenter]
                                          addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                                          object:nil
                                          queue:nil
                                          usingBlock:^(NSNotification *note) {
                                              [self log:SFLogLevelDebug format:@"SFSmartStore UIApplicationProtectedDataDidBecomeAvailable"];
                                              this->_dataProtectionKnownAvailable = YES;
                                          }];
        
        _dataProtectUnavailObserverToken = [[NSNotificationCenter defaultCenter]
                                            addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable
                                            object:nil
                                            queue:nil
                                            usingBlock:^(NSNotification *note) {
                                                [self log:SFLogLevelDebug format:@"SFSmartStore UIApplicationProtectedDataWillBecomeUnavailable"];
                                                this->_dataProtectionKnownAvailable = NO;
                                            }];
        
        
        _indexSpecsBySoup = [[NSMutableDictionary alloc] init];
        
        _smartSqlToSql = [[NSMutableDictionary alloc] init];
        
        if (![_dbMgr persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                self = nil;
            }
        } else {
            if (![self openStoreDatabase]) {
                self = nil;
            }
        }
        
        
    }
    return self;
}

- (void)dealloc {
    [self log:SFLogLevelDebug format:@"dealloc store: '%@'",_storeName];
    [self.storeQueue close];
    SFRelease(_indexSpecsBySoup);
    SFRelease(_smartSqlToSql);
    
    //remove data protection observer
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectAvailObserverToken];
    SFRelease(_dataProtectAvailObserverToken);
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectUnavailObserverToken];
    SFRelease(_dataProtectUnavailObserverToken);
}


- (BOOL)firstTimeStoreDatabaseSetup {
    BOOL result = NO;
    NSError *createErr = nil, *protectErr = nil;
    
    if (![self isFileDataProtectionActive]) {
        //This is expected on simulator and when user does not have unlock passcode set
        [self log:SFLogLevelDebug format:@"WARNING file data protection inactive when creating store db."];
    }
    
    // Ensure that the store directory exists.
    [self.dbMgr createStoreDir:self.storeName error:&createErr];
    if (nil == createErr) {
        // Need to create the db file itself before we can encrypt it.
        if ([self openStoreDatabase]) {
            if ([self createMetaTables]) {
                [self.storeQueue close];  self.storeQueue = nil; // Need to close before setting encryption.
                [self.dbMgr protectStoreDir:self.storeName error:&protectErr];
                if (protectErr != nil) {
                    [self log:SFLogLevelError format:@"Couldn't protect store: %@", protectErr];
                } else {
                    //reopen the storeDb now that it's protected
                    result = [self openStoreDatabase];
                }
            }
        }
    }
    
    if (!result) {
        [self log:SFLogLevelError format:@"Deleting store dir since we can't set it up properly: %@", self.storeName];
        [self.dbMgr removeStoreDir:self.storeName];
    }
    
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:result forUser:self.user store:self.storeName];
    return result;
}

- (BOOL)openStoreDatabase {
   NSError *openDbError = nil;
    self.storeQueue = [self.dbMgr openStoreQueueWithName:self.storeName key:[[self class] encKey] error:&openDbError];
    if (self.storeQueue == nil) {
        [self log:SFLogLevelError format:@"Error opening store '%@': %@", self.storeName, [openDbError localizedDescription]];
    }
    
    return (self.storeQueue != nil);
}

#pragma mark - Store methods

+ (id)sharedStoreWithName:(NSString *)storeName {
    return [self sharedStoreWithName:storeName user:[SFUserAccountManager sharedInstance].currentUser];
}

+ (id)sharedStoreWithName:(NSString*)storeName user:(SFUserAccount *)user {
    if (nil == _allSharedStores) {
        _allSharedStores = [NSMutableDictionary dictionary];
    }
    NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
    if ([_allSharedStores objectForKey:userKey] == nil) {
        [_allSharedStores setObject:[NSMutableDictionary dictionary] forKey:userKey];
    }
    
    SFSmartStore *store = [[_allSharedStores objectForKey:userKey] objectForKey:storeName];
    if (nil == store) {
        store = [[self alloc] initWithName:storeName user:user];
        if (store)
            [[_allSharedStores objectForKey:userKey] setObject:store forKey:storeName];
    }
    
    return store;
}

+ (void)removeSharedStoreWithName:(NSString *)storeName {
    [self removeSharedStoreWithName:storeName forUser:[SFUserAccountManager sharedInstance].currentUser];
}

+ (void)removeSharedStoreWithName:(NSString*)storeName forUser:(SFUserAccount *)user {
    [self log:SFLogLevelDebug format:@"removeSharedStoreWithName: %@, user: %@", storeName, user];
    NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
    SFSmartStore *existingStore = [[_allSharedStores objectForKey:userKey] objectForKey:storeName];
    if (nil != existingStore) {
        [existingStore.storeQueue close];
        [[_allSharedStores objectForKey:userKey] removeObjectForKey:storeName];
    }
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:user store:storeName];
    [[SFSmartStoreDatabaseManager sharedManagerForUser:user] removeStoreDir:storeName];
}

+ (void)removeAllStores {
    [self removeAllStoresForUser:[SFUserAccountManager sharedInstance].currentUser];
}

+ (void)removeAllStoresForUser:(SFUserAccount *)user {
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManagerForUser:user] allStoreNames];
    for (NSString *storeName in allStoreNames) {
        [self removeSharedStoreWithName:storeName forUser:user];
    }
    [SFSmartStoreDatabaseManager removeSharedManagerForUser:user];
}

+ (void)clearSharedStoreMemoryState
{
    [_allSharedStores removeAllObjects];
}

- (BOOL)createMetaTables {
    __block BOOL result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self createMetaTablesWithDb:db];
    }];
    
    /*
     TODO bring back
    @try {
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelError format:@"Exception creating meta tables: %@", exception];
    }
    @finally {
        if (!result) {
            [self log:SFLogLevelError format:@"ERROR %d creating meta tables: '%@'",
             [db lastErrorCode],
             [db lastErrorMessage]];
        }
    }
    */
    
    return result;
}


- (BOOL)createMetaTablesWithDb:(FMDatabase*) db {
    // Create SOUP_INDEX_MAP_TABLE
    NSString *createSoupIndexTableSql = [NSString stringWithFormat:
                                         @"CREATE TABLE IF NOT EXISTS %@ (%@ TEXT, %@ TEXT, %@ TEXT, %@ TEXT )",
                                         SOUP_INDEX_MAP_TABLE,
                                         SOUP_NAME_COL,
                                         PATH_COL,
                                         COLUMN_NAME_COL,
                                         COLUMN_TYPE_COL
                                         ];
    
    [self log:SFLogLevelDebug format:@"createSoupIndexTableSql: %@",createSoupIndexTableSql];
    
    
    // Create SOUP_NAMES_TABLE
    // The table name for the soup will simply be TABLE_<soupId>
    NSString *createSoupNamesTableSql = [NSString stringWithFormat:
                                         @"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT )",
                                         SOUP_NAMES_TABLE,
                                         ID_COL,
                                         SOUP_NAME_COL
                                         ];
    
    
    [self log:SFLogLevelDebug format:@"createSoupNamesTableSql: %@",createSoupNamesTableSql];
    
    // Create an index for SOUP_NAME_COL in SOUP_NAMES_TABLE
    NSString *createSoupNamesIndexSql = [NSString stringWithFormat:
                                         @"CREATE INDEX %@_0 on %@ ( %@ )",
                                         SOUP_NAMES_TABLE, SOUP_NAMES_TABLE, SOUP_NAME_COL];
    [self log:SFLogLevelDebug format:@"createSoupNamesIndexSql: %@",createSoupNamesIndexSql];
    
    
    BOOL result = NO;
    result =[db  executeUpdate:createSoupIndexTableSql];
    if (result) {
        result =[db  executeUpdate:createSoupNamesTableSql];
        // Add index on SOUP_NAME_COL
        if (result) {
            result = [db executeUpdate:createSoupNamesIndexSql];
        }
    }
    
    return result;
}


#pragma mark - Utility methods

+ (NSString *)encKey
{
    SFEncryptionKey *key = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kSFSmartStoreEncryptionKeyLabel autoCreate:YES];
    return [key keyAsString];
}

- (NSNumber *)currentTimeInMilliseconds {
    NSTimeInterval rawTime = 1000 * [[NSDate date] timeIntervalSince1970];
    rawTime = floor(rawTime);
    NSNumber *nowVal = [NSNumber numberWithDouble:rawTime];
    return nowVal;
}

- (BOOL)isFileDataProtectionActive {
    return _dataProtectionKnownAvailable;
}

#pragma mark - Data access utility methods

- (BOOL)insertIntoTable:(NSString*)tableName values:(NSDictionary*)map withDb:(FMDatabase *) db {
    // map all of the columns and values from soupIndexMapInserts
    __strong NSMutableString *fieldNames = [[NSMutableString alloc] init];
    __strong NSMutableArray *binds = [[NSMutableArray alloc] init];
    __strong NSMutableString *fieldValueMarkers = [[NSMutableString alloc] init];
    __block NSUInteger fieldCount = 0;
    
    [map enumerateKeysAndObjectsUsingBlock:
     ^(id key, id obj, BOOL *stop) {
         if (fieldCount > 0) {
             [fieldNames appendFormat:@",%@",key];
             [fieldValueMarkers appendString:@",?"];
         } else {
             [fieldNames appendString:key];
             [fieldValueMarkers appendString:@"?"];
         }
         [binds addObject:obj];
         fieldCount++;
     }];
    
    
    NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",
                           tableName, fieldNames, fieldValueMarkers];
    //[self log:SFLogLevelDebug format:@"insertSql: %@ binds: %@",insertSql,binds];
    BOOL result = [db executeUpdate:insertSql withArgumentsInArray:binds];
    
    return result;
    
}

- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId withDb:(FMDatabase*) db
{
    NSAssert(entryId != nil, @"Entry ID must have a value.");
    
    // map all of the columns and values from soupIndexMapInserts
    __strong NSMutableString *fieldEntries = [[NSMutableString alloc] init];
    __strong NSMutableArray *binds = [[NSMutableArray alloc] init];
    __block NSUInteger fieldCount = 0;
    
    [map enumerateKeysAndObjectsUsingBlock:
     ^(id key, id obj, BOOL *stop) {
         if (fieldCount > 0) {
             [fieldEntries appendString:@", "];
         }
         [fieldEntries appendFormat:@"%@ = ?", key];
         [binds addObject:obj];
         fieldCount++;
     }];
    
    [binds addObject:entryId];
    
    
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?",
                           tableName, fieldEntries, ID_COL];
    //[self log:SFLogLevelDebug format:@"upsertSql: %@ binds: %@",upsertSql,binds];
    BOOL result = [db executeUpdate:updateSql withArgumentsInArray:binds];
    
    return result;
    
}

- (NSString*)columnNameForPath:(NSString*)path inSoup:(NSString*)soupName withDb:(FMDatabase*) db {
    //TODO cache these with soupName:path ? if slow...
    NSString *result = nil;
    if (nil == path) {
        return result;
    }
    
    NSString *querySql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ? AND %@ = ?",
                          COLUMN_NAME_COL,SOUP_INDEX_MAP_TABLE,
                          SOUP_NAME_COL,
                          PATH_COL
                          ];
    FMResultSet *frs = [db executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObjects:soupName, path, nil]];
    if ([frs next]) {
        result = [frs stringForColumnIndex:0];
    }
    [frs close];
    
    if (nil == result) {
        [self log:SFLogLevelDebug format:@"Unknown index path '%@' in soup '%@' ",path,soupName];
    }
    return result;
    
}

- (NSString*) convertSmartSql:(NSString*)smartSql
{
    __block NSString* result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self convertSmartSql:smartSql withDb:db];
    }];
    return result;
}

- (NSString*) convertSmartSql:(NSString*)smartSql withDb:(FMDatabase*)db
{
    [self log:SFLogLevelDebug format:@"convertSmartSQl:%@", smartSql];
    NSObject* sql = [_smartSqlToSql objectForKey:smartSql];
    
    if (nil == sql) {
        sql = [[SFSmartSqlHelper sharedInstance] convertSmartSql:smartSql withStore:self withDb:db];
        
        // Conversion failed, putting the NULL in the cache so that we don't retry conversion
        if (sql == nil) {
            [self log:SFLogLevelDebug format:@"convertSmartSql:putting NULL in cache"];
            [_smartSqlToSql setObject:[NSNull null] forKey:smartSql];
        }
        // Updating cache
        else {
            [self log:SFLogLevelDebug format:@"convertSmartSql:putting %@ in cache", sql];
            [_smartSqlToSql setObject:sql forKey:smartSql];
        }
    }
    else if ([sql isEqual:[NSNull null]]) {
        [self log:SFLogLevelDebug format:@"convertSmartSql:found NULL in cache"];
        return nil;
    }
    
    return (NSString*) sql;
}

- (FMResultSet *)queryTable:(NSString*)table
                 forColumns:(NSArray*)columns
                    orderBy:(NSString*)orderBy
                      limit:(NSString*)limit
                whereClause:(NSString*)whereClause
                  whereArgs:(NSArray*)whereArgs
                     withDb:(FMDatabase*)db
{
    NSString *columnsStr = (nil == columns) ? @"" : [columns componentsJoinedByString:@","];
    columnsStr = ([@"" isEqualToString:columnsStr]) ? @"*" : columnsStr;
    
    NSString *orderByStr = (nil == orderBy) ?
    @"" :
    [NSString stringWithFormat:@"ORDER BY %@",orderBy ];
    NSString *selectionStr = (nil == whereClause) ?
    @"" :
    [NSString stringWithFormat:@"WHERE %@",whereClause ];
    NSString *limitStr = (nil == limit) ?
    @"" :
    [NSString stringWithFormat:@"LIMIT %@",limit ];
    
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ %@ %@ %@",
                     columnsStr, table, selectionStr, orderByStr, limitStr];
    FMResultSet *frs = [db executeQuery:sql withArgumentsInArray:whereArgs];
    return frs;
}


#pragma mark - Soup maniupulation methods

- (NSString*)tableNameForSoup:(NSString*)soupName withDb:(FMDatabase*) db {
    NSString *result  = nil;
    
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_NAMES_TABLE,SOUP_NAME_COL];
    //    [self log:SFLogLevelDebug format:@"tableName query: %@",sql];
    FMResultSet *frs = [db executeQuery:sql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
    
    if ([frs next]) {
        int colIdx = [frs columnIndexForName:ID_COL];
        long soupId = [frs longForColumnIndex:colIdx];
        result = [self tableNameBySoupId:soupId];
    } else {
        [self log:SFLogLevelDebug format:@"No table for: '%@'",soupName];
    }
    [frs close];
    
    return result;
}


- (NSString *)tableNameBySoupId:(long)soupId {
    return [NSString stringWithFormat:@"TABLE_%ld",soupId];
}

- (NSArray *)tableNamesForAllSoupsWithDb:(FMDatabase*) db{
    NSMutableArray* result = [NSMutableArray array]; // equivalent to: [[[NSMutableArray alloc] init] autorelease]
    NSString* sql = [NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_NAMES_TABLE];
    FMResultSet *frs = [db executeQuery:sql];
    while ([frs next]) {
        NSString* tableName = [frs stringForColumn:SOUP_NAME_COL];
        [result addObject:tableName];
    }
    
    [frs close];
    return result;
}

- (NSArray*)indicesForSoup:(NSString*)soupName {
    __block NSArray* result;
    [self.storeQueue inDatabase:^(FMDatabase * db) {
        result = [self indicesForSoup:soupName withDb:db];
    }];
    return result;
}

- (NSArray*)indicesForSoup:(NSString*)soupName withDb:(FMDatabase *)db {
    //look in the cache first
    NSMutableArray *result = [_indexSpecsBySoup objectForKey:soupName];
    if (nil == result) {
        result = [NSMutableArray array];
        
        //no cached indices ...reload from SOUP_INDEX_MAP_TABLE
        NSString *querySql = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@ = ?",
                              PATH_COL, COLUMN_NAME_COL, COLUMN_TYPE_COL,
                              SOUP_INDEX_MAP_TABLE,
                              SOUP_NAME_COL];
        [self log:SFLogLevelDebug format:@"indices sql: %@",querySql];
        FMResultSet *frs = [db executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
        
        while([frs next]) {
            NSString *path = [frs stringForColumn:PATH_COL];
            NSString *columnName = [frs stringForColumn:COLUMN_NAME_COL];
            NSString *type = [frs stringForColumn:COLUMN_TYPE_COL];
            
            SFSoupIndex *spec = [[SFSoupIndex alloc] initWithPath:path indexType:type columnName:columnName];
            [result addObject:spec];
        }
        [frs close];
        
        //update the cache
        [_indexSpecsBySoup setObject:result forKey:soupName];
    }
    
    if (!(result.count > 0)) {
        [self log:SFLogLevelDebug format:@"no indices for '%@'",soupName];
    }
    return result;
}

- (BOOL)soupExists:(NSString*)soupName {
    __block BOOL result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self soupExists:soupName withDb:db];
    }];
    return result;
}

- (BOOL)soupExists:(NSString*)soupName withDb:(FMDatabase*) db {
    BOOL result = NO;
    //first verify that we have this soup name in our soup names table
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    if (nil != soupTableName) {
        //double-check that we actually have this table
        result = [db tableExists:soupTableName];
    }
    
    return result;
}


- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts withDb:(FMDatabase*)db {
    BOOL result = YES;
    
    // update the mapping table for this soup's columns
    for (NSDictionary *map in soupIndexMapInserts) {
        BOOL runOk = [self insertIntoTable:SOUP_INDEX_MAP_TABLE values:map withDb:db];
        if (!runOk) {
            result = NO;
            break;
        }
    }
    
    return result;
}

- (NSString *)registerNewSoupName:(NSString*)soupName withDb:(FMDatabase*) db {
    NSString *soupTableName = nil;
    
    //Get a safe table name for the soupName
    NSDictionary *soupMapValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                   soupName, SOUP_NAME_COL,
                                   nil];
    
    BOOL insertSucceeded = [self insertIntoTable:SOUP_NAMES_TABLE values:soupMapValues withDb:db];
    if (insertSucceeded) {
        soupTableName = [self tableNameForSoup:soupName withDb:db];
    }
    
    if (nil == soupTableName) {
        [self log:SFLogLevelDebug format:@"couldn't properly register soupName: '%@' ",soupName];
    }
    
    return soupTableName;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs {
    __block BOOL result;
    [self.storeQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        result = [self registerSoup:soupName withIndexSpecs:indexSpecs withDb:db];
        
        if (!result) {
            *rollback = YES;
        }
    }];
    return result;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs withDb:(FMDatabase*) db
{
    BOOL result = NO;
    
    //verify soupName
    if (!([soupName length] > 0)) {
        [self log:SFLogLevelDebug format:@"Bogus soupName: '%@'",soupName];
        return result;
    }
    //verify indexSpecs
    if (!([indexSpecs count] > 0)) {
        [self log:SFLogLevelDebug format:@"Bogus indexSpecs: '%@'",indexSpecs];
        return result;
    }
    
    // If soup with soupName already exists, just return success.
    if ([self soupExists:soupName withDb:db]) {
        result = YES;
        return result;
    }
    
    NSString *soupTableName = [self registerNewSoupName:soupName withDb:db];
    if (nil == soupTableName) {
        return result;
    } else {
        [self log:SFLogLevelDebug format:@"==== Creating %@ ('%@') ====",soupTableName,soupName];
    }
    
    NSMutableArray *soupIndexMapInserts = [[NSMutableArray alloc] init ];
    NSMutableArray *createIndexStmts = [[NSMutableArray alloc] init ];
    NSMutableString *createTableStmt = [[NSMutableString alloc] init];
    [createTableStmt appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (",soupTableName];
    [createTableStmt appendFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT",ID_COL];
    [createTableStmt appendFormat:@", %@ TEXT",SOUP_COL]; //this is the column where the raw json is stored
    [createTableStmt appendFormat:@", %@ INTEGER",CREATED_COL];
    [createTableStmt appendFormat:@", %@ INTEGER",LAST_MODIFIED_COL];
    
    
    for (NSUInteger i = 0; i < [indexSpecs count]; i++) {
        NSDictionary *rawIndexSpec = [indexSpecs objectAtIndex:i];
        SFSoupIndex *indexSpec = [[SFSoupIndex alloc] initWithIndexSpec:rawIndexSpec];
        
        // for creating the soup table itself in the store db
        NSString *columnName = [NSString stringWithFormat:@"%@_%lu",soupTableName,(unsigned long)i];
        NSString * columnType = [indexSpec columnType];
        [createTableStmt appendFormat:@", %@ %@ ",columnName,columnType];
        [self log:SFLogLevelDebug format:@"adding indexPath: %@ %@  ('%@')",columnName, columnType, [indexSpec path]];
        
        // for inserting into meta mapping table
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init ];
        [values setObject:soupName forKey:SOUP_NAME_COL];
        [values setObject:indexSpec.path forKey:PATH_COL];
        [values setObject:columnName forKey:COLUMN_NAME_COL];
        [values setObject:indexSpec.indexType forKey:COLUMN_TYPE_COL];
        [soupIndexMapInserts addObject:values];
        
        // for creating an index on the soup table
        NSString *indexName = [NSString stringWithFormat:@"%@_%lu_idx",soupTableName,(unsigned long)i];
        [createIndexStmts addObject:
         [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ ON %@ ( %@ )",indexName, soupTableName, columnName]
         ];
    }
    
    [createTableStmt appendString:@")"];
    [self log:SFLogLevelDebug format:@"createTableStmt:\n %@",createTableStmt];
    
    // create the main soup table
    BOOL runOk = [db  executeUpdate:createTableStmt];
    if (!runOk) {
        [self log:SFLogLevelError format:@"ERROR creating soup table  %d %@ stmt: %@",
         [db lastErrorCode],
         [db lastErrorMessage],
         createTableStmt];
    } else {
        // create indices for this soup
        for (NSString *createIndexStmt in createIndexStmts) {
            [self log:SFLogLevelDebug format:@"createIndexStmt: %@",createIndexStmt];
            runOk = [db  executeUpdate:createIndexStmt];
            if (!runOk) {
                [self log:SFLogLevelError format:@"ERROR creating soup index  %d %@",
                 [db lastErrorCode],
                 [db lastErrorMessage]];
                break;
            }
        }
        
        if (runOk) {
            // update the mapping table for this soup's columns
            runOk = [self insertIntoSoupIndexMap:soupIndexMapInserts withDb:db];
        }
    }
    
    return  runOk;
}


- (void)removeSoup:(NSString*)soupName {
    [self.storeQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeSoup:soupName withDb:db];
        // TODO try-catch rollback?
    }];
}

- (void)removeSoup:(NSString*)soupName withDb:(FMDatabase*)db {
    [self log:SFLogLevelDebug format:@"removeSoup: %@", soupName];
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    if (nil == soupTableName)
        return;
    
    NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",soupTableName];
    [db executeUpdate:dropSql];
    
    NSString *deleteIndexSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                                SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, soupName];
    [db executeUpdate:deleteIndexSql];
    NSString *deleteNameSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                               SOUP_NAMES_TABLE, SOUP_NAME_COL, soupName];
    [db executeUpdate:deleteNameSql];
    
    [_indexSpecsBySoup removeObjectForKey:soupName ];
    
    // Cleanup _smartSqlToSql
    NSString* soupRef = [[NSArray arrayWithObjects:@"{", soupName, @"}", nil] componentsJoinedByString:@""];
    NSMutableArray* keysToRemove = [NSMutableArray array];
    for (NSString* smartSql in [_smartSqlToSql allKeys]) {
        if ([smartSql rangeOfString:soupRef].location != NSNotFound) {
            [keysToRemove addObject:smartSql];
            [self log:SFLogLevelDebug format:@"removeSoup: removing cached sql for %@", smartSql];
        }
    }
    [_smartSqlToSql removeObjectsForKeys:keysToRemove];
}

- (void)removeAllSoups
{
    [self.storeQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [self removeAllSoupWithDb:db];
    }];
}

- (void) removeAllSoupWithDb:(FMDatabase*) db
{
    NSArray* soupTableNames = [self tableNamesForAllSoupsWithDb:db];
    if (nil == soupTableNames)
        return;
    for (NSString* soupTableName in soupTableNames) {
        [self removeSoup:soupTableName withDb:db];
    }
}

- (NSNumber *)lookupSoupEntryIdForSoupName:(NSString *)soupName
                             soupTableName:(NSString *)soupTableName
                              forFieldPath:(NSString *)fieldPath
                                fieldValue:(NSString *)fieldValue
                                     error:(NSError **)error
                                    withDb:(FMDatabase*)db
{
    NSAssert(soupName != nil && [soupName length] > 0, @"Soup name must have a value.");
    NSAssert(soupTableName != nil && [soupTableName length] > 0, @"Soup table name must have a value.");
    NSAssert(fieldPath != nil && [fieldPath length] > 0, @"Field path must have a value.");
    
    NSString *fieldPathColumnName = [self columnNameForPath:fieldPath inSoup:soupName withDb:db];
    if (fieldPathColumnName == nil) {
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreIndexNotDefinedDescription, fieldPath];
            *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                         code:kSFSmartStoreIndexNotDefinedCode
                                     userInfo:[NSDictionary dictionaryWithObject:errorDesc
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    
    NSString *whereClause;
    if (fieldValue != nil) {
        whereClause = [NSString stringWithFormat:@"%@ = ?", fieldPathColumnName];
    } else {
        whereClause = [NSString stringWithFormat:@"%@ IS NULL", fieldPathColumnName];
    }
    
    FMResultSet *rs = [self queryTable:soupTableName
                            forColumns:[NSArray arrayWithObject:ID_COL]
                               orderBy:nil
                                 limit:nil
                           whereClause:whereClause
                             whereArgs:(fieldValue != nil ? [NSArray arrayWithObject:fieldValue] : nil)
                                withDb:db];
    NSNumber *returnId = nil;
    if ([rs next]) {
        returnId = [NSNumber numberWithInt:[rs intForColumn:ID_COL]];
        if ([rs next]) {
            // Shouldn't be more than one value; that's an error.
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreTooManyEntriesDescription,
                                   (fieldValue != nil ? fieldValue : @"NULL"),
                                   fieldPath];
            if (error != nil) {
                *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                             code:kSFSmartStoreTooManyEntriesCode
                                         userInfo:[NSDictionary dictionaryWithObject:errorDesc
                                                                              forKey:NSLocalizedDescriptionKey]];
            }
            returnId = nil;
        }
    }
    [rs close];
    
    return returnId;
}

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec
{
    __block NSInteger result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self countWithQuerySpec:querySpec withDb:db];
    }];
    return result;
}

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec withDb:(FMDatabase*)db
{
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSUInteger result = 0;
    
    // SQL
    NSString* countSql = [self convertSmartSql:querySpec.countSmartSql withDb:db];
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: countSql:%@ \n", countSql];
    //    NSString* sql = [self convertSmartSql: querySpec.smartSql withDb:db];
    //    NSString* countSql = [[NSArray arrayWithObjects:@"SELECT COUNT(*) FROM (", sql, @") ", nil] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: countSql:%@ \n", countSql];
    
    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [db executeQuery:countSql withArgumentsInArray:args];
    if([frs next]) {
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
    return result;
}

- (NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex
{
    __block NSArray* result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self queryWithQuerySpec:querySpec pageIndex:pageIndex withDb:db];
    }];
    return result;
}

- (NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex withDb:(FMDatabase*)db
{
    [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:querySpec.pageSize];
    
    // Page
    NSUInteger offsetRows = querySpec.pageSize * pageIndex;
    NSUInteger numberRows = querySpec.pageSize;
    NSString* limit = [NSString stringWithFormat:@"%lu,%lu",(unsigned long)offsetRows,(unsigned long)numberRows];
    
    // SQL
    NSString* sql = [self convertSmartSql: querySpec.smartSql withDb:db];
    NSString* limitSql = [[NSArray arrayWithObjects:@"SELECT * FROM (", sql, @") LIMIT ", limit, nil] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nlimitSql:%@ \npageIndex:%d \n", limitSql, pageIndex];
    
    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [db executeQuery:limitSql withArgumentsInArray:args];
    while ([frs next]) {
        // Smart queries
        if (querySpec.queryType == kSFSoupQueryTypeSmart) {
            [result addObject:[self getDataFromRow:frs]];
        }
        // Exact/like/range queries
        else {
            NSString *rawJson = [frs stringForColumn:SOUP_COL];
            [result addObject:[SFJsonUtils objectFromJSONString:rawJson]];
        }
    }
    [frs close];
    
    return result;
}

- (NSArray *) getDataFromRow:(FMResultSet*) frs
{
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:frs.columnCount];
    NSDictionary* valuesMap = [frs resultDictionary];
    for(int i=0; i<frs.columnCount; i++) {
        NSString* columnName = [frs columnNameForIndex:i];
        id value = [valuesMap objectForKey:columnName];
        if ([columnName hasSuffix:SOUP_COL]) {
            [result addObject:[SFJsonUtils objectFromJSONString:(NSString*)value]];
        }
        else {
            [result addObject:value];
        }
    }
    return result;
}

- (SFStoreCursor *)queryWithQuerySpec:(NSDictionary *)spec  withSoupName:(NSString*)targetSoupName
{
    __block SFStoreCursor* result;
    [self.storeQueue inDatabase:^(FMDatabase*  db) {
        result = [self queryWithQuerySpec:spec withSoupName:targetSoupName withDb:db];
    }];
    return result;
}

- (SFStoreCursor *)queryWithQuerySpec:(NSDictionary *)spec  withSoupName:(NSString*)targetSoupName withDb:(FMDatabase*)db
{
    SFQuerySpec *querySpec = [[SFQuerySpec alloc] initWithDictionary:spec withSoupName:targetSoupName];
    if (nil == querySpec) {
        // Problem already logged
        return nil;
    }
    
    NSString* sql = [self convertSmartSql:querySpec.smartSql withDb:db];
    if (nil == sql) {
        // Problem already logged
        return nil;
    }
    
    NSUInteger totalEntries = [self  countWithQuerySpec:querySpec withDb:db];
    NSArray* firstPageEntries = (totalEntries > 0
                                 ? [self queryWithQuerySpec:querySpec pageIndex:0 withDb:db]
                                 : [NSArray array]);
    SFStoreCursor *result = [[SFStoreCursor alloc] initWithStore:self querySpec:querySpec totalEntries:totalEntries firstPageEntries:firstPageEntries];
    
    return result;
}


- (NSString *)soupEntryIdsPredicate:(NSArray *)soupEntryIds
{
    NSString *allIds = [soupEntryIds componentsJoinedByString:@","];
    NSString *pred = [NSString stringWithFormat:@"%@ IN (%@) ",ID_COL,allIds];
    return pred;
}


- (NSArray *)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    __block NSArray* result;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        result = [self retrieveEntries:soupEntryIds fromSoup:soupName withDb:db];
    }];
    return result;
}

- (NSArray *)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    NSMutableArray *result = [NSMutableArray array]; //empty result array by default
    
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    if (nil == soupTableName) {
        [self log:SFLogLevelDebug format:@"Soup: '%@' does not exist",soupName];
        return result;
    }
    
    NSString *pred = [self soupEntryIdsPredicate:soupEntryIds];
    NSString *querySql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
                          SOUP_COL,soupTableName,pred];
    FMResultSet *frs = [db executeQuery:querySql];
    
    while([frs next]) {
        NSString *rawJson = [frs stringForColumn:SOUP_COL];
        //TODO this is pretty inefficient...we read json from db then reconvert to NSDictionary, then reconvert again in cordova
        NSDictionary *entry = [SFJsonUtils objectFromJSONString:rawJson];
        [result addObject:entry];
    }
    [frs close];
    
    return result;
}



- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices withDb:(FMDatabase*) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    NSMutableDictionary *baseColumns = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        @"", SOUP_COL,
                                        nowVal, CREATED_COL,
                                        nowVal, LAST_MODIFIED_COL,
                                        nil];
    
    //build up the set of index column values for this new row
    for (SFSoupIndex *idx in indices) {
        NSString *indexColVal = [SFJsonUtils projectIntoJson:entry path:[idx path]];
        if (nil != indexColVal) {//not every entry will have a value for each index column
            NSString *colName = [idx columnName];
            [baseColumns setObject:indexColVal forKey:colName];
        }
    }
    
    BOOL insertOk =[self insertIntoTable:soupTableName values:baseColumns withDb:db];
    if (!insertOk) {
        return nil;
    }
    
    //set the newly-calculated entry ID so that our next update will update this entry (and not create a new one)
    NSNumber *newEntryId = [NSNumber numberWithInteger:[db lastInsertRowId]];
    
    //clone the entry so that we can insert the new SOUP_ENTRY_ID into the json
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:newEntryId forKey:SOUP_ENTRY_ID];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    
    //now update the SOUP_COL (raw json) for the soup entry
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    NSArray *binds = [NSArray arrayWithObjects:
                      rawJson,
                      newEntryId,
                      nil];
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?", soupTableName, SOUP_COL, ID_COL];
    //    [self log:SFLogLevelDebug format:@"updateSql: \n %@ \n binds: %@",updateSql,binds];
    
    BOOL updateOk = [db executeUpdate:updateSql withArgumentsInArray:binds];
    if (!updateOk) {
        mutableEntry = nil;
    }
    
    return mutableEntry;
}


- (NSDictionary *)updateOneEntry:(NSDictionary *)entry
                     withEntryId:(NSNumber *)entryId
                     inSoupTable:(NSString *)soupTableName
                         indices:(NSArray *)indices
                          withDb:(FMDatabase *) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    
    NSMutableDictionary *colVals = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    nowVal, LAST_MODIFIED_COL,
                                    nil];
    
    //build up the set of index column values for this row
    for (SFSoupIndex *idx in indices) {
        NSString *indexColVal = [SFJsonUtils projectIntoJson:entry path:[idx path]];
        if (nil != indexColVal) { //not every entry will have a value for each index column
            NSString *colName = [idx columnName];
            [colVals setObject:indexColVal forKey:colName];
        }
    }
    
    //clone the entry so that we can modify SOUP_LAST_MODIFIED_DATE
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    [mutableEntry setValue:entryId forKey:SOUP_ENTRY_ID];
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    [colVals setObject:rawJson forKey:SOUP_COL];
    
    BOOL updateOk =[self updateTable:soupTableName values:colVals entryId:entryId withDb:db];
    if (!updateOk) {
        return nil;
    }
    
    return mutableEntry;
    
}


- (NSDictionary *)upsertOneEntry:(NSDictionary *)entry
                          inSoup:(NSString*)soupName
                         indices:(NSArray*)indices
                   externalIdPath:(NSString *)externalIdPath
                           error:(NSError **)error
                          withDb:(FMDatabase*)db
{
    NSDictionary *result = nil;
    
    // NB: We're assuming soupExists has already been validated on the soup name.  This happens
    // e.g. in upsertEntries:toSoup:withExternalIdPath: .
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    
    NSNumber *soupEntryId = nil;
    if (externalIdPath != nil) {
        if ([externalIdPath isEqualToString:SOUP_ENTRY_ID]) {
            soupEntryId = [entry objectForKey:SOUP_ENTRY_ID];
        } else {
            NSString *fieldValue = [SFJsonUtils projectIntoJson:entry path:externalIdPath];
            if (fieldValue == nil) {
                // Cannot have empty values for user-defined external ID upsert.
                if (error != nil) {
                    *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                                 code:kSFSmartStoreExternalIdNilCode
                                             userInfo:[NSDictionary dictionaryWithObject:kSFSmartStoreExternalIdNilDescription forKey:NSLocalizedDescriptionKey]];
                }
                return nil;
            }
            
            soupEntryId = [self lookupSoupEntryIdForSoupName:soupName
                                               soupTableName:soupTableName
                                                forFieldPath:externalIdPath
                                                  fieldValue:fieldValue
                                                       error:error
                                                      withDb:db];
            if (error != nil && *error != nil) {
                NSString *errorMsg = [NSString stringWithFormat:kSFSmartStoreExtIdLookupError,
                                      externalIdPath, fieldValue, [*error localizedDescription]];
                [self log:SFLogLevelDebug format:@"%@", errorMsg];
                return nil;
            }
        }
    }
    
    if (nil != soupEntryId) {
        //entry already has an entry id: update
        result = [self updateOneEntry:entry withEntryId:soupEntryId inSoupTable:soupTableName indices:indices withDb:db];
    } else {
        //no entry id: insert
        result = [self insertOneEntry:entry inSoupTable:soupTableName indices:indices withDb:db];
    }
    
    return result;
}



- (NSArray *)upsertEntries:(NSArray *)entries toSoup:(NSString *)soupName
{
    // Specific NSError messages are generated exclusively around user-defined external ID logic.
    // Ignore them here, and preserve the interface.
    NSError* error = nil;
    return [self upsertEntries:entries toSoup:soupName withExternalIdPath:SOUP_ENTRY_ID error:&error];
}

- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error
{
    __block NSArray* result;
    [self.storeQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        result = [self upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:error withDb:db];
    }];
    return result;
}

- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error withDb:(FMDatabase*)db
{
    NSMutableArray *result = nil;
    NSString *localExternalIdPath;
    if (externalIdPath != nil)
        localExternalIdPath = externalIdPath;
    else
        localExternalIdPath = SOUP_ENTRY_ID;
    
    if ([self soupExists:soupName withDb:db]) {
        NSArray *indices = [self indicesForSoup:soupName withDb:db];
        
        result = [NSMutableArray array]; //empty result array by default
        BOOL upsertSuccess = YES;
        for (NSDictionary *entry in entries) {
            NSError *localError = nil;
            NSDictionary *upsertedEntry = [self upsertOneEntry:entry inSoup:soupName indices:indices externalIdPath:localExternalIdPath error:&localError withDb:db];
            if (nil != upsertedEntry && localError == nil) {
                [result addObject:upsertedEntry];
            } else {
                if (error != nil) *error = localError;
                upsertSuccess = NO;
                break;
            }
        }
        
        if (!upsertSuccess) {
            [result removeAllObjects];
        }
    }
    
    return result;
}
- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    [self.storeQueue inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeEntries:soupEntryIds fromSoup:soupName withDb:db];
    }];
}

- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    if ([self soupExists:soupName withDb:db]) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *pred = [self soupEntryIdsPredicate:soupEntryIds];
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",
                               soupTableName,pred];
        BOOL ranOK = [db executeUpdate:deleteSql];
        if (!ranOK) {
            [self log:SFLogLevelError format:@"ERROR %d deleting entries: '%@'",
             [db lastErrorCode],
             [db lastErrorMessage]];
        }
    }
    
}

@end
