//
//  SFSmartStoreDatabaseManager.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 8/17/12.
//
//

#import "SFSmartStoreDatabaseManager.h"
#import "UIDevice+SFHardware.h"
#import "NSData+SFAdditions.h"
#import "NSString+SFAdditions.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "SFLogger.h"

static SFSmartStoreDatabaseManager *sharedInstance = nil;

static NSString * const kStoresDirectory          = @"stores";
static NSString * const kStoreDbFileName          = @"store.sqlite";

// NSError constants
NSString *        const kSFSmartStoreDbErrorDomain         = @"com.salesforce.smartstore.db.error";
static NSInteger  const kSFSmartStoreAttachNewDbErrorCode  = 1;
static NSString * const kSFSmartStoreAttachNewDbErrorDesc  = @"Failed to attach new DB for %@: %@";
static NSInteger  const kSFSmartStoreDbExportErrorCode     = 2;
static NSString * const kSFSmartStoreDbExportErrorDesc     = @"Failed to export contents of original DB: %@";
static NSInteger  const kSFSmartStoreDetachDbErrorCode     = 3;
static NSString * const kSFSmartStoreDetachDbErrorDesc     = @"Failed to detach the new DB: %@";
static NSInteger  const kSFSmartStoreDbBackupErrorCode     = 4;
static NSString * const kSFSmartStoreDbBackupErrorDesc     = @"Could not make a backup of store '%@': %@";
static NSInteger  const kSFSmartStoreReplaceDbErrorCode    = 5;
static NSString * const kSFSmartStoreReplaceDbErrorDesc    = @"Could not replace old DB with new DB: %@";
static NSInteger  const kSFSmartStoreVerifyDbErrorCode     = 6;
static NSString * const kSFSmartStoreVerifyDbErrorDesc     = @"Could not open database at path '%@' for verification: %@";
static NSInteger  const kSFSmartStoreVerifyReadDbErrorCode = 7;
static NSString * const kSFSmartStoreVerifyReadDbErrorDesc = @"Could not read from database at path '%@', for verification: %@";

@interface SFSmartStoreDatabaseManager ()

/**
 @param storeName The name of the store.
 @return The filesystem diretory containing for the given store name
 */
- (NSString *)storeDirectoryForStoreName:(NSString *)storeName;

/**
 @param storeName The name of the store (excluding paths)
 @return full filesystem path for the store db file
 */
- (NSString*)fullDbFilePathForStoreName:(NSString*)storeName;

/**
 @return The root directory where all the SmartStore DBs live.
 */
- (NSString *)rootStoreDirectory;

- (FMDatabase *)encryptOrUnencryptDb:(FMDatabase *)db
                                name:(NSString *)storeName
                              oldKey:(NSString *)oldKey
                              newKey:(NSString *)newKey
                               error:(NSError **)error;
- (BOOL)openDatabaseWithPath:(NSString *)dbPath key:(NSString *)key db:(FMDatabase **)db;
- (BOOL)verifyDatabaseAccess:(NSString *)dbPath key:(NSString *)key error:(NSError **)error;

@end

@implementation SFSmartStoreDatabaseManager

#pragma mark - Singleton initialization / management

+ (SFSmartStoreDatabaseManager *)sharedManager
{
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedManager] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark - Database management methods

- (BOOL)persistentStoreExists:(NSString*)storeName {
    NSString *fullDbFilePath = [self fullDbFilePathForStoreName:storeName];
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:fullDbFilePath];
    return result;
}

- (BOOL)openStoreDatabaseWithName:(NSString *)storeName key:(NSString *)key db:(FMDatabase **)db {
    NSString *fullDbFilePath = [self fullDbFilePathForStoreName:storeName];
    return [self openDatabaseWithPath:fullDbFilePath key:key db:db];
}

- (BOOL)openDatabaseWithPath:(NSString *)dbPath key:(NSString *)key db:(FMDatabase **)db {
    BOOL result = NO;
    
    *db = [FMDatabase databaseWithPath:dbPath];
    [*db setLogsErrors:YES];
    [*db setCrashOnErrors:YES];
    if ([*db open]) {
        [*db setKey:key];
        result = YES;
    } else {
        NSLog(@"Couldn't open store db at: %@ error: %@", dbPath,[*db lastErrorMessage] );
    }
    
    return result;
}

- (FMDatabase *)encryptDb:(FMDatabase *)db name:(NSString *)storeName key:(NSString *)key error:(NSError **)error
{
    return [self encryptOrUnencryptDb:db name:storeName oldKey:@"" newKey:key error:error];
}

- (FMDatabase *)unencryptDb:(FMDatabase *)db name:(NSString *)storeName oldKey:(NSString *)oldKey error:(NSError **)error
{
    return [self encryptOrUnencryptDb:db name:storeName oldKey:oldKey newKey:@"" error:error];
}

