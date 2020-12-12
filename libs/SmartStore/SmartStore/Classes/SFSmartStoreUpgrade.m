/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStoreUpgrade.h"
#import "SFSmartStore+Internal.h"
#import "SFSmartStoreUtils.h"
#import "SFSmartStoreDatabaseManager+Internal.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/UIDevice+SFHardware.h>
#import <SalesforceSDKCore/SFCrypto.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFSDKDataSharinghelper.h>
#import "FMDatabase.h"

static NSString * const kLegacyDefaultPasscodeStoresKey = @"com.salesforce.smartstore.defaultPasscodeStores";
static NSString * const kLegacyDefaultEncryptionTypeKey = @"com.salesforce.smartstore.defaultEncryptionType";
static NSString * const kKeyStoreEncryptedStoresKey = @"com.salesforce.smartstore.keyStoreEncryptedStores";
static NSString * const kKeyStoreHasExternalSalt = @"com.salesforce.smartstore.external.hasExternalSalt";

@implementation SFSmartStoreUpgrade

+ (void)updateStoreLocations
{
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating stores from legacy locations, where necessary."];
    NSArray *allStoreNames = [SFSmartStoreUpgrade legacyAllStoreNames];
    if ([allStoreNames count] == 0) {
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"No legacy stores to migrate."];
        return;
    }
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Number of stores to migrate: %d", [allStoreNames count]];
    for (NSString *storeName in allStoreNames) {
        BOOL migratedStore = [SFSmartStoreUpgrade updateStoreLocationForStore:storeName];
        if (migratedStore) {
            [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Successfully migrated store '%@'", storeName];
        }
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtPath:[SFSmartStoreUpgrade legacyRootStoreDirectory] error:nil];
}

+ (BOOL)updateStoreLocationForStore:(NSString *)storeName
{
    NSString *origStoreDirPath = [SFSmartStoreUpgrade legacyStoreDirectoryForStoreName:storeName];
    NSString *origStoreFilePath = [SFSmartStoreUpgrade legacyFullDbFilePathForStoreName:storeName];
    NSString *newStoreDirPath = [[SFSmartStoreDatabaseManager sharedManager] storeDirectoryForStoreName:storeName];
    NSString *newStoreFilePath = [[SFSmartStoreDatabaseManager sharedManager] fullDbFilePathForStoreName:storeName];

    // No store in the original location?  Nothing to do.
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:origStoreFilePath]) {
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"File for store '%@' does not exist at legacy path.  Nothing to do.", storeName];
        [manager removeItemAtPath:origStoreDirPath error:nil];
        return YES;
    }
    
    // Create the new store directory.
    NSError *fileIoError = nil;
    BOOL createdNewStoreDir = [manager createDirectoryAtPath:newStoreDirPath withIntermediateDirectories:YES attributes:nil error:&fileIoError];
    if (!createdNewStoreDir) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error creating new store directory for store '%@': %@", storeName, [fileIoError localizedDescription]];
        return NO;
    }
    
    // Move the store from the old directory to the new one.
    BOOL movedStore = [manager moveItemAtPath:origStoreFilePath toPath:newStoreFilePath error:&fileIoError];
    if (!movedStore) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error moving store '%@' to new directory: %@", storeName, [fileIoError localizedDescription]];
        return NO;
    }
    
    // Remove the old store directory.
    [manager removeItemAtPath:origStoreDirPath error:nil];
    return YES;
}

+ (void)updateEncryptionSalt
{
    
    if ( ![SFSDKDatasharingHelper sharedInstance].appGroupEnabled || [[NSUserDefaults msdkUserDefaults] boolForKey:kKeyStoreHasExternalSalt]) {
        //already migrated or does not need Externalizing of Salt
        return;
    }
    
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Updating encryption salt for stores in shared mode."];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Number of stores to update: %d", [allStoreNames count]];
    SFUserAccount *currentUser = [SFUserAccountManager sharedInstance].currentUser;
    for (NSString *storeName in allStoreNames) {
        if (![SFSmartStoreUpgrade updateSaltForStore:storeName user:currentUser]) {
             [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to upgrade store for sharing mode: %@", storeName];
        }
    }
}

