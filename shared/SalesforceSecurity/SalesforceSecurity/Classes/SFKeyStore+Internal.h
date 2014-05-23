

#import "SFKeyStore.h"

static NSString * const kKeyStoreDecryptionFailedMessage = @"Could not decrypt key store with existing key store key.  Key store is invalid.";

@interface SFKeyStore ()

@property (nonatomic, readonly) NSString *storeKeychainIdentifier;
@property (nonatomic, readonly) NSString *storeDataArchiveKey;
@property (nonatomic, readonly) NSString *encryptionKeyKeychainIdentifier;
@property (nonatomic, readonly) NSString *encryptionKeyDataArchiveKey;

/**
 Creates a keychain ID that should be unique across app installs/re-installs, making sure
 that erroneous keychain data is not present if the app is re-installed.
 @param baseKeychainId The identifier that the keychain key is based on.
 @return An identifier with the base ID and unique data appended to it.
 */
- (NSString *)buildUniqueKeychainId:(NSString *)baseKeychainId;

/**
 Retrieves the key store dictionary, decrypting it with the specified key.
 @param decryptKey The key used to decrypt the dictionary.
 @return The decrypted dictionary, or `nil` if the dictionary could not be decrypted.
 */
- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey;

@end