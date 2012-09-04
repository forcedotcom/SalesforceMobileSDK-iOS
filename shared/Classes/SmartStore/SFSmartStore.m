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
#import "SFJsonUtils.h"
#import "SFSmartStore.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupCursor.h"
#import "SFSoupIndex.h"
#import "SFSoupQuerySpec.h"
#import "SFPasscodeManager.h"
#import "SFSmartStoreDatabaseManager.h"
#import "UIDevice+SFHardware.h"
#import "NSString+SFAdditions.h"
#import "NSData+SFAdditions.h"



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

static const char *const_key = "H347ergher/32hhj5%hff?Dn@21o";
static NSString * const kDefaultPasscodeStoresKey = @"com.salesforce.smartstore.defaultPasscodeStores";

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


@synthesize storeDb = _storeDb;
@synthesize storeName = _storeName;

- (id) initWithName:(NSString*)name {
    self = [super init];
    
    if (nil != self)  {
        NSLog(@"SFSmartStore initWithStoreName: %@",name);
        
         _storeName = [name retain];
        //Setup listening for data protection available / unavailable
        _dataProtectionKnownAvailable = NO;
        //we use this so that addObserverForName doesn't retain us
        __block SFSmartStore *this = self;
        _dataProtectAvailObserverToken = [[NSNotificationCenter defaultCenter] 
                                          addObserverForName:UIApplicationProtectedDataDidBecomeAvailable 
                                          object:nil
                                          queue:nil 
                                          usingBlock:^(NSNotification *note) {
                                              NSLog(@"SFSmartStore UIApplicationProtectedDataDidBecomeAvailable");
                                              this->_dataProtectionKnownAvailable = YES;
                                          }];
        
        _dataProtectUnavailObserverToken = [[NSNotificationCenter defaultCenter] 
                                            addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable 
                                            object:nil
                                            queue:nil 
                                            usingBlock:^(NSNotification *note) {
                                                NSLog(@"SFSmartStore UIApplicationProtectedDataWillBecomeUnavailable");
                                                this->_dataProtectionKnownAvailable = NO;
                                            }];
        
                
        _indexSpecsBySoup = [[NSMutableDictionary alloc] init];

        if (![self.class persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                [self release];
                self = nil;
            }
        } else {
            if (![self openStoreDatabase:NO]) {
                [self release];
                self = nil;
            }
        }
        

    }
    return self;
}




- (void)dealloc {    
    NSLog(@"dealloc store: '%@'",_storeName);
    
    [self.storeDb close]; [_storeDb release]; _storeDb = nil;
    [_indexSpecsBySoup release] ; _indexSpecsBySoup = nil;
    
    //remove data protection observer
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectAvailObserverToken];
    _dataProtectAvailObserverToken = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectUnavailObserverToken];
    _dataProtectUnavailObserverToken = nil;
    
    [_storeName release]; _storeName = nil;
    
    [super dealloc];
}


- (BOOL)firstTimeStoreDatabaseSetup {
    BOOL result = NO;
    NSError *createErr = nil, *protectErr = nil;

    if (![self isFileDataProtectionActive]) {
        //This is expected on simulator and when user does not have unlock passcode set 
        NSLog(@"WARNING file data protection inactive when creating store db.");
    }
    
    // Ensure that the store directory exists.
    [[SFSmartStoreDatabaseManager sharedManager] createStoreDir:self.storeName error:&createErr];
    if (nil == createErr) {
        //need to create the db file itself before we can encrypt it
        if ([self openStoreDatabase:YES]) {
            if ([self createMetaTables]) {
                [self.storeDb close]; [_storeDb release]; _storeDb = nil; // Need to close before setting encryption.
                [[SFSmartStoreDatabaseManager sharedManager] protectStoreDir:self.storeName error:&protectErr];
                if (protectErr != nil) {
                    NSLog(@"Couldn't protect store: %@", protectErr);
                } else {
                    //reopen the storeDb now that it's protected
                    result = [self openStoreDatabase:NO];
                }
            }
        }
    } 
    
    if (!result) {
        NSLog(@"Deleting store dir since we can't set it up properly: %@", self.storeName);
        [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:self.storeName];
        [self.class setUsesDefaultKey:NO forStore:self.storeName];
    }
    return result;
}

