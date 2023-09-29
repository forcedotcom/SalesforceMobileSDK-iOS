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
#import "SFSmartStore+Internal.h"
#import "SFSmartStoreUtils.h"
#import "SFSmartSqlHelper.h"
#import "SFSmartSqlCache.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import "SFAlterSoupLongOperation.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import <SalesforceSDKCommon/SFSDKDataSharingHelper.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>

static NSMutableDictionary *_allSharedStores;
static NSMutableDictionary *_allGlobalSharedStores;
static SFSmartStoreEncryptionKeyGenerator _encryptionKeyGenerator = NULL;
static SFSmartStoreEncryptionSaltBlock _encryptionSaltBlock = NULL;
static BOOL _jsonSerializationCheckEnabled = NO;
static BOOL _postRawJsonOnError = NO;

// The name of the store name used by the SFSmartStorePlugin for hybrid apps
NSString * const kDefaultSmartStoreName   = @"defaultStore";

NSString * const kSFAppFeatureSmartStoreUser   = @"US";
NSString * const kSFAppFeatureSmartStoreGlobal   = @"GS";
NSString * const kSFSmartStoreJSONParseErrorNotification = @"SFSmartStoreJSONParseErrorNotification";
NSString * const kSFSmartStoreJSONSerializationErrorNotification = @"SFSmartStoreJSONSerializationErrorNotification";

// NSError constants  (TODO: We should move this stuff into a framework where errors can be configurable
// in a plist, once we start delivering a bundle.
NSString *        const kSFSmartStoreErrorDomain                 = @"com.salesforce.smartstore.error";
static NSInteger  const kSFSmartStoreTooManyEntriesCode          = 1;
static NSString * const kSFSmartStoreTooManyEntriesDescription   = @"Cannot update entry: the value '%@' for path '%@' does not represent a unique entry!";
static NSInteger  const kSFSmartStoreIndexNotDefinedCode         = 2;
static NSString * const kSFSmartStoreIndexNotDefinedDescription  = @"No index column defined for field '%@'.";
static NSInteger  const kSFSmartStoreExternalIdNilCode           = 3;
static NSString * const kSFSmartStoreExternalIdNilDescription    = @"For upsert with external ID path '%@', value cannot be empty for any entries.";
static NSString * const kSFSmartStoreExtIdLookupError = @"There was an error retrieving the soup entry ID for path '%@' and value '%@': %@";
static NSInteger  const kSFSmartStoreWhereArgsNotSupportedCode   = 5;
static NSString * const kSFSmartStoreWhereArgsNotSupportedDescription = @"whereArgs can only be provided for smart queries";
static NSInteger  const kSFSmartStoreOtherErrorCode              = 999;

NSString *const kSFSmartStoreErrorLoadExternalSoup =  @"com.salesforce.smartstore.LoadExternalSoupError";

// Encryption constants
NSString * const kSFSmartStoreEncryptionKeyLabel = @"com.salesforce.smartstore.encryption.keyLabel";

// Encryption constants
NSString * const kSFSmartStoreEncryptionSaltLabel = @"com.salesforce.smartstore.encryption.saltLabel";
NSUInteger const kSFSmartStoreEncryptionSaltLength = 16;

// Table to keep track of soup attributes
static NSString *const SOUP_NAMES_TABLE = @"soup_names"; //legacy soup attrs, still around for backward compatibility. Do not use it.

// Columns of the soup index map table
NSString *const COLUMN_NAME_COL = @"columnName";

// Columns of a soup table
NSString *const ID_COL = @"id";
NSString *const CREATED_COL = @"created";
NSString *const LAST_MODIFIED_COL = @"lastModified";
NSString *const SOUP_COL = @"soup";

// JSON fields added to soup element on insert/update
NSString *const SOUP_ENTRY_ID = @"_soupEntryId";
NSString *const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";

// Explain support
NSString *const EXPLAIN_SQL = @"sql";
NSString *const EXPLAIN_ARGS = @"args";

// Caches count limit
NSUInteger CACHES_COUNT_LIMIT = 1024;

@implementation SFSmartStore

+ (void)initialize
{
    if (!_encryptionKeyGenerator) {
        _encryptionKeyGenerator = ^NSData *{
            NSError *error = nil;
            NSData *key = [SFSDKKeyGenerator encryptionKeyFor:kSFSmartStoreEncryptionKeyLabel error:&error];
            if (error) {
                [SFSDKSmartStoreLogger e:[self class] format:@"Error getting encryption key: %@", error.localizedDescription];
            }
            return key;
        };
    }
    
    if (!_encryptionSaltBlock) {
        _encryptionSaltBlock = ^ {
            NSString *salt = nil;
 
            NSData *existingSalt = [SFSDKKeychainHelper readWithService:kSFSmartStoreEncryptionSaltLabel account:nil].data;
            if (existingSalt) {
                salt = [existingSalt sfsdk_newHexStringFromBytes];
            } else if ([[SFSDKDatasharingHelper sharedInstance] appGroupEnabled]) {
                NSData *newSalt = [[NSMutableData dataWithLength:kSFSmartStoreEncryptionSaltLength] sfsdk_randomDataOfLength:kSFSmartStoreEncryptionSaltLength];
                SFSDKKeychainResult *result = [SFSDKKeychainHelper writeWithService:kSFSmartStoreEncryptionSaltLabel data:newSalt account:nil];
                if (result.success) {
                    salt = [newSalt sfsdk_newHexStringFromBytes];
                } else {
                    [SFSDKSmartStoreLogger e:[self class] format:@"Error writing salt to keychain: %@", result.error.localizedDescription];
                }
            }
            return salt;
        };
    }
}

