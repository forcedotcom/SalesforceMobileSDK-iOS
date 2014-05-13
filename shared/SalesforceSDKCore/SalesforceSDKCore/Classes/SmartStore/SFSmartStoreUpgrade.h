//
//  SFSmartStoreUpgrade.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 5/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Enumeration of types of encryption used for the default encryption of stores.
 */
typedef enum {
    SFSmartStoreDefaultEncryptionTypeNone,
    SFSmartStoreDefaultEncryptionTypeMac,
    SFSmartStoreDefaultEncryptionTypeIdForVendor,
    SFSmartStoreDefaultEncryptionTypeBaseAppId,
    SFSmartStoreDefaultEncryptionTypeKeyStore
} SFSmartStoreDefaultEncryptionType;

@interface SFSmartStoreUpgrade : NSObject

+ (void)updateDefaultEncryption;

/**
 Determines whether the given store uses a legacy default key for encryption.
 @param storeName The store associated with the setting.
 @return YES if it does, NO if it doesn't.
 */
+ (BOOL)usesDefaultKey:(NSString *)storeName;

/**
 Sets a property specifying whether the given store uses a default key for encryption.
 @param usesDefault Whether the store uses a default key.
 @param storeName The store for which the setting applies.
 */
+ (void)setUsesDefaultKey:(BOOL)usesDefault forStore:(NSString *)storeName;

/**
 @return The default key to use, if no encryption key exists.
 */
+ (NSString *)defaultKey;

@end
