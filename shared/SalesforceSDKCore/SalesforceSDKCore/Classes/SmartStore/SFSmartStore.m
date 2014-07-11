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
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFKeyStoreManager.h>
#import <SalesforceSecurity/SFEncryptionKey.h>
#import "SFAlterSoupLongOperation.h"
#import "SFUserAccountManager.h"

static NSMutableDictionary *_allSharedStores;
static SFSmartStoreEncryptionKeyBlock _encryptionKeyBlock = NULL;
static BOOL _storeUpgradeHasRun = NO;

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
static NSInteger  const kSFSmartStoreOtherErrorCode             = 999;

// Encryption constants
NSString * const kSFSmartStoreEncryptionKeyLabel = @"com.salesforce.smartstore.encryption.keyLabel";

// Table to keep track of soup names
static NSString *const SOUP_NAMES_TABLE = @"soup_names";

// Table to keep track of soup's index specs
NSString *const SOUP_INDEX_MAP_TABLE = @"soup_index_map";

// Columns of the soup index map table
NSString *const SOUP_NAME_COL = @"soupName";
NSString *const PATH_COL = @"path";
NSString *const COLUMN_NAME_COL = @"columnName";
NSString *const COLUMN_TYPE_COL = @"columnType";

// Columns of a soup table
NSString *const ID_COL = @"id";
NSString *const CREATED_COL = @"created";
NSString *const LAST_MODIFIED_COL = @"lastModified";
NSString *const SOUP_COL = @"soup";

// Table to keep track of status of long operations in flight
NSString *const LONG_OPERATIONS_STATUS_TABLE = @"long_operations_status";

// Columns of long operations status table
NSString *const TYPE_COL = @"type";
NSString *const DETAILS_COL = @"details";
NSString *const STATUS_COL = @"status";

// JSON fields added to soup element on insert/update
NSString *const SOUP_ENTRY_ID = @"_soupEntryId";
NSString *const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";

@implementation SFSmartStore

@synthesize storeQueue = _storeQueue;
@synthesize storeName = _storeName;
@synthesize user = _user;
@synthesize dbMgr = _dbMgr;

+ (void)initialize
{
    if (!_encryptionKeyBlock) {
        _encryptionKeyBlock = ^NSString *{
            SFEncryptionKey *key = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kSFSmartStoreEncryptionKeyLabel autoCreate:YES];
            return [key keyAsString];
        };
    }
}

- (id) initWithName:(NSString*)name user:(SFUserAccount *)user {
    self = [super init];
    
    if (nil != self)  {
        [self log:SFLogLevelDebug format:@"SFSmartStore initWithName: %@, user: %@", name, [SFSmartStoreUtils userKeyForUser:user]];
        
        @synchronized ([SFSmartStore class]) {
            if (!_storeUpgradeHasRun) {
                _storeUpgradeHasRun = YES;
                [SFSmartStoreUpgrade updateStoreLocations];
                [SFSmartStoreUpgrade updateEncryption];
            }
        }
        
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
        
        _soupNameToTableName = [[NSMutableDictionary alloc] init];
        
        _indexSpecsBySoup = [[NSMutableDictionary alloc] init];
        
        _smartSqlToSql = [[NSMutableDictionary alloc] init];
        
        if (![_dbMgr persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                self = nil;
            }
        } else {
            if (![self subsequentTimesStoreDatabaseSetup]) {
                self = nil;
            }
        }
        
        
    }
    return self;
}

- (void)dealloc {
    [self log:SFLogLevelDebug format:@"dealloc store: '%@'",_storeName];
    [self.storeQueue close];
    SFRelease(_soupNameToTableName);
    SFRelease(_indexSpecsBySoup);
    SFRelease(_smartSqlToSql);
    
    //remove data protection observer
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectAvailObserverToken];
    SFRelease(_dataProtectAvailObserverToken);
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectUnavailObserverToken];
    SFRelease(_dataProtectUnavailObserverToken);
}

// Called when first setting up the database
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
                [self.storeQueue close];
                self.storeQueue = nil; // Need to close before setting encryption.
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