- (BOOL)openStoreDatabase:(BOOL)forCreation {
    NSString * const kOpenExistingDatabaseError = @"Error opening existing store '%@': %@";
    NSString * const kCreateDatabaseError       = @"Error creating store '%@': %@";
    NSString * const kEncryptDatabaseError      = @"Error encrypting unencrypted store '%@': %@";
    FMDatabase *db = nil;
    BOOL result = NO;
    NSError *openDbError = nil;
    
    // If there's a bona fide user-defined passcode key, we assume that any existing databases have already
    // been updated (if necessary) as the result of the passcode addition/change.  Otherwise, we have to do
    // some special casing around default passcodes.
    NSString *key = [self.class encKey];
    if (key != nil && [key length] > 0) {
        // User-defined key.  Create or open the database with that.
        db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
        if (db) {
            self.storeDb = db;
            result = YES;
        } else {
            NSLog(kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]);
        }
    } else if (forCreation) {
        // For creation, we can just set the default key from the start.
        key = [self.class defaultKey];
        db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
        if (db) {
            self.storeDb = db;
            [self.class setUsesDefaultKey:YES forStore:self.storeName];
            result = YES;
        } else {
            NSLog(kCreateDatabaseError, self.storeName, [openDbError localizedDescription]);
        }
    } else {
        // For existing databases, we may need to update to the default encryption, if not updated already.
        key = [self.class defaultKey];
        if (![self.class usesDefaultKey:self.storeName]) {
            // This DB is unencrypted.  Encrypt it before proceeding.
            db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:@"" error:&openDbError];
            if (!db) {
                NSLog(kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]);
            } else {
                NSError *encryptDbError = nil;
                db = [[SFSmartStoreDatabaseManager sharedManager] encryptDb:db name:self.storeName key:key error:&encryptDbError];
                if (encryptDbError) {
                    NSLog(kEncryptDatabaseError, self.storeName, [encryptDbError localizedDescription]);
                } else {
                    self.storeDb = db;
                    [self.class setUsesDefaultKey:YES forStore:self.storeName];
                    result = YES;
                }
            }
        } else {
            // Already uses the default encryption key.  Open with that.
            db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
            if (db) {
                self.storeDb = db;
                result = YES;
            } else {
                NSLog(kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]);
            }
        }
    }
    
    return result;
}

#pragma mark - Store methods


+ (BOOL)persistentStoreExists:(NSString*)storeName {
    return [[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName];
}


+ (id)sharedStoreWithName:(NSString*)storeName {
    if (nil == _allSharedStores) {
        _allSharedStores = [[NSMutableDictionary alloc] init];
    }
    
    id store = [_allSharedStores objectForKey:storeName];
    if (nil == store) {
        store = [[SFSmartStore alloc] initWithName:storeName];
        if (store)
            [_allSharedStores setObject:store forKey:storeName];
        [store release]; //the store is retained by _allSharedStores so we can return it
    }
    
    return store;
}

+ (void)removeSharedStoreWithName:(NSString*)storeName {
    NSLog(@"removeSharedStoreWithName: %@", storeName);
    SFSmartStore *existingStore = [_allSharedStores objectForKey:storeName];
    if (nil != existingStore) {
        [existingStore.storeDb close];
        [_allSharedStores removeObjectForKey:storeName];
    }
    [self.class setUsesDefaultKey:NO forStore:storeName];
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
}

+ (void)removeAllStores {
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    for (NSString *storeName in allStoreNames) {
        [self removeSharedStoreWithName:storeName];
    }
}

+ (void)clearSharedStoreMemoryState
{
    [_allSharedStores removeAllObjects];
}

+ (void)changeKeyForStores:(NSString *)oldKey newKey:(NSString *)newKey
{
    if (oldKey == nil) oldKey = @"";
    if (newKey == nil) newKey = @"";
    
    // If the keys are the same, no work to be done.
    if ([oldKey isEqualToString:newKey])
        return;
    
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    for (NSString *storeName in allStoreNames) {
        SFSmartStore *currentStore = [_allSharedStores objectForKey:storeName];
        if (currentStore != nil) {
            // Existing store (whose DB should be initialized and open, if it's in _allSharedStores).
            NSLog(@"Updating key for opened store '%@'", storeName);
            FMDatabase *updatedDb = [self changeKeyForDb:currentStore.storeDb name:storeName oldKey:oldKey newKey:newKey];
            currentStore.storeDb = updatedDb;
        } else {
            // Store database is not resident in memory.  Open it long enough to make the change, then close it.
            NSLog(@"Updating key for store '%@' on filesystem", storeName);
            NSString *keyUsedToOpen;
            if ([oldKey length] == 0) {
                // No old key.  Are we using the default key?
                if ([self usesDefaultKey:storeName]) {
                    keyUsedToOpen = [self defaultKey];
                } else {
                    keyUsedToOpen = @"";
                }
            } else {
                // There's a previously-defined key.  Use that.
                keyUsedToOpen = oldKey;
            }
            NSError *openError = nil;
            FMDatabase *nonStoreDb = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:storeName
                                                                                                        key:keyUsedToOpen
                                                                                                      error:&openError];
            if (nonStoreDb == nil || openError != nil) {
                NSLog(@"Error opening store '%@' to update encryption: %@", storeName, [openError localizedDescription]);
            } else {
                nonStoreDb = [self changeKeyForDb:nonStoreDb name:storeName oldKey:oldKey newKey:newKey];
            }
            [nonStoreDb close];
        }
    }
}

+ (FMDatabase *)changeKeyForDb:(FMDatabase *)db name:(NSString *)storeName oldKey:(NSString *)oldKey newKey:(NSString *)newKey
{
    NSString * const kEncryptionChangeErrorMessage = @"Error changing the encryption key for store '%@': %@";
    NSString * const kNewEncryptionErrorMessage = @"Error encrypting the unencrypted store '%@': %@";
    
    // NB: Assumes keys have already been checked for equality, and that they're not equal.  Ergo if
    // oldKey is empty, newKey is not.
    if (oldKey == nil || [oldKey length] == 0) {
        // No old key originally.  See if we're using the default key.
        if ([self usesDefaultKey:storeName]) {
            BOOL rekeyResult = [db rekey:newKey];
            if (!rekeyResult) {
                NSLog(kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]);
            } else {
                [self setUsesDefaultKey:NO forStore:storeName];
            }
            return db;
        } else {
            // No default key either, which means there's no encryption for this store.  Need to encrypt it.
            NSError *encryptDbError = nil;
            db = [[SFSmartStoreDatabaseManager sharedManager] encryptDb:db name:storeName key:newKey error:&encryptDbError];
            if (encryptDbError != nil) {
                NSLog(kNewEncryptionErrorMessage, storeName, [encryptDbError localizedDescription]);
            }
            return db;
        }
    } else {
        // DB is already encrypted with a user-defined key.
        if (newKey != nil && [newKey length] > 0) {
            // User-defined new key.
            BOOL rekeyResult = [db rekey:newKey];
            if (!rekeyResult) {
                NSLog(kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]);
            }
            return db;
        } else {
            // New key is empty.  Revert to default encryption.
            NSString *defaultKey = [self defaultKey];
            BOOL rekeyResult = [db rekey:defaultKey];
            if (!rekeyResult) {
                NSLog(kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]);
            } else {
                [self setUsesDefaultKey:YES forStore:storeName];
            }
            return db;
        }
    }
}


- (BOOL)createMetaTables {
    // Create SOUP_INDEX_MAP_TABLE
    NSString *createSoupIndexTableSql = [NSString stringWithFormat:
                                    @"CREATE TABLE IF NOT EXISTS %@ (%@ TEXT, %@ TEXT, %@ TEXT, %@ TEXT )",
                                    SOUP_INDEX_MAP_TABLE,
                                    SOUP_NAME_COL,
                                    PATH_COL,
                                    COLUMN_NAME_COL,
                                    COLUMN_TYPE_COL
                                    ];
    
    NSLog(@"createSoupIndexTableSql: %@",createSoupIndexTableSql);
            
    
    // Create SOUP_NAMES_TABLE 
    // The table name for the soup will simply be TABLE_<soupId>
    NSString *createSoupNamesTableSql = [NSString stringWithFormat:
                                    @"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT )",
                                    SOUP_NAMES_TABLE,
                                    ID_COL,
                                    SOUP_NAME_COL
                                    ];

    
    NSLog(@"createSoupNamesTableSql: %@",createSoupNamesTableSql);
    
    // Create an index for SOUP_NAME_COL in SOUP_NAMES_TABLE
    NSString *createSoupNamesIndexSql = [NSString stringWithFormat:
                                        @"CREATE INDEX %@_0 on %@ ( %@ )", 
                                         SOUP_NAMES_TABLE, SOUP_NAMES_TABLE, SOUP_NAME_COL];
    NSLog(@"createSoupNamesIndexSql: %@",createSoupNamesIndexSql);
    
    
    BOOL result = NO;
    
    @try {
        result =[self.storeDb  executeUpdate:createSoupIndexTableSql];
        if (result) {
            result =[self.storeDb  executeUpdate:createSoupNamesTableSql];
            // Add index on SOUP_NAME_COL
            if (result) {
                result = [self.storeDb executeUpdate:createSoupNamesIndexSql];
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception creating meta tables: %@", exception);
    }
    @finally {
        if (!result) {
            NSLog(@"ERROR %d creating meta tables: '%@'", 
            [self.storeDb lastErrorCode], 
            [self.storeDb lastErrorMessage] );
        }
    }
    
    
    return result;
}


#pragma mark - Utility methods

+ (BOOL)usesDefaultKey:(NSString *)storeName {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultPasscodeDict = [userDefaults objectForKey:kDefaultPasscodeStoresKey];
    
    if (defaultPasscodeDict == nil)
        return NO;
    
    NSNumber *usesDefaultKeyNum = [defaultPasscodeDict objectForKey:storeName];
    if (usesDefaultKeyNum == nil)
        return NO;
    else
        return [usesDefaultKeyNum boolValue];
}

+ (void)setUsesDefaultKey:(BOOL)usesDefault forStore:(NSString *)storeName {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultPasscodeDict = [userDefaults objectForKey:kDefaultPasscodeStoresKey];
    NSMutableDictionary *newDict;
    if (defaultPasscodeDict == nil)
        newDict = [NSMutableDictionary dictionary];
    else
        newDict = [NSMutableDictionary dictionaryWithDictionary:defaultPasscodeDict];
    
    NSNumber *usesDefaultNum = [NSNumber numberWithBool:usesDefault];
    [newDict setObject:usesDefaultNum forKey:storeName];
    [userDefaults setObject:newDict forKey:kDefaultPasscodeStoresKey];
    [userDefaults synchronize];
}

+ (NSString *)encKey
{
    NSString *key = [[SFPasscodeManager sharedManager] hashedPasscode];
    return (key == nil ? @"" : key);
}

+ (NSString *)defaultKey
{
    NSString *macAddress = [[UIDevice currentDevice] macaddress];
    NSString *constKey = [[[NSString alloc] initWithBytes:const_key length:strlen(const_key) encoding:NSUTF8StringEncoding] autorelease];
    NSString *strSecret = [macAddress stringByAppendingString:constKey];
    return [[strSecret sha256] base64Encode];
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


- (BOOL)insertIntoTable:(NSString*)tableName values:(NSDictionary*)map  {    
    // map all of the columns and values from soupIndexMapInserts
    __block NSMutableString *fieldNames = [[NSMutableString alloc] init];
    __block NSMutableArray *binds = [[NSMutableArray alloc] init];
    __block NSMutableString *fieldValueMarkers = [[NSMutableString alloc] init];
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
    //NSLog(@"upsertSql: %@ binds: %@",upsertSql,binds);
    [fieldNames release]; [fieldValueMarkers release];
    BOOL result = [self.storeDb executeUpdate:insertSql withArgumentsInArray:binds];
    [binds release];
        
    return result;
    
}

- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId
{
    NSAssert(entryId != nil, @"Entry ID must have a value.");
    
    // map all of the columns and values from soupIndexMapInserts
    __block NSMutableString *fieldEntries = [[NSMutableString alloc] init];
    __block NSMutableArray *binds = [[NSMutableArray alloc] init];
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
    //NSLog(@"upsertSql: %@ binds: %@",upsertSql,binds);
    [fieldEntries release];
    BOOL result = [self.storeDb executeUpdate:updateSql withArgumentsInArray:binds];
    [binds release];
    
    return result;
    
}


- (NSString*)columnNameForPath:(NSString*)path inSoup:(NSString*)soupName {
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
    FMResultSet *frs = [self.storeDb executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObjects:soupName, path, nil]];
    if ([frs next]) {        
        result = [frs stringForColumnIndex:0];         
    }
    [frs close];
          
    if (nil == result) {
        NSLog(@"Unknown index path '%@' in soup '%@' ",path,soupName);
    }
    return result;

}

- (NSString *)keyRangePredicateForQuerySpec:(SFSoupQuerySpec*)querySpec columnName:(NSString*)columnName
{
    NSString *result = nil;
    
    switch (querySpec.queryType) {
            
        case kSFSoupQueryTypeRange: 
            if ((nil != querySpec.beginKey) && (nil != querySpec.endKey))
                result = [NSString stringWithFormat:@"%@ >= ? AND %@ <= ?",columnName,columnName];
            else if (nil != querySpec.beginKey)
                result = [NSString stringWithFormat:@"%@ >= ?",columnName];
            else if (nil != querySpec.endKey)
                result = [NSString stringWithFormat:@"%@ <= ?",columnName];
            break;
            
        case kSFSoupQueryTypeLike:
            if (nil != querySpec.beginKey)
                result = [NSString stringWithFormat:@"%@ LIKE ? ",columnName]; 
            else 
                result = @"";
            break;
            
        case kSFSoupQueryTypeExact:
        default:
            if (nil != querySpec.beginKey)
                result = [NSString stringWithFormat:@"%@ == ?",columnName];
            else 
                result = @"";
            break;
    }
    
    return result;
}


- (NSArray *)bindsForQuerySpec:(SFSoupQuerySpec*)querySpec
{
    NSArray *result = nil;
    
    switch (querySpec.queryType) {
        case kSFSoupQueryTypeRange:
            if ((nil != querySpec.beginKey) && (nil != querySpec.endKey))
                result = [NSArray arrayWithObjects:querySpec.beginKey,querySpec.endKey, nil];
            else if (nil != querySpec.beginKey)
                result = [NSArray arrayWithObject:querySpec.beginKey];
            else if (nil != querySpec.endKey)
                result = [NSArray arrayWithObject:querySpec.endKey];
            break;
            
        case kSFSoupQueryTypeLike:
            if (nil != querySpec.beginKey)
                result = [NSArray arrayWithObject:querySpec.beginKey]; 
            break;
            
        case kSFSoupQueryTypeExact:
        default:
            if (nil != querySpec.beginKey)
                result = [NSArray arrayWithObject:querySpec.beginKey];
            break;
            
    }
    
    return result;
}

#pragma mark - Soup maniupulation methods


- (NSString*)tableNameForSoup:(NSString*)soupName {
    NSString *result  = nil;
    
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_NAMES_TABLE,SOUP_NAME_COL];
//    NSLog(@"tableName query: %@",sql);
    FMResultSet *frs = [self.storeDb executeQuery:sql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
    
    if ([frs next]) {
        NSUInteger colIdx = [frs columnIndexForName:ID_COL];
        long soupId = [frs longForColumnIndex:colIdx];
        result = [self tableNameBySoupId:soupId];
    } else {
        NSLog(@"No table for: '%@'",soupName);
    }
    [frs close];
    
    return result;
}


- (NSString *)tableNameBySoupId:(long)soupId {
    return [NSString stringWithFormat:@"TABLE_%ld",soupId];
}

- (NSArray *)tableNamesForAllSoups {
    NSMutableArray* result = [NSMutableArray array]; // equivalent to: [[[NSMutableArray alloc] init] autorelease]
    NSString* sql = [NSString stringWithFormat:@"SELECT %@ FROM %@", SOUP_NAME_COL, SOUP_NAMES_TABLE];
    FMResultSet *frs = [self.storeDb executeQuery:sql];
    while ([frs next]) {
        NSString* tableName = [frs stringForColumn:SOUP_NAME_COL];
        [result addObject:tableName];
    }

    [frs close];
    return result;
}

/**
 @param soupName the name of the soup
 @return NSArray of SFSoupIndex for the given soup
 */
- (NSArray*)indicesForSoup:(NSString*)soupName {
    //look in the cache first
    NSMutableArray *result = [_indexSpecsBySoup objectForKey:soupName];
    if (nil == result) {
        result = [NSMutableArray array];
        
        //no cached indices ...reload from SOUP_INDEX_MAP_TABLE
        NSString *querySql = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@ = ?",
                              PATH_COL, COLUMN_NAME_COL, COLUMN_TYPE_COL,
                              SOUP_INDEX_MAP_TABLE,
                              SOUP_NAME_COL];
        NSLog(@"indices sql: %@",querySql);
        FMResultSet *frs = [self.storeDb executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
        
        while([frs next]) {
            NSString *path = [frs stringForColumn:PATH_COL];
            NSString *columnName = [frs stringForColumn:COLUMN_NAME_COL];
            NSString *type = [frs stringForColumn:COLUMN_TYPE_COL];
            
            SFSoupIndex *spec = [[SFSoupIndex alloc] initWithPath:path indexType:type columnName:columnName];
            [result addObject:spec];   
            [spec release];
        }
        [frs close];
                              
        //update the cache
        [_indexSpecsBySoup setObject:result forKey:soupName];
    }
    
    if (!(result.count > 0)) {
        NSLog(@"no indices for '%@'",soupName);
    }
    return result;
}

- (BOOL)soupExists:(NSString*)soupName {
    BOOL result = NO;
    //first verify that we have this soup name in our soup names table
    NSString *soupTableName = [self tableNameForSoup:soupName];
    if (nil != soupTableName) {
        //double-check that we actually have this table
        result = [self.storeDb tableExists:soupTableName];
    }

    return result;
}


- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts {
    BOOL result = YES;
    
    // update the mapping table for this soup's columns
    for (NSDictionary *map in soupIndexMapInserts) {
        BOOL runOk = [self insertIntoTable:SOUP_INDEX_MAP_TABLE values:map ];
        if (!runOk) {
            result = NO;
            break;
        }
    }
                    
    return result;
}


- (NSString *)registerNewSoupName:(NSString*)soupName {
    NSString *soupTableName = nil;
    
    //Get a safe table name for the soupName
    NSDictionary *soupMapValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                   soupName, SOUP_NAME_COL,
                                   nil];
    
    [self.storeDb beginTransaction];
    BOOL insertSucceeded = [self insertIntoTable:SOUP_NAMES_TABLE values:soupMapValues];
    if (insertSucceeded) {
        [self.storeDb commit];
        soupTableName = [self tableNameForSoup:soupName];
    } else
        [self.storeDb rollback];
    
    if (nil == soupTableName) {
        NSLog(@"couldn't properly register soupName: '%@' ",soupName);
    }
    
    return soupTableName;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
{
    BOOL result = NO;
    
    //verify soupName
    if (!([soupName length] > 0)) {
        NSLog(@"Bogus soupName: '%@'",soupName);
        return result;
    }
    //verify indexSpecs
    if (!([indexSpecs count] > 0)) {
        NSLog(@"Bogus indexSpecs: '%@'",indexSpecs);
        return result;
    }
    
    // If soup with soupName already exists, just return success.
    if ([self soupExists:soupName]) {
        result = YES;
        return result;
    }
    
    NSString *soupTableName = [self registerNewSoupName:soupName];
    if (nil == soupTableName) {
        return result;
    } else {
        NSLog(@"==== Creating %@ ('%@') ====",soupTableName,soupName);
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
        NSString *columnName = [NSString stringWithFormat:@"%@_%d",soupTableName,i];
        NSString * columnType = [indexSpec columnType];
        [createTableStmt appendFormat:@", %@ %@ ",columnName,columnType];
        NSLog(@"adding indexPath: %@ %@  ('%@')",columnName, columnType, [indexSpec path]);
        
        // for inserting into meta mapping table
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init ];
        [values setObject:soupName forKey:SOUP_NAME_COL];
        [values setObject:indexSpec.path forKey:PATH_COL];
        [values setObject:columnName forKey:COLUMN_NAME_COL];
        [values setObject:indexSpec.indexType forKey:COLUMN_TYPE_COL];
        [indexSpec release];
        [soupIndexMapInserts addObject:values];
        [values release];
        
        // for creating an index on the soup table
        NSString *indexName = [NSString stringWithFormat:@"%@_%d_idx",soupTableName,i];
        [createIndexStmts addObject:
         [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ ON %@ ( %@ )",indexName, soupTableName, columnName]
         ];
    }
    
    [createTableStmt appendString:@")"];
    NSLog(@"createTableStmt:\n %@",createTableStmt);

    if ([self.storeDb beginTransaction]) {
        // create the main soup table
        BOOL runOk = [self.storeDb  executeUpdate:createTableStmt];
        if (!runOk) {
            NSLog(@"ERROR creating soup table  %d %@ stmt: %@", 
                  [self.storeDb lastErrorCode], 
                  [self.storeDb lastErrorMessage],
                  createTableStmt);
        } else {
            // create indices for this soup
            for (NSString *createIndexStmt in createIndexStmts) {
                NSLog(@"createIndexStmt: %@",createIndexStmt);
                runOk = [self.storeDb  executeUpdate:createIndexStmt];
                if (!runOk) {
                    NSLog(@"ERROR creating soup index  %d %@", 
                          [self.storeDb lastErrorCode], 
                          [self.storeDb lastErrorMessage] );
                    break;
                }
            }
            
            if (runOk) {
                // update the mapping table for this soup's columns
                runOk = [self insertIntoSoupIndexMap:soupIndexMapInserts]; 
            }
        }
        
        if (runOk)
            [self.storeDb commit];
        else
            [self.storeDb rollback];
        
        result = runOk;
    }
    
    [createTableStmt release];
    [createIndexStmts release];
    [soupIndexMapInserts release];
    
    return  result;
}




- (void)removeSoup:(NSString*)soupName {
    NSString *soupTableName = [self tableNameForSoup:soupName];
    if (nil == soupTableName) 
        return;
    
    @try {
        NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",soupTableName];
        [self.storeDb executeUpdate:dropSql];
        
        [self.storeDb beginTransaction];
        
        NSString *deleteIndexSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"", 
                                    SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, soupName];
        [self.storeDb executeUpdate:deleteIndexSql];
        NSString *deleteNameSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"", 
                                   SOUP_NAMES_TABLE, SOUP_NAME_COL, soupName];
        [self.storeDb executeUpdate:deleteNameSql];
        
        [self.storeDb commit];
                    
        [_indexSpecsBySoup removeObjectForKey:soupName ];
         

        

    }
    @catch (NSException *exception) {
        NSLog(@"exception removing soup: %@", exception);
        [self.storeDb rollback];
    }


}

 - (void)removeAllSoups {
    NSArray* soupTableNames = [self tableNamesForAllSoups];
    if (nil == soupTableNames)
        return;
    for (NSString* soupTableName in soupTableNames) {
        [self removeSoup:soupTableName];
    }
 }

- (NSNumber *)lookupSoupEntryIdForSoupName:(NSString *)soupName
                             soupTableName:(NSString *)soupTableName
                  forFieldPath:(NSString *)fieldPath
                    fieldValue:(NSString *)fieldValue
                         error:(NSError **)error
{
    NSAssert(soupName != nil && [soupName length] > 0, @"Soup name must have a value.");
    NSAssert(soupTableName != nil && [soupTableName length] > 0, @"Soup table name must have a value.");
    NSAssert(fieldPath != nil && [fieldPath length] > 0, @"Field path must have a value.");
    
    NSString *fieldPathColumnName = [self columnNameForPath:fieldPath inSoup:soupName];
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
                             whereArgs:(fieldValue != nil ? [NSArray arrayWithObject:fieldValue] : nil)];
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

- (FMResultSet *)queryTable:(NSString*)table 
                 forColumns:(NSArray*)columns 
                    orderBy:(NSString*)orderBy 
                      limit:(NSString*)limit 
                whereClause:(NSString*)whereClause 
                  whereArgs:(NSArray*)whereArgs 
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
    FMResultSet *frs = [self.storeDb executeQuery:sql withArgumentsInArray:whereArgs];
    return frs;
}

- (NSArray *)querySoup:(NSString*)soupName withQuerySpec:(SFSoupQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex
{
    NSString *soupTableName = [self tableNameForSoup:soupName];
    if (nil == soupTableName) {
        NSLog(@"Soup: '%@' does not exist",soupName);
        return nil;
    }
    
    FMResultSet *frs = nil;
    NSString *columnName = [self columnNameForPath:querySpec.path inSoup:soupName];
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:querySpec.pageSize];

    // Page
    NSUInteger offsetRows = querySpec.pageSize * pageIndex;
    NSUInteger numberRows = querySpec.pageSize;
    NSString *limit = [NSString stringWithFormat:@"%d,%d",offsetRows,numberRows];
    NSString *orderBy = [NSString stringWithFormat:@"%@ %@",columnName,querySpec.sqlSortOrder];
    NSArray *fetchCols = [NSArray arrayWithObject:SOUP_COL];
    
    if ((nil == querySpec.beginKey) && (nil == querySpec.endKey)) {
        // Get all the rows
        frs = [self queryTable:soupTableName 
                    forColumns:fetchCols 
                       orderBy:orderBy 
                         limit:limit 
                   whereClause:nil 
                     whereArgs:nil
               ];
    } else {
        NSArray *binds = nil;
        NSString *keyRangePredicate = [self keyRangePredicateForQuerySpec:querySpec columnName:columnName];
        if ([keyRangePredicate length] > 0) {
            binds = [self bindsForQuerySpec:querySpec];
        }
        // Get a range of rows (between beginKey and endKey)
        frs = [self queryTable:soupTableName 
                    forColumns:fetchCols 
                       orderBy:orderBy 
                         limit:limit 
                   whereClause:keyRangePredicate 
                     whereArgs:binds
               ];
    }
    
    while ([frs next]) {
        NSString *rawJson = [frs stringForColumn:SOUP_COL];
        //TODO we do not (yet?) support projections 
        NSDictionary *soupElt = [SFJsonUtils objectFromJSONString:rawJson];
        if (nil != soupElt) {
            [result addObject:soupElt];
        }
    }
    [frs close];
    
    return result;
}


    
- (SFSoupCursor *)querySoup:(NSString*)soupName withQuerySpec:(NSDictionary *)spec
{
    if (![self soupExists:soupName]) {
        NSLog(@"Soup: '%@' does not exist",soupName);
        return nil;
    }
    
    SFSoupQuerySpec *querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:spec];
    if (nil == querySpec) {
        return nil;
    }
    
    NSUInteger totalEntries = [self  countEntriesInSoup:soupName withQuerySpec:querySpec];
    if ((0 == totalEntries) && (nil != querySpec.path)) {
        NSString *columnName = [self columnNameForPath:querySpec.path inSoup:soupName];
        if (nil == columnName) {
            //asking for a query on an index that doesn't exist
            [querySpec release];
            return nil;
        }
    }
    
    SFSoupCursor *result = [[SFSoupCursor alloc] initWithSoupName:soupName store:self querySpec:querySpec totalEntries:totalEntries];
    [querySpec release];
    
    return [result autorelease];
}


- (NSUInteger)countEntriesInSoup:(NSString *)soupName withQuerySpec:(SFSoupQuerySpec*)querySpec 
{
    NSString *soupTableName = [self tableNameForSoup:soupName];
    if (nil == soupTableName) {
        NSLog(@"Soup: '%@' does not exist",soupName);
        return 0;
    }
    
    NSString *columnName = nil;
    NSString *indexPath = [querySpec path];
    
    if (nil != indexPath) {
        columnName = [self columnNameForPath:indexPath inSoup:soupName];
        if (nil == columnName) {
            //asking for a query on an index that doesn't exist
            NSLog(@"soup '%@' has no index named '%@' ",soupName,indexPath);
            return 0;
        }
    }

    
    NSString *querySql = nil;
    FMResultSet *frs = nil;
    NSArray *binds = nil;
    NSString *keyRangePredicate = [self keyRangePredicateForQuerySpec:querySpec columnName:columnName];
    NSString *whereClause = @"";
    if ([keyRangePredicate length] > 0) {
        whereClause = [NSString stringWithFormat:@"WHERE %@",keyRangePredicate];
        binds = [self bindsForQuerySpec:querySpec];
    }
    querySql = [NSString stringWithFormat:@"SELECT count(*) FROM %@ %@", soupTableName, whereClause];
    NSLog(@"countSql: \n %@ \n binds: %@",querySql,binds);
    frs = [self.storeDb executeQuery:querySql withArgumentsInArray:binds];
    
    NSUInteger result = 0;

    if([frs next]) {
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
    NSLog(@"countEntriesInSoup '%@' result: %d",soupName,result);
    return result;
}


- (NSString *)soupEntryIdsPredicate:(NSArray *)soupEntryIds {
    NSString *allIds = [soupEntryIds componentsJoinedByString:@","];
    NSString *pred = [NSString stringWithFormat:@"%@ IN (%@) ",ID_COL,allIds];    
    return pred;
}


- (NSArray *)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    NSMutableArray *result = [NSMutableArray array]; //empty result array by default

    NSString *soupTableName = [self tableNameForSoup:soupName];
    if (nil == soupTableName) {
        NSLog(@"Soup: '%@' does not exist",soupName);
        return result;
    }
    
    NSString *pred = [self soupEntryIdsPredicate:soupEntryIds];
    NSString *querySql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
                          SOUP_COL,soupTableName,pred];
    FMResultSet *frs = [self.storeDb executeQuery:querySql];

    while([frs next]) {
        NSString *rawJson = [frs stringForColumn:SOUP_COL];
        //TODO this is pretty inefficient...we read json from db then reconvert to NSDictionary, then reconvert again in cordova
        NSDictionary *entry = [SFJsonUtils objectFromJSONString:rawJson];
        [result addObject:entry];          
    }
    [frs close];
    
    
    return result;
}



- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoupTable:(NSString*)soupTableName indices:(NSArray*)indices
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
    
    BOOL insertOk =[self insertIntoTable:soupTableName values:baseColumns ];
    if (!insertOk) {
        return nil;
    }

    //set the newly-calculated entry ID so that our next update will update this entry (and not create a new one)
    NSNumber *newEntryId = [NSNumber numberWithInteger:[self.storeDb lastInsertRowId]];
    
    //clone the entry so that we can insert the new SOUP_ENTRY_ID into the json
    NSMutableDictionary *mutableEntry = [[entry mutableCopy] autorelease];
    [mutableEntry setValue:newEntryId forKey:SOUP_ENTRY_ID];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
             
    //now update the SOUP_COL (raw json) for the soup entry
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    NSArray *binds = [NSArray arrayWithObjects:
                      rawJson,
                      newEntryId,
                      nil];
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?", soupTableName, SOUP_COL, ID_COL];
//    NSLog(@"updateSql: \n %@ \n binds: %@",updateSql,binds);
                
    BOOL updateOk = [self.storeDb executeUpdate:updateSql withArgumentsInArray:binds];
    if (!updateOk) {
        mutableEntry = nil;
    }
    
    return mutableEntry;
}


- (NSDictionary *)updateOneEntry:(NSDictionary *)entry 
                     withEntryId:(NSNumber *)entryId 
                     inSoupTable:(NSString *)soupTableName 
                         indices:(NSArray *)indices
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
    NSMutableDictionary *mutableEntry = [[entry mutableCopy] autorelease];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
    [mutableEntry setValue:entryId forKey:SOUP_ENTRY_ID];
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    [colVals setObject:rawJson forKey:SOUP_COL];

    BOOL updateOk =[self updateTable:soupTableName values:colVals entryId:entryId];
    if (!updateOk) {
        return nil;
    }
     
    return mutableEntry;
    
}


