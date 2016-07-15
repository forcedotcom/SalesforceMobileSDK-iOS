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

//required for UIApplicationProtectedDataDidBecomeAvailable
#import <UIKit/UIKit.h>
#import "sqlite3.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFSmartStore+Internal.h"
#import "SFSmartStoreUpgrade.h"
#import "SFSmartStoreUtils.h"
#import "SFSmartSqlHelper.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import "SFSoupSpec.h"
#import "SFSoupSpec+Internal.h"
#import <SalesforceSDKCore/SFPasscodeManager.h>
#import <SalesforceSDKCore/SFKeyStoreManager.h>
#import <SalesforceSDKCore/SFEncryptionKey.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCore/SFEncryptStream.h>
#import <SalesforceSDKCore/SFDecryptStream.h>
#import "SFAlterSoupLongOperation.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>

static NSMutableDictionary *_allSharedStores;
static NSMutableDictionary *_allGlobalSharedStores;
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

// Table to keep track of soup attributes
static NSString *const SOUP_ATTRS_TABLE = @"soup_attrs";
static NSString *const SOUP_NAMES_TABLE = @"soup_names"; //legacy soup attrs, still around for backward compatibility. Do not use it.

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

// Columns of a soup fts table
NSString *const ROWID_COL = @"rowid";

// Table to keep track of status of long operations in flight
NSString *const LONG_OPERATIONS_STATUS_TABLE = @"long_operations_status";

// Columns of long operations status table
NSString *const TYPE_COL = @"type";
NSString *const DETAILS_COL = @"details";
NSString *const STATUS_COL = @"status";

// JSON fields added to soup element on insert/update
NSString *const SOUP_ENTRY_ID = @"_soupEntryId";
NSString *const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";

// Explain support
NSString *const EXPLAIN_SQL = @"sql";
NSString *const EXPLAIN_ARGS = @"args";
NSString *const EXPLAIN_ROWS = @"rows";

@implementation SFSmartStore

+ (void)initialize
{
    if (!_encryptionKeyBlock) {
        _encryptionKeyBlock = ^SFEncryptionKey *{
            SFEncryptionKey *key = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kSFSmartStoreEncryptionKeyLabel autoCreate:YES];
            return key;
        };
    }
}

- (id)initWithName:(NSString *)name user:(SFUserAccount *)user {
    return [self initWithName:name user:user isGlobal:NO];
}

- (id) initWithName:(NSString*)name user:(SFUserAccount *)user isGlobal:(BOOL)isGlobal {
    self = [super init];
    if (self)  {
        if ((user == nil || [user.accountIdentity isEqual:[SFUserAccountManager sharedInstance].temporaryUserIdentity]) && !isGlobal) {
            [self log:SFLogLevelWarning format:@"%@ Cannot create SmartStore with name '%@': user is not configured, and isGlobal is not configured.  Did you mean to call [%@ sharedGlobalStoreWithName:]?",
             NSStringFromSelector(_cmd),
             name,
             NSStringFromClass([self class])];
            return nil;
        }
        
        [self log:SFLogLevelDebug format:@"%@ %@, user: %@, isGlobal: %d", NSStringFromSelector(_cmd), name, [SFSmartStoreUtils userKeyForUser:user], isGlobal];
        
        @synchronized ([SFSmartStore class]) {
            if ([SFUserAccountManager sharedInstance].currentUser != nil && !_storeUpgradeHasRun) {
                _storeUpgradeHasRun = YES;
                [SFSmartStoreUpgrade updateStoreLocations];
                [SFSmartStoreUpgrade updateEncryption];
            }
        }
        
        _storeName = name;
        _isGlobal = isGlobal;
        _user = user;
        
        if (_isGlobal) {
            _dbMgr = [SFSmartStoreDatabaseManager sharedGlobalManager];
        } else {
            _dbMgr = [SFSmartStoreDatabaseManager sharedManagerForUser:_user];
        }
        
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
        _attrSpecBySoup = [[NSMutableDictionary alloc] init];
        _indexSpecsBySoup = [[NSMutableDictionary alloc] init];
        
        _smartSqlToSql = [[NSMutableDictionary alloc] init];
        
        // Using FTS5 by default
        _ftsExtension = SFSmartStoreFTS5;
        
        if (![_dbMgr persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                self = nil;
            }
        } else {
            if (![self subsequentTimesStoreDatabaseSetup]) {
                self = nil;
            }
        }
        
        // Register features in soup attributes table.
        [self registerNewSoupAttribute:kSoupFeatureExternalStorage];
    }
    return self;
}

- (void)dealloc {
    [self log:SFLogLevelDebug format:@"dealloc store: '%@'",_storeName];
    [self.storeQueue close];
    SFRelease(_soupNameToTableName);
    SFRelease(_attrSpecBySoup);
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

    // Ensure that the store directory exists.
    result = [self.dbMgr createStoreDir:self.storeName];

    // Need to create the db file itself before we can protect it.
    result = result && [self openStoreDatabase] && [self createMetaTables];

    // Need to close before protecting db file
    if (result) {
        [self.storeQueue close];
        self.storeQueue = nil;
        result = [self.dbMgr protectStoreDirIfNeeded:self.storeName protection:NSFileProtectionCompleteUntilFirstUserAuthentication];
    }

    //Reopen the storeDb now that it's protected
    result = result && [self openStoreDatabase];

    // Delete db file if its setup was not successful
    if (!result) {
        [self log:SFLogLevelError format:@"Deleting store dir since we can't set it up properly: %@", self.storeName];
        [self.dbMgr removeStoreDir:self.storeName];
    }
    
    if (self.user != nil) {
        [SFSmartStoreUpgrade setUsesKeyStoreEncryption:result forUser:self.user store:self.storeName];
    }
    
    return result;
}

// Called when opening a database setup previously
- (BOOL)subsequentTimesStoreDatabaseSetup {
    BOOL result = NO;
    
    // Adjusting filesystem protection if needed
    result = [self.dbMgr protectStoreDirIfNeeded:self.storeName protection:NSFileProtectionCompleteUntilFirstUserAuthentication];
    
    // Open db file
    result = result && [self openStoreDatabase];

    // Do any upgrade needed
    if (result) {
        // like the onUpgrade for android - create long operations table if needed (if db was created with sdk 2.2 or before)
        [self createLongOperationsStatusTable];
        // like the onOpen for android - running interrupted long operations if any
        [self resumeLongOperations];
        // upgrade legacy soup_attrs table
        [self upgradeRenameTableSoupNamesToSoupAttrs];
    }

    return result;
}