// Called when opening a database setup previously
- (BOOL)subsequentTimesStoreDatabaseSetup {

    BOOL result = NO;
    if ([self openStoreDatabase]) {
        // like the onUpgrade for android - create long operations table if needed (if db was created with sdk 2.2 or before)
        [self createLongOperationsStatusTable];
        // like the onOpen for android - running interrupted long operations if any
        [self resumeLongOperations];
        // good to go
        result = YES;
    }
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
    if (_allSharedStores[userKey] == nil) {
        _allSharedStores[userKey] = [NSMutableDictionary dictionary];
    }
    
    SFSmartStore *store = _allSharedStores[userKey][storeName];
    if (nil == store) {
        store = [[self alloc] initWithName:storeName user:user];
        if (store)
            _allSharedStores[userKey][storeName] = store;
    }
    
    return store;
}

+ (void)removeSharedStoreWithName:(NSString *)storeName {
    [self removeSharedStoreWithName:storeName forUser:[SFUserAccountManager sharedInstance].currentUser];
}

+ (void)removeSharedStoreWithName:(NSString*)storeName forUser:(SFUserAccount *)user {
    [self log:SFLogLevelDebug format:@"removeSharedStoreWithName: %@, user: %@", storeName, user];
    NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
    SFSmartStore *existingStore = _allSharedStores[userKey][storeName];
    if (nil != existingStore) {
        [existingStore.storeQueue close];
        [_allSharedStores[userKey] removeObjectForKey:storeName];
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
    NSError* error = nil;
    [self inDatabase:^(FMDatabase* db) {
        [self createMetaTablesWithDb:db];
    } error:&error];
    return !error;
}

- (void)createMetaTablesWithDb:(FMDatabase*) db {
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
    
    
    [self executeUpdateThrows:createSoupIndexTableSql withDb:db];
    [self executeUpdateThrows:createSoupNamesTableSql withDb:db];
    [self createLongOperationsStatusTableWithDb:db];
    [self executeUpdateThrows:createSoupNamesIndexSql withDb:db];
}

- (BOOL)createLongOperationsStatusTable
{
    NSError* error = nil;
    [self inDatabase:^(FMDatabase* db) {
        [self createLongOperationsStatusTableWithDb:db];
    } error:&error];
    return !error;
}


- (void) createLongOperationsStatusTableWithDb:(FMDatabase*)db
{
    // Create SOUP_INDEX_MAP_TABLE
    NSString *createLongOperationsStatusTableSql =
        [NSString stringWithFormat:
            @"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ TEXT, %@ TEXT, %@ INTEGER, %@ INTEGER )",
            LONG_OPERATIONS_STATUS_TABLE,
            ID_COL,
            TYPE_COL,
            DETAILS_COL,
            STATUS_COL,
            CREATED_COL,
            LAST_MODIFIED_COL
         ];
    
    [self log:SFLogLevelDebug format:@"createLongOperationsStatusTableSql: %@",createLongOperationsStatusTableSql];
    [self executeUpdateThrows:createLongOperationsStatusTableSql withDb:db];
}

#pragma mark - Long operations recovery methods

- (void) resumeLongOperations
{
    // TODO call after opening db
    NSArray* longOperations = [self getLongOperations];
    for(SFAlterSoupLongOperation* longOperation in longOperations) {
        [longOperation run];
    }
}

- (NSArray*) getLongOperations
{
    __block NSArray* results;
    [self inDatabase:^(FMDatabase* db) {
        results = [self getLongOperationsWithDb:db];
    } error:nil];
    return results;
}

- (NSArray*) getLongOperationsWithDb:(FMDatabase*)db
{
    NSMutableArray* longOperations = [NSMutableArray array];
    
    // TODO assuming all long operations are alter soup operations
    //      revisit when we introduced another type of long operation
    
    FMResultSet* frs = [self queryTable:LONG_OPERATIONS_STATUS_TABLE forColumns:@[ID_COL, DETAILS_COL, STATUS_COL] orderBy:nil limit:nil whereClause:nil whereArgs:nil withDb:db];
    
    while([frs next]) {
        long rowId = [frs longForColumn:ID_COL];
        NSDictionary *details = [SFJsonUtils objectFromJSONString:[frs stringForColumn:DETAILS_COL]];
        SFAlterSoupStep status = (SFAlterSoupStep)[frs intForColumn:STATUS_COL];
        SFAlterSoupLongOperation *longOperation = [[SFAlterSoupLongOperation alloc] initWithStore:self rowId:rowId details:details status:status];
        [longOperations addObject:longOperation];
    }
    [frs close];
    
    return longOperations;
 }

#pragma mark - Db helper methods
- (FMResultSet*) executeQueryThrows:(NSString*)sql withDb:(FMDatabase*)db {
    FMResultSet* result = [db executeQuery:sql];
    if (!result) {
        [self logAndThrowLastError:[NSString stringWithFormat:@"executeQuery [%@] failed", sql] withDb:db];
    }
    return result;
}

- (FMResultSet*) executeQueryThrows:(NSString*)sql withArgumentsInArray:(NSArray*)arguments withDb:(FMDatabase*)db {
    FMResultSet* result = [db executeQuery:sql withArgumentsInArray:arguments];
    if (!result) {
        [self logAndThrowLastError:[NSString stringWithFormat:@"executeQuery [%@] failed", sql] withDb:db];
    }
    return result;
}

- (void) executeUpdateThrows:(NSString*)sql withDb:(FMDatabase*)db {
    BOOL result = [db executeUpdate:sql];
    if (!result) {
        [self logAndThrowLastError:[NSString stringWithFormat:@"executeUpdate [%@] failed", sql] withDb:db];
    }
}

- (void) executeUpdateThrows:(NSString*)sql withArgumentsInArray:(NSArray*)arguments withDb:(FMDatabase*)db {
    BOOL result = [db executeUpdate:sql withArgumentsInArray:arguments];
    if (!result) {
        [self logAndThrowLastError:[NSString stringWithFormat:@"executeUpdate [%@] failed", sql] withDb:db];
    }
}

- (void) logAndThrowLastError:(NSString*)message  withDb:(FMDatabase*)db {
    
    @throw [NSException exceptionWithName:message reason:[db lastErrorMessage] userInfo:nil];
}

- (void)inDatabase:(void (^)(FMDatabase *db))block error:(NSError**)error
{
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        @try {
            block(db);
        }
        @catch (NSException *exception) {
            if (error != nil) {
                *error = [self errorForException:exception];
            }
        }
    }];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block error:(NSError**)error {
    [self.storeQueue inTransaction:^(FMDatabase* db, BOOL *rollback) {
        @try {
            block(db, rollback);
        }
        @catch (NSException *exception) {
            if (rollback) {
                *rollback = YES;
            }
            if (error != nil) {
                *error = [self errorForException:exception];
            }
        }
    }];
    
}

