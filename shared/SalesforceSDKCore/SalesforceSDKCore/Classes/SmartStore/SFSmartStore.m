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
#import "SFSmartSqlHelper.h"
#import "SFStoreCursor.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import "SFPasscodeManager.h"
#import "SFSmartStoreDatabaseManager.h"
#import <SalesforceCommonUtils/UIDevice+SFHardware.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import <SalesforceCommonUtils/NSData+SFAdditions.h>
#import <SalesforceCommonUtils/SFCrypto.h>

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
static NSString * const kDefaultEncryptionTypeKey = @"com.salesforce.smartstore.defaultEncryptionType";

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

+ (void)initialize
{
    // We do this as the very first thing, because there are so many class methods that access
    // the data stores without initializing an SFSmartStore instance.
    [self updateDefaultEncryption];
}

- (id) initWithName:(NSString*)name {
    self = [super init];
    
    if (nil != self)  {
        [self log:SFLogLevelDebug format:@"SFSmartStore initWithStoreName: %@",name];
        
         _storeName = name;
        //Setup listening for data protection available / unavailable
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
        
        if (![[self class] persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                self = nil;
            }
        } else {
            if (![self openStoreDatabase:NO]) {
                self = nil;
            }
        }
        

    }
    return self;
}

- (void)dealloc {    
    [self log:SFLogLevelDebug format:@"dealloc store: '%@'",_storeName];
    [self.storeDb close];
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
    [[SFSmartStoreDatabaseManager sharedManager] createStoreDir:self.storeName error:&createErr];
    if (nil == createErr) {
        //need to create the db file itself before we can encrypt it
        if ([self openStoreDatabase:YES]) {
            if ([self createMetaTables]) {
                [self.storeDb close];  _storeDb = nil; // Need to close before setting encryption.
                [[SFSmartStoreDatabaseManager sharedManager] protectStoreDir:self.storeName error:&protectErr];
                if (protectErr != nil) {
                    [self log:SFLogLevelDebug format:@"Couldn't protect store: %@", protectErr];
                } else {
                    //reopen the storeDb now that it's protected
                    result = [self openStoreDatabase:NO];
                }
            }
        }
    } 
    
    if (!result) {
        [self log:SFLogLevelDebug format:@"Deleting store dir since we can't set it up properly: %@", self.storeName];
        [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:self.storeName];
        [[self class] setUsesDefaultKey:NO forStore:self.storeName];
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
    NSString *key = [[self class] encKey];
    if (key != nil && [key length] > 0) {
        // User-defined key.  Create or open the database with that.
        db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
        if (db) {
            self.storeDb = db;
            result = YES;
        } else {
            [self log:SFLogLevelError format:kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]];
        }
    } else if (forCreation) {
        // For creation, we can just set the default key from the start.
        key = [[self class] defaultKey];
        db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
        if (db) {
            self.storeDb = db;
            [[self class] setUsesDefaultKey:YES forStore:self.storeName];
            result = YES;
        } else {
            [self log:SFLogLevelError format:kCreateDatabaseError, self.storeName, [openDbError localizedDescription]];
        }
    } else {
        // For existing databases, we may need to update to the default encryption, if not updated already.
        key = [[self class] defaultKey];
        if (![[self class] usesDefaultKey:self.storeName]) {
            // This DB is unencrypted.  Encrypt it before proceeding.
            db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:@"" error:&openDbError];
            if (!db) {
                [self log:SFLogLevelError format:kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]];
            } else {
                NSError *encryptDbError = nil;
                db = [[SFSmartStoreDatabaseManager sharedManager] encryptDb:db name:self.storeName key:key error:&encryptDbError];
                if (encryptDbError) {
                    [self log:SFLogLevelError format:kEncryptDatabaseError, self.storeName, [encryptDbError localizedDescription]];
                } else {
                    self.storeDb = db;
                    [[self class] setUsesDefaultKey:YES forStore:self.storeName];
                    result = YES;
                }
            }
        } else {
            // Already uses the default encryption key.
            db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:self.storeName key:key error:&openDbError];
            if (db) {
                self.storeDb = db;
                result = YES;
            } else {
                [self log:SFLogLevelError format:kOpenExistingDatabaseError, self.storeName, [openDbError localizedDescription]];
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
         //the store is retained by _allSharedStores so we can return it
    }
    
    return store;
}

+ (void)removeSharedStoreWithName:(NSString*)storeName {
    [self log:SFLogLevelDebug format:@"removeSharedStoreWithName: %@", storeName];
    SFSmartStore *existingStore = [_allSharedStores objectForKey:storeName];
    if (nil != existingStore) {
        [existingStore.storeDb close];
        [_allSharedStores removeObjectForKey:storeName];
    }
    [[self class] setUsesDefaultKey:NO forStore:storeName];
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
            [self log:SFLogLevelDebug format:@"Updating key for opened store '%@'", storeName];
            FMDatabase *updatedDb = [self changeKeyForDb:currentStore.storeDb name:storeName oldKey:oldKey newKey:newKey];
            currentStore.storeDb = updatedDb;
        } else {
            // Store database is not resident in memory.  Open it long enough to make the change, then close it.
            [self log:SFLogLevelDebug format:@"Updating key for store '%@' on filesystem", storeName];
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
                [self log:SFLogLevelError format:@"Error opening store '%@' to update encryption: %@", storeName, [openError localizedDescription]];
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
                [self log:SFLogLevelError format:kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]];
            } else {
                [self setUsesDefaultKey:NO forStore:storeName];
            }
            return db;
        } else {
            // No default key either, which means there's no encryption for this store.  Need to encrypt it.
            NSError *encryptDbError = nil;
            db = [[SFSmartStoreDatabaseManager sharedManager] encryptDb:db name:storeName key:newKey error:&encryptDbError];
            if (encryptDbError != nil) {
                [self log:SFLogLevelError format:kNewEncryptionErrorMessage, storeName, [encryptDbError localizedDescription]];
            }
            return db;
        }
    } else {
        // DB is already encrypted with a user-defined key.
        if (newKey != nil && [newKey length] > 0) {
            // User-defined new key.
            BOOL rekeyResult = [db rekey:newKey];
            if (!rekeyResult) {
                [self log:SFLogLevelError format:kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]];
            }
            return db;
        } else {
            // New key is empty.  Revert to default encryption.
            NSString *defaultKey = [self defaultKey];
            BOOL rekeyResult = [db rekey:defaultKey];
            if (!rekeyResult) {
                [self log:SFLogLevelError format:kEncryptionChangeErrorMessage, storeName, [db lastErrorMessage]];
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
        [self log:SFLogLevelError format:@"Exception creating meta tables: %@", exception];
    }
    @finally {
        if (!result) {
            [self log:SFLogLevelError format:@"ERROR %d creating meta tables: '%@'", 
            [self.storeDb lastErrorCode], 
            [self.storeDb lastErrorMessage]];
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
    
    // Update the default encryption type too.
    if (usesDefault)
        [self setDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeBaseAppId forStore:storeName];
    else
        [self setDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeNone forStore:storeName];
}

+ (SFSmartStoreDefaultEncryptionType)defaultEncryptionTypeForStore:(NSString *)storeName
{
    NSDictionary *encTypeDict = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultEncryptionTypeKey];
    if (encTypeDict == nil) return SFSmartStoreDefaultEncryptionTypeMac;
    NSNumber *encTypeNum = [encTypeDict objectForKey:storeName];
    if (encTypeNum == nil) return SFSmartStoreDefaultEncryptionTypeMac;
    return [encTypeNum intValue];
}

+ (void)setDefaultEncryptionType:(SFSmartStoreDefaultEncryptionType)encType forStore:(NSString *)storeName
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultEncTypeDict = [userDefaults objectForKey:kDefaultEncryptionTypeKey];
    NSMutableDictionary *newDict;
    if (defaultEncTypeDict == nil)
        newDict = [NSMutableDictionary dictionary];
    else
        newDict = [NSMutableDictionary dictionaryWithDictionary:defaultEncTypeDict];
    
    NSNumber *encTypeNum = [NSNumber numberWithInt:encType];
    [newDict setObject:encTypeNum forKey:storeName];
    [userDefaults setObject:newDict forKey:kDefaultEncryptionTypeKey];
    [userDefaults synchronize];
}

