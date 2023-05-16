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
#import <SalesforceSDKCommon/SFFileProtectionHelper.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import "SFSDKSalesforceSDKUpgradeManager.h"
#import "SFDirectoryManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFDefaultUserAccountPersister.h"
#import "SFApplicationHelper.h"

NSString * const kSalesforceSDKManagerVersionKey = @"com.salesforce.mobilesdk.salesforcesdkmanager.version";
static NSString * _lastVersion = nil;
static NSString * _currentVersion = nil;

@implementation SFSDKSalesforceSDKUpgradeManager

+ (void)upgrade {
    @synchronized ([SFSDKSalesforceSDKUpgradeManager class]) {
        NSString *lastVersion = [SFSDKSalesforceSDKUpgradeManager lastVersion];
        NSString *currentVersion = [SFSDKSalesforceSDKUpgradeManager currentVersion];
        
        if ([currentVersion isEqualToString:lastVersion]) {
            return;
        }

        if (!lastVersion || [lastVersion compare:@"9.2.1" options:NSNumericSearch] == NSOrderedAscending) {
            // 9.2.0 & 9.2.1 upgrade steps both need file and keychain access, if we don't have those,
            // abort the upgrade so that it can rerun

            if (![SFSDKKeychainHelper accessibilityAttribute]) {
                // Only update accessible attribute if the app isn't setting it
                [SFLogger log:[self class] level:SFLogLevelError format:@"Attempt keychain attribute update"];
                SFSDKKeychainResult *result = [SFSDKKeychainHelper setAccessibleAttribute:KeychainItemAccessibilityAfterFirstUnlockThisDeviceOnly];
                if (result.status == errSecInteractionNotAllowed) {
                    [SFLogger log:[self class] level:SFLogLevelError format:@"Upgrade step skipped because keychain access not allowed"];
                    return;
                }
            }
            
            NSArray<NSString *> *filesWithCompleteProtection = [SFSDKSalesforceSDKUpgradeManager filesWithCompleteProtection];
            if ([filesWithCompleteProtection count] > 0) {
                if (![SFApplicationHelper sharedApplication].isProtectedDataAvailable) {
                    [SFLogger log:[self class] level:SFLogLevelError format:@"Upgrade step skipped because files have complete protection and protected data isn't available"];
                    return;
                }
                [SFSDKSalesforceSDKUpgradeManager updateDefaultProtection:filesWithCompleteProtection];
            }
        }

        if (!lastVersion || [lastVersion compare:@"9.2.0" options:NSNumericSearch] == NSOrderedAscending) {
            [SFDirectoryManager upgradeUserDirectories];
            [NSURLCache.sharedURLCache removeAllCachedResponses]; // For cache encryption key change
        }
        
        if (!lastVersion || [lastVersion compare:@"10.1.1" options:NSNumericSearch] == NSOrderedAscending) {
            [SFSDKSalesforceSDKUpgradeManager upgradePasscode];
        }
        
        [SFSDKSalesforceSDKUpgradeManager setLastVersion:currentVersion];
    }
}

+ (NSArray<NSString *> *)filesWithCompleteProtection {
    NSMutableArray<NSString *> *filesToReturn = [NSMutableArray new];
    
    NSArray *directories = @[[[SFDirectoryManager sharedManager] directoryForOrg:nil user:nil community:nil type:NSLibraryDirectory components:nil], [[SFDirectoryManager sharedManager] directoryForOrg:nil user:nil community:nil type:NSDocumentDirectory components:nil]];
    for (NSString *directory in directories) {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:directory] includingPropertiesForKeys:@[NSURLFileProtectionKey] options:NSDirectoryEnumerationProducesRelativePathURLs errorHandler:nil];
        NSURL *fileURL;
        while (fileURL = [enumerator nextObject]) {
            NSString *fileString = [fileURL relativeString];
            // Anything scoped to the org and below, or global stores
            if ([fileString hasPrefix:@"00D"] || [fileString hasPrefix:@"stores"] || [fileString hasPrefix:@"key_value_stores"]) {
                NSString *fileProtection = nil;
                [fileURL getResourceValue:&fileProtection forKey:NSURLFileProtectionKey error:nil];
                if ([fileProtection isEqualToString:NSURLFileProtectionComplete]) {
                    [filesToReturn addObject:[directory stringByAppendingPathComponent:fileString]];
                }
            }
        }
    }
    return filesToReturn;
}

+ (void)updateDefaultProtection:(NSArray<NSString *> *)paths {
    for (NSString *path in paths) {
        NSString *fileProtection = [SFFileProtectionHelper fileProtectionForPath:path];
        [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:fileProtection} ofItemAtPath:path error:nil];
    }
}

+ (void)setLastVersion:(NSString *)version {
    [[NSUserDefaults msdkUserDefaults] setValue:version forKey:kSalesforceSDKManagerVersionKey];
    [[NSUserDefaults msdkUserDefaults] synchronize];
    _lastVersion = version;
    [SFLogger log:[self class] level:SFLogLevelInfo format:@"Upgraded to %@", version];
}

+ (NSString *)lastVersion {
    if (!_lastVersion) {
        _lastVersion = [[NSUserDefaults msdkUserDefaults] stringForKey:kSalesforceSDKManagerVersionKey];
    }
    return _lastVersion;
}

+ (NSString *)currentVersion {
    if (!_currentVersion) {
        _currentVersion = [[[NSBundle bundleForClass:[SFSDKSalesforceSDKUpgradeManager class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    }
    return _currentVersion;
}


+ (void)upgradePasscode {
    [[SFScreenLockManagerInternal shared] upgradePasscode];
}

@end
