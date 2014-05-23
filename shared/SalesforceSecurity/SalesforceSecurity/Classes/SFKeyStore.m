//
//  SFKeyStore.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 5/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFKeyStore+Internal.h"
#import <SalesforceCommonUtils/SFCrypto.h>
#import <SalesforceCommonUtils/SFKeychainItemWrapper.h>
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
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:keychainId account:nil];
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
        NSString *keychainId = self.storeKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:keychainId account:nil];
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

- (NSData *)encryptDictionary:(NSDictionary *)dictionary
{
    NSMutableData *dictionaryData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dictionaryData];
    [archiver encodeObject:dictionary forKey:self.storeDataArchiveKey];
    [archiver finishEncoding];
    
    NSData *encryptedData = dictionaryData;
    if (self.keyStoreKey.encryptionKey != nil) {
        encryptedData = [SFSDKCryptoUtils aes256EncryptData:dictionaryData
                                                    withKey:self.keyStoreKey.encryptionKey.key
                                                         iv:self.keyStoreKey.encryptionKey.initializationVector];
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

- (BOOL)keyStoreActive
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