- (NSError*) errorForException:(NSException*)exception
{
    return [NSError errorWithDomain:kSFSmartStoreErrorDomain
                               code:kSFSmartStoreOtherErrorCode
                           userInfo:@{NSLocalizedDescriptionKey: [exception description]}];
}

#pragma mark - Utility methods

- (NSArray*) allSoupNames
{
    __block NSArray* result;
    [self inDatabase:^(FMDatabase* db) {
        result = [self allSoupNamesWithDb:db];
    } error:nil];
    return result;
}

- (NSArray*) allSoupNamesWithDb:(FMDatabase*) db
{
    NSMutableArray* soupNames = [NSMutableArray array];
    FMResultSet* frs = [self executeQueryThrows:[NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_NAMES_TABLE] withDb:db];
    while ([frs next]) {
        [soupNames addObject:[frs stringForColumnIndex:0]];
    }
    [frs close];
    
    return soupNames;
}

+ (NSString *)encKey
{
    return (_encryptionKeyBlock ? _encryptionKeyBlock() : nil);
}

+ (SFSmartStoreEncryptionKeyBlock)encryptionKeyBlock {
    return _encryptionKeyBlock;
}

+ (void)setEncryptionKeyBlock:(SFSmartStoreEncryptionKeyBlock)newEncryptionKeyBlock {
    if (newEncryptionKeyBlock != _encryptionKeyBlock) {
        _encryptionKeyBlock = newEncryptionKeyBlock;
    }
}

- (NSNumber *)currentTimeInMilliseconds {
    NSTimeInterval rawTime = 1000 * [[NSDate date] timeIntervalSince1970];
    rawTime = floor(rawTime);
    NSNumber *nowVal = @(rawTime);
    return nowVal;
}

- (BOOL)isFileDataProtectionActive {
    return _dataProtectionKnownAvailable;
}

#pragma mark - Data access utility methods

