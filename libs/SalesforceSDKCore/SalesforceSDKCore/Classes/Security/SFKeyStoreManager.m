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

#import <CommonCrypto/CommonCrypto.h>

#import "SFKeyStoreManager+Internal.h"
#import "SFSDKCryptoUtils.h"
#import "SFKeychainItemWrapper.h"
#import "SFCrypto.h"

// Keychain and NSCoding constants
static NSString * const kKeyStoreKeychainIdentifier = @"com.salesforce.keystore.keystoreKeychainId";
static NSString * const kKeyStoreDataArchiveKey = @"com.salesforce.keystore.keystoreDataArchive";
static NSString * const kKeyStoreEncryptionKeyKeychainIdentifier = @"com.salesforce.keystore.keystoreEncryptionKeyId";
static NSString * const kKeyStoreEncryptionKeyDataArchiveKey = @"com.salesforce.keystore.keystoreEncryptionKeyDataArchive";

// Static log messages/format strings
static NSString * const kKeyStoreDecryptionFailedMessage = @"Could not decrypt key store with existing key store key.  Key store is invalid.";
static NSString * const kUnknownKeyStoreTypeFormatString = @"Unknown key store key type: %lu.  Key store is invalid.";

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
    return [self retrieveKeyWithLabel:keyLabel keyType:SFKeyStoreKeyTypePasscode autoCreate:create];
}

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel keyType:(SFKeyStoreKeyType)keyType autoCreate:(BOOL)create
{
    if (keyLabel == nil) return nil;
    
    @synchronized (self) {
        SFKeyStoreKey *key = nil;
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel keyType:keyType];
        if (keyType == SFKeyStoreKeyTypeGenerated) {
            key = (self.generatedKeyStore.keyStoreDictionary)[typedKeyLabel];
        } else if (keyType == SFKeyStoreKeyTypePasscode) {
            if (self.passcodeKeyStore.keyStoreEnabled) {
                // There's a passcode configured, so the passcode key store should be in use.
                if (self.passcodeKeyStore.keyStoreAvailable) {
                    key = (self.passcodeKeyStore.keyStoreDictionary)[typedKeyLabel];
                } else {
                    [self log:SFLogLevelError format:@"Passcode key store is not yet available.  Cannot retrieve key with label '%@'.", keyLabel];
                    return nil;
                }
            } else {
                // No passcode configured.  Passcode keys fall back to being stored in the generated key store.
                key = (self.generatedKeyStore.keyStoreDictionary)[typedKeyLabel];
            }
        } else {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Key type with value %lu is not supported.", (unsigned long)keyType]
                                         userInfo:nil];
        }
        
        if (!key && create) {
            SFEncryptionKey *newKey = [self keyWithRandomValue];
            key = [[SFKeyStoreKey alloc] initWithKey:newKey type:keyType];
            [self storeKeyStoreKey:key withLabel:keyLabel];
        }
        
        return key.encryptionKey;
    }
}

- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel
{
    return [self storeKey:key withKeyType:SFKeyStoreKeyTypePasscode label:keyLabel];
}

- (void)storeKey:(SFEncryptionKey *)key withKeyType:(SFKeyStoreKeyType)keyType label:(NSString *)keyLabel
{
    NSAssert(key != nil, @"key must have a value.");
    NSAssert(keyLabel != nil, @"key label must have a value.");
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:key type:keyType];
    [self storeKeyStoreKey:keyStoreKey withLabel:keyLabel];
}

- (void)removeKeyWithLabel:(NSString *)keyLabel
{
    [self removeKeyWithLabel:keyLabel keyType:SFKeyStoreKeyTypePasscode];
}

- (void)removeKeyWithLabel:(NSString *)keyLabel keyType:(SFKeyStoreKeyType)keyType
{
    if (keyLabel == nil) return;
    
    @synchronized (self) {
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel keyType:keyType];
        if (keyType == SFKeyStoreKeyTypeGenerated) {
            NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
            [mutableKeyStoreDict removeObjectForKey:typedKeyLabel];
            self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
        } else if (keyType == SFKeyStoreKeyTypePasscode) {
            if (self.passcodeKeyStore.keyStoreEnabled) {
                // There's a passcode configured, so the passcode key store should be in use.
                if (self.passcodeKeyStore.keyStoreAvailable) {
                    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.passcodeKeyStore.keyStoreDictionary];
                    [mutableKeyStoreDict removeObjectForKey:typedKeyLabel];
                    self.passcodeKeyStore.keyStoreDictionary = mutableKeyStoreDict;
                } else {
                    [self log:SFLogLevelError format:@"Passcode key store is not yet available.  Cannot remove key with label '%@'.", keyLabel];
                }
            } else {
                // No passcode configured.  Passcode keys fall back to being stored in the generated key store.
                NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
                [mutableKeyStoreDict removeObjectForKey:typedKeyLabel];
                self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
            }
        } else {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Key type with value %lu is not supported.", (unsigned long)keyType]
                                         userInfo:nil];
        }
    }
}

- (BOOL)keyWithLabelExists:(NSString *)keyLabel
{
    return [self keyWithLabelAndKeyTypeExists:keyLabel keyType:SFKeyStoreKeyTypePasscode];
}

- (BOOL)keyWithLabelAndKeyTypeExists:(NSString *)keyLabel keyType:(SFKeyStoreKeyType)keyType
{
    @synchronized (self) {
        SFEncryptionKey *key = [self retrieveKeyWithLabel:keyLabel keyType:keyType autoCreate:NO];
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
    self.passcodeKeyStore = [[SFPasscodeKeyStore alloc] init];
    if (self.passcodeKeyStore.keyStoreKey == nil) {
        if (self.passcodeKeyStore.keyStoreAvailable) {
            // There's a passcode where there wasn't one before.  Migrate keys of that class.
            self.passcodeKeyStore.keyStoreKey = [self createNewPasscodeKey];
            [self migrateGeneratedToPasscode];
        }
    }
}

- (void)migrateGeneratedToPasscode
{
    // We will assume that sanity checks (passcode exists, etc.) have already been performed prior to calling this method.
    @synchronized (self) {
        NSMutableDictionary *keysToMove = [NSMutableDictionary dictionary];
        for (NSString *generatedKeyLabel in [self.generatedKeyStore.keyStoreDictionary allKeys]) {
            SFKeyStoreKey *generatedKey = (self.generatedKeyStore.keyStoreDictionary)[generatedKeyLabel];
            if (generatedKey.keyType == SFKeyStoreKeyTypePasscode) {
                keysToMove[generatedKeyLabel] = generatedKey;
            }
        }
        
        NSMutableDictionary *updatedGeneratedDictionary = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        NSMutableDictionary *updatedPasscodeDictionary = [NSMutableDictionary dictionaryWithDictionary:self.passcodeKeyStore.keyStoreDictionary];
        for (NSString *keyToMoveLabel in [keysToMove allKeys]) {
            [updatedGeneratedDictionary removeObjectForKey:keyToMoveLabel];
            SFKeyStoreKey *keyToMove = keysToMove[keyToMoveLabel];
            updatedPasscodeDictionary[keyToMoveLabel] = keyToMove;
        }
        
        self.generatedKeyStore.keyStoreDictionary = updatedGeneratedDictionary;
        self.passcodeKeyStore.keyStoreDictionary = updatedPasscodeDictionary;
    }
}

- (void)migratePasscodeToGenerated
{
    @synchronized (self) {
        // Everything moves in this direction.  Passcode store should only have passcode keys.
        NSDictionary *keysToMove = [NSDictionary dictionaryWithDictionary:self.passcodeKeyStore.keyStoreDictionary];
        NSMutableDictionary *updatedGeneratedDictionary = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
        for (NSString *keyToMoveLabel in [keysToMove allKeys]) {
            SFKeyStoreKey *keyToMove = keysToMove[keyToMoveLabel];
            updatedGeneratedDictionary[keyToMoveLabel] = keyToMove;
        }
        
        self.generatedKeyStore.keyStoreDictionary = updatedGeneratedDictionary;
        self.passcodeKeyStore.keyStoreDictionary = nil;
    }
}

- (void)storeKeyStoreKey:(SFKeyStoreKey *)key withLabel:(NSString *)keyLabel
{
    @synchronized (self) {
        NSString *typedKeyLabel = [self keyLabelForBaseLabel:keyLabel keyType:key.keyType];
        if (key.keyType == SFKeyStoreKeyTypeGenerated) {
            NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
            mutableKeyStoreDict[typedKeyLabel] = key;
            self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
        } else if (key.keyType == SFKeyStoreKeyTypePasscode) {
            if (self.passcodeKeyStore.keyStoreEnabled) {
                // There's a passcode configured, so the passcode key store should be in use.
                if (self.passcodeKeyStore.keyStoreAvailable) {
                    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.passcodeKeyStore.keyStoreDictionary];
                    mutableKeyStoreDict[typedKeyLabel] = key;
                    self.passcodeKeyStore.keyStoreDictionary = mutableKeyStoreDict;
                } else {
                    [self log:SFLogLevelError format:@"Passcode key store is not yet available.  Cannot store key with label '%@'.", keyLabel];
                }
            } else {
                // No passcode configured.  Passcode keys fall back to being stored in the generated key store.
                NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.generatedKeyStore.keyStoreDictionary];
                mutableKeyStoreDict[typedKeyLabel] = key;
                self.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;
            }
        } else {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Key type with value %lu is not supported.", (unsigned long)key.keyType]
                                         userInfo:nil];
        }
    }
}

