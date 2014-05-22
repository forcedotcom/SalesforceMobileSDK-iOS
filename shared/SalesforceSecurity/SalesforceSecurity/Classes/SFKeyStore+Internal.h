

#import "SFKeyStore.h"

static NSString * const kKeyStoreDecryptionFailedMessage = @"Could not decrypt key store with existing key store key.  Key store is invalid.";

@interface SFKeyStore ()

@property (nonatomic, readonly) NSString *storeKeychainIdentifier;
@property (nonatomic, readonly) NSString *storeDataArchiveKey;
@property (nonatomic, readonly) NSString *encryptionKeyKeychainIdentifier;
@property (nonatomic, readonly) NSString *encryptionKeyDataArchiveKey;

- (NSString *)buildUniqueKeychainId:(NSString *)baseKeychainId;
- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey;

@end