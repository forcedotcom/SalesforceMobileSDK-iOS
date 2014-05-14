//
//  SFSmartStoreUpgrade.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 5/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFSmartStoreUpgrade+Internal.h"
#import "SFSmartStore.h"
#import "SFSmartStoreDatabaseManager.h"
#import <SalesforceCommonUtils/UIDevice+SFHardware.h>
#import <SalesforceCommonUtils/SFCrypto.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import <SalesforceCommonUtils/NSData+SFAdditions.h>
#import "FMDatabase.h"

static const char *const_key = "H347ergher/32hhj5%hff?Dn@21o";
static NSString * const kDefaultPasscodeStoresKey = @"com.salesforce.smartstore.defaultPasscodeStores";
static NSString * const kDefaultEncryptionTypeKey = @"com.salesforce.smartstore.defaultEncryptionType";

@implementation SFSmartStoreUpgrade

+ (void)updateDefaultEncryption
{
    [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Updating encryption method for all stores, where necessary."];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    [SFLogger log:[self class] level:SFLogLevelInfo format:@"Number of stores to update: %d", [allStoreNames count]];
    for (NSString *storeName in allStoreNames) {
        if (![self updateEncryptionForStore:storeName]) {
            [SFLogger log:[self class] level:SFLogLevelError format:@"Could not update encryption for '%@', which means the data is no longer accessible.  Removing store.", storeName];
            [SFSmartStore removeSharedStoreWithName:storeName];
        }
    }
}

+ (BOOL)updateEncryptionForStore:(NSString *)storeName
{
    if (![[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName]) {
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

+ (SFSmartStoreDefaultEncryptionType)defaultEncryptionTypeForStore:(NSString *)storeName
{
    NSDictionary *encTypeDict = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultEncryptionTypeKey];
    if (encTypeDict == nil) return SFSmartStoreDefaultEncryptionTypeMac;
    NSNumber *encTypeNum = [encTypeDict objectForKey:storeName];
    if (encTypeNum == nil) return SFSmartStoreDefaultEncryptionTypeMac;
    return [encTypeNum intValue];
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

@end