- (id)initWithName:(NSString *)name user:(SFUserAccount *)user {
    return [self initWithName:name user:user isGlobal:NO];
}

- (id) initWithName:(NSString*)name user:(SFUserAccount *)user isGlobal:(BOOL)isGlobal {
    self = [super init];
    if (self)  {
        if (user == nil  && !isGlobal) {
            [SFSDKSmartStoreLogger w:[self class] format:@"%@ Cannot create SmartStore with name '%@': user is not configured, and isGlobal is not configured.  Did you mean to call [%@ sharedGlobalStoreWithName:]?",
             NSStringFromSelector(_cmd),
             name,
             NSStringFromClass([self class])];
            return nil;
        }
        [SFSDKSmartStoreLogger d:[self class] format:@"%@ %@, user: %@, isGlobal: %d", NSStringFromSelector(_cmd), name, [SFSmartStoreUtils userKeyForUser:user], isGlobal];
        _storeName = name;
        _isGlobal = isGlobal;
        _user = user;
        if (_isGlobal) {
            _dbMgr = [SFSmartStoreDatabaseManager sharedGlobalManager];
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSmartStoreGlobal];
        } else {
            _dbMgr = [SFSmartStoreDatabaseManager sharedManagerForUser:_user];
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSmartStoreUser];
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
                                              [SFSDKSmartStoreLogger d:[self class] format:@"SFSmartStore UIApplicationProtectedDataDidBecomeAvailable"];
                                              this->_dataProtectionKnownAvailable = YES;
                                          }];
        
        _dataProtectUnavailObserverToken = [[NSNotificationCenter defaultCenter]
                                            addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable
                                            object:nil
                                            queue:nil
                                            usingBlock:^(NSNotification *note) {
                                                [SFSDKSmartStoreLogger d:[self class] format:@"SFSmartStore UIApplicationProtectedDataWillBecomeUnavailable"];
                                                this->_dataProtectionKnownAvailable = NO;
                                            }];
        
        _soupNameToTableName = [[NSCache alloc] init];
        _soupNameToTableName.countLimit = CACHES_COUNT_LIMIT;
        
        _indexSpecsBySoup = [[NSCache alloc] init];
        _indexSpecsBySoup.countLimit = CACHES_COUNT_LIMIT;
        
        _smartSqlToSql = [[SFSmartSqlCache alloc] initWithCountLimit:CACHES_COUNT_LIMIT];
        
        // Using FTS5 by default
        _ftsExtension = SFSmartStoreFTS5;
        
        if (![_dbMgr persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                self = nil;
            }
        } else {
            if (![self subsequentTimesStoreDatabaseSetup]) {
                // If it couldn't be opened, it gets deleted
                // So we should try to set a new one up
                if (![self firstTimeStoreDatabaseSetup]) {
                    self = nil;
                }
            }
        }
    }
    return self;
}

- (void)dealloc {
    [SFSDKSmartStoreLogger d:[self class] format:@"dealloc store: '%@'", _storeName];
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
        [SFSDKSmartStoreLogger e:[self class] format:@"Deleting store dir since we can't set it up properly: %@", self.storeName];
        [self.dbMgr removeStoreDir:self.storeName];
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
    
    // Delete db file if it can no longer be opened
    if (!result) {
        [SFSDKSmartStoreLogger e:[self class] format:@"Deleting store dir since we can't open it anymore: %@", self.storeName];
        [self.dbMgr removeStoreDir:self.storeName];
    }
    
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
    NSString *salt = [[self class]encryptionSaltBlock] ? [[self class] encryptionSaltBlock]() : nil;
    self.storeQueue = [self.dbMgr openStoreQueueWithName:self.storeName key:[[self class] encKey] salt:salt error:&openDbError];
    if (self.storeQueue == nil) {
        [SFSDKSmartStoreLogger e:[self class] format:@"Error opening store '%@': %@", self.storeName, [openDbError localizedDescription]];
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
            [SFSDKSmartStoreLogger w:[self class] format:@"%@ Cannot create shared store with name '%@' for nil user.  Did you mean to call [%@ sharedGlobalStoreWithName:]?", NSStringFromSelector(_cmd), storeName, NSStringFromClass(self)];
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
            if (user.loginState != SFUserAccountLoginStateLoggedIn) {
                [SFSDKSmartStoreLogger w:[self class] format:@"%@ A user account must be in the  SFUserAccountLoginStateLoggedIn state in order to create a store.", NSStringFromSelector(_cmd), storeName, NSStringFromClass(self)];
                return nil;
            }
            store = [[self alloc] initWithName:storeName user:user];
            if (store)
                _allSharedStores[userKey][storeName] = store;
            
            NSInteger numUserStores = [(NSDictionary *)(_allSharedStores[userKey]) count];
            [SFSDKEventBuilderHelper createAndStoreEvent:@"userSmartStoreInit" userAccount:user className:NSStringFromClass([self class]) attributes:@{ @"numUserStores" : [NSNumber numberWithInteger:numUserStores] }];
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
        NSInteger numGlobalStores = _allGlobalSharedStores.allKeys.count;
        [SFSDKEventBuilderHelper createAndStoreEvent:@"globalSmartStoreInit" userAccount:nil className:NSStringFromClass([self class]) attributes:@{ @"numGlobalStores" : [NSNumber numberWithInteger:numGlobalStores] }];
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
            [SFSDKSmartStoreLogger i:[self class] format:@"%@ Cannot remove store with name '%@' for nil user.  Did you mean to call [%@ removeSharedGlobalStoreWithName:]?", NSStringFromSelector(_cmd), storeName, NSStringFromClass(self)];
            return;
        }
        [SFSDKSmartStoreLogger d:[self class] format:@"removeSharedStoreWithName: %@, user: %@", storeName, user];
        NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
        SFSmartStore *existingStore = _allSharedStores[userKey][storeName];
        if (nil != existingStore) {
            [existingStore.storeQueue close];
            [_allSharedStores[userKey] removeObjectForKey:storeName];
        }
        [[SFSmartStoreDatabaseManager sharedManagerForUser:user] removeStoreDir:storeName];
    }
}

