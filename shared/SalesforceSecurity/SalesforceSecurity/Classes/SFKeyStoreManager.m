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
#import <SalesforceCommonUtils/SFKeychainItemWrapper.h>

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
        [[SFPasscodeManager sharedManager] addDelegate:self];
        if (self.keyStoreKey == nil) {
            self.keyStoreKey = [self createDefaultKey];
        }
    }
    return self;
}

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel
{
    if (keyLabel == nil) return nil;
    
    SFEncryptionKey *key = [self.keyStoreDictionary objectForKey:keyLabel];
    return key;
}

- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel
{
    NSAssert(key != nil, @"key must have a value.");
    NSAssert(keyLabel != nil, @"key label must have a value.");
    
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.keyStoreDictionary];
    [mutableKeyStoreDict setObject:key forKey:keyLabel];
    self.keyStoreDictionary = mutableKeyStoreDict;
}

- (void)removeKeyWithLabel:(NSString *)keyLabel
{
    if (keyLabel == nil) return;
    
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.keyStoreDictionary];
    [mutableKeyStoreDict removeObjectForKey:keyLabel];
    self.keyStoreDictionary = mutableKeyStoreDict;
}

- (BOOL)keyWithLabelExists:(NSString *)keyLabel
{
    SFEncryptionKey *key = [self retrieveKeyWithLabel:keyLabel];
    return (key != nil);
}

- (SFEncryptionKey *)keyWithRandomValue
{
    NSData *keyData = [SFSDKCryptoUtils randomByteDataWithLength:kCCKeySizeAES256];
    NSData *iv = [SFSDKCryptoUtils randomByteDataWithLength:kCCBlockSizeAES128];
    SFEncryptionKey *key = [[SFEncryptionKey alloc] initWithData:keyData initializationVector:iv];
    return key;
}

#pragma mark - Private methods

- (NSDictionary *)keyStoreDictionary
{
    return [self keyStoreDictionaryWithKey:self.keyStoreKey.encryptionKey];
}

- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreKeychainIdentifier account:nil];
        NSData *keyStoreData = [keychainItem valueData];
        // NB: We will return an empty dictionary if one doesn't exist, and nil if an existing dictionary
        // couldn't be decrypted.  This allows us to differentiate between a non-existent key store dictionary
        // and one that can't be accessed.
        if (keyStoreData == nil) {
            return [NSDictionary dictionary];
        } else {
            NSDictionary *keyStoreDict = [self decryptDictionaryData:keyStoreData withKey:decryptKey];
            return keyStoreDict;
        }
    }
}

- (void)setKeyStoreDictionary:(NSDictionary *)keyStoreDictionary
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreKeychainIdentifier account:nil];
        if (keyStoreDictionary == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store from the keychain."];
            }
        } else {
            NSData *keyStoreData = [self encryptDictionary:keyStoreDictionary];
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store to the keychain."];
            }
        }
    }
}

- (SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreEncryptionKeyKeychainIdentifier account:nil];
        NSData *keyStoreKeyData = [keychainItem valueData];
        if (keyStoreKeyData == nil) {
            return nil;
        } else {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keyStoreKeyData];
            SFKeyStoreKey *keyStoreKey = [unarchiver decodeObjectForKey:kKeyStoreEncryptionKeyDataArchiveKey];
            [unarchiver finishDecoding];
            
            // For passcode key, get the key data.
            if (keyStoreKey.keyType == SFKeyStoreKeyTypePasscode) {
                NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
                keyStoreKey.encryptionKey.key = [self keyStringToData:passcodeEncryptionKey];
            }
            return keyStoreKey;
        }
    }
}

- (void)setKeyStoreKey:(SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreEncryptionKeyKeychainIdentifier account:nil];
        if (keyStoreKey == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store key from the keychain."];
            }
        } else {
            // Make sure we don't store the passcode key.
            if (keyStoreKey.keyType == SFKeyStoreKeyTypePasscode)
                keyStoreKey.encryptionKey.key = nil;
            NSMutableData *keyStoreKeyData = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:keyStoreKeyData];
            [archiver encodeObject:keyStoreKey forKey:kKeyStoreEncryptionKeyDataArchiveKey];
            [archiver finishEncoding];
            
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreKeyData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store key to the keychain."];
            }
        }
    }
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
        [self log:SFLogLevelError msg:@"Attempting to create a passcode-based key, but passcode encryption key is not present."];
        return nil;
    }
    SFEncryptionKey *encKey = [[SFEncryptionKey alloc] initWithData:[self keyStringToData:passcodeEncryptionKey]
                                               initializationVector:[SFSDKCryptoUtils randomByteDataWithLength:kCCBlockSizeAES128]];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypePasscode];
    return keyStoreKey;
}

- (NSData *)keyStringToData:(NSString *)keyString
{
    return [keyString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSDictionary *)decryptDictionaryData:(NSData *)dictionaryData withKey:(SFEncryptionKey *)decryptKey
{
    NSData *decryptedDictionaryData = [SFSDKCryptoUtils aes256DecryptData:dictionaryData
                                                                  withKey:decryptKey.key
                                                                       iv:decryptKey.initializationVector];
    if (decryptedDictionaryData == nil)
        return nil;
    
    NSDictionary *keyStoreDict = nil;
    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:decryptedDictionaryData];
        keyStoreDict = [unarchiver decodeObjectForKey:kKeyStoreDataArchiveKey];
        [unarchiver finishDecoding];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelError msg:@"Unable to decrypt key store data.  Key store is invalid."];
        return nil;
    }

    return keyStoreDict;
}

- (NSData *)encryptDictionary:(NSDictionary *)dictionary
{
    NSMutableData *dictionaryData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dictionaryData];
    [archiver encodeObject:dictionary forKey:kKeyStoreDataArchiveKey];
    [archiver finishEncoding];
    
    NSData *encryptedData = [SFSDKCryptoUtils aes256EncryptData:dictionaryData
                                                        withKey:self.keyStoreKey.encryptionKey.key
                                                             iv:self.keyStoreKey.encryptionKey.initializationVector];
    return encryptedData;
}

#pragma mark - SFPasscodeManagerDelegate

- (void)passcodeManager:(SFPasscodeManager *)manager didChangeEncryptionKey:(NSString *)oldKey toEncryptionKey:(NSString *)newKey
{
    @synchronized (self) {
        // NB: If this method is called, the encryption key is guaranteed to have changed.
        if ([oldKey length] == 0 && [newKey length] > 0) {
            // Switching from no key to key.
            if (self.keyStoreKey.keyType == SFKeyStoreKeyTypeGenerated) {
                // Expected for use case with no oldKey value.
                [self log:SFLogLevelInfo msg:@"Changing key store encryption based on new passcode creation."];
                NSDictionary *keyStoreDict = self.keyStoreDictionary;
                self.keyStoreKey = [self createNewPasscodeKey];
                if (keyStoreDict == nil) {
                    [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
                    self.keyStoreDictionary = nil;
                } else {
                    self.keyStoreDictionary = keyStoreDict;
                }
            } else if (self.keyStoreKey.keyType == SFKeyStoreKeyTypePasscode) {
                [self log:SFLogLevelError msg:@"Key store key is based on passcode, but the original key value is not available.  Decryption of key store cannot continue."];
                self.keyStoreDictionary = nil;
                self.keyStoreKey = [self createNewPasscodeKey];
            } else {
                [self log:SFLogLevelError format:kUnknownKeyStoreTypeFormatString, self.keyStoreKey.keyType];
                self.keyStoreDictionary = nil;
                self.keyStoreKey = [self createNewPasscodeKey];
            }
        } else if ([oldKey length] > 0 && [newKey length] == 0) {
            // Encryption key is resetting.  Default back to generated key.
            if (self.keyStoreKey.keyType == SFKeyStoreKeyTypePasscode) {
                // Expected for use case where oldKey has a value.
                [self log:SFLogLevelInfo msg:@"Changing key store key back to generated, after passcode removal."];
                SFEncryptionKey *origKeyStoreEncryptionKey = self.keyStoreKey.encryptionKey;
                // We have to explicitly set the old key value, as self.keyStoreKey will be based on the encryption key,
                // which has already changed.
                origKeyStoreEncryptionKey.key = [self keyStringToData:oldKey];
                NSDictionary *keyStoreDict = [self keyStoreDictionaryWithKey:origKeyStoreEncryptionKey];
                self.keyStoreKey = [self createDefaultKey];  // No passcode, so revert to a generated key.
                if (keyStoreDict == nil) {
                    [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
                    self.keyStoreDictionary = nil;
                } else {
                    self.keyStoreDictionary = keyStoreDict;
                }
            } else if (self.keyStoreKey.keyType == SFKeyStoreKeyTypeGenerated) {
                // Shouldn't be the case if oldKey is not empty, but this is the desired end state, so no-op.
                [self log:SFLogLevelInfo msg:@"Generated key already configured.  No re-encryption will be attempted."];
            } else {
                [self log:SFLogLevelError format:kUnknownKeyStoreTypeFormatString, self.keyStoreKey.keyType];
                self.keyStoreDictionary = nil;
                self.keyStoreKey = [self createDefaultKey];
            }
        } else {
            // Old passcode-based key to new passcode-based key.
            if (self.keyStoreKey.keyType == SFKeyStoreKeyTypePasscode) {
                // Expected for use case where oldKey has a value.
                [self log:SFLogLevelInfo msg:@"Changing passcode-based key store encryption key, based on passcode change."];
                SFEncryptionKey *origKeyStoreEncryptionKey = self.keyStoreKey.encryptionKey;
                origKeyStoreEncryptionKey.key = [self keyStringToData:oldKey];
                NSDictionary *keyStoreDict = [self keyStoreDictionaryWithKey:origKeyStoreEncryptionKey];
                self.keyStoreKey = [self createNewPasscodeKey];
                if (keyStoreDict == nil) {
                    [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
                    self.keyStoreDictionary = nil;
                } else {
                    self.keyStoreDictionary = keyStoreDict;
                }
            } else if (self.keyStoreKey.keyType == SFKeyStoreKeyTypeGenerated) {
                // Shouldn't be the case if oldKey is not empty, but we'll try to manage.
                [self log:SFLogLevelInfo msg:@"Old passcode exists, but key store key is generated.  Will attempt to use generated key store key as the source of truth for decrypting the key store."];
                NSDictionary *keyStoreDict = self.keyStoreDictionary;
                self.keyStoreKey = [self createNewPasscodeKey];
                if (keyStoreDict == nil) {
                    [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
                    self.keyStoreDictionary = nil;
                } else {
                    self.keyStoreDictionary = keyStoreDict;
                }
            } else {
                [self log:SFLogLevelError format:kUnknownKeyStoreTypeFormatString, self.keyStoreKey.keyType];
                self.keyStoreDictionary = nil;
                self.keyStoreKey = [self createNewPasscodeKey];
            }
        }
    }
}

@end