- (BOOL) openStoreDatabase {
   NSError *openDbError = nil;
    self.storeQueue = [self.dbMgr openStoreQueueWithName:self.storeName key:[[self class] encKey] error:&openDbError];
    if (self.storeQueue == nil) {
        [self log:SFLogLevelError format:@"Error opening store '%@': %@", self.storeName, [openDbError localizedDescription]];
    }
    
    return (self.storeQueue != nil);
}

- (NSString *)storePath {
    if (self.storeName.length == 0)
        return nil;
    
    return [self.dbMgr fullDbFilePathForStoreName:self.storeName];
}

#pragma mark - Store methods

+ (id)sharedStoreWithName:(NSString *)storeName {
    @synchronized (self) {
        return [self sharedStoreWithName:storeName user:[SFUserAccountManager sharedInstance].currentUser];
    }
}

+ (id)sharedStoreWithName:(NSString*)storeName user:(SFUserAccount *)user {
    @synchronized (self) {
        if (user == nil) {
            [SFLogger log:self level:SFLogLevelWarning format:@"%@ Cannot create shared store with name '%@' for nil user.  Did you mean to call [%@ sharedGlobalStoreWithName:]?", NSStringFromSelector(_cmd), storeName, NSStringFromClass(self)];
            return nil;
        }
        
        if (nil == _allSharedStores) {
            _allSharedStores = [NSMutableDictionary dictionary];
        }
        NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
        if (!userKey) {
            // if user key is nil for any reason, return nil directly here otherwise app will crash with nil userKey
            return nil;
        }
        
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
}

+ (id)sharedGlobalStoreWithName:(NSString *)storeName {
    @synchronized (self) {
        if (nil == _allGlobalSharedStores) {
            _allGlobalSharedStores = [NSMutableDictionary dictionary];
        }

        SFSmartStore *store = _allGlobalSharedStores[storeName];
        if (nil == store) {
            store = [[self alloc] initWithName:storeName user:nil isGlobal:YES];
            if (store)
                _allGlobalSharedStores[storeName] = store;
        }
        
        return store;
    }
}

+ (void)removeSharedStoreWithName:(NSString *)storeName {
    @synchronized (self) {
        [self removeSharedStoreWithName:storeName forUser:[SFUserAccountManager sharedInstance].currentUser];
    }
}

+ (void)removeSharedStoreWithName:(NSString*)storeName forUser:(SFUserAccount *)user {
    @synchronized (self) {
        if (user == nil) {
            [SFLogger log:self level:SFLogLevelInfo format:@"%@ Cannot remove store with name '%@' for nil user.  Did you mean to call [%@ removeSharedGlobalStoreWithName:]?", NSStringFromSelector(_cmd), storeName, NSStringFromClass(self)];
            return;
        }
        
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
}

+ (void)removeSharedGlobalStoreWithName:(NSString *)storeName {
    @synchronized (self) {
        [SFLogger log:self level:SFLogLevelDebug format:@"%@ %@", NSStringFromSelector(_cmd), storeName];
        SFSmartStore *existingStore = _allGlobalSharedStores[storeName];
        if (nil != existingStore) {
            [existingStore.storeQueue close];
            [_allGlobalSharedStores removeObjectForKey:storeName];
        }
        [[SFSmartStoreDatabaseManager sharedGlobalManager] removeStoreDir:storeName];
    }
}

+ (void)removeAllStores {
    @synchronized (self) {
        [self removeAllStoresForUser:[SFUserAccountManager sharedInstance].currentUser];
    }
}

+ (void)removeAllStoresForUser:(SFUserAccount *)user {
    @synchronized (self) {
        if (user == nil) {
            [SFLogger log:self level:SFLogLevelInfo format:@"%@ Cannot remove all stores for nil user.  Did you mean to call [%@ removeAllGlobalStores]?", NSStringFromSelector(_cmd), NSStringFromClass(self)];
            return;
        }
        
        NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManagerForUser:user] allStoreNames];
        for (NSString *storeName in allStoreNames) {
            [self removeSharedStoreWithName:storeName forUser:user];
        }
        [SFSmartStoreDatabaseManager removeSharedManagerForUser:user];
    }
}

+ (void)removeAllGlobalStores {
    @synchronized (self) {
        NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedGlobalManager] allStoreNames];
        for (NSString *storeName in allStoreNames) {
            [self removeSharedGlobalStoreWithName:storeName];
        }
    }
}

+ (void)clearSharedStoreMemoryState
{
    @synchronized (self) {
        [_allSharedStores removeAllObjects];
        [_allGlobalSharedStores removeAllObjects];
    }
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
    
    
    // Create SOUP_ATTRS_TABLE
    // The table name for the soup will simply be TABLE_<soupId>
    NSString *createSoupNamesTableSql = [NSString stringWithFormat:
                                         @"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT )",
                                         SOUP_ATTRS_TABLE,
                                         ID_COL,
                                         SOUP_NAME_COL
                                         ];
    
    
    [self log:SFLogLevelDebug format:@"createSoupNamesTableSql: %@",createSoupNamesTableSql];
    
    // Create an index for SOUP_NAME_COL in SOUP_ATTRS_TABLE
    NSString *createSoupNamesIndexSql = [NSString stringWithFormat:
                                         @"CREATE INDEX %@_0 on %@ ( %@ )",
                                         SOUP_ATTRS_TABLE, SOUP_ATTRS_TABLE, SOUP_NAME_COL];
    [self log:SFLogLevelDebug format:@"createSoupNamesIndexSql: %@",createSoupNamesIndexSql];
    
    
    [self executeUpdateThrows:createSoupIndexTableSql withDb:db];
    [self executeUpdateThrows:createSoupNamesTableSql withDb:db];
    [self createLongOperationsStatusTableWithDb:db];
    [self executeUpdateThrows:createSoupNamesIndexSql withDb:db];
}

- (void)registerNewSoupAttribute:(NSString *)attrColName
{
    [self inDatabase:^(FMDatabase *db) {
        if (![db columnExists:attrColName inTableWithName:SOUP_ATTRS_TABLE]) {
            // Add column attrColName in SOUP_ATTRS_TABLE
            NSString *addAttrColSql = [NSString stringWithFormat:
                                          @"ALTER TABLE %@ ADD COLUMN %@ INTEGER DEFAULT 0",
                                          SOUP_ATTRS_TABLE,
                                          attrColName
                                          ];
            
            [self log:SFLogLevelDebug format:@"addAttrColSql: %@",addAttrColSql];
            [self executeUpdateThrows:addAttrColSql withDb:db];
        }
    } error:nil];
}