- (NSString *)keyLabelForBaseLabel:(NSString *)baseLabel keyType:(SFKeyStoreKeyType)keyType
{
    SFKeyStore *keyStore = (keyType == SFKeyStoreKeyTypeGenerated ? self.generatedKeyStore : self.passcodeKeyStore);
    return [keyStore keyLabelForString:baseLabel];
}

- (SFKeyStoreKey *)createDefaultKey
{
    SFEncryptionKey *encKey = [self keyWithRandomValue];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypeGenerated];
    return keyStoreKey;
}

- (SFKeyStoreKey *)createNewPasscodeKey
{
    NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
    if ([passcodeEncryptionKey length] == 0) {
        [self log:SFLogLevelWarning msg:@"Attempting to create a passcode-based key, but passcode encryption key is not present."];
        return nil;
    }
    SFEncryptionKey *encKey = [[SFEncryptionKey alloc] initWithData:[[self class] keyStringToData:passcodeEncryptionKey]
                                               initializationVector:[SFSDKCryptoUtils randomByteDataWithLength:kCCBlockSizeAES128]];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypePasscode];
    return keyStoreKey;
}

+ (NSData *)keyStringToData:(NSString *)keyString
{
    return [keyString dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - SFPasscodeManager encryption key updates

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Watch the encryption key of the passcode manager, as its value drives the availability of the passcode key store.
    
    if (!(object == [SFPasscodeManager sharedManager] && [keyPath isEqualToString:@"encryptionKey"])) {
        return;
    }
    
    @synchronized (self) {
        NSString *oldKey = change[NSKeyValueChangeOldKey];
        NSString *newKey = change[NSKeyValueChangeNewKey];
        if ([oldKey isEqual:[NSNull null]]) oldKey = nil;
        if ([newKey isEqual:[NSNull null]]) newKey = nil;
        
        if ([oldKey isEqual:newKey])
            return;
        
        if (oldKey == nil && newKey == nil) {
            // This could happen in an edge case, where the passcode is reset before it was ever verified (e.g. if the
            // user forgot the passcode).  In this case, we won't be able to recover the passcode-class keys, but it
            // doesn't really matter, as the user effectively failed authentication, so those keys should no longer
            // be available.
            [self log:SFLogLevelWarning msg:@"Passcode reset without verification.  Passcode-class keys will be removed."];
            self.passcodeKeyStore.keyStoreKey = nil;
            self.passcodeKeyStore.keyStoreDictionary = nil;
        } else if ([oldKey length] == 0 && [newKey length] > 0) {
            // No encryption key -> encryption key.  Happens either on new passcode creation or first-time passcode verification.
            // We can infer the operation from the pre-existence of a key store key for the passcode store.
            if (self.passcodeKeyStore.keyStoreKey == nil) {
                // No previous passcode store key.  Assume passcode creation.
                [self log:SFLogLevelInfo msg:@"Passcode created.  Migrating passcode-class keys to passcode key store."];
                self.passcodeKeyStore.keyStoreKey = [self createNewPasscodeKey];
                [self migrateGeneratedToPasscode];
            } else {
                // Previous passcode store key.  Assume passcode verification.  Stage encryption key, but no re-encryption or
                // migration should be necessary.
                [self log:SFLogLevelInfo msg:@"Passcode verified.  Making passcode key store available."];
                self.passcodeKeyStore.keyStoreKey.encryptionKey.key = [[self class] keyStringToData:newKey];
            }
        } else if ([oldKey length] > 0 && [newKey length] == 0) {
            // Can only happen if passcode / encryption key is resetting.  Migrate accordingly.
            [self log:SFLogLevelInfo msg:@"Attempting to migrate passcode-class keys to generated store, after passcode removal."];
            self.passcodeKeyStore.keyStoreKey.encryptionKey.key = [[self class] keyStringToData:oldKey];
            [self migratePasscodeToGenerated];
            self.passcodeKeyStore.keyStoreKey = nil;
            self.passcodeKeyStore.keyStoreDictionary = nil;
        } else {
            // Encryption key is changing from one value to another.  Update passcode store encryption accordingly.
            [self log:SFLogLevelInfo format:@"Changing passcode-based key store encryption key, based on passcode change."];
            self.passcodeKeyStore.keyStoreKey.encryptionKey.key = [[self class] keyStringToData:oldKey];
            self.passcodeKeyStore.keyStoreKey = [self createNewPasscodeKey];
        }
    }
}

@end
