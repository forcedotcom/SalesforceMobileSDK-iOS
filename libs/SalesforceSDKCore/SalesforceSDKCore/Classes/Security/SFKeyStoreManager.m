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

#import <CommonCrypto/CommonCrypto.h>

#import "SFKeyStoreManager+Internal.h"
#import "SFSDKCryptoUtils.h"

// Keychain and NSCoding constants
static NSString * const kKeyStoreKeychainIdentifier = @"com.salesforce.keystore.keystoreKeychainId";
static NSString * const kKeyStoreDataArchiveKey = @"com.salesforce.keystore.keystoreDataArchive";
static NSString * const kKeyStoreEncryptionKeyKeychainIdentifier = @"com.salesforce.keystore.keystoreEncryptionKeyId";
static NSString * const kKeyStoreEncryptionKeyDataArchiveKey = @"com.salesforce.keystore.keystoreEncryptionKeyDataArchive";

// Static log messages/format strings
static NSString * const kKeyStoreDecryptionFailedMessage = @"Could not decrypt key store with existing key store key.  Key store is invalid.";

@implementation SFKeyStoreManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static SFKeyStoreManager *keyStoreManager = nil;
    dispatch_once(&pred, ^{
		keyStoreManager = [[self alloc] init];
	});
    return keyStoreManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self initializeKeyStores];
        [[SFPasscodeManager sharedManager] addObserver:self forKeyPath:@"encryptionKey" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
    }
    return self;
}

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel autoCreate:(BOOL)create
{
    if (keyLabel == nil) return nil;
    
    @synchronized (self) {
        SFKeyStoreKey *key = nil;
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel];
        key = (self.generatedKeyStore.keyStoreDictionary)[typedKeyLabel];

        if (!key && create) {
            SFEncryptionKey *newKey = [self keyWithRandomValue];
            key = [[SFKeyStoreKey alloc] initWithKey:newKey];
            [self storeKeyStoreKey:key withLabel:keyLabel];
        }
        
        return key.encryptionKey;
    }
}

- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel
{
    NSAssert(key != nil, @"key must have a value.");
    NSAssert(keyLabel != nil, @"key label must have a value.");
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:key];
    [self storeKeyStoreKey:keyStoreKey withLabel:keyLabel];
}

- (void)removeKeyWithLabel:(NSString *)keyLabel
{
    if (keyLabel == nil) return;
    
    @synchronized (self) {
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel];
        NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        [mutableKeyStoreDict removeObjectForKey:typedKeyLabel];
        self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
    }
}

- (BOOL)keyWithLabelExists:(NSString *)keyLabel
{
    @synchronized (self) {
        SFEncryptionKey *key = [self retrieveKeyWithLabel:keyLabel autoCreate:NO];
        return (key != nil);
    }
}

- (SFEncryptionKey *)keyWithRandomValue
{
    NSData *keyData = [SFSDKCryptoUtils randomByteDataWithLength:kCCKeySizeAES256];
    NSData *iv = [SFSDKCryptoUtils randomByteDataWithLength:kCCBlockSizeAES128];
    SFEncryptionKey *key = [[SFEncryptionKey alloc] initWithData:keyData initializationVector:iv];
    return key;
}

#pragma mark - Private methods

- (void)initializeKeyStores
{
    self.generatedKeyStore = [[SFGeneratedKeyStore alloc] init];
    if (self.generatedKeyStore.keyStoreKey == nil) {
        self.generatedKeyStore.keyStoreKey = [self createDefaultKey];
    }
    else {
        // Pre SDK 6.0 code would store keys with keytype passcode in generated store if there was no passcode enabled
        // Starting with SDK 6.0, we don't pass the keytype anymore (it's always generated)
        // For things to work, we need to rename keys named xxx__Passcode to xxx__Generated
        [self renameKeysWithKeyTypePasscode:self.generatedKeyStore];
    }
}