+ (BOOL)updateSaltForStore:(NSString *)storeName user:(SFUserAccount *)user {
    
    SFSmartStoreDatabaseManager *databaseManager = [SFSmartStoreDatabaseManager sharedManagerForUser:user];
    if (![databaseManager persistentStoreExists:storeName]) {
        //NEW Database no need for External Salt migration
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Store '%@' does not exist on the filesystem. Skipping Externalized Salt based migration is not required. ", storeName];
        return NO;
    }
    
    NSError *openDbError = nil;
    
    //get Key and new Salt
    NSString *key = [SFSmartStore encKey];
    NSString *newSalt = [SFSmartStore salt];
    
    FMDatabase *originalEncyptedDB = [databaseManager openStoreDatabaseWithName:storeName
                                                                            key:key
                                                                           salt:nil
                                                                          error:&openDbError];
    if (originalEncyptedDB == nil || openDbError != nil) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error opening store '%@' to update encryption: %@", storeName, [openDbError localizedDescription]];
        return NO;
    } else if (![[databaseManager class] verifyDatabaseAccess:originalEncyptedDB error:&openDbError]) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error reading the content of store '%@' during externalized salt encryption upgrade: %@", storeName, [openDbError  localizedDescription]];
        [originalEncyptedDB close];
        return NO;
    }
    
    if ([key length] > 0) {
        // Unencrypt with previous key.
        NSString *origDatabasePath = originalEncyptedDB.databasePath;
        
        NSString *storePath = [databaseManager fullDbFilePathForStoreName:storeName];
        NSString *backupStorePath = [NSString stringWithFormat:@"%@_%@",storePath,@"backup"];
        NSError *backupError = nil;
        
        // backup and attempt to copy the reencryopted db with the new key + salt
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *origDatabaseURL = [NSURL fileURLWithPath:origDatabasePath isDirectory:NO];
        NSURL *backupDatabaseURL = [NSURL fileURLWithPath:backupStorePath isDirectory:NO];
        
        if ([fileManager fileExistsAtPath:backupStorePath]) {
            [fileManager removeItemAtPath:backupStorePath error:nil];
        }
        
        [fileManager copyItemAtURL:origDatabaseURL toURL:backupDatabaseURL error:&backupError];
        if (backupError) {
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to backup db from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
            return NO;
        }
        
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db, did backup db first from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
        NSError *decryptDbError = nil;
        
        //lets decryptDB
        FMDatabase *decryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:originalEncyptedDB name:storeName  path:originalEncyptedDB.databasePath  oldKey:key newKey:nil salt:nil error:&decryptDbError];
        if (decryptDbError || ![SFSmartStoreDatabaseManager verifyDatabaseAccess:decryptedDB error:&decryptDbError] ) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to decrypt  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        // Now encrypt with new SALT + KEY
        NSError *reEncryptDbError = nil;
        FMDatabase *reEncryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:decryptedDB name:storeName  path:decryptedDB.databasePath  oldKey:@"" newKey:key salt:newSalt error:&reEncryptDbError];
        if (!reEncryptedDB || reEncryptDbError) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to reencrypt DB %@:", [reEncryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [fileManager removeItemAtPath:decryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        if (![SFSmartStoreDatabaseManager verifyDatabaseAccess:reEncryptedDB error:&decryptDbError]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Failed to verify reencrypted  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', %@", storePath,errorDesc];
            [fileManager removeItemAtPath:reEncryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        [reEncryptedDB close];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Migration complete.", storePath];
        [fileManager removeItemAtPath:backupStorePath error:nil];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Removed backup.", backupStorePath];
        [[NSUserDefaults msdkUserDefaults] setBool:YES forKey:kKeyStoreHasExternalSalt];
        return YES;
    }
    return NO;
}

+ (BOOL)restoreBackupTo:(NSURL *)origDatabaseURL from:(NSURL *)backupDatabaseURL {
    BOOL success = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *restoreBackupError = nil;
    [fileManager removeItemAtPath:origDatabaseURL.path error:nil];
    [fileManager copyItemAtURL:backupDatabaseURL toURL:origDatabaseURL error:&restoreBackupError];
    if (restoreBackupError) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Could not restore  from backup.", origDatabaseURL];
    } else {
        success = YES;
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Recovered from backup.", origDatabaseURL];
    }
    return success;
}

#pragma mark - Legacy SmartStore filesystem functionality

+ (NSArray *)legacyAllStoreNames
{
    NSString *rootDir = [SFSmartStoreUpgrade legacyRootStoreDirectory];
    NSError *getStoresError = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    
    // First see if the legacy root folder exists.
    BOOL rootDirIsDirectory = NO;
    BOOL rootDirExists = [manager fileExistsAtPath:rootDir isDirectory:&rootDirIsDirectory];
    if (!rootDirExists || !rootDirIsDirectory) {
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Legacy SmartStore directory does not exist. Nothing to do."];
        return nil;
    }
    
    // Get the folder paths of the legacy stores.
    NSArray *storesDirNames = [manager contentsOfDirectoryAtPath:rootDir error:&getStoresError];
    if (getStoresError) {
        [SFSDKSmartStoreLogger w:[SFSmartStoreUpgrade class] format:@"Problem retrieving store names from legacy SmartStore directory: %@.  Will not continue.", [getStoresError localizedDescription]];
        return nil;
    }
    NSMutableArray *allStoreNames = [NSMutableArray array];
    for (NSString *storesDirName in storesDirNames) {
        if ([SFSmartStoreUpgrade legacyPersistentStoreExists:storesDirName])
            [allStoreNames addObject:storesDirName];
    }
    return allStoreNames;
}

+ (BOOL)legacyPersistentStoreExists:(NSString *)storeName
{
    NSString *fullDbFilePath = [SFSmartStoreUpgrade legacyFullDbFilePathForStoreName:storeName];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL result = [manager fileExistsAtPath:fullDbFilePath];
    return result;
}

+ (NSString *)legacyFullDbFilePathForStoreName:(NSString *)storeName
{
    NSString *storePath = [SFSmartStoreUpgrade legacyStoreDirectoryForStoreName:storeName];
    NSString *fullDbFilePath = [storePath stringByAppendingPathComponent:kStoreDbFileName];
    return fullDbFilePath;
}

+ (NSString *)legacyStoreDirectoryForStoreName:(NSString *)storeName
{
    NSString *storesDir = [SFSmartStoreUpgrade legacyRootStoreDirectory];
    NSString *result = [storesDir stringByAppendingPathComponent:storeName];
    
    return result;
}

+ (NSString *)legacyRootStoreDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *storesDir = [documentsDirectory stringByAppendingPathComponent:kStoresDirectory];
    
    return storesDir;
}


@end
