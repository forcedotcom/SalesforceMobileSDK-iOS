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
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFSDKDataSharinghelper.h>
#import "FMDatabase.h"

NSString * const kKeyStoreHasExternalSalt = @"com.salesforce.smartstore.external.hasExternalSalt";
NSString * const kSmartStoreVersionKey = @"com.salesforce.mobilesdk.smartstore.version";

@implementation SFSmartStoreUpgrade

+ (void)upgrade {
    NSString *lastVersion = [SFSmartStoreUpgrade lastVersion];
    NSString *currentVersion = [SFSmartStoreUpgrade currentVersion];
    
    if ([currentVersion isEqualToString:lastVersion]) {
        return;
    }
    
    if (!lastVersion || [lastVersion doubleValue] < 9.2) {
        [SFSmartStoreUpgrade upgradeEncryption];
    }
    
    [[NSUserDefaults msdkUserDefaults] setValue:currentVersion forKey:kSmartStoreVersionKey];
    [[NSUserDefaults msdkUserDefaults] synchronize];
}

+ (NSString *)lastVersion {
    return [[NSUserDefaults msdkUserDefaults] stringForKey:kSmartStoreVersionKey];
}

+ (NSString *)currentVersion {
    return [[[NSBundle bundleForClass:[SFSmartStoreUpgrade class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (void)upgradeEncryption {
    // Update user stores
    for (SFUserAccount *userAccount in [[SFUserAccountManager sharedInstance] allUserAccounts]) {
        SFSmartStoreDatabaseManager *databaseManager = [SFSmartStoreDatabaseManager sharedManagerForUser:userAccount];
        [SFSmartStoreUpgrade updateEncryptionForDatabaseManager:databaseManager];
    }
    
    // Global store
    [SFSmartStoreUpgrade updateEncryptionForDatabaseManager:[SFSmartStoreDatabaseManager sharedGlobalManager]];
}

+ (void)updateEncryptionForDatabaseManager:(SFSmartStoreDatabaseManager *)databaseManager {
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Updating encryption for stores."];
    NSArray *allStoreNames = [databaseManager allStoreNames];
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Number of stores to update: %d", [allStoreNames count]];
    for (NSString *storeName in allStoreNames) {
        if (![SFSmartStoreUpgrade updateEncryptionForStore:storeName databaseManager:databaseManager]) {
             [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to encryption and salt for %@", storeName];
        }
    }
}


+ (BOOL)updateEncryptionForStore:(NSString *)storeName databaseManager:(SFSmartStoreDatabaseManager *)databaseManager {
    if (![databaseManager persistentStoreExists:storeName]) {
        //NEW Database no need for encryption key
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Store '%@' does not exist on the filesystem. Skipping encryption update.", storeName];
        return NO;
    }
    
    NSError *openDbError = nil;
    NSString *legacyKey = [SFSmartStore legacyEncKey];
    NSString *key = [SFSmartStore encKey];
    NSString *legacySalt = [[NSUserDefaults msdkUserDefaults] boolForKey:kKeyStoreHasExternalSalt] ? [SFSmartStore legacySalt] : nil;
    NSString *newSalt = [SFSmartStore salt];
    
    FMDatabase *originalEncyptedDB = [databaseManager openStoreDatabaseWithName:storeName
                                                                            key:legacyKey
                                                                           salt:legacySalt
                                                                          error:&openDbError];
    if (originalEncyptedDB == nil || openDbError != nil) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error opening store '%@' to update encryption: %@", storeName, [openDbError localizedDescription]];
        return NO;
    } else if (![[databaseManager class] verifyDatabaseAccess:originalEncyptedDB error:&openDbError]) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error reading the content of store '%@' during encryption upgrade: %@", storeName, [openDbError  localizedDescription]];
        [originalEncyptedDB close];
        return NO;
    }
    
    if ([key length] > 0) {
        // Unencrypt with previous key.
        NSString *origDatabasePath = originalEncyptedDB.databasePath;
        
        NSString *storePath = [databaseManager fullDbFilePathForStoreName:storeName];
        NSString *backupStorePath = [NSString stringWithFormat:@"%@_%@", storePath, @"backup"];
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
        
        // Let's decrypt DB
        FMDatabase *decryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:originalEncyptedDB name:storeName  path:originalEncyptedDB.databasePath oldKey:legacyKey newKey:nil salt:legacySalt error:&decryptDbError];
        if (decryptDbError || ![SFSmartStoreDatabaseManager verifyDatabaseAccess:decryptedDB error:&decryptDbError] ) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating DB, failed to decrypt DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating DB '%@', %@", storePath, errorDesc];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        // Now encrypt with new SALT + KEY
        NSError *reEncryptDbError = nil;
        FMDatabase *reEncryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:decryptedDB name:storeName path:decryptedDB.databasePath oldKey:@"" newKey:key salt:newSalt error:&reEncryptDbError];
        if (!reEncryptedDB || reEncryptDbError) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating DB, failed to reencrypt DB %@:", [reEncryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating DB '%@', %@", storePath, errorDesc];
            [fileManager removeItemAtPath:decryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        if (![SFSmartStoreDatabaseManager verifyDatabaseAccess:reEncryptedDB error:&decryptDbError]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Failed to verify reencrypted DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating DB at '%@', %@", storePath,errorDesc];
            [fileManager removeItemAtPath:reEncryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        [reEncryptedDB close];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating DB '%@', migration complete.", storePath];
        [fileManager removeItemAtPath:backupStorePath error:nil];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating DB '%@', removed backup.", backupStorePath];
        
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
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Could not restore from backup.", origDatabaseURL];
    } else {
        success = YES;
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Recovered from backup.", origDatabaseURL];
    }
    return success;
}

@end
