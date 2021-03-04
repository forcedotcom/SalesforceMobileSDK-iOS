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
#import "SFSecureEncryptionKey.h"
#import "SalesforceSDKConstants.h"

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
            key = [SFKeyStoreKey createKey];
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

#pragma mark - Private methods

- (void)initializeKeyStores
{
    self.generatedKeyStore = [[SFGeneratedKeyStore alloc] init];
    if (self.generatedKeyStore.keyStoreKey == nil) {
        self.generatedKeyStore.keyStoreKey = [self createDefaultKey];
    }
    else {
        // Pre SDK 7.1 SFGeneratedKeyStore were encrypted with SFEncryptionKey
        // Starting in SDK 7.1, we use SFSecureEncryptionKey instead
        // Switch to SFSecureEncryptionKey if needed
        [self switchToSecureKeyIfNeeded:self.generatedKeyStore];
    }
}

- (void)switchToSecureKeyIfNeeded:(SFGeneratedKeyStore*)generatedKeyStore
{
    SFKeyStoreKey* currentKey = generatedKeyStore.keyStoreKey;
    if (![currentKey.encryptionKey isKindOfClass:[SFSecureEncryptionKey class]]) {
        SFKeyStoreKey* newKey = [self createDefaultKey];
        generatedKeyStore.keyStoreKey = newKey;
        [SFSDKCoreLogger i:[self class] format:@"Switching to secure key"];
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
    // Starting in SDK 7.1, we use SFSecureEncryptionKey to encrypt the key store
    SFSecureEncryptionKey* encKey = [SFSecureEncryptionKey createKey:@"default"];
    return [[SFKeyStoreKey alloc] initWithKey:encKey];
}

+ (NSData *)keyStringToData:(NSString *)keyString
{
    return [keyString dataUsingEncoding:NSUTF8StringEncoding];
}

@end