- (NSArray *)registeredSoupFeaturesWithDb:(FMDatabase*)db
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    FMResultSet *attrsSchema = [db getTableSchema:SOUP_ATTRS_TABLE];
    while ([attrsSchema next]) {
        NSString *col = [attrsSchema stringForColumn:@"name"];
        if (![col isEqualToString:ID_COL] && ![col isEqualToString:SOUP_NAME_COL]) {
            [result addObject:col];
        }
    }
    [attrsSchema close];
    return result;
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
    if (self.captureExplainQueryPlan) {
        NSString* explainSql = [NSString stringWithFormat:@"EXPLAIN QUERY PLAN %@", sql];
        NSMutableDictionary* lastPlan = [NSMutableDictionary new];
        lastPlan[EXPLAIN_SQL] = explainSql;
        if (arguments.count > 0) lastPlan[EXPLAIN_ARGS] = arguments;
        NSMutableArray* explainRows = [NSMutableArray new];
        
        FMResultSet* frs = [db executeQuery:explainSql withArgumentsInArray:arguments];
        while ([frs next]) {
            NSMutableDictionary* explainRow = [NSMutableDictionary new];
            for (int i=0; i<frs.columnCount; i++) {
                explainRow[[frs columnNameForIndex:i]] = [frs stringForColumnIndex:i];
            }
            [explainRows addObject:explainRow];
        }
        [frs close];
        lastPlan[EXPLAIN_ROWS] = explainRows;
        self.lastExplainQueryPlan = lastPlan;
    }
    
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
    FMResultSet* frs = [self executeQueryThrows:[NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_ATTRS_TABLE] withDb:db];
    while ([frs next]) {
        [soupNames addObject:[frs stringForColumnIndex:0]];
    }
    [frs close];
    
    return soupNames;
}

+ (NSString *)encKey
{
    if (_encryptionKeyBlock) {
        SFEncryptionKey *key = _encryptionKeyBlock();
        return key.keyAsString;
    }
    return nil;
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

+ (NSDate *)dateFromLastModifiedValue:(NSNumber *)lastModifiedValue {
    NSTimeInterval lastModifiedSecs = [lastModifiedValue doubleValue] / 1000.0;
    NSDate *retDate = [[NSDate alloc] initWithTimeIntervalSince1970:lastModifiedSecs];
    return retDate;
}

- (BOOL)isFileDataProtectionActive {
    return _dataProtectionKnownAvailable;
}

#pragma mark - External Storage utility methods

- (NSString *)externalStorageRootDirectory {
    return [[self.storePath stringByDeletingPathExtension] stringByAppendingString:@"_external_soup_blobs"];
}

- (NSString *)externalStorageSoupDirectory:(NSString *)soupTableName {
    NSString *rootDir = [self externalStorageRootDirectory];
    return [rootDir stringByAppendingPathComponent:soupTableName];
}

- (NSString *)externalStorageSoupFilePath:(NSNumber *)soupEntryId
                            soupTableName:(NSString *)soupTableName {
    NSString *soupDir = [self externalStorageSoupDirectory:soupTableName];
    return [soupDir stringByAppendingPathComponent:[NSString stringWithFormat:@"soupelt_%@", soupEntryId]];
}

- (BOOL)createExternalStorageDirectory:(NSString *)soupTableName {
    NSError *error = nil;
    NSString *dir = [self externalStorageSoupDirectory:soupTableName];
    BOOL dirExists = [SFDirectoryManager ensureDirectoryExists:dir error:&error];
    if (!dirExists) {
        [self log:SFLogLevelError format:@"Failed to create external storage directory at path '%@', error: %@", dir, error];
    }
    return dirExists;
}

- (BOOL)saveSoupEntryExternally:(NSDictionary *)soupEntry
                    soupEntryId:(NSNumber *)soupEntryId
                  soupTableName:(NSString *)soupTableName {
    NSString *filePath = [self externalStorageSoupFilePath:soupEntryId
                                             soupTableName:soupTableName];
    NSOutputStream *outputStream = nil;
    SFSmartStoreEncryptionKeyBlock keyBlock = [SFSmartStore encryptionKeyBlock];
    if (keyBlock) {
        SFEncryptStream *encryptStream = [[SFEncryptStream alloc] initToFileAtPath:filePath append:NO];
        [encryptStream setupWithKey:keyBlock().key andInitializationVector:nil];
        outputStream = encryptStream;
    } else {
        outputStream = [[NSOutputStream alloc] initToFileAtPath:filePath append:NO];
    }
    [outputStream open];
    NSError *error = nil;
    BOOL success = [NSJSONSerialization writeJSONObject:soupEntry
                                               toStream:outputStream
                                                options:0
                                                  error:&error];
    [outputStream close];
    if (!success) {
        NSString *errorMessage = [NSString stringWithFormat:@"Saving external soup to file failed! encrypted: %@, soupEntryId: %@, soupTableName: %@, filePath: '%@', error: %@.",
                                  keyBlock ? @"YES" : @"NO",
                                  soupEntryId,
                                  soupTableName,
                                  filePath,
                                  error];
        NSAssert(NO, errorMessage);
        [self log:SFLogLevelError msg:errorMessage];
    }
    
    return success;
}

- (id)loadExternalSoupEntry:(NSNumber *)soupEntryId
              soupTableName:(NSString *)soupTableName {
    NSString *filePath = [self externalStorageSoupFilePath:soupEntryId
                                             soupTableName:soupTableName];
    NSInputStream *inputStream = nil;
    SFSmartStoreEncryptionKeyBlock keyBlock = [SFSmartStore encryptionKeyBlock];
    if (keyBlock) {
        SFDecryptStream *decryptStream = [[SFDecryptStream alloc] initWithFileAtPath:filePath];
        [decryptStream setupWithKey:keyBlock().key andInitializationVector:nil];
        inputStream = decryptStream;
    } else {
        inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    }
    [inputStream open];
    NSError *error = nil;
    id result = [NSJSONSerialization JSONObjectWithStream:inputStream
                                                  options:NSJSONReadingAllowFragments
                                                    error:&error];
    [inputStream close];
    if (!result && error) {
        NSString *errorMessage = [NSString stringWithFormat:@"Loading external soup from file failed! encrypted: %@, soupEntryId: %@, soupTableName: %@, filePath: '%@', error: %@.",
                                  keyBlock ? @"YES" : @"NO",
                                  soupEntryId,
                                  soupTableName,
                                  filePath,
                                  error];
        NSAssert(NO, errorMessage);
        [self log:SFLogLevelError msg:errorMessage];
    }
    
    return result;
}

- (void)deleteExternalSoupEntry:(NSNumber *)soupEntryId
                  soupTableName:(NSString *)soupTableName {
    NSString *filePath = [self externalStorageSoupFilePath:soupEntryId
                                             soupTableName:soupTableName];
    NSError *delError = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:filePath
                                                    error:&delError]) {
        [self log:SFLogLevelError format:@"Failed to delete external entry at path '%@', error: %@.", filePath, delError];
    }
}

