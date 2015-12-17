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

#import "SFKeyStore+Internal.h"
#import "SFCrypto.h"
#import "SFKeychainItemWrapper.h"
#import "SFSDKCryptoUtils.h"

@implementation SFKeyStore

- (NSDictionary *)keyStoreDictionary
{
    @synchronized (self) {
        return [self keyStoreDictionaryWithKey:self.keyStoreKey.encryptionKey];
    }
}

- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey
{
    @synchronized (self) {
        NSString *keychainId = self.storeKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
        NSData *keyStoreData = [keychainItem valueData];
        // NB: We will return an empty dictionary if one doesn't exist, and nil if an existing dictionary
        // couldn't be decrypted.  This allows us to differentiate between a non-existent key store dictionary
        // and one that can't be accessed.
        if (keyStoreData == nil) {
            return @{};
        } else {
            NSDictionary *keyStoreDict = [self decryptDictionaryData:keyStoreData withKey:decryptKey];
            return keyStoreDict;
        }
    }
}

- (void)setKeyStoreDictionary:(NSDictionary *)keyStoreDictionary
{
    [self setKeyStoreDictionary:keyStoreDictionary withKey:self.keyStoreKey.encryptionKey];
}

- (void)setKeyStoreDictionary:(NSDictionary *)keyStoreDictionary withKey:(SFEncryptionKey *)theEncryptionKey
{
    @synchronized (self) {
        NSString *keychainId = self.storeKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
        if (keyStoreDictionary == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store from the keychain."];
            }
        } else {
            NSData *keyStoreData = [self encryptDictionary:keyStoreDictionary withKey:theEncryptionKey];
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store to the keychain."];
            }
        }
    }
}

- (NSData *)encryptDictionary:(NSDictionary *)dictionary withKey:(SFEncryptionKey *)theEncryptionKey
{
    NSMutableData *dictionaryData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dictionaryData];
    [archiver encodeObject:dictionary forKey:self.storeDataArchiveKey];
    [archiver finishEncoding];
    
    NSData *encryptedData = dictionaryData;
    if (theEncryptionKey != nil) {
        encryptedData = [SFSDKCryptoUtils aes256EncryptData:dictionaryData
                                                    withKey:theEncryptionKey.key
                                                         iv:theEncryptionKey.initializationVector];
    }
    
    return encryptedData;
}

- (NSDictionary *)decryptDictionaryData:(NSData *)dictionaryData withKey:(SFEncryptionKey *)decryptKey
{
    
    NSData *decryptedDictionaryData = dictionaryData;
    if (decryptKey != nil) {
        decryptedDictionaryData = [SFSDKCryptoUtils aes256DecryptData:dictionaryData
                                                              withKey:decryptKey.key
                                                                   iv:decryptKey.initializationVector];
    }
    if (decryptedDictionaryData == nil)
        return nil;
    
    NSDictionary *keyStoreDict = nil;
    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:decryptedDictionaryData];
        keyStoreDict = [unarchiver decodeObjectForKey:self.storeDataArchiveKey];
        [unarchiver finishDecoding];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelError msg:@"Unable to decrypt key store data.  Key store is invalid."];
        return nil;
    }
    
    return keyStoreDict;
}

#pragma mark - Utils

- (NSString *)buildUniqueKeychainId:(NSString *)baseKeychainId
{
    NSString *baseAppId = [SFCrypto baseAppIdentifier];
    return [NSString stringWithFormat:@"%@_%@", baseKeychainId, baseAppId];
}

#pragma mark - Abstract properties and methods

- (NSString *)storeKeychainIdentifier
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (NSString *)storeDataArchiveKey
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (NSString *)encryptionKeyKeychainIdentifier
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (NSString *)encryptionKeyDataArchiveKey
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (SFKeyStoreKey *)keyStoreKey
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (void)setKeyStoreKey:(SFKeyStoreKey *)keyStoreKey
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (BOOL)keyStoreAvailable
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (BOOL)keyStoreEnabled
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end