- (void)renameKeysWithKeyTypePasscode:(SFGeneratedKeyStore*)generatedKeyStore
{
    @synchronized (self) {
        NSDictionary *originalKeys = [NSDictionary dictionaryWithDictionary:generatedKeyStore.keyStoreDictionary];
        NSMutableDictionary *updatedGeneratedDictionary = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        for (NSString *originalKeyLabel in [originalKeys allKeys]) {
            SFKeyStoreKey *key = originalKeys[originalKeyLabel];
            NSRange suffixRange = [originalKeyLabel rangeOfString:kPasscodeKeyLabelSuffix options:NSBackwardsSearch];
            if (suffixRange.location != NSNotFound) {
                NSString* renamedKeyLabel = [originalKeyLabel stringByReplacingCharactersInRange:suffixRange withString:kGeneratedKeyLabelSuffix];
                updatedGeneratedDictionary[renamedKeyLabel] = key;
                [updatedGeneratedDictionary removeObjectForKey:originalKeyLabel];
                [SFSDKCoreLogger i:[self class] format:@"Renaming key %@ to %@", originalKeyLabel, renamedKeyLabel];
            }
        }
        
        self.generatedKeyStore.keyStoreDictionary = updatedGeneratedDictionary;
    }

}

- (void)migratePasscodeToGenerated:(SFPasscodeKeyStore*)passcodeKeyStore
{
    @synchronized (self) {
        NSDictionary *keysToMove = [NSDictionary dictionaryWithDictionary:passcodeKeyStore.keyStoreDictionary];
        NSMutableDictionary *updatedGeneratedDictionary = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        for (NSString *keyToMoveLabel in [keysToMove allKeys]) {
            SFKeyStoreKey *keyToMove = keysToMove[keyToMoveLabel];
            NSRange suffixRange = [keyToMoveLabel rangeOfString:kPasscodeKeyLabelSuffix options:NSBackwardsSearch];
            NSString* movedKeyLabel = [keyToMoveLabel stringByReplacingCharactersInRange:suffixRange withString:kGeneratedKeyLabelSuffix];
            updatedGeneratedDictionary[movedKeyLabel] = keyToMove;
            [SFSDKCoreLogger i:[self class] format:@"Migrating key %@ to %@", keyToMoveLabel, movedKeyLabel];
        }
        
        self.generatedKeyStore.keyStoreDictionary = updatedGeneratedDictionary;
        passcodeKeyStore.keyStoreDictionary = nil;
    }
}

- (void)storeKeyStoreKey:(SFKeyStoreKey *)key withLabel:(NSString *)keyLabel
{
    @synchronized (self) {
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel];
        NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        mutableKeyStoreDict[typedKeyLabel] = key;
        self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
    }
}

- (NSString *)keyLabelForBaseLabel:(NSString *)baseLabel
{
    return [self.generatedKeyStore keyLabelForString:baseLabel];
}

- (SFKeyStoreKey *)createDefaultKey
{
    SFEncryptionKey *encKey = [self keyWithRandomValue];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey];
    return keyStoreKey;
}

+ (NSData *)keyStringToData:(NSString *)keyString
{
    return [keyString dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - SFPasscodeManager encryption key updates

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Starting in SDK 6.0, we no longer use SFPasscodeKeyStore.
    // The only reason we are still watching the encryption key of the passcode manager is to handle upgrade from pre-6.0 SDK to 6+.
    // As soon as we get the passcode, we migrate all the keys from the passcode key store to the generated key store.
    
    if (!(object == [SFPasscodeManager sharedManager] && [keyPath isEqualToString:@"encryptionKey"])) {
        return;
    }
    
    @synchronized (self) {
        NSString *oldKey = change[NSKeyValueChangeOldKey];
        NSString *newKey = change[NSKeyValueChangeNewKey];
        if ([oldKey isEqual:[NSNull null]]) oldKey = nil;
        if ([newKey isEqual:[NSNull null]]) newKey = nil;

        if ([oldKey length] == 0 && [newKey length] > 0) {
            // We just got the passcode, migrate keys (if any)
            SFPasscodeKeyStore *passcodeKeyStore = [[SFPasscodeKeyStore alloc] init];
            passcodeKeyStore.keyStoreKey.encryptionKey.key = [[self class] keyStringToData:newKey];
            if (passcodeKeyStore.keyStoreKey != nil && passcodeKeyStore.keyStoreDictionary.count > 0) {
                [self migratePasscodeToGenerated:passcodeKeyStore];
            }
        }
    }
}

@end