- (void)deleteAllExternalEntries:(NSString *)soupTableName
                       deleteDir:(BOOL)deleteDir {
    NSString *dirPath = [self externalStorageSoupDirectory:soupTableName];
    
    NSError *deleteDirError = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:dirPath error:&deleteDirError]) {
        [self log:SFLogLevelError format:@"Failed to delete external soup dir path '%@', error: %@.", dirPath, deleteDirError];
    }
    
    // Re-create dir if necessary
    if (!deleteDir) {
        [self createExternalStorageDirectory:soupTableName];
    }
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

- (void)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId idCol:(NSString*)idCol withDb:(FMDatabase*) db
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
                           tableName, fieldEntries, idCol];
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
    [self log:SFLogLevelVerbose format:@"convertSmartSQl:%@", smartSql];
    NSObject* sql = _smartSqlToSql[smartSql];
    
    if (nil == sql) {
        sql = [[SFSmartSqlHelper sharedInstance] convertSmartSql:smartSql withStore:self withDb:db];
        
        // Conversion failed, putting the NULL in the cache so that we don't retry conversion
        if (sql == nil) {
            [self log:SFLogLevelVerbose format:@"convertSmartSql:putting NULL in cache"];
            _smartSqlToSql[smartSql] = [NSNull null];
        }
        // Updating cache
        else {
            [self log:SFLogLevelVerbose format:@"convertSmartSql:putting %@ in cache", sql];
            _smartSqlToSql[smartSql] = sql;
        }
    }
    else if ([sql isEqual:[NSNull null]]) {
        [self log:SFLogLevelVerbose format:@"convertSmartSql:found NULL in cache"];
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
        NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_ATTRS_TABLE,SOUP_NAME_COL];
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


- (NSString *)tableNameBySoupId:(sqlite3_int64)soupId {
    return [NSString stringWithFormat:@"TABLE_%lld", soupId];
}

- (NSNumber *)soupIdFromTableName:(NSString *)tableName {
    return @([[tableName stringByReplacingOccurrencesOfString:@"TABLE_" withString:@""] longLongValue]);
}

- (NSArray *)tableNamesForAllSoupsWithDb:(FMDatabase*) db{
    NSMutableArray* result = [NSMutableArray array]; // equivalent to: [[[NSMutableArray alloc] init] autorelease]
    NSString* sql = [NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_ATTRS_TABLE];
    FMResultSet *frs = [self executeQueryThrows:sql withDb:db];
    while ([frs next]) {
        NSString* tableName = [frs stringForColumn:SOUP_NAME_COL];
        [result addObject:tableName];
    }
    
    [frs close];
    return result;
}

- (SFSoupSpec*)attributesForSoup:(NSString*)soupName {
    __block SFSoupSpec *specs = nil;
    [self inDatabase:^(FMDatabase* db) {
        specs = [self attributesForSoup:soupName withDb:db];
    } error:nil];
    return specs;
}

- (SFSoupSpec*)attributesForSoup:(NSString*)soupName withDb:(FMDatabase *)db {
    //look in the cache first
    SFSoupSpec *attrs = _attrSpecBySoup[soupName];
    if (nil == attrs) {
        //no cached attributes ...reload from SOUP_ATTRS_TABLE
        NSString *attrsSql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", SOUP_ATTRS_TABLE, SOUP_NAME_COL];
        [self log:SFLogLevelDebug format:@"attrs sql: %@",attrsSql];
        
        FMResultSet *frs = [self executeQueryThrows:attrsSql withArgumentsInArray:@[soupName] withDb:db];
        if ([frs next]) {
            NSMutableArray *soupFeatures = [[NSMutableArray alloc] init];
            for (NSString *feature in [self registeredSoupFeaturesWithDb:db]) {
                if ([frs intForColumn:feature] == kSoupFeatureEnabled) {
                    [soupFeatures addObject:feature];
                }
            }
            attrs = [SFSoupSpec newSoupSpec:soupName withFeatures:soupFeatures];
            
            //update the cache
            _attrSpecBySoup[soupName] = attrs;
        }
        
        [frs close];
    }
    
    if (!attrs) {
        [self log:SFLogLevelDebug format:@"no attributes for '%@'",soupName];
    }
    return attrs;
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

- (NSString *)registerNewSoupWithSpec:(SFSoupSpec*)soupSpec withDb:(FMDatabase*) db {
    NSMutableDictionary *soupMapValues = [[NSMutableDictionary alloc] initWithObjectsAndKeys:soupSpec.soupName, SOUP_NAME_COL, nil];
    for (NSString *feature in [self registeredSoupFeaturesWithDb:db]) {
        if ([soupSpec.features containsObject:feature]) {
            soupMapValues[feature] = @(kSoupFeatureEnabled);
        }
    }
    [self insertIntoTable:SOUP_ATTRS_TABLE values:soupMapValues withDb:db];

    //Get a safe table name for the soupName
    NSString *soupTableName = [self tableNameBySoupId:[db lastInsertRowId]];
    if (nil == soupTableName) {
        [self log:SFLogLevelDebug format:@"couldn't properly register soupName: '%@' ",soupSpec.soupName];
    }
    return soupTableName;
}

// Attention, this only updates the metadata about the soup features
// To actually perform features conversions, use alter soup.
- (void)updateExistingSoupFeaturesWithSpec:(SFSoupSpec*)soupSpec withSoupTableName:(NSString*)soupTableName withDb:(FMDatabase*) db {
    NSMutableDictionary *featuresMapValues = [[NSMutableDictionary alloc] initWithCapacity:soupSpec.features.count];
    for (NSString *feature in [self registeredSoupFeaturesWithDb:db]) {
        if ([soupSpec.features containsObject:feature]) {
            featuresMapValues[feature] = @(kSoupFeatureEnabled);
        } else {
            featuresMapValues[feature] = @(kSoupFeatureDisabled);
        }
    }
    
    NSNumber *soupId = [self soupIdFromTableName:soupTableName];
    [self updateTable:SOUP_ATTRS_TABLE values:featuresMapValues entryId:soupId idCol:ID_COL withDb:db];
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs {
    return [self registerSoup:soupName withIndexSpecs:indexSpecs error:nil];
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs error:(NSError**)error {
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:soupName withFeatures:nil];
    return [self registerSoupWithSpec:soupSpec withIndexSpecs:indexSpecs error:error];
}

- (BOOL)registerSoupWithSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray*)indexSpecs error:(NSError**)error {
    NSError *localError = nil;
    
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self registerSoupWithSpec:soupSpec withIndexSpecs:indexSpecs withSoupTableName:nil withDb:db];
    } error:&localError];
    
    if (error) {
        *error = localError;
    }

    if (localError) {
        return NO;
    }
    return YES;
}