+ (void)removeSharedGlobalStoreWithName:(NSString *)storeName {
    @synchronized (self) {
        [SFSDKSmartStoreLogger d:[self class] format:@"%@ %@", NSStringFromSelector(_cmd), storeName];
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
            [SFSDKSmartStoreLogger i:[self class] format:@"%@ Cannot remove all stores for nil user. Did you mean to call [%@ removeAllGlobalStores]?", NSStringFromSelector(_cmd), NSStringFromClass(self)];
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

+ (NSArray *)allStoreNames {
    @synchronized (self) {
        NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManagerForUser:[SFUserAccountManager sharedInstance].currentUser] allStoreNames];
        return allStoreNames;
    }
}

+ (NSArray *)allGlobalStoreNames {
    @synchronized (self) {
        return [[SFSmartStoreDatabaseManager sharedGlobalManager] allStoreNames];
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
    [SFSDKSmartStoreLogger d:[self class] format:@"createSoupIndexTableSql: %@", createSoupIndexTableSql];

    // Create SOUP_ATTRS_TABLE
    // The table name for the soup will simply be TABLE_<soupId>
    NSString *createSoupNamesTableSql = [NSString stringWithFormat:
                                         @"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT )",
                                         SOUP_ATTRS_TABLE,
                                         ID_COL,
                                         SOUP_NAME_COL
                                         ];
    [SFSDKSmartStoreLogger d:[self class] format:@"createSoupNamesTableSql: %@", createSoupNamesTableSql];
    
    // Create an index for SOUP_NAME_COL in SOUP_ATTRS_TABLE
    NSString *createSoupNamesIndexSql = [NSString stringWithFormat:
                                         @"CREATE INDEX %@_0 on %@ ( %@ )",
                                         SOUP_ATTRS_TABLE, SOUP_ATTRS_TABLE, SOUP_NAME_COL];
    [SFSDKSmartStoreLogger d:[self class] format:@"createSoupNamesIndexSql: %@", createSoupNamesIndexSql];
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
    [SFSDKSmartStoreLogger d:[self class] format:@"createLongOperationsStatusTableSql: %@", createLongOperationsStatusTableSql];
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

- (BOOL)inDatabase:(void (^)(FMDatabase *db))block error:(NSError* __autoreleasing *)error
{
    __block BOOL success = YES;
    [self.storeQueue inDatabase:^(FMDatabase* db) {
        @try {
            block(db);
        }
        @catch (NSException *exception) {
            if (error != nil) {
                *error = [self errorForException:exception];
            }
            success = NO;
        }
    }];
    return success;
}

- (BOOL)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block error:(NSError* __autoreleasing *)error {
    __block BOOL success = YES;
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
            success = NO;
        }
    }];
    return success;
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

+ (NSString *)encKey {
    if (_encryptionKeyGenerator) {
        NSData *key = _encryptionKeyGenerator();
        return [key base64EncodedStringWithOptions:0];
    }
    return nil;
}

+ (NSString *)salt {
    if (_encryptionSaltBlock) {
        return  _encryptionSaltBlock();
    }
    return nil;
}

+ (SFSmartStoreEncryptionSaltBlock)encryptionSaltBlock {
    return _encryptionSaltBlock;
}

+ (void)setEncryptionSaltBlock:(SFSmartStoreEncryptionSaltBlock)newEncryptionSaltBlock {
    if (newEncryptionSaltBlock != _encryptionSaltBlock) {
        _encryptionSaltBlock = newEncryptionSaltBlock;
    }
}

+ (SFSmartStoreEncryptionKeyGenerator)encryptionKeyGenerator {
    return _encryptionKeyGenerator;
}

+ (void)setEncryptionKeyGenerator:(SFSmartStoreEncryptionKeyGenerator)newEncryptionKeyGenerator {
    if (newEncryptionKeyGenerator != _encryptionKeyGenerator) {
        _encryptionKeyGenerator = newEncryptionKeyGenerator;
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


+ (void)buildEventOnJsonParseErrorForUser:(SFUserAccount *)user fromMethod:(NSString*)fromMethod rawJson:(NSString*)rawJson {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"errorCode"] = [NSNumber numberWithInteger:SFJsonUtils.lastError.code];
    attributes[@"errorMessage"] = SFJsonUtils.lastError.localizedDescription;
    attributes[@"fromMethod"] = fromMethod;
    [SFSDKEventBuilderHelper createAndStoreEvent:@"SmartStoreJSONParseError" userAccount:user className:NSStringFromClass([self class]) attributes:attributes];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:attributes];
    if (_postRawJsonOnError) info[@"rawJson"] = rawJson;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFSmartStoreJSONParseErrorNotification object:self userInfo:info];
}

+ (void)buildEventOnJsonSerializationErrorForUser:(SFUserAccount *)user fromMethod:(NSString*)fromMethod error:(NSError*)error {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
    attributes[@"errorMessage"] = error.localizedDescription;
    attributes[@"fromMethod"] = fromMethod;
    [SFSDKEventBuilderHelper createAndStoreEvent:@"SmartStoreJSONSerializationError" userAccount:user className:NSStringFromClass([self class]) attributes:attributes];

    [[NSNotificationCenter defaultCenter] postNotificationName:kSFSmartStoreJSONParseErrorNotification object:self userInfo:attributes];
}

- (BOOL)checkRawJson:(NSString*)rawJson fromMethod:(NSString*)fromMethod {
    if (_jsonSerializationCheckEnabled && [SFJsonUtils objectFromJSONString:rawJson] == nil) {
        [SFSDKSmartStoreLogger e:[self class] format:@"Error parsing JSON in SmartStore in %@", fromMethod];
        [SFSmartStore buildEventOnJsonParseErrorForUser:self.user fromMethod:fromMethod rawJson:rawJson];
        return NO;
    } else {
        return YES;
    }
}

+ (NSString*) stringFromInputStream:(NSInputStream*)inputStream {
    //
    // We get all the bytes and then convert them to a string
    // If you convert each buffer's worth of bytes to a string
    // you might end up corrupting the string (because a multi bytes character could have been split at the buffer boundary)
    //
    uint8_t buffer[kBufferSize];
    NSInteger len;
    NSMutableData* content = [NSMutableData new];
    [inputStream open];
    while ((len = [inputStream read:buffer maxLength:sizeof(buffer)]) > 0) {
        [content appendBytes:buffer length:len];
    }
    [inputStream close];
    return [[NSString alloc] initWithData:content encoding:NSUTF8StringEncoding];
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
    [self executeUpdateThrows:updateSql withArgumentsInArray:binds withDb:db];
}

- (NSString*)columnNameForPath:(NSString*)path inSoup:(NSString*)soupName withDb:(FMDatabase*) db {
    NSString *result = nil;
    NSArray* indexSpecs = [self indicesForSoup:soupName withDb:db];
    for (SFSoupIndex* indexSpec in indexSpecs) {
        if ([indexSpec.path isEqualToString:path]) {
            result = indexSpec.columnName;
        }
    }
    
    if (nil == result) {
        [SFSDKSmartStoreLogger d:[self class] format:@"Unknown index path '%@' in soup '%@' ", path, soupName];
    }
    return result;
}

- (BOOL) hasIndexForPath:(NSString*)path inSoup:(NSString*)soupName withDb:(FMDatabase*) db {
    NSArray* indexSpecs = [self indicesForSoup:soupName withDb:db];
    for (SFSoupIndex* indexSpec in indexSpecs) {
        if ([indexSpec.path isEqualToString:path]) {
            return YES;
        }
    }
    return NO;
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
    [SFSDKSmartStoreLogger v:[self class] format:@"convertSmartSQl:%@", smartSql];
    NSObject* sql = [_smartSqlToSql sqlForSmartSql:smartSql];
    if (nil == sql) {
        sql = [[SFSmartSqlHelper sharedInstance] convertSmartSql:smartSql withStore:self withDb:db];
        
        // Conversion failed, putting the NULL in the cache so that we don't retry conversion
        if (sql == nil) {
            [SFSDKSmartStoreLogger v:[self class] format:@"convertSmartSql:putting NULL in cache"];
            [_smartSqlToSql setSql:@"null" forSmartSql:smartSql];
        }
        // Updating cache
        else {
            [SFSDKSmartStoreLogger v:[self class] format:@"convertSmartSql:putting %@ in cache", sql];
            [_smartSqlToSql setSql:(NSString*)sql forSmartSql:smartSql];
        }
    }
    else if ([sql isEqual:@"null"]) {
        [SFSDKSmartStoreLogger v:[self class] format:@"convertSmartSql:found NULL in cache"];
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
    NSString *soupTableName = [_soupNameToTableName objectForKey:soupName];
    
    if (nil == soupTableName) {
        NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_ATTRS_TABLE,SOUP_NAME_COL];
        FMResultSet *frs = [self executeQueryThrows:sql withArgumentsInArray:@[soupName] withDb:db];
        if ([frs next]) {
            int colIdx = [frs columnIndexForName:ID_COL];
            long soupId = [frs longForColumnIndex:colIdx];
            soupTableName = [self tableNameBySoupId:soupId];
            
            // update cache
            [_soupNameToTableName setObject:soupTableName forKey:soupName];
        } else {
            [SFSDKSmartStoreLogger d:[self class] format:@"No table for: '%@'", soupName];
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

- (NSArray*)indicesForSoup:(NSString*)soupName {
    __block NSArray* result;
    [self inDatabase:^(FMDatabase * db) {
        result = [self indicesForSoup:soupName withDb:db];
    } error:nil];
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
        [SFSDKSmartStoreLogger d:[self class] format:@"indices sql: %@", querySql];
        FMResultSet *frs = [self executeQueryThrows:querySql withArgumentsInArray:@[soupName] withDb:db];
        while([frs next]) {
            NSString *path = [frs stringForColumn:PATH_COL];
            NSString *columnName = [frs stringForColumn:COLUMN_NAME_COL];
            NSString *type = [frs stringForColumn:COLUMN_TYPE_COL];
            SFSoupIndex *spec = [[SFSoupIndex alloc] initWithPath:path indexType:type columnName:columnName];
            [result addObject:spec];
        }
        [frs close];
        
        // update the cache
        [_indexSpecsBySoup setObject:result forKey:soupName];
    }
    if (!(result.count > 0)) {
        [SFSDKSmartStoreLogger d:[self class] format:@"no indices for '%@'", soupName];
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

- (NSString *)registerNewSoupWithName:(NSString*)soupName withDb:(FMDatabase*) db {
    NSMutableDictionary *soupMapValues = [[NSMutableDictionary alloc] initWithObjectsAndKeys:soupName, SOUP_NAME_COL, nil];
    [self insertIntoTable:SOUP_ATTRS_TABLE values:soupMapValues withDb:db];
    // Get a safe table name for the soupName
    NSString *soupTableName = [self tableNameBySoupId:[db lastInsertRowId]];
    if (nil == soupTableName) {
        [SFSDKSmartStoreLogger d:[self class] format:@"couldn't properly register soupName: '%@' ", soupName];
    }
    return soupTableName;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs error:(NSError**)error {
    NSError *localError = nil;
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self registerSoupWithName:soupName withIndexSpecs:indexSpecs withSoupTableName:nil withDb:db];
    } error:&localError];
    
    if (error) {
        *error = localError;
    }

    if (localError) {
        return NO;
    }
    return YES;
}

- (void)registerSoupWithName:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs withSoupTableName:(NSString*) soupTableName withDb:(FMDatabase*) db
{
    //verify soupName
    if (!([soupName length] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus soupName" reason:soupName userInfo:nil];
    }
    //verify indexSpecs
    if (!([indexSpecs count] > 0)) {
        @throw [NSException exceptionWithName:@"Bogus indexSpecs" reason:nil userInfo:nil];
    }
    
    // If soup with same name already exists, just return success.
    if ([self soupExists:soupName withDb:db]) {
        return;
    }
    
    BOOL soupUsesJSON1 = [SFSoupIndex hasJSON1:indexSpecs];
   
    if (nil == soupTableName) {
        soupTableName = [self registerNewSoupWithName:soupName withDb:db];
    }
    NSMutableArray *soupIndexMapInserts = [[NSMutableArray alloc] init ];
    NSMutableArray *createIndexStmts = [[NSMutableArray alloc] init ];
    NSMutableString *createTableStmt = [[NSMutableString alloc] init];
    [createTableStmt appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (",soupTableName];
    [createTableStmt appendFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT",ID_COL];
    [createTableStmt appendFormat:@", %@ TEXT",SOUP_COL]; //this is the column where the raw json is stored
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
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
        values[SOUP_NAME_COL] = soupName;
        values[PATH_COL] = indexSpec.path;
        values[COLUMN_NAME_COL] = columnName;
        values[COLUMN_TYPE_COL] = indexSpec.indexType;
        [soupIndexMapInserts addObject:values];
        
        // for creating an index on the soup table
        [createIndexStmts addObject:[NSString stringWithFormat:createIndexFormat, soupTableName, [NSString stringWithFormat:@"%u", i], soupTableName, columnName]];
    }
    
    [createTableStmt appendString:@")"];
    [SFSDKSmartStoreLogger d:[self class] format:@"createTableStmt: %@", createTableStmt];
    
    // fts
    if (columnsForFts.count > 0) {
        [createFtsStmt appendFormat:@"CREATE VIRTUAL TABLE %@_fts USING fts%u(%@)", soupTableName, (unsigned)self.ftsExtension, [columnsForFts componentsJoinedByString:@","]];
        [SFSDKSmartStoreLogger d:[self class] format:@"createFtsStmt: %@", createFtsStmt];
    }
    
    // create the main soup table
    [self  executeUpdateThrows:createTableStmt withDb:db];

    // fts
    if (columnsForFts.count > 0) {
        [self executeUpdateThrows:createFtsStmt withDb:db];
    }
    
    // create indices for this soup
    for (NSString *createIndexStmt in createIndexStmts) {
        [SFSDKSmartStoreLogger d:[self class] format:@"createIndexStmt: %@", createIndexStmt];
        [self executeUpdateThrows:createIndexStmt withDb:db];
    }
    [self insertIntoSoupIndexMap:soupIndexMapInserts withDb:db];

    // Logs analytics event.
    NSMutableArray<NSString *> *features = [[NSMutableArray alloc] init];
    if (soupUsesJSON1) {
        [features addObject:@"JSON1"];
    }
    if ([SFSoupIndex hasFts:indexSpecs]) {
        [features addObject:@"FTS"];
    }
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"features"] = features;
    [SFSDKEventBuilderHelper createAndStoreEvent:@"registerSoup" userAccount:self.user className:NSStringFromClass([self class]) attributes:attributes];
}

- (void)removeSoup:(NSString*)soupName {
    [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeSoup:soupName withDb:db];
    } error:nil];
}

- (void)removeSoup:(NSString*)soupName withDb:(FMDatabase*)db {
    [SFSDKSmartStoreLogger d:[self class] format:@"removeSoup: %@", soupName];
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    if (nil == soupTableName)
        return;
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
    
    // Cleanup caches
    [self removeFromCache:soupName];
}

- (void)removeAllSoups
{
    [self inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [self removeAllSoupWithDb:db];
    } error:nil];
}

- (void)removeFromCache:(NSString*) soupName {
    [_indexSpecsBySoup removeObjectForKey:soupName ];
    [_soupNameToTableName removeObjectForKey:soupName ];
    [_smartSqlToSql removeEntriesForSoup:soupName ];
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
                                     error:(NSError * __autoreleasing *)error
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

- (NSNumber*)countWithQuerySpec:(SFQuerySpec*)querySpec error:(NSError **)error;
{
    __block NSInteger result;
    [self inDatabase:^(FMDatabase* db) {
        result = [self countWithQuerySpec:querySpec withDb:db];
    } error:error];
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec withDb:(FMDatabase*)db
{
    [SFSDKSmartStoreLogger d:[self class] format:@"countWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSUInteger result = 0;
    
    // SQL
    NSString* countSql = [self convertSmartSql:querySpec.countSmartSql withDb:db];
    [SFSDKSmartStoreLogger d:[self class] format:@"countWithQuerySpec: countSql:%@ \n", countSql];

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
    return [self queryWithQuerySpec:querySpec pageIndex:pageIndex whereArgs:nil error:error];
}

- (NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex whereArgs:(NSArray*)whereArgs error:(NSError **)error
{
    if (whereArgs != nil && querySpec.queryType != kSFSoupQueryTypeSmart) {
        *error = [NSError errorWithDomain:kSFSmartStoreErrorDomain
                                     code:kSFSmartStoreWhereArgsNotSupportedCode
                                 userInfo:@{NSLocalizedDescriptionKey: kSFSmartStoreWhereArgsNotSupportedDescription}];
        return nil;
    }
    
    __block NSMutableArray* resultArray = [NSMutableArray new];
    BOOL succ = [self inDatabase:^(FMDatabase* db) {
        [self runQuery:resultArray resultString:nil querySpec:querySpec pageIndex:pageIndex whereArgs:whereArgs withDb:db];
    } error:error];
    if (succ) {
        return resultArray;
    } else {
        return nil;
    }
}

- (BOOL) queryAsString:(NSMutableString*)resultString querySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error NS_SWIFT_NAME(query(result:querySpec:pageIndex:))
{
    return [self inDatabase:^(FMDatabase* db) {
        [self runQuery:nil resultString:resultString querySpec:querySpec pageIndex:pageIndex whereArgs:nil withDb:db];
    } error:error];
}

- (void)runQuery:(NSMutableArray*)resultArray resultString:(NSMutableString*)resultString querySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex whereArgs:(NSArray*)whereArgs withDb:(FMDatabase*)db
{
    NSAssert(resultArray != nil ^ resultString != nil, @"resultArray or resultString must be non-nil, but not both at the same times.");
    BOOL computeResultAsString = resultString != nil;
    
    // Page
    NSUInteger offsetRows = querySpec.pageSize * pageIndex;
    NSUInteger numberRows = querySpec.pageSize;
    NSString* limit = [NSString stringWithFormat:@"%lu,%lu",(unsigned long)offsetRows,(unsigned long)numberRows];
    
    // SQL
    NSString* sql = [self convertSmartSql: querySpec.smartSql withDb:db];
    NSString* limitSql = [@[@"SELECT * FROM (", sql, @") LIMIT ", limit] componentsJoinedByString:@""];
    
    // Args
    NSArray* args = querySpec.queryType != kSFSoupQueryTypeSmart ? [querySpec bindsForQuerySpec] : whereArgs;
    
    // Executing query
    FMResultSet *frs = [self executeQueryThrows:limitSql withArgumentsInArray:args withDb:db];
    NSMutableArray *resultStrings = [NSMutableArray array];
    NSUInteger currentRow = 0;
    while ([frs next]) {
        currentRow++;
        
        // Smart queries
        if (querySpec.queryType == kSFSoupQueryTypeSmart || querySpec.selectPaths != nil) {
            if (computeResultAsString) {
                NSMutableString *rowData = [NSMutableString new];
                [self getDataFromRow:nil resultString:rowData resultSet:frs];
                if (rowData) {
                    [resultStrings addObject:rowData];
                }
            } else {
                NSMutableArray *rowData = [NSMutableArray new];
                [self getDataFromRow:rowData resultString:nil resultSet:frs];
                if (rowData) {
                    [resultArray addObject:rowData];
                }
            }
        }
        // Exact/like/range queries
        else {
            NSString* rawJson;
            NSString *columnName = [frs columnNameForIndex:0];
            if ([columnName isEqualToString:SOUP_COL]) {
                rawJson = [frs stringForColumnIndex:0];
            }
            if (computeResultAsString) {
                if (rawJson) {
                    [resultStrings addObject:rawJson];
                }
            } else {
                id entry = [SFJsonUtils objectFromJSONString:rawJson];
                if (entry) {
                    [resultArray addObject:entry];
                }
            }
        }
    }
    [frs close];
    
    if (computeResultAsString) {
        [resultString appendString:@"["];
        [resultString appendString:[resultStrings componentsJoinedByString:@","]];
        [resultString appendString:@"]"];
    }
}

- (void) getDataFromRow:(NSMutableArray*)resultArray resultString:(NSMutableString*)resultString resultSet:(FMResultSet*)frs
{
    NSAssert(resultArray != nil ^ resultString != nil, @"resultArray or resultString must be non-nil, but not both at the same times.");
    BOOL computeResultAsString = resultString != nil;
    NSDictionary* valuesMap = [frs resultDictionary];
    NSMutableArray *resultStrings = [NSMutableArray array];
    
    for (int i = 0; i < frs.columnCount; i++) {
        @autoreleasepool {
            NSString* columnName = [frs columnNameForIndex:i];
            id value = valuesMap[columnName];
            
            BOOL isSoupCol = [value isKindOfClass:[NSString class]] &&
            ([columnName isEqualToString:SOUP_COL] || [columnName hasPrefix:[NSString stringWithFormat:@"%@:", SOUP_COL]]);
            
            // If this is a soup column then the value is a serialized json
            if (isSoupCol) {
                if (computeResultAsString) {
                    if (value) {
                        [resultStrings addObject:value];
                    } else {
                        // This is a smart query, we can't skip
                        // If you do select x,y,z, then you expect 3 values per row in the result set
                        [resultStrings addObject:@"null"];
                    }
                } else {
                    id entry = [SFJsonUtils objectFromJSONString:value];
                    if (entry) {
                        [resultArray addObject:entry];
                    } else {
                        // This is a smart query, we can't skip
                        // If you do select x,y,z, then you expect 3 values per row in the result set
                        [resultStrings addObject:[NSNull null]];
                    }
                }
            }
            // Otherwise the value is an atomic type
            else {
                if (computeResultAsString) {
                    if ([value isKindOfClass:[NSNull class]]) {
                        [resultStrings addObject:@"null"];
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        [resultStrings addObject:[((NSNumber*)value) stringValue]];
                    }
                    else if ([value isKindOfClass:[NSString class]]) {
                        NSString *escapedAndQuotedValue = [self escapeStringValueAndQuote:(NSString*) value];
                        if (escapedAndQuotedValue) {
                            [resultStrings addObject:escapedAndQuotedValue];
                        } else {
                            // This is a smart query, we can't skip
                            // If you do select x,y,z, then you expect 3 values per row in the result set
                            [resultStrings addObject:@"null"];
                        }
                    }

                } else {
                    [resultArray addObject:value];
                }
            }
        }
    }
    
    if (computeResultAsString) {
        [resultString appendString:@"["];
        [resultString appendString:[resultStrings componentsJoinedByString:@","]];
        [resultString appendString:@"]"];
    }
}

-(NSString*) escapeStringValueAndQuote:(NSString*) raw {
    NSMutableString* escaped = [NSMutableString new];
    [escaped appendString:@"\""];
    for (NSUInteger i = 0; i < raw.length; i += 1) {
        unichar c = [raw characterAtIndex:i];
        switch (c) {
            case '\\':
            case '/':
            case '"':
                [escaped appendFormat:@"\\%C", c];
                break;
            case '\b':
                [escaped appendString:@"\\b"];
                break;
            case '\f':
                [escaped appendString:@"\\f"];
                break;
            case '\n':
                [escaped appendString:@"\\n"];
                break;
            case '\r':
                [escaped appendString:@"\\r"];
                break;
            case '\t':
                [escaped appendString:@"\\t"];
                break;
            default:
                if (c < ' ') {
                    [escaped appendFormat:@"\\u%04x", c];
                } else {
                    [escaped appendFormat:@"%C", c];
                }
        }
    }
    [escaped appendString:@"\""];
    
    if (![self checkRawJson:[NSString stringWithFormat:@"[%@]", escaped] fromMethod:NSStringFromSelector(_cmd)]) {
        return nil;
    } else {
        return [NSString stringWithString:escaped];
    }
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
        [SFSDKSmartStoreLogger d:[self class] format:@"Soup: '%@' does not exist", soupName];
        return result;
    }
    
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
    
    return result;
}

- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices withDb:(FMDatabase*) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    NSNumber *newEntryId;
    
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
    //now update the SOUP_COL (raw json) for the soup entry
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    values[SOUP_COL] = rawJson;
    
    //build up the set of index column values for this new row
    [self projectIndexedPaths:entry values:values indices:indices typeFilter:kValueExtractedToColumn];
    [self insertIntoTable:soupTableName values:values withDb:db];

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
                         indices:(NSArray *)indices
                          withDb:(FMDatabase *) db
{
    NSNumber *nowVal = [self currentTimeInMilliseconds];
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    nowVal, LAST_MODIFIED_COL,
                                    nil];
    
    //build up the set of index column values for this row
    [self projectIndexedPaths:entry values:values indices:indices typeFilter:kValueExtractedToColumn];
    
    //clone the entry so that we can modify SOUP_LAST_MODIFIED_DATE
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    [mutableEntry setValue:entryId forKey:SOUP_ENTRY_ID];

    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    values[SOUP_COL] = rawJson;
	
    [self updateTable:soupTableName values:values entryId:entryId idCol:ID_COL withDb:db];
    
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
                [SFSDKSmartStoreLogger d:[self class] format:@"%@", errorMsg];
                return nil;
            }
        }
    }
    
    if (nil != soupEntryId) {
        //entry already has an entry id: update
        result = [self updateOneEntry:entry
                          withEntryId:soupEntryId
                          inSoupTable:soupTableName
                              indices:indices
                               withDb:db];
    } else {
        //no entry id: insert
        result = [self insertOneEntry:entry
                          inSoupTable:soupTableName
                              indices:indices
                               withDb:db];
    }
    
    return result;
}



- (NSArray *)upsertEntries:(NSArray *)entries toSoup:(NSString *)soupName
{
    return [self upsertEntries:entries toSoup:soupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
}

- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError * __autoreleasing *)error
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

- (BOOL)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName error:(NSError**)error
{
    return [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
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
    }
}

- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName
{
    [self removeEntriesByQuery:querySpec fromSoup:soupName error:nil];
}

- (BOOL)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName error:(NSError**)error
{
    return [self inTransaction:^(FMDatabase* db, BOOL* rollback) {
        [self removeEntriesByQuery:querySpec fromSoup:soupName withDb:db];
    } error:error];
}

- (void)removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName withDb:(FMDatabase*) db
{
    NSString *soupTableName = [self tableNameForSoup:soupName withDb:db];
    NSString* querySql = [self convertSmartSql: querySpec.idsSmartSql withDb:db];
    NSString* limitSql = [NSString stringWithFormat:@"SELECT * FROM (%@) LIMIT %lu", querySql, (unsigned long)querySpec.pageSize];
    NSArray* args = [querySpec bindsForQuerySpec];
    
    NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ in (%@)", soupTableName, ID_COL, limitSql];
    [self executeUpdateThrows:deleteSql withArgumentsInArray:args withDb:db];
    // fts
    if ([self hasFts:soupName withDb:db]) {
        NSString *deleteFtsSql = [NSString stringWithFormat:@"DELETE FROM %@_fts WHERE %@ in (%@)", soupTableName, ROWID_COL, querySql];
        [self executeUpdateThrows:deleteFtsSql withDb:db];
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
    }
}

- (unsigned long long)getDatabaseSize
{
    unsigned long long size = 0;
    NSString *dbPath = [self.dbMgr fullDbFilePathForStoreName:_storeName];
    size = [[[NSFileManager defaultManager] attributesOfItemAtPath:dbPath error:nil] fileSize];
    return size;
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

        NSArray *queryCols = @[ID_COL, SOUP_COL];

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
            @autoreleasepool {
                NSNumber *entryId = @([frs longForColumn:ID_COL]);
                NSDictionary *entry;
                NSString *soupElt = [frs stringForColumn:SOUP_COL];
                entry = [SFJsonUtils objectFromJSONString:soupElt];
                
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

+ (void)setJsonSerializationCheckEnabled:(BOOL)jsonSerializationCheckEnabled {
    _jsonSerializationCheckEnabled = jsonSerializationCheckEnabled;
}

+ (void)setPostRawJsonOnError:(BOOL)postRawJsonOnError {
    _postRawJsonOnError = postRawJsonOnError;
}

+(BOOL) isJsonSerializationCheckEnabled {
    return _jsonSerializationCheckEnabled;
}

#pragma mark - Misc

- (void) projectIndexedPaths:(NSDictionary*)entry values:(NSMutableDictionary*)values indices:(NSArray*)indices typeFilter:(SFIndexSpecTypeFilterBlock)typeFilter
{
    // build up the set of index column values for this row
    for (SFSoupIndex *idx in indices) {
        if (!typeFilter(idx))
            continue;
        
        id indexColVal = [SFJsonUtils projectIntoJson:entry path:[idx path]];
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
            [SFSDKSmartStoreLogger d:[self class] format:@"renameSoupNamesTableSql: %@", renameSoupNamesTableSql];
            [self executeUpdateThrows:renameSoupNamesTableSql withDb:db];
        }
    } error:nil];
}

#pragma mark - Misc info methods
- (NSArray*) getRuntimeSettings
{
    return [self queryPragma:@"cipher_settings"];
}

- (NSArray*) getCompileOptions
{
    return [self queryPragma:@"compile_options"];
}

- (NSString*) getSQLCipherVersion
{
    return [[self queryPragma:@"cipher_version"] componentsJoinedByString:@""];
}

- (NSArray*) queryPragma:(NSString*) pragma
{
    __block NSMutableArray* result = [NSMutableArray new];

    [self.storeQueue inDatabase:^(FMDatabase *db) {

        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"pragma %@", pragma]];

        while ([rs next]) {
            [result addObject:[rs stringForColumnIndex:0]];
        }

        [rs close];
    }];

    return result;
}

@end