+ (void)updateDefaultEncryption
{
    [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Updating default encryption for all stores, where necessary."];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    [SFLogger log:[self class] level:SFLogLevelInfo format:@"Number of stores to update: %d", [allStoreNames count]];
    for (NSString *storeName in allStoreNames) {
        if (![self updateDefaultEncryptionForStore:storeName]) {
            [SFLogger log:[self class] level:SFLogLevelError format:@"Could not update default encryption for '%@', which means the data is no longer accessible.  Removing store.", storeName];
            [self removeSharedStoreWithName:storeName];
        }
    }
}

+ (BOOL)updateDefaultEncryptionForStore:(NSString *)storeName
{
    if (![self persistentStoreExists:storeName]) {
        [SFLogger log:[self class] level:SFLogLevelInfo format:@"Store '%@' does not exist on the filesystem.  Skipping.", storeName];
        return YES;
    }
    if (![self usesDefaultKey:storeName]) {
        [SFLogger log:[self class] level:SFLogLevelInfo format:@"Store '%@' does not use default encryption.  Skipping.", storeName];
        return YES;
    }
    
    SFSmartStoreDefaultEncryptionType encType = [self defaultEncryptionTypeForStore:storeName];
    if (encType == SFSmartStoreDefaultEncryptionTypeBaseAppId) {
        [SFLogger log:[self class] level:SFLogLevelInfo format:@"Store '%@' already uses the preferred default encryption.  Skipping.", storeName];
        return YES;  // This is our prefered default encryption.
    }
    
    // Otherwise, update the default encryption.
    
    NSString *origKey;
    switch (encType) {
        case SFSmartStoreDefaultEncryptionTypeNone:
        case SFSmartStoreDefaultEncryptionTypeMac:
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"Store '%@' uses MAC encryption.", storeName];
            origKey = [self defaultKeyMac];
            break;
        case SFSmartStoreDefaultEncryptionTypeIdForVendor:
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"Store '%@' uses vendor identifier encryption.", storeName];
            origKey = [self defaultKeyIdForVendor];
            break;
        default:
            [SFLogger log:[self class] level:SFLogLevelError format:@"Unknown encryption type '%d'.  Cannot convert store '%@'.", encType, storeName];
            return NO;
    }
    
    NSError *openDbError = nil;
    FMDatabase *db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:storeName key:origKey error:&openDbError];
    if (!db) {
        [SFLogger log:[self class] level:SFLogLevelError format:@"Error opening store '%@': %@", storeName, [openDbError localizedDescription]];
        return NO;
    }
    
    // Can the database be read with the original default key?
    NSString *dbPath = [[SFSmartStoreDatabaseManager sharedManager] fullDbFilePathForStoreName:storeName];
    NSError *verifyDbError = nil;
    BOOL dbAccessible = [[SFSmartStoreDatabaseManager sharedManager] verifyDatabaseAccess:dbPath key:origKey error:&verifyDbError];
    if (!dbAccessible) {
        [SFLogger log:[self class] level:SFLogLevelError format:@"Error verifying the database contents for store '%@': %@", storeName, [verifyDbError localizedDescription]];
        [db close];
        return NO;
    }
    
    [SFLogger log:[self class] level:SFLogLevelInfo format:@"Updating default encryption for store '%@'.", storeName];
    NSString *newDefaultKey = [self defaultKeyBaseAppId];
    BOOL rekeyResult = [db rekey:newDefaultKey];
    if (!rekeyResult) {
        [SFLogger log:[self class] level:SFLogLevelError format:@"Error updating the default encryption for store '%@'.", storeName];
    } else {
        [self setDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeBaseAppId forStore:storeName];
    }
    
    [db close];
    return rekeyResult;
}

