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

#import "SFSmartStoreDatabaseManager+Internal.h"
#import <SalesforceCommonUtils/UIDevice+SFHardware.h>
#import <SalesforceCommonUtils/NSData+SFAdditions.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import "SFSmartStoreUtils.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFDirectoryManager.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

static SFSmartStoreDatabaseManager *sharedInstance = nil;
static NSMutableDictionary *sDatabaseManagers;

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

@implementation SFSmartStoreDatabaseManager

@synthesize user = _user;

#pragma mark - Singleton initialization / management

+ (void)initialize
{
    sDatabaseManagers = [NSMutableDictionary dictionary];
}

+ (SFSmartStoreDatabaseManager *)sharedManager
{
    return [self sharedManagerForUser:[SFUserAccountManager sharedInstance].currentUser];
}

+ (SFSmartStoreDatabaseManager *)sharedManagerForUser:(SFUserAccount *)user
{
    @synchronized (self) {
        NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
        SFSmartStoreDatabaseManager *mgr = sDatabaseManagers[userKey];
        if (mgr == nil) {
            mgr = [[SFSmartStoreDatabaseManager alloc] initWithUser:user];
            sDatabaseManagers[userKey] = mgr;
        }
        return mgr;
    }
}

+ (void)removeSharedManagerForUser:(SFUserAccount *)user
{
    @synchronized (self) {
        NSString *userKey = [SFSmartStoreUtils userKeyForUser:user];
        SFSmartStoreDatabaseManager *mgr = sDatabaseManagers[userKey];
        if (mgr != nil) {
            [sDatabaseManagers removeObjectForKey:userKey];
        }
    }
}

- (id)initWithUser:(SFUserAccount *)user
{
    self = [super init];
    if (self) {
        self.user = ([user isEqual:[SFUserAccountManager sharedInstance].temporaryUser] ? nil : user);
    }
    return self;
}

#pragma mark - Database management methods

- (BOOL)persistentStoreExists:(NSString*)storeName {
    NSString *fullDbFilePath = [self fullDbFilePathForStoreName:storeName];
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:fullDbFilePath];
    return result;
}

- (FMDatabase *)openStoreDatabaseWithName:(NSString *)storeName key:(NSString *)key error:(NSError **)error {
    NSString *fullDbFilePath = [self fullDbFilePathForStoreName:storeName];
    return [self openDatabaseWithPath:fullDbFilePath key:key error:error];
}

- (FMDatabaseQueue *)openStoreQueueWithName:(NSString *)storeName key:(NSString *)key error:(NSError **)error {
    __block BOOL result = YES;
    NSString *fullDbFilePath = [self fullDbFilePathForStoreName:storeName];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:fullDbFilePath];
    [queue inDatabase:^(FMDatabase* db) {
        result = ([self setKeyForDb:db key:key error:error] != nil);
    }];
    return (result ? queue : nil);
}

- (FMDatabase *)openDatabaseWithPath:(NSString *)dbPath key:(NSString *)key error:(NSError **)error {
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    return [self setKeyForDb:db key:key error:error];
}

- (FMDatabase*) setKeyForDb:(FMDatabase*) db key:(NSString *)key error:(NSError **)error {
    [db setLogsErrors:YES];
    [db setCrashOnErrors:NO];
    if ([db open]) {
        [db setKey:key];
        return db;
    } else {
        [self log:SFLogLevelDebug format:@"Couldn't open store db at: %@ error: %@", [db databasePath],[db lastErrorMessage]];
        if (error != nil)
            *error = [db lastError];
        return nil;
    }
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
        if (error != nil)
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreAttachNewDbErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    FMResultSet *rs = [db executeQuery:@"SELECT sqlcipher_export('encrypted')"];
    if (rs == nil || ![rs next]) {
        [rs close];
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDbExportErrorDesc, [db lastErrorMessage]];
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreDbExportErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    [rs close];
    updateResult = [db executeUpdate:@"DETACH DATABASE encrypted"];
    if (!updateResult) {
        NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDetachDbErrorDesc, [db lastErrorMessage]];
        if (error != nil) {
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreDetachDbErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    
    // As a sanity check, verify that the new encrypted DB can be opened and read.
    NSError *openNewlyEncryptedDbError = nil;
    FMDatabase *newlyEncryptedDb = [self openDatabaseWithPath:encDbPath key:newKey error:&openNewlyEncryptedDbError];
    if (!newlyEncryptedDb) {
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreVerifyDbErrorDesc, encDbPath, [openNewlyEncryptedDbError localizedDescription]];
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreVerifyDbErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    } else if (![self verifyDatabaseAccess:newlyEncryptedDb error:error]) {
        [newlyEncryptedDb close];
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        return db;
    }
    [newlyEncryptedDb close];
    
    // New database created and verified.  Move it into place of the old one.
    [db close];
    NSString *backupPath = [origDbPath stringByAppendingString:@".bak"];
    BOOL fileOpSuccess = [[NSFileManager defaultManager] moveItemAtPath:origDbPath toPath:backupPath error:error];
    if (!fileOpSuccess) {
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreDbBackupErrorDesc, storeName, *error];
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreDbBackupErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        [db open];
        [db setKey:oldKey];
        return db;
    }
    fileOpSuccess = [[NSFileManager defaultManager] moveItemAtPath:encDbPath toPath:origDbPath error:error];
    if (!fileOpSuccess) {
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreReplaceDbErrorDesc, *error];
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreReplaceDbErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [[NSFileManager defaultManager] removeItemAtPath:encDbPath error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:origDbPath error:nil];
        [db open];
        [db setKey:oldKey];
        return db;
    }
    
    FMDatabase *encDb = [self openDatabaseWithPath:origDbPath key:newKey error:nil];
    if (encDb) {
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

- (BOOL)verifyDatabaseAccess:(FMDatabase *)db error:(NSError **)error
{
    NSString *sqlCommand = @"SELECT name FROM sqlite_master LIMIT 1";
    FMResultSet *rs = [db executeQuery:sqlCommand];
    if (rs == nil) {
        // May not be results, but rs should never be nil coming back.
        if (error != nil) {
            NSString *errorDesc = [NSString stringWithFormat:kSFSmartStoreVerifyReadDbErrorDesc, [db databasePath], [db lastErrorMessage]];
            *error = [NSError errorWithDomain:kSFSmartStoreDbErrorDomain
                                         code:kSFSmartStoreVerifyReadDbErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        [rs close];
        return NO;
    }
    
    [rs close];
    return YES;
}

#pragma mark - Utilities

- (BOOL)createStoreDir:(NSString *)storeName error:(NSError **)error
{
    NSString *storeDir = [self storeDirectoryForStoreName:storeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeDir]) {
        // This store has not yet been created; create it.
        return [[NSFileManager defaultManager] createDirectoryAtPath:storeDir withIntermediateDirectories:YES attributes:nil error:error];
    } else {
        return YES;
    }
}

- (BOOL)protectStoreDir:(NSString *)storeName error:(NSError **)error
{
    // Setup the database file with filesystem encryption.
    NSString *dbFilePath = [self fullDbFilePathForStoreName:storeName];
    NSDictionary *attr = @{NSFileProtectionKey: NSFileProtectionComplete};
    return [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:dbFilePath error:error];
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
    NSString *rootStoreDir;
    if (self.user == nil) {
        rootStoreDir = [[SFDirectoryManager sharedManager] globalDirectoryOfType:NSDocumentDirectory components:@[ kStoresDirectory ]];
    } else {
        rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:self.user type:NSDocumentDirectory components:@[ kStoresDirectory ]];
    }
    
    return rootStoreDir;
}

- (NSArray *)allStoreNames {
    NSString *rootDir = [self rootStoreDirectory];
    NSError *getStoresError = nil;
    NSArray *storesDirNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootDir error:&getStoresError];
    if (getStoresError) {
        [self log:SFLogLevelDebug format:@"Warning: Problem retrieving all store names from the root stores folder: %@.", [getStoresError localizedDescription]];
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