- (NSDictionary *)upsertOneEntry:(NSDictionary *)entry 
                     inSoup:(NSString*)soupName  
                         indices:(NSArray*)indices
                       exteralIdPath:(NSString *)externalIdPath
                           error:(NSError **)error
{
    NSDictionary *result = nil;
    
    // NB: We're assuming soupExists has already been validated on the soup name.  This happens
    // e.g. in upsertEntries:toSoup:withExternalIdPath: .
    NSString *soupTableName = [self tableNameForSoup:soupName];
    
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
                                                      error:error];
            if (error != nil && *error != nil) {
                NSString *errorMsg = [NSString stringWithFormat:kSFSmartStoreExtIdLookupError,
                                      externalIdPath, fieldValue, [*error localizedDescription]];
                NSLog(@"%@", errorMsg);
                return nil;
            }
        }
    }
    
    if (nil != soupEntryId) {
        //entry already has an entry id: update
        result = [self updateOneEntry:entry withEntryId:soupEntryId inSoupTable:soupTableName indices:indices];
    } else {
        //no entry id: insert
        result = [self insertOneEntry:entry inSoupTable:soupTableName indices:indices];
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
    NSMutableArray *result = nil;
    NSString *localExternalIdPath;
    if (externalIdPath != nil)
        localExternalIdPath = externalIdPath;
    else
        localExternalIdPath = SOUP_ENTRY_ID;
    
    if ([self soupExists:soupName]) {
        NSArray *indices = [self indicesForSoup:soupName];

        result = [NSMutableArray array]; //empty result array by default
        BOOL upsertSuccess = YES;
        [self.storeDb beginTransaction];
        
        for (NSDictionary *entry in entries) {
            NSError *localError = nil;
            NSDictionary *upsertedEntry = [self upsertOneEntry:entry inSoup:soupName indices:indices exteralIdPath:localExternalIdPath error:&localError];
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
        
        if (upsertSuccess)
            [self.storeDb commit];
        else
            [self.storeDb rollback];
        
    }
    
    return result;
}

- (void)removeEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    if ([self soupExists:soupName]) {
        NSString *soupTableName = [self tableNameForSoup:soupName];
        NSString *pred = [self soupEntryIdsPredicate:soupEntryIds];
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",
                              soupTableName,pred];
        BOOL ranOK = [self.storeDb executeUpdate:deleteSql];
        if (!ranOK) {
            NSLog(@"ERROR %d deleting entries: '%@'", 
                  [self.storeDb lastErrorCode], 
                  [self.storeDb lastErrorMessage] );
        }
    }
    
}

@end
