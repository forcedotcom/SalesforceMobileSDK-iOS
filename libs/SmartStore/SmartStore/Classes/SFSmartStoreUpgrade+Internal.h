/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

/**
 Enumeration of types of encryption used for the default encryption of stores.
 */
typedef NS_ENUM(NSUInteger, SFSmartStoreLegacyDefaultEncryptionType) {
    SFSmartStoreDefaultEncryptionTypeNone,
    SFSmartStoreDefaultEncryptionTypeMac,
    SFSmartStoreDefaultEncryptionTypeIdForVendor,
    SFSmartStoreDefaultEncryptionTypeBaseAppId
};

@interface SFSmartStoreUpgrade ()

/**
 @return The default key to use, if no encryption key exists.
 */
+ (NSString *)legacyDefaultKey;

/**
 Determines whether the given store uses a legacy default key for encryption.
 @param storeName The store associated with the setting.
 @return YES if it does, NO if it doesn't.
 */
+ (BOOL)usesLegacyDefaultKey:(NSString *)storeName;

/**
 Sets a property specifying whether the given store uses a default key for encryption.
 @param usesDefault Whether the store uses a default key.
 @param storeName The store for which the setting applies.
 */
+ (void)setUsesLegacyDefaultKey:(BOOL)usesDefault forStore:(NSString *)storeName;

/**
 Sets the default encryption type for the given store.
 @param encType The type of default encryption being used for the store.
 @param storeName The name of the store to set the value for.
 */
+ (void)setLegacyDefaultEncryptionType:(SFSmartStoreLegacyDefaultEncryptionType)encType forStore:(NSString *)storeName;

/**
 Gets the default encryption type for the given store.
 @param storeName The name of the story to query for its default encryption type.
 @return An SFSmartStoreDefaultEncryptionType enumerated value specifying the default encryption type.
 */
+ (SFSmartStoreLegacyDefaultEncryptionType)legacyDefaultEncryptionTypeForStore:(NSString *)storeName;

/**
 @return The default key, based on the MAC address.
 */
+ (NSString *)legacyDefaultKeyMac;

/**
 @return The default key, based on the idForVendor value.
 */
+ (NSString *)legacyDefaultKeyIdForVendor;

/**
 @return The default key, based on the base app id.
 */
+ (NSString *)legacyDefaultKeyBaseAppId;

/**
 Creates a default key with the given seed.
 @param seed The seed for creating the default key.
 @return The default key, based on the seed.
 */
+ (NSString *)legacyDefaultKeyWithSeed:(NSString *)seed;

@end