+ (NSString *)encKey
{
    NSString *key = [SFPasscodeManager sharedManager].encryptionKey;
    return (key == nil ? @"" : key);
}

+ (NSString *)defaultKey
{
    return [self defaultKeyBaseAppId];
}

+ (NSString *)defaultKeyIdForVendor
{
    NSString *idForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return [self defaultKeyWithSeed:idForVendor];
}

+ (NSString *)defaultKeyMac
{
    NSString *macAddress = [[UIDevice currentDevice] macaddress];
    return [self defaultKeyWithSeed:macAddress];
}

+ (NSString *)defaultKeyBaseAppId
{
    NSString *baseAppId = [SFCrypto baseAppIdentifier];
    return [self defaultKeyWithSeed:baseAppId];
}

+ (NSString *)defaultKeyWithSeed:(NSString *)seed
{
    NSString *constKey = [[NSString alloc] initWithBytes:const_key length:strlen(const_key) encoding:NSUTF8StringEncoding];
    NSString *strSecret = [seed stringByAppendingString:constKey];
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
    //[self log:SFLogLevelDebug format:@"upsertSql: %@ binds: %@",upsertSql,binds];
    BOOL result = [self.storeDb executeUpdate:insertSql withArgumentsInArray:binds];
        
    return result;
    
}

- (BOOL)updateTable:(NSString*)tableName values:(NSDictionary*)map entryId:(NSNumber *)entryId
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
    BOOL result = [self.storeDb executeUpdate:updateSql withArgumentsInArray:binds];
    
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
        [self log:SFLogLevelDebug format:@"Unknown index path '%@' in soup '%@' ",path,soupName];
    }
    return result;

}