- (void)registerSoupWithSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray*)indexSpecs withSoupTableName:(NSString*) soupTableName withDb:(FMDatabase*) db
{
    //verify soupName
    if (!([soupSpec.soupName length] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus soupName" reason:soupSpec.soupName userInfo:nil];
    }
    //verify indexSpecs
    if (!([indexSpecs count] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus indexSpecs" reason:nil userInfo:nil];
    }
    
    // If soup with same name already exists, just return success.
    if ([self soupExists:soupSpec.soupName withDb:db]) {
        return;
    }

    // Can't have JSON1 index specs in externally stored soup
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    BOOL soupUsesJSON1 = [SFSoupIndex hasJSON1:indexSpecs];
    if (soupUsesExternalStorage && soupUsesJSON1) {
        @throw [NSException exceptionWithName:@"Can't have JSON1 index specs in externally stored soup" reason:nil userInfo:nil];
    }
    
    if (nil == soupTableName) {
        soupTableName = [self registerNewSoupWithSpec:soupSpec withDb:db];
    } else {
        // This is a re-registration case.
        // Update soup features if necessary.
        [self updateExistingSoupFeaturesWithSpec:soupSpec
                               withSoupTableName:soupTableName
                                          withDb:db];
        [self log:SFLogLevelDebug
           format:@"==== Creating %@ ('%@', features: '%@') ====",
            soupTableName,
            soupSpec.soupName,
            soupSpec.features?:@[]];
    }
    
    NSMutableArray *soupIndexMapInserts = [[NSMutableArray alloc] init ];
    NSMutableArray *createIndexStmts = [[NSMutableArray alloc] init ];
    NSMutableString *createTableStmt = [[NSMutableString alloc] init];
    [createTableStmt appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (",soupTableName];
    [createTableStmt appendFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT",ID_COL];
    if (!soupUsesExternalStorage) {
        [createTableStmt appendFormat:@", %@ TEXT",SOUP_COL]; //this is the column where the raw json is stored
    }
    [createTableStmt appendFormat:@", %@ INTEGER",CREATED_COL];
    [createTableStmt appendFormat:@", %@ INTEGER",LAST_MODIFIED_COL];
    
    NSMutableString *createFtsStmt = [NSMutableString new];
    NSMutableArray *columnsForFts = [NSMutableArray new];
    
    // Indexes on created and lastModified
    NSString* createIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_%@_idx ON %@ ( %@ )";
    for (NSString* col in @[CREATED_COL, LAST_MODIFIED_COL]) {
        [createIndexStmts addObject:[NSString stringWithFormat:createIndexFormat, soupTableName, col, soupTableName, col]];
    }
    
    for (int i = 0; i < [indexSpecs count]; i++) {
        SFSoupIndex *indexSpec = (SFSoupIndex*) indexSpecs[i];
        
        // for creating the soup table itself in the store db
        // Column name or expression the db index is on
        NSString *columnName = [NSString stringWithFormat:@"%@_%lu",soupTableName,(unsigned long)i];
        if (kValueIndexedWithJSONExtract(indexSpec)) {
            columnName = [NSString stringWithFormat:@"json_extract(soup, '$.%@')", indexSpec.path];
        }
        if (kValueExtractedToColumn(indexSpec)) {
            NSString * columnType = [indexSpec columnType];
            [createTableStmt appendFormat:@", %@ %@ ",columnName,columnType];
        }
        
        // for fts
        if ([indexSpec.indexType isEqualToString:kSoupIndexTypeFullText]) {
            [columnsForFts addObject:columnName];
        }
        
        // for inserting into meta mapping table
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init ];
        values[SOUP_NAME_COL] = soupSpec.soupName;
        values[PATH_COL] = indexSpec.path;
        values[COLUMN_NAME_COL] = columnName;
        values[COLUMN_TYPE_COL] = indexSpec.indexType;
        [soupIndexMapInserts addObject:values];
        
        // for creating an index on the soup table
        [createIndexStmts addObject:[NSString stringWithFormat:createIndexFormat, soupTableName, [NSString stringWithFormat:@"%u", i], soupTableName, columnName]];
    }
    
    [createTableStmt appendString:@")"];
    [self log:SFLogLevelDebug format:@"createTableStmt: %@",createTableStmt];
    
    // fts
    if (columnsForFts.count > 0) {
        [createFtsStmt appendFormat:@"CREATE VIRTUAL TABLE %@_fts USING fts%u(%@)", soupTableName, (unsigned)self.ftsExtension, [columnsForFts componentsJoinedByString:@","]];
        [self log:SFLogLevelDebug format:@"createFtsStmt: %@",createFtsStmt];
    }
    
    // create the main soup table
    [self  executeUpdateThrows:createTableStmt withDb:db];

    // fts
    if (columnsForFts.count > 0) {
        [self executeUpdateThrows:createFtsStmt withDb:db];
    }
    
    // create indices for this soup
    for (NSString *createIndexStmt in createIndexStmts) {
        [self log:SFLogLevelDebug format:@"createIndexStmt: %@",createIndexStmt];
        [self executeUpdateThrows:createIndexStmt withDb:db];
    }
    [self insertIntoSoupIndexMap:soupIndexMapInserts withDb:db];
    
    // if soup uses external storage, create the dir now
    if (soupUsesExternalStorage) {
        if (![self createExternalStorageDirectory:soupTableName]) {
            @throw [NSException exceptionWithName:@"External storage soup dir creation error."
                                           reason:nil
                                         userInfo:nil];
        }
    }
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
    // Get soup spec while it exists
    SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    
    NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",soupTableName];
    [self executeUpdateThrows:dropSql withDb:db];

    // fts
    if ([self hasFts:soupName withDb:db]) {
        NSString *dropFtsSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@_fts",soupTableName];
        [self executeUpdateThrows:dropFtsSql withDb:db];
    }
    
    NSString *deleteIndexSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                                SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, soupName];
    [self executeUpdateThrows:deleteIndexSql withDb:db];
    NSString *deleteNameSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                               SOUP_ATTRS_TABLE, SOUP_NAME_COL, soupName];
    [self executeUpdateThrows:deleteNameSql withDb:db];
    
    [_attrSpecBySoup removeObjectForKey:soupName ];
    [_indexSpecsBySoup removeObjectForKey:soupName ];
    [_soupNameToTableName removeObjectForKey:soupName ];
    
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
    
    // Cleanup external storage directory
    if (soupUsesExternalStorage) {
        [self deleteAllExternalEntries:soupTableName
                             deleteDir:YES];
    }
}

- (void)removeAllSoups
{
    [self inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [self removeAllSoupWithDb:db];
    } error:nil];
}

- (void)removeFromCache:(NSString*) soupName {
    [_attrSpecBySoup removeObjectForKey:soupName ];
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
                              forFieldPath:(NSString *)fieldPath
                                fieldValue:(NSString *)fieldValue
                                     error:(NSError **)error
{
    __block NSNumber* result;
    [self inDatabase:^(FMDatabase* db) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        result = [self lookupSoupEntryIdForSoupName:(NSString *)soupName
                                      soupTableName:(NSString *)soupTableName
                                       forFieldPath:(NSString *)fieldPath
                                         fieldValue:(NSString *)fieldValue
                                              error:(NSError **)error
                                             withDb:(FMDatabase*)db];
    } error:nil];
    return result;
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
    // [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:querySpec.pageSize];
    
    // Page
    NSUInteger offsetRows = querySpec.pageSize * pageIndex;
    NSUInteger numberRows = querySpec.pageSize;
    NSString* limit = [NSString stringWithFormat:@"%lu,%lu",(unsigned long)offsetRows,(unsigned long)numberRows];
    
    // SQL
    NSString* sql = [self convertSmartSql: querySpec.smartSql withDb:db];
    NSString* limitSql = [@[@"SELECT * FROM (", sql, @") LIMIT ", limit] componentsJoinedByString:@""];
    // [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nlimitSql:%@ \npageIndex:%d \n", limitSql, pageIndex];
    
    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [self executeQueryThrows:limitSql withArgumentsInArray:args withDb:db];
    while ([frs next]) {
        // Smart queries
        if (querySpec.queryType == kSFSoupQueryTypeSmart || querySpec.selectPaths != nil) {
            NSArray *data = [self getDataFromRow:frs];
            if (data) {
                [result addObject:data];
            }
        }
        // Exact/like/range queries
        else {
            for (int i = 0; i < frs.columnCount; i++) {
                NSString *columnName = [frs columnNameForIndex:i];
                id entry = nil;
                if ([columnName isEqualToString:SOUP_COL]) {
                    NSString *rawJson = [frs stringForColumnIndex:i];
                    entry = [SFJsonUtils objectFromJSONString:rawJson];
                    if (entry) {
                        [result addObject:entry];
                    }
                }
                else if ([columnName isEqualToString:kSoupFeatureExternalStorage]) {
                    NSString *tableName = [frs stringForColumnIndex:i];
                    NSNumber *soupEntryId = @([frs longForColumnIndex:++i]);
                    id entry = [self loadExternalSoupEntry:soupEntryId soupTableName:tableName];
                    if (entry) {
                        [result addObject:entry];
                    }
                }
            }
        }
    }
    [frs close];
    
    return result;
}

- (NSArray *) getDataFromRow:(FMResultSet*) frs
{
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:frs.columnCount];
    NSDictionary* valuesMap = [frs resultDictionary];
    for (int i = 0; i < frs.columnCount; i++) {
        NSString* columnName = [frs columnNameForIndex:i];
        id value = valuesMap[columnName];
        if ([columnName hasSuffix:SOUP_COL] && [value isKindOfClass:[NSString class]]) {
            id entry = [SFJsonUtils objectFromJSONString:value];
            if (entry) {
                [result addObject:entry];
            }
        }
        else if ([columnName isEqualToString:kSoupFeatureExternalStorage]) {
            NSNumber *soupEntryId = @([frs longForColumnIndex:++i]);
            id entry = [self loadExternalSoupEntry:soupEntryId soupTableName:value];
            if (entry) {
                [result addObject:entry];
            }
        }
        else {
            if (value) {
                [result addObject:value];
            }
        }
    }
    return result;
}

