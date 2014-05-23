//
//  SFPasscodeKeyStore.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 5/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFPasscodeKeyStore.h"
#import "SFKeyStore+Internal.h"
#import "SFKeyStoreKey.h"
#import "SFPasscodeManager.h"
#import "SFKeyStoreManager+Internal.h"
#import <SalesforceCommonUtils/SFKeychainItemWrapper.h>

// Keychain and NSCoding constants
static NSString * const kPasscodeKeyStoreKeychainIdentifier = @"com.salesforce.keystore.passcodeKeystoreKeychainId";
static NSString * const kPasscodeKeyStoreDataArchiveKey = @"com.salesforce.keystore.passcodeKeystoreDataArchive";
static NSString * const kPasscodeKeyStoreEncryptionKeyKeychainIdentifier = @"com.salesforce.keystore.passcodeKeystoreEncryptionKeyId";
static NSString * const kPasscodeKeyStoreEncryptionKeyDataArchiveKey = @"com.salesforce.keystore.passcodeKeystoreEncryptionKeyDataArchive";

@interface SFPasscodeKeyStore ()
{
    SFKeyStoreKey *_keyStoreKey;
}

@end

@implementation SFPasscodeKeyStore

- (NSString *)storeDataArchiveKey
{
    return kPasscodeKeyStoreDataArchiveKey;
}

- (NSString *)storeKeychainIdentifier
{
    return [self buildUniqueKeychainId:kPasscodeKeyStoreKeychainIdentifier];
}

- (NSString *)encryptionKeyDataArchiveKey
{
    return kPasscodeKeyStoreEncryptionKeyDataArchiveKey;
}

- (NSString *)encryptionKeyKeychainIdentifier
{
    return [self buildUniqueKeychainId:kPasscodeKeyStoreEncryptionKeyKeychainIdentifier];
}

- (BOOL)keyStoreAvailable
{
    return ([[SFPasscodeManager sharedManager].encryptionKey length] > 0);
}

- (BOOL)keyStoreActive
{
    return [[SFPasscodeManager sharedManager] passcodeIsSet];
}

- (SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        if (_keyStoreKey != nil)
            return _keyStoreKey;
        
        NSString *keychainId = self.encryptionKeyKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:keychainId account:nil];
        NSData *keyStoreKeyData = [keychainItem valueData];
        if (keyStoreKeyData == nil) {
            return nil;
        } else {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keyStoreKeyData];
            _keyStoreKey = [unarchiver decodeObjectForKey:self.encryptionKeyDataArchiveKey];
            [unarchiver finishDecoding];
            
            NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
            _keyStoreKey.encryptionKey.key = [[SFKeyStoreManager sharedInstance] keyStringToData:passcodeEncryptionKey];
            
            return _keyStoreKey;
        }
    }
}

- (void)setKeyStoreKey:(SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        if (keyStoreKey == _keyStoreKey)
            return;
        
        // Update the key store dictionary as part of the key update process.
        NSDictionary *origKeyStoreDict = [self keyStoreDictionaryWithKey:_keyStoreKey.encryptionKey];  // Old key.
        _keyStoreKey = [keyStoreKey copy];
        if (origKeyStoreDict == nil) {
            [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
            self.keyStoreDictionary = nil;
        } else {
            self.keyStoreDictionary = origKeyStoreDict;
        }
        
        // Store the key store key in the keychain.
        NSString *keychainId = self.encryptionKeyKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:keychainId account:nil];
        if (keyStoreKey == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store key from the keychain."];
            }
        } else {
            keyStoreKey.encryptionKey.key = nil;
            NSMutableData *keyStoreKeyData = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:keyStoreKeyData];
            [archiver encodeObject:keyStoreKey forKey:self.encryptionKeyDataArchiveKey];
            [archiver finishEncoding];
            
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreKeyData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store key to the keychain."];
            }
        }
    }
}

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel
{
    return [NSString stringWithFormat:@"%@__Passcode", baseKeyLabel];
}

@end