- (FMDatabase *)encryptOrUnencryptDb:(FMDatabase *)db
                                name:(NSString *)storeName
                              oldKey:(NSString *)oldKey
                              newKey:(NSString *)newKey
                               error:(NSError **)error
{
    if (newKey == nil) newKey = @"";
    NSString *escapedKey = [newKey stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    NSString *origDbPath = [self fullDbFilePathForStoreName:storeName];
    NSString *encDbPath = [origDbPath stringByAppendingString:@".encrypted"];
    
    BOOL encrypting = ([newKey length] > 0);
    [self log:SFLogLevelInfo format:@"DB for store '%@' is %@. %@.",
     storeName,
     (encrypting ? @"unencrypted" : @"encrypted"),
     (encrypting ? @"Encrypting" : @"Unencrypting")];
    
    // Use sqlcipher_export() to move the data from the input DB over to the new one.
    NSString *attachDbString = [NSString stringWithFormat:@"ATTACH DATABASE '%@' AS encrypted KEY '%@'", encDbPath, escapedKey];
    BOOL updateResult = [db executeUpdate:attachDbString];
    if (!updateResult) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreAttachNewDbErrorDesc,
                               (encrypting ? @"encrypting" : @"decrypting"),
                               [db lastErrorMessage]];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreAttachNewDbErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    FMResultSet *rs = [db executeQuery:@"SELECT sqlcipher_export('encrypted')"];
    if (rs == nil || ![rs next]) {
        [rs close];
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDbExportErrorDesc, [db lastErrorMessage]];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreDbExportErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    [rs close];
    updateResult = [db executeUpdate:@"DETACH DATABASE encrypted"];
    if (!updateResult) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDetachDbErrorDesc, [db lastErrorMessage]];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreDetachDbErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    
    // As a sanity check, verify that the new encrypted DB can be opened and read.
    if (![self verifyDatabaseAccess:encDbPath key:newKey error:error]) {
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    
    // New database created and verified.  Move it into place of the old one.
    [db close];
    NSString *backupPath = [origDbPath stringByAppendingString:@".bak"];
    BOOL fileOpSuccess = [[NSFileManager defaultManager] moveItemAtPath:origDbPath toPath:backupPath error:error];
    if (!fileOpSuccess) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDbBackupErrorDesc, storeName, *error];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreDbBackupErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        [db open];
        [db setKey:oldKey];
        return db;
    }
    fileOpSuccess = [[NSFileManager defaultManager] moveItemAtPath:encDbPath toPath:origDbPath error:error];
    if (!fileOpSuccess) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreReplaceDbErrorDesc, *error];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreReplaceDbErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:origDbPath error:nil];
        [db open];
        [db setKey:oldKey];
        return db;
    }
    
    FMDatabase *encDb = nil;
    if ([self openDatabaseWithPath:origDbPath key:newKey db:&encDb]) {
        [[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil];
        return encDb;
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:origDbPath error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:origDbPath error:nil];
        [db open];
        [db setKey:oldKey];
        return db;
    }
}

- (BOOL)verifyDatabaseAccess:(NSString *)dbPath key:(NSString *)key error:(NSError **)error
{
    FMDatabase *db = nil;
    BOOL canOpenDb = [self openDatabaseWithPath:dbPath key:key db:&db];
    if (!canOpenDb) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreVerifyDbErrorDesc, dbPath, [db lastErrorMessage]];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreVerifyDbErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    
    NSString *sqlCommand = @"SELECT name FROM sqlite_master LIMIT 1";
    FMResultSet *rs = [db executeQuery:sqlCommand];
    if (rs == nil) {
        // May not be results, but rs should never be nil coming back.
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreVerifyReadDbErrorDesc, dbPath, [db lastErrorMessage]];
        *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                     code:kSFSmartStoreVerifyReadDbErrorCode
                                 userInfo:[NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey]];
        [rs close];
        return NO;
    }
    
    [rs close];
    [db close];
    return YES;
}

#pragma mark - Utilities

- (void)createStoreDir:(NSString *)storeName error:(NSError **)error
{
    NSString *storeDir = [self storeDirectoryForStoreName:storeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeDir]) {
        // This store has not yet been created; create it.
        [[NSFileManager defaultManager] createDirectoryAtPath:storeDir withIntermediateDirectories:YES attributes:nil error:error];
    }
}

- (void)protectStoreDir:(NSString *)storeName error:(NSError **)error
{
    // Setup the database file with filesystem encryption.
    NSString *dbFilePath = [self fullDbFilePathForStoreName:storeName];
    NSDictionary *attr = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:dbFilePath error:error];
}

- (void)removeStoreDir:(NSString *)storeName
{
    NSString *storeDir = [self storeDirectoryForStoreName:storeName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:storeDir]) {
        [[NSFileManager defaultManager] removeItemAtPath:storeDir error:nil];
    }
}

- (NSString*)fullDbFilePathForStoreName:(NSString*)storeName {
    NSString *storePath = [self storeDirectoryForStoreName:storeName];
    NSString *fullDbFilePath = [storePath stringByAppendingPathComponent:kStoreDbFileName];
    return fullDbFilePath;
}

- (NSString *)storeDirectoryForStoreName:(NSString *)storeName {
    NSString *storesDir = [self rootStoreDirectory];
    NSString *result = [storesDir stringByAppendingPathComponent:storeName];
    
    return result;
}

- (NSString *)rootStoreDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *storesDir = [documentsDirectory stringByAppendingPathComponent:kStoresDirectory];
    
    return storesDir;
}

- (NSArray *)allStoreNames {
    NSString *rootDir = [self rootStoreDirectory];
    NSError *getStoresError = nil;
    NSArray *storesDirNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootDir error:&getStoresError];
    if (getStoresError) {
        NSLog(@"Warning: Problem retrieving all store names from the root stores folder: %@.", [getStoresError localizedDescription]);
        return nil;
    }
    
    NSMutableArray *allStoreNames = [NSMutableArray array];
    for (NSString *storesDirName in storesDirNames) {
        if ([self persistentStoreExists:storesDirName])
            [allStoreNames addObject:storesDirName];
    }
    
    return allStoreNames;
}

@end