- (NSString *)idsInPredicate:(NSArray *)ids idCol:(NSString*)idCol
{
    NSString *allIds = [ids componentsJoinedByString:@","];
    NSString *pred = [NSString stringWithFormat:@"%@ IN (%@) ", idCol, allIds];
    return pred;
}

- (NSArray *)allSoupEntryIds:(NSString *)soupTableName withDb:(FMDatabase *)db {
    NSMutableArray *soupEntryIds = [[NSMutableArray alloc] init];
    FMResultSet *idsResultSet = [self queryTable:soupTableName
                                      forColumns:@[ID_COL]
                                         orderBy:nil
                                           limit:nil
                                     whereClause:nil
                                       whereArgs:nil
                                          withDb:db];
    while ([idsResultSet next]) {
        [soupEntryIds addObject:@([idsResultSet longForColumn:ID_COL])];
    }
    [idsResultSet close];
    return soupEntryIds;
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
    
    SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    if (soupUsesExternalStorage) {
        for (NSNumber *soupEntryId in soupEntryIds) {
            @autoreleasepool {
                NSDictionary *entry = [self loadExternalSoupEntry:soupEntryId
                                                    soupTableName:soupTableName];
                if (entry) {
                    [result addObject:entry];
                }
            }
        }
    }
    else {
        NSString *pred = [self idsInPredicate:soupEntryIds idCol:ID_COL];
        NSString *querySql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
                              SOUP_COL,soupTableName,pred];
        FMResultSet *frs = [self executeQueryThrows:querySql withDb:db];
        while ([frs next]) {
            @autoreleasepool {
                NSString *rawJson = [frs stringForColumn:SOUP_COL];
                //TODO this is pretty inefficient...we read json from db then reconvert to NSDictionary, then reconvert again in cordova
                NSDictionary *entry = [SFJsonUtils objectFromJSONString:rawJson];
                [result addObject:entry];
            }
        }
        [frs close];
    }
    
    return result;
}

- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName soupAttributes:(SFSoupSpec*)soupSpec indices:(NSArray*)indices withDb:(FMDatabase*) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    NSNumber *newEntryId;
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    
    // Get next id
    FMResultSet *frs = [self executeQueryThrows:@"SELECT seq FROM SQLITE_SEQUENCE WHERE name = ?" withArgumentsInArray:@[soupTableName] withDb:db];
    if ([frs next]) {
        newEntryId = [NSNumber numberWithLongLong:1LL + [frs longLongIntForColumnIndex:0]];
    }
    else {
        // First time, we won't find any rows;
        newEntryId = [NSNumber numberWithLongLong:1LL];
    }
    [frs close];

    //clone the entry so that we can insert the new SOUP_ENTRY_ID into the json
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:newEntryId forKey:SOUP_ENTRY_ID];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   nowVal, CREATED_COL,
                                   nowVal, LAST_MODIFIED_COL,
                                   nil];
    if (!soupUsesExternalStorage) {
        //now update the SOUP_COL (raw json) for the soup entry
        NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
        values[SOUP_COL] = rawJson;
    }
    
    //build up the set of index column values for this new row
    [self projectIndexedPaths:entry values:values indices:indices typeFilter:kValueExtractedToColumn];
    [self insertIntoTable:soupTableName values:values withDb:db];
    
    // external storage
    if (soupUsesExternalStorage) {
        BOOL didSave = [self saveSoupEntryExternally:mutableEntry
                                         soupEntryId:newEntryId
                                       soupTableName:soupTableName];
        if (!didSave) {
            @throw [NSException exceptionWithName:@"Failed to save external soup file."
                                           reason:nil
                                         userInfo:nil];
        }
    }

    // fts
    if ([SFSoupIndex hasFts:indices]) {
        NSMutableDictionary *ftsValues = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          newEntryId, ROWID_COL,
                                          nil];
        [self projectIndexedPaths:entry values:ftsValues indices:indices typeFilter:kValueExtractedToFtsColumn];
        [self insertIntoTable:[NSString stringWithFormat:@"%@_fts", soupTableName] values:ftsValues withDb:db];
    }
    
    return mutableEntry;
}


