

#import "SFSmartStoreUpgrade.h"

@interface SFSmartStoreUpgrade ()

/**
 Sets the default encryption type for the given store.
 @param encType The type of default encryption being used for the store.
 @param storeName The name of the store to set the value for.
 */
+ (void)setDefaultEncryptionType:(SFSmartStoreDefaultEncryptionType)encType forStore:(NSString *)storeName;

/**
 Gets the default encryption type for the given store.
 @param storeName The name of the story to query for its default encryption type.
 @return An SFSmartStoreDefaultEncryptionType enumerated value specifying the default encryption type.
 */
+ (SFSmartStoreDefaultEncryptionType)defaultEncryptionTypeForStore:(NSString *)storeName;

/**
 @return The default key, based on the MAC address.
 */
+ (NSString *)defaultKeyMac;

/**
 @return The default key, based on the idForVendor value.
 */
+ (NSString *)defaultKeyIdForVendor;

/**
 @return The default key, based on the base app id.
 */
+ (NSString *)defaultKeyBaseAppId;

/**
 Creates a default key with the given seed.
 @param seed The seed for creating the default key.
 @return The default key, based on the seed.
 */
+ (NSString *)defaultKeyWithSeed:(NSString *)seed;

@end