//
//  SFSDKSalesforceSDKUpgradeManager.m
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 9/14/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import "SFSDKSalesforceSDKUpgradeManager.h"
#import "SFDirectoryManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFKeyStoreManager.h"
#import "SFDefaultUserAccountPersister.h"
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import "SFSecurityLockout+Internal.h"

NSString * const kSalesforceSDKManagerVersionKey = @"com.salesforce.mobilesdk.salesforcesdkmanager.version";

@implementation SFSDKSalesforceSDKUpgradeManager

+ (void)upgrade {
    NSString *lastVersion = [SFSDKSalesforceSDKUpgradeManager lastVersion];
    NSString *currentVersion = [SFSDKSalesforceSDKUpgradeManager currentVersion];
    
    if ([currentVersion isEqualToString:lastVersion]) {
        return;
    }
    
    if (!lastVersion || [lastVersion doubleValue] < 9.2) {
        [SFDirectoryManager upgradeUserDirectories];
        [SFSDKSalesforceSDKUpgradeManager upgradeUserAccounts];
        [NSURLCache.sharedURLCache removeAllCachedResponses]; // For cache encryption key change
        [SFSDKSalesforceSDKUpgradeManager upgradePasscode];
    }
    
    [[NSUserDefaults msdkUserDefaults] setValue:currentVersion forKey:kSalesforceSDKManagerVersionKey];
    [[NSUserDefaults msdkUserDefaults] synchronize];
}

+ (NSString *)lastVersion {
    return [[NSUserDefaults msdkUserDefaults] stringForKey:kSalesforceSDKManagerVersionKey];
}

+ (NSString *)currentVersion {
    return [[[NSBundle bundleForClass:[SFSDKSalesforceSDKUpgradeManager class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (void)upgradeUserAccounts {
    NSString *rootDirectory = [[SFDirectoryManager sharedManager] directoryForOrg:nil user:nil community:nil type:NSLibraryDirectory components:nil];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:rootDirectory]) {
        NSArray *rootContents = [fm contentsOfDirectoryAtPath:rootDirectory error:nil];
        for (NSString *rootContent in rootContents) {
            if (![rootContent hasPrefix:kOrgPrefix]) {
                continue;
            }
            NSString *rootPath = [rootDirectory stringByAppendingPathComponent:rootContent];
            NSArray *orgContents = [fm contentsOfDirectoryAtPath:rootPath error:nil];
            for (NSString *orgContent in orgContents) {
                if (![orgContent hasPrefix:kUserPrefix]) {
                    continue;
                }
                NSString *orgPath = [rootPath stringByAppendingPathComponent:orgContent];

                // Check for user account file
                // ~/Library/<appBundleId>/<orgId>/<userId>/UserAccount.plist
                NSString *userAccountPath = [orgPath stringByAppendingPathComponent:kUserAccountPlistFileName];
                if ([fm fileExistsAtPath:userAccountPath]) {
                    [SFSDKSalesforceSDKUpgradeManager updateEncryptionForUserAccountPath:userAccountPath];
                }
                
                // Check for user photo
                NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:[NSURL URLWithString:orgPath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
                NSURL *userContent;
                while ((userContent = [enumerator nextObject])) {
                    if ([userContent.absoluteString hasSuffix:@"mobilesdk/photos/"]) {
                        [SFSDKSalesforceSDKUpgradeManager updatePhoto:userContent userID:orgContent];
                    }
                }
            }
        }
    }
}

+ (void)updatePhoto:(NSURL *)photoDirectory userID:(NSString *)userID {
    NSURL *photoURL = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:photoDirectory includingPropertiesForKeys:nil options:0 error:nil].firstObject;
    if (!photoURL) {
        return;
    }

    // Starting in Mobile SDK 8.2, 18 character IDs are used instead of 15 character IDs.
    // This renames the 15 character profile picture to 18 characters.
    if ([[photoURL lastPathComponent] isEqualToString:[userID substringToIndex:15]]) {
        NSURL *shortURL = photoURL;
        photoURL = [[shortURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:userID];
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtURL:shortURL toURL:photoURL error:&error];
        if (error) {
            [SFSDKCoreLogger e:[self class] format:@"Error moving %@ to %@: %@", shortURL, photoURL, error];
        }
    }

    // Starting in Mobile SDK 9.2, photos are encrypted with a different key
    // Decrypt with legacy key
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SFEncryptionKey *oldKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountPhotoEncryptionKeyLabel autoCreate:NO];
    #pragma clang diagnostic pop
    NSData *data = [NSData dataWithContentsOfURL:photoURL];
    NSData *decryptedPhoto = [oldKey decryptData:data];
   
    // Reencrypt with new key
    NSError *error = nil;
    NSData *newKey = [SFSDKKeyGenerator encryptionKeyFor:kUserAccountPhotoEncryptionKeyLabel error:&error];
    if (error) {
        [SFSDKCoreLogger e:[SFSDKSalesforceSDKUpgradeManager class] format:@"Error getting encryption key for %@: %@", kUserAccountPhotoEncryptionKeyLabel, error.localizedDescription];
        return;
    }
    NSData *encryptedPhoto = [SFSDKEncryptor encryptData:decryptedPhoto key:newKey error:&error];
    if (error) {
        [SFSDKCoreLogger e:[SFSDKSalesforceSDKUpgradeManager class] format:@"Error reencrypting user photo: %@", error.localizedDescription];
        return;
    }

    [encryptedPhoto writeToURL:photoURL atomically:YES];
}

+ (void)updateEncryptionForUserAccountPath:(NSString *)userAccountPath {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSData *encryptedUserAccountData = [manager contentsAtPath:userAccountPath];

    // Decrypt account with legacy key
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SFEncryptionKey *oldKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel autoCreate:NO];
    #pragma clang diagnostic pop
    if (!oldKey || !encryptedUserAccountData) {
        [SFSDKCoreLogger e:[SFSDKSalesforceSDKUpgradeManager class] format:@"Existing account or key is nil"];
        return;
    }
    NSData *decryptedArchiveData = [oldKey decryptData:encryptedUserAccountData];

    // Reencrypt with new key
    NSError *error = nil;
    NSData *encryptionKey = [SFSDKKeyGenerator encryptionKeyFor:kUserAccountEncryptionKeyLabel error:&error];
    if (error) {
        [SFSDKCoreLogger e:[SFSDKSalesforceSDKUpgradeManager class] format:@"Error getting encryption key for %@ : %@", kUserAccountEncryptionKeyLabel, error.localizedDescription];
        return;
    }
    NSData *encryptedArchiveData = [SFSDKEncryptor encryptData:decryptedArchiveData key:encryptionKey error:&error];
    if (error) {
        [SFSDKCoreLogger e:[SFSDKSalesforceSDKUpgradeManager class] format:@"Error reencrypting user account: %@", error.localizedDescription];
        return;
    }
    [encryptedArchiveData writeToFile:userAccountPath atomically:YES];
}

+ (void)upgradePasscode {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [SFSecurityLockout resetPasscode];
    #pragma clang diagnostic pop
    [[SFScreenLockManager shared] upgradePasscode];
}

@end