- (NSDictionary *)updateOneEntry:(NSDictionary *)entry
                     withEntryId:(NSNumber *)entryId
                     inSoupTable:(NSString *)soupTableName
                  soupAttributes:(SFSoupSpec *)soupSpec
                         indices:(NSArray *)indices
                          withDb:(FMDatabase *) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    nowVal, LAST_MODIFIED_COL,
                                    nil];
    
    //build up the set of index column values for this row
    [self projectIndexedPaths:entry values:values indices:indices typeFilter:kValueExtractedToColumn];
    
    //clone the entry so that we can modify SOUP_LAST_MODIFIED_DATE
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    [mutableEntry setValue:entryId forKey:SOUP_ENTRY_ID];

    if (!soupUsesExternalStorage) {
        NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
        values[SOUP_COL] = rawJson;
    }
	
    [self updateTable:soupTableName values:values entryId:entryId idCol:ID_COL withDb:db];
    
    // external storage:
    // Update db first
    // (If file save fails, db will be rolledback)
    if (soupUsesExternalStorage) {
        [self updateTable:soupTableName values:values entryId:entryId idCol:ID_COL withDb:db];
        
        BOOL didSave = [self saveSoupEntryExternally:mutableEntry
                                         soupEntryId:entryId
                                       soupTableName:soupTableName];
        if (!didSave) {
            @throw [NSException exceptionWithName:@"Failed to re-save external soup file."
                                           reason:nil
                                         userInfo:nil];
        }
    }

    // fts
    if ([SFSoupIndex hasFts:indices]) {
        NSMutableDictionary *ftsValues = [NSMutableDictionary new];
        [self projectIndexedPaths:entry values:ftsValues indices:indices typeFilter:kValueExtractedToFtsColumn];
        [self updateTable:[NSString stringWithFormat:@"%@_fts", soupTableName] values:ftsValues entryId:entryId idCol:ROWID_COL withDb:db];
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
    SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
    
    NSNumber *soupEntryId = nil;
    if (externalIdPath != nil) {
        if ([externalIdPath isEqualToString:SOUP_ENTRY_ID]) {
            soupEntryId = entry[SOUP_ENTRY_ID];
        } else {
            NSString *fieldValue = [SFJsonUtils projectIntoJson:entry path:externalIdPath];
            if (fieldValue == nil) {
                // Cannot have empty values for user-defined external ID upsert.
                if (error != nil) {
                    NSString *errorDescription = [NSString stringWithFormat:kSFSmartStoreExternalIdNilDescription, externalIdPath];
                    *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                                 code:kSFSmartStoreExternalIdNilCode
                                             userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
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
        result = [self updateOneEntry:entry
                          withEntryId:soupEntryId
                          inSoupTable:soupTableName
                       soupAttributes:soupSpec
                              indices:indices
                               withDb:db];
    } else {
        //no entry id: insert
        result = [self insertOneEntry:entry
                          inSoupTable:soupTableName
                       soupAttributes:soupSpec
                              indices:indices
                               withDb:db];
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
    [self removeEntries:soupEntryIds fromSoup:soupName error:nil];
}

- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName error:(NSError**)error
{
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeEntries:soupEntryIds fromSoup:soupName withDb:db];
    } error:error];
}

- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    if ([self soupExists:soupName withDb:db]) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", soupTableName, [self idsInPredicate:soupEntryIds idCol:ID_COL]];
        [self executeUpdateThrows:deleteSql withDb:db];

        // fts
        if ([self hasFts:soupName withDb:db]) {
            NSString *deleteFtsSql = [NSString stringWithFormat:@"DELETE FROM %@_fts WHERE %@", soupTableName, [self idsInPredicate:soupEntryIds idCol:ROWID_COL]];
            [self executeUpdateThrows:deleteFtsSql withDb:db];
        }

        SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
        BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
        if (soupUsesExternalStorage) {
            for (NSNumber *entryId in soupEntryIds) {
                [self deleteExternalSoupEntry:entryId
                                soupTableName:soupTableName];
            }
        }
    }
}

- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName
{
    [self removeEntriesByQuery:querySpec fromSoup:soupName error:nil];
}

- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName error:(NSError**)error
{
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeEntriesByQuery:querySpec fromSoup:soupName withDb:db];
    } error:nil];
}

- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    NSString* querySql = [self convertSmartSql: querySpec.idsSmartSql withDb:db];
    NSString* limitSql = [NSString stringWithFormat:@"SELECT * FROM (%@) LIMIT %lu", querySql, (unsigned long)querySpec.pageSize];
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // For soup using external storage, run query to get ids
    NSMutableArray* ids = [NSMutableArray new];
    SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
    BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    if (soupUsesExternalStorage) {
        FMResultSet* frs = [self executeQueryThrows:limitSql withArgumentsInArray:args withDb:db];
        while ([frs next]) {
            [ids addObject:@([frs longForColumnIndex:0])];
        }
    }
    
    NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ in (%@)", soupTableName, ID_COL, limitSql];
    [self executeUpdateThrows:deleteSql withArgumentsInArray:args withDb:db];
    // fts
    if ([self hasFts:soupName withDb:db]) {
        NSString *deleteFtsSql = [NSString stringWithFormat:@"DELETE FROM %@_fts WHERE %@ in (%@)", soupTableName, ROWID_COL, querySql];
        [self executeUpdateThrows:deleteFtsSql withDb:db];
    }

    // External storage
    if (soupUsesExternalStorage) {
        for (NSNumber *entryId in ids) {
            [self deleteExternalSoupEntry:entryId
                            soupTableName:soupTableName];
        }
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
        // fts
        if ([self hasFts:soupName withDb:db]) {
            NSString *deleteFtsSql = [NSString stringWithFormat:@"DELETE FROM %@_fts", soupTableName];
            [self executeUpdateThrows:deleteFtsSql withDb:db];
        }

        // Delete external files if necessary
        SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
        BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
        if (soupUsesExternalStorage) {
            [self deleteAllExternalEntries:soupTableName
                                 deleteDir:NO];
        }
    }
}