- (NSString*) convertSmartSql:(NSString*)smartSql
{
    [self log:SFLogLevelDebug format:@"convertSmartSQl:%@", smartSql];
    NSObject* sql = [_smartSqlToSql objectForKey:smartSql];
    
    if (nil == sql) {
        sql = [[SFSmartSqlHelper sharedInstance] convertSmartSql:smartSql withStore:self];
        
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


#pragma mark - Soup maniupulation methods


- (NSString*)tableNameForSoup:(NSString*)soupName {
    NSString *result  = nil;
    
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?",ID_COL,SOUP_NAMES_TABLE,SOUP_NAME_COL];
//    [self log:SFLogLevelDebug format:@"tableName query: %@",sql];
    FMResultSet *frs = [self.storeDb executeQuery:sql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
    
    if ([frs next]) {
        NSUInteger colIdx = [frs columnIndexForName:ID_COL];
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
        [self log:SFLogLevelDebug format:@"indices sql: %@",querySql];
        FMResultSet *frs = [self.storeDb executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObject:soupName]];
        
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
        [self log:SFLogLevelDebug format:@"couldn't properly register soupName: '%@' ",soupName];
    }
    
    return soupTableName;
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
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
    if ([self soupExists:soupName]) {
        result = YES;
        return result;
    }
    
    NSString *soupTableName = [self registerNewSoupName:soupName];
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
        NSString *columnName = [NSString stringWithFormat:@"%@_%d",soupTableName,i];
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
        NSString *indexName = [NSString stringWithFormat:@"%@_%d_idx",soupTableName,i];
        [createIndexStmts addObject:
         [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ ON %@ ( %@ )",indexName, soupTableName, columnName]
         ];
    }
    
    [createTableStmt appendString:@")"];
    [self log:SFLogLevelDebug format:@"createTableStmt:\n %@",createTableStmt];

    if ([self.storeDb beginTransaction]) {
        // create the main soup table
        BOOL runOk = [self.storeDb  executeUpdate:createTableStmt];
        if (!runOk) {
            [self log:SFLogLevelError format:@"ERROR creating soup table  %d %@ stmt: %@", 
                  [self.storeDb lastErrorCode], 
                  [self.storeDb lastErrorMessage],
                  createTableStmt];
        } else {
            // create indices for this soup
            for (NSString *createIndexStmt in createIndexStmts) {
                [self log:SFLogLevelDebug format:@"createIndexStmt: %@",createIndexStmt];
                runOk = [self.storeDb  executeUpdate:createIndexStmt];
                if (!runOk) {
                    [self log:SFLogLevelError format:@"ERROR creating soup index  %d %@", 
                          [self.storeDb lastErrorCode], 
                          [self.storeDb lastErrorMessage]];
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
    
    
    return  result;
}



- (void)removeSoup:(NSString*)soupName {
    [self log:SFLogLevelDebug format:@"removeSoup: %@", soupName];
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
    @catch (NSException *exception) {
        [self log:SFLogLevelDebug format:@"exception removing soup: %@", exception];
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

- (NSUInteger)countWithQuerySpec:(SFQuerySpec*)querySpec
{
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSUInteger result = 0;

    // SQL
    NSString* sql = [self convertSmartSql: querySpec.smartSql];
    NSString* countSql = [[NSArray arrayWithObjects:@"SELECT COUNT(*) FROM (", sql, @") ", nil] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"countWithQuerySpec: countSql:%@ \n", countSql];

    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [self.storeDb executeQuery:countSql withArgumentsInArray:args];
    if([frs next]) {
        result = [frs intForColumnIndex:0];
    }
    [frs close];

    return result;
}


- (NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex
{
    [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nquerySpec:%@ \n", querySpec];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:querySpec.pageSize];

    // Page
    NSUInteger offsetRows = querySpec.pageSize * pageIndex;
    NSUInteger numberRows = querySpec.pageSize;
    NSString* limit = [NSString stringWithFormat:@"%d,%d",offsetRows,numberRows];

    // SQL
    NSString* sql = [self convertSmartSql: querySpec.smartSql];
    NSString* limitSql = [[NSArray arrayWithObjects:@"SELECT * FROM (", sql, @") LIMIT ", limit, nil] componentsJoinedByString:@""];
    [self log:SFLogLevelDebug format:@"queryWithQuerySpec: \nlimitSql:%@ \npageIndex:%d \n", limitSql, pageIndex];

    // Args
    NSArray* args = [querySpec bindsForQuerySpec];
    
    // Executing query
    FMResultSet *frs = [self.storeDb executeQuery:limitSql withArgumentsInArray:args];
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
    SFQuerySpec *querySpec = [[SFQuerySpec alloc] initWithDictionary:spec withSoupName:targetSoupName];
    if (nil == querySpec) {
        // Problem already logged
        return nil;
    }
    
    NSString* sql = [self convertSmartSql:querySpec.smartSql];
    if (nil == sql) {
        // Problem already logged
        return nil;
    }
    
    NSUInteger totalEntries = [self  countWithQuerySpec:querySpec];
    SFStoreCursor *result = [[SFStoreCursor alloc] initWithStore:self querySpec:querySpec totalEntries:totalEntries];
    
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
        [self log:SFLogLevelDebug format:@"Soup: '%@' does not exist",soupName];
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
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
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
                [self log:SFLogLevelDebug format:@"%@", errorMsg];
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
            [self log:SFLogLevelError format:@"ERROR %d deleting entries: '%@'", 
                  [self.storeDb lastErrorCode], 
                  [self.storeDb lastErrorMessage]];
        }
    }
    
}

@end