- (void)insertIntoTable:(NSString*)tableName values:(NSDictionary*)map withDb:(FMDatabase *) db {
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
    [self executeUpdateThrows:insertSql withArgumentsInArray:binds withDb:db];
    
}

- (void)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId withDb:(FMDatabase*) db
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
    [self executeUpdateThrows:updateSql withArgumentsInArray:binds withDb:db];
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
    FMResultSet *frs = [self executeQueryThrows:querySql withArgumentsInArray:@[soupName, path] withDb:db];
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
    [self inDatabase:^(FMDatabase* db) {
        result = [self convertSmartSql:smartSql withDb:db];
    } error:nil];
    return result;
}

- (NSString*) convertSmartSql:(NSString*)smartSql withDb:(FMDatabase*)db
{
    [self log:SFLogLevelDebug format:@"convertSmartSQl:%@", smartSql];
    NSObject* sql = _smartSqlToSql[smartSql];
    
    if (nil == sql) {
        sql = [[SFSmartSqlHelper sharedInstance] convertSmartSql:smartSql withStore:self withDb:db];
        
        // Conversion failed, putting the NULL in the cache so that we don't retry conversion
        if (sql == nil) {
            [self log:SFLogLevelDebug format:@"convertSmartSql:putting NULL in cache"];
            _smartSqlToSql[smartSql] = [NSNull null];
        }
        // Updating cache
        else {
            [self log:SFLogLevelDebug format:@"convertSmartSql:putting %@ in cache", sql];
            _smartSqlToSql[smartSql] = sql;
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
    FMResultSet *frs = [self executeQueryThrows:sql withArgumentsInArray:whereArgs withDb:db];
    return frs;
}


#pragma mark - Soup manipulation methods

- (NSString*)tableNameForSoup:(NSString*)soupName withDb:(FMDatabase*) db {
    NSString *soupTableName = _soupNameToTableName[soupName];
    
    if (nil == soupTableName) {
        NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_NAMES_TABLE,SOUP_NAME_COL];
        //    [self log:SFLogLevelDebug format:@"tableName query: %@",sql];
        FMResultSet *frs = [self executeQueryThrows:sql withArgumentsInArray:@[soupName] withDb:db];
        
        if ([frs next]) {
            int colIdx = [frs columnIndexForName:ID_COL];
            long soupId = [frs longForColumnIndex:colIdx];
            soupTableName = [self tableNameBySoupId:soupId];
            
            // update cache
            _soupNameToTableName[soupName] = soupTableName;
        } else {
            [self log:SFLogLevelDebug format:@"No table for: '%@'",soupName];
        }
        [frs close];
    }
    return soupTableName;
}


- (NSString *)tableNameBySoupId:(long)soupId {
    return [NSString stringWithFormat:@"TABLE_%ld",soupId];
}

- (NSArray *)tableNamesForAllSoupsWithDb:(FMDatabase*) db{
    NSMutableArray* result = [NSMutableArray array]; // equivalent to: [[[NSMutableArray alloc] init] autorelease]
    NSString* sql = [NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_NAMES_TABLE];
    FMResultSet *frs = [self executeQueryThrows:sql withDb:db];
    while ([frs next]) {
        NSString* tableName = [frs stringForColumn:SOUP_NAME_COL];
        [result addObject:tableName];
    }
    
    [frs close];
    return result;
}

- (NSArray*)indicesForSoup:(NSString*)soupName {
    __block NSArray* result;
    [self inDatabase:^(FMDatabase * db) {
        result = [self indicesForSoup:soupName withDb:db];
    } error:nil];
    return result;
}

- (NSArray*)indicesForSoup:(NSString*)soupName withDb:(FMDatabase *)db {
    //look in the cache first
    NSMutableArray *result = _indexSpecsBySoup[soupName];
    if (nil == result) {
        result = [NSMutableArray array];
        
        //no cached indices ...reload from SOUP_INDEX_MAP_TABLE
        NSString *querySql = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@ = ?",
                              PATH_COL, COLUMN_NAME_COL, COLUMN_TYPE_COL,
                              SOUP_INDEX_MAP_TABLE,
                              SOUP_NAME_COL];
        [self log:SFLogLevelDebug format:@"indices sql: %@",querySql];
        FMResultSet *frs = [self executeQueryThrows:querySql withArgumentsInArray:@[soupName] withDb:db];
        
        while([frs next]) {
            NSString *path = [frs stringForColumn:PATH_COL];
            NSString *columnName = [frs stringForColumn:COLUMN_NAME_COL];
            NSString *type = [frs stringForColumn:COLUMN_TYPE_COL];
            
            SFSoupIndex *spec = [[SFSoupIndex alloc] initWithPath:path indexType:type columnName:columnName];
            [result addObject:spec];
        }
        [frs close];
        
        //update the cache
        _indexSpecsBySoup[soupName] = result;
    }
    
    if (!(result.count > 0)) {
        [self log:SFLogLevelDebug format:@"no indices for '%@'",soupName];
    }
    return result;
}

- (BOOL)soupExists:(NSString*)soupName {
    __block BOOL result;
    [self inDatabase:^(FMDatabase* db) {
        result = [self soupExists:soupName withDb:db];
    } error:nil];
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


- (void)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts withDb:(FMDatabase*)db {
    // update the mapping table for this soup's columns
    for (NSDictionary *map in soupIndexMapInserts) {
        [self insertIntoTable:SOUP_INDEX_MAP_TABLE values:map withDb:db];
    }
}

- (NSString *)registerNewSoupName:(NSString*)soupName withDb:(FMDatabase*) db {
    NSString *soupTableName = nil;
    
    //Get a safe table name for the soupName
    NSDictionary *soupMapValues = @{SOUP_NAME_COL: soupName};
    
    [self insertIntoTable:SOUP_NAMES_TABLE values:soupMapValues withDb:db];
    soupTableName = [self tableNameBySoupId:[db lastInsertRowId]];
    
    if (nil == soupTableName) {
        [self log:SFLogLevelDebug format:@"couldn't properly register soupName: '%@' ",soupName];
    }
    
    return soupTableName;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs {
    NSError* error = nil;
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self registerSoup:soupName withIndexSpecs:indexSpecs withDb:db];
    } error:&error];
    return !error;
}

- (void)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs withDb:(FMDatabase*) db
{
    [self registerSoup:soupName withIndexSpecs:indexSpecs withSoupTableName:nil withDb:db];
}

- (void)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs withSoupTableName:(NSString*) soupTableName withDb:(FMDatabase*) db
{
    //verify soupName
    if (!([soupName length] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus soupName" reason:soupName userInfo:nil];
    }
    //verify indexSpecs
    if (!([indexSpecs count] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus indexSpecs" reason:nil userInfo:nil];
    }
    
    // If soup with soupName already exists, just return success.
    if ([self soupExists:soupName withDb:db]) {
        return;
    }
    
    if (nil == soupTableName) {
        soupTableName = [self registerNewSoupName:soupName withDb:db];
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
        SFSoupIndex *indexSpec = (SFSoupIndex*) indexSpecs[i];
        
        // for creating the soup table itself in the store db
        NSString *columnName = [NSString stringWithFormat:@"%@_%lu",soupTableName,(unsigned long)i];
        NSString * columnType = [indexSpec columnType];
        [createTableStmt appendFormat:@", %@ %@ ",columnName,columnType];
        [self log:SFLogLevelDebug format:@"adding indexPath: %@ %@  ('%@')",columnName, columnType, [indexSpec path]];
        
        // for inserting into meta mapping table
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init ];
        values[SOUP_NAME_COL] = soupName;
        values[PATH_COL] = indexSpec.path;
        values[COLUMN_NAME_COL] = columnName;
        values[COLUMN_TYPE_COL] = indexSpec.indexType;
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
    [self  executeUpdateThrows:createTableStmt withDb:db];
    // create indices for this soup
    for (NSString *createIndexStmt in createIndexStmts) {
        [self log:SFLogLevelDebug format:@"createIndexStmt: %@",createIndexStmt];
        [self executeUpdateThrows:createIndexStmt withDb:db];
    }
    [self insertIntoSoupIndexMap:soupIndexMapInserts withDb:db];
}

- (void)removeSoup:(NSString*)soupName {
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeSoup:soupName withDb:db];
    } error:nil];
}

- (void)removeSoup:(NSString*)soupName withDb:(FMDatabase*)db {
    [self log:SFLogLevelDebug format:@"removeSoup: %@", soupName];
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    if (nil == soupTableName)
        return;
    
    NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",soupTableName];
    [self executeUpdateThrows:dropSql withDb:db];
    
    NSString *deleteIndexSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                                SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, soupName];
    [self executeUpdateThrows:deleteIndexSql withDb:db];
    NSString *deleteNameSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                               SOUP_NAMES_TABLE, SOUP_NAME_COL, soupName];
    [self executeUpdateThrows:deleteNameSql withDb:db];
    
    [_indexSpecsBySoup removeObjectForKey:soupName ];
    
    // Cleanup _smartSqlToSql
    NSString* soupRef = [@[@"{", soupName, @"}"] componentsJoinedByString:@""];
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
    [self inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [self removeAllSoupWithDb:db];
    } error:nil];
}

- (void)removeFromCache:(NSString*) soupName {
    [_indexSpecsBySoup removeObjectForKey:soupName ];
    
    // Cleanup _smartSqlToSql
    NSString* soupRef = [@[@"{", soupName, @"}"] componentsJoinedByString:@""];
    NSMutableArray* keysToRemove = [NSMutableArray array];
    for (NSString* smartSql in [_smartSqlToSql allKeys]) {
        if ([smartSql rangeOfString:soupRef].location != NSNotFound) {
            [keysToRemove addObject:smartSql];
            [self log:SFLogLevelDebug format:@"removeSoup: removing cached sql for %@", smartSql];
        }
    }
    [_smartSqlToSql removeObjectsForKeys:keysToRemove];
    
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
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
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
                            forColumns:@[ID_COL]
                               orderBy:nil
                                 limit:nil
                           whereClause:whereClause
                             whereArgs:(fieldValue != nil ? @[fieldValue] : nil)
                                withDb:db];
    NSNumber *returnId = nil;
    if ([rs next]) {
        returnId = @([rs intForColumn:ID_COL]);
        if ([rs next]) {
            // Shouldn't be more than one value; that's an error.
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreTooManyEntriesDescription,
                                   (fieldValue != nil ? fieldValue : @"NULL"),
                                   fieldPath];
            if (error != nil) {
                *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                             code:kSFSmartStoreTooManyEntriesCode
                                         userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
            }
            returnId = nil;
        }
    }
    [rs close];
    
    return returnId;
}

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec error:(NSError **)error;
{
    __block NSInteger result;
    [self inDatabase:^(FMDatabase* db) {
        result = [self countWithQuerySpec:querySpec withDb:db];
    } error:error];
    return result;
}

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec withDb:(FMDatabase*)db
{
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSUInteger result = 0;
    
    // SQL
    NSString* countSql = [self convertSmartSql:querySpec.countSmartSql withDb:db];
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: countSql:%@ \n", countSql];

    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [self executeQueryThrows:countSql withArgumentsInArray:args withDb:db];
    if([frs next]) {
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
    return result;
}

- (NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error;
{
    __block NSArray* result;
    [self inDatabase:^(FMDatabase* db) {
        result = [self queryWithQuerySpec:querySpec pageIndex:pageIndex withDb:db];
    } error:error];
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
    NSString* limitSql = [@[@"SELECT * FROM (", sql, @") LIMIT ", limit] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nlimitSql:%@ \npageIndex:%d \n", limitSql, pageIndex];
    
    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [self executeQueryThrows:limitSql withArgumentsInArray:args withDb:db];
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
        id value = valuesMap[columnName];
        if ([columnName hasSuffix:SOUP_COL]) {
            [result addObject:[SFJsonUtils objectFromJSONString:(NSString*)value]];
        }
        else {
            [result addObject:value];
        }
    }
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
    [self inDatabase:^(FMDatabase* db) {
        result = [self retrieveEntries:soupEntryIds fromSoup:soupName withDb:db];
    } error:nil];
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
    FMResultSet *frs = [self executeQueryThrows:querySql withDb:db];
    
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
            baseColumns[colName] = indexColVal;
        }
    }
    
    [self insertIntoTable:soupTableName values:baseColumns withDb:db];
    
    //set the newly-calculated entry ID so that our next update will update this entry (and not create a new one)
    NSNumber *newEntryId = [NSNumber numberWithInteger:[db lastInsertRowId]];
    
    //clone the entry so that we can insert the new SOUP_ENTRY_ID into the json
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:newEntryId forKey:SOUP_ENTRY_ID];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    
    //now update the SOUP_COL (raw json) for the soup entry
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    NSArray *binds = @[rawJson,
                      newEntryId];
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?", soupTableName, SOUP_COL, ID_COL];
    //    [self log:SFLogLevelDebug format:@"updateSql: \n %@ \n binds: %@",updateSql,binds];
    
    [self executeUpdateThrows:updateSql withArgumentsInArray:binds withDb:db];
    
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
            colVals[colName] = indexColVal;
        }
    }
    
    //clone the entry so that we can modify SOUP_LAST_MODIFIED_DATE
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    [mutableEntry setValue:entryId forKey:SOUP_ENTRY_ID];
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    colVals[SOUP_COL] = rawJson;
    [self updateTable:soupTableName values:colVals entryId:entryId withDb:db];
    
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
            soupEntryId = entry[SOUP_ENTRY_ID];
        } else {
            NSString *fieldValue = [SFJsonUtils projectIntoJson:entry path:externalIdPath];
            if (fieldValue == nil) {
                // Cannot have empty values for user-defined external ID upsert.
                if (error != nil) {
                    *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                                 code:kSFSmartStoreExternalIdNilCode
                                             userInfo:@{NSLocalizedDescriptionKey: kSFSmartStoreExternalIdNilDescription}];
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
    return [self upsertEntries:entries toSoup:soupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
}

- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error
{
    __block NSArray* result;
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        result = [self upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:error withDb:db];
    } error:error];
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
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeEntries:soupEntryIds fromSoup:soupName withDb:db];
    } error:nil];
}

- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    if ([self soupExists:soupName withDb:db]) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *pred = [self soupEntryIdsPredicate:soupEntryIds];
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",
                               soupTableName,pred];
        [self executeUpdateThrows:deleteSql withDb:db];
    }
}

- (void)clearSoup:(NSString*)soupName
{
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self clearSoup:soupName withDb:db];
    } error:nil];

}

- (void)clearSoup:(NSString*)soupName withDb:(FMDatabase*)db
{
    if ([self soupExists:soupName withDb:db]) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@", soupTableName];
        [self executeUpdateThrows:deleteSql withDb:db];
    }
}

- (long)getDatabaseSize
{
    NSString *dbPath = [[SFSmartStoreDatabaseManager sharedManager] fullDbFilePathForStoreName:_storeName];
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:dbPath error:nil] fileSize];
}

- (BOOL) alterSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs reIndexData:(BOOL)reIndexData
{
    if ([self soupExists:soupName]) {
        SFAlterSoupLongOperation* operation = [[SFAlterSoupLongOperation alloc] initWithStore:self soupName:soupName newIndexSpecs:indexSpecs reIndexData:reIndexData];
        [operation run];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) reIndexSoup:(NSString*)soupName withIndexPaths:(NSArray*)indexPaths
{
    __block BOOL result;
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        result = [self reIndexSoup:soupName withIndexPaths:indexPaths withDb:db];
    } error:nil];
    return result;
}

- (BOOL) reIndexSoup:(NSString*)soupName withIndexPaths:(NSArray*)indexPaths withDb:(FMDatabase*)db
{
    if ([self soupExists:soupName withDb:db]) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSDictionary *mapIndexSpecs = [SFSoupIndex mapForSoupIndexes:[self indicesForSoup:soupName withDb:db]];

        FMResultSet* frs = [self queryTable:soupTableName forColumns:@[ID_COL, SOUP_COL] orderBy:nil limit:nil whereClause:nil whereArgs:nil withDb:db];
    
        while([frs next]) {
            NSNumber *entryId = @([frs longForColumn:ID_COL]);
            NSString *soupElt = [frs stringForColumn:SOUP_COL];
            NSDictionary *entry = [SFJsonUtils objectFromJSONString:soupElt];
            NSMutableDictionary *colVals = [NSMutableDictionary dictionary];
            //build up the set of index column values for this row
            for (NSString *indexPath in indexPaths) {
                SFSoupIndex *idx = mapIndexSpecs[indexPath];
                NSString *indexColVal = [SFJsonUtils projectIntoJson:entry path:idx.path];
                if (nil != indexColVal) { //not every entry will have a value for each index column
                    NSString *colName = [idx columnName];
                    colVals[colName] = indexColVal;
                }
            }
            if ([colVals count] > 0)
                [self updateTable:soupTableName values:colVals entryId:entryId withDb:db];
        }
        return YES;
    }
    else {
        return NO;
    }
}


@end