- (unsigned long long)getDatabaseSize
{
    unsigned long long size = 0;
    NSString *dbPath = [self.dbMgr fullDbFilePathForStoreName:_storeName];
    size = [[[NSFileManager defaultManager] attributesOfItemAtPath:dbPath error:nil] fileSize];
    
    NSString *externalItemsPath = [self externalStorageRootDirectory];
    NSArray *allExternalItems = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:externalItemsPath
                                                                                    error:nil];
    for (NSString *item in allExternalItems) {
        NSString *fullItemPath = [externalItemsPath stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        // Don't count directories
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullItemPath isDirectory:&isDir] && !isDir) {
            size += [[[NSFileManager defaultManager] attributesOfItemAtPath:fullItemPath error:nil] fileSize];
        }
    }
    return size;
}

- (unsigned long long)getExternalFileStorageSizeForSoup:(NSString*)soupName {
    __block unsigned long long size = 0;

    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *externalItemsPath = [self externalStorageSoupDirectory:soupTableName];
        NSArray *allExternalItems = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:externalItemsPath
                                                                                        error:nil];
        for (NSString *item in allExternalItems) {
            NSString *fullItemPath = [externalItemsPath stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            // Don't count directories
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullItemPath isDirectory:&isDir] && !isDir) {
                size += [[[NSFileManager defaultManager] attributesOfItemAtPath:fullItemPath error:nil] fileSize];
            }
        }
    } error:nil];

    return size;
}

- (NSUInteger)getExternalFilesCountForSoup:(NSString*)soupName {
    __block NSUInteger count = 0;
    
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
        NSString *externalItemsPath = [self externalStorageSoupDirectory:soupTableName];
        NSArray *allExternalItems = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:externalItemsPath
                                                                                        error:nil];
        count = [allExternalItems count];
    } error:nil];
    
    return count;
}

- (BOOL) alterSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs reIndexData:(BOOL)reIndexData
{
    if ([self soupExists:soupName]) {
        SFAlterSoupLongOperation* operation = [[SFAlterSoupLongOperation alloc] initWithStore:self
                                                                                     soupName:soupName
                                                                                newIndexSpecs:indexSpecs
                                                                                  reIndexData:reIndexData];
        [operation run];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) alterSoup:(NSString*)soupName withSoupSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray*)indexSpecs reIndexData:(BOOL)reIndexData
{
    if ([self soupExists:soupName]) {
        SFAlterSoupLongOperation* operation = [[SFAlterSoupLongOperation alloc] initWithStore:self
                                                                                     soupName:soupName
                                                                                  newSoupSpec:soupSpec
                                                                                newIndexSpecs:indexSpecs
                                                                                  reIndexData:reIndexData];
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
        NSMutableArray* indices = [NSMutableArray new];

        SFSoupSpec *soupSpec = [self attributesForSoup:soupName withDb:db];
        BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
        NSArray *queryCols = soupUsesExternalStorage ? @[ID_COL] : @[ID_COL, SOUP_COL];

        BOOL hasFts = NO;
        for (NSString* indexPath in  indexPaths) {
            SFSoupIndex *idx = mapIndexSpecs[indexPath];
            if (idx) {
                [indices addObject:idx];
                if ([idx.indexType isEqualToString:kSoupIndexTypeFullText]) {
                    hasFts = YES;
                }
            }
        }
        FMResultSet* frs = [self queryTable:soupTableName forColumns:queryCols orderBy:nil limit:nil whereClause:nil whereArgs:nil withDb:db];
    
        while([frs next]) {
            NSNumber *entryId = @([frs longForColumn:ID_COL]);
            NSDictionary *entry;
            if (soupUsesExternalStorage) {
                entry = [self loadExternalSoupEntry:entryId
                                      soupTableName:soupTableName];
            }
            else {
                NSString *soupElt = [frs stringForColumn:SOUP_COL];
                entry = [SFJsonUtils objectFromJSONString:soupElt];
            }
            
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            [self projectIndexedPaths:entry values:values indices:indices typeFilter:kValueExtractedToColumn];
            if ([values count] > 0) {
                [self updateTable:soupTableName values:values entryId:entryId idCol:ID_COL withDb:db];
            }
            // fts
            if (hasFts) {
                NSMutableDictionary *ftsValues = [NSMutableDictionary dictionary];
                [self projectIndexedPaths:entry values:ftsValues indices:indices typeFilter:kValueExtractedToFtsColumn];
                if ([ftsValues count] > 0) {
                    [self updateTable:[NSString stringWithFormat:@"%@_fts", soupTableName] values:ftsValues entryId:entryId idCol:ROWID_COL withDb:db];
                }
            }
        }
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL) hasFts:(NSString*)soupName withDb:(FMDatabase *)db
{
    NSArray *indices = [self indicesForSoup:soupName withDb:db];
    return [SFSoupIndex hasFts:indices];
}

#pragma mark - Misc

- (void) projectIndexedPaths:(NSDictionary*)entry values:(NSMutableDictionary*)values indices:(NSArray*)indices typeFilter:(SFIndexSpecTypeFilterBlock)typeFilter
{
    // build up the set of index column values for this row
    for (SFSoupIndex *idx in indices) {
        if (!typeFilter(idx))
            continue;
        
        id indexColVal = [SFJsonUtils projectIntoJson:entry path:[idx path]];;
        // values for non-leaf nodes are json-ized
        if ([indexColVal isKindOfClass:[NSDictionary class]] || [indexColVal isKindOfClass:[NSArray class]]) {
            indexColVal = [SFJsonUtils JSONRepresentation:indexColVal options:0];
        }
        
        NSString *colName = [idx columnName];
        values[colName] = indexColVal != nil ? indexColVal : [NSNull null];
    }
}

#pragma mark - Compatibilty methods

- (void)upgradeRenameTableSoupNamesToSoupAttrs
{
    [self inDatabase:^(FMDatabase *db) {
        if ([db tableExists:SOUP_NAMES_TABLE]) {
            // Renames SOUP_NAMES_TABLE to SOUP_ATTRS_TABLE
            NSString *renameSoupNamesTableSql = [NSString stringWithFormat:
                                                 @"ALTER TABLE %@ RENAME TO %@",
                                                 SOUP_NAMES_TABLE,
                                                 SOUP_ATTRS_TABLE
                                                 ];
            
            [self log:SFLogLevelDebug format:@"renameSoupNamesTableSql: %@",renameSoupNamesTableSql];
            [self executeUpdateThrows:renameSoupNamesTableSql withDb:db];
        }
    } error:nil];
}
@end
