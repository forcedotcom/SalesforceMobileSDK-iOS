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

#import "SFPasscodeKeyStore.h"
#import "SFKeyStore+Internal.h"
#import "SFKeyStoreKey.h"
#import "SFPasscodeManager.h"
#import "SFKeyStoreManager+Internal.h"
#import "SFKeychainItemWrapper.h"

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

- (BOOL)keyStoreEnabled
{
    return [[SFPasscodeManager sharedManager] passcodeIsSet];
}

- (SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        if (_keyStoreKey != nil)
            return _keyStoreKey;
        
        NSString *keychainId = self.encryptionKeyKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
        NSData *keyStoreKeyData = [keychainItem valueData];
        if (keyStoreKeyData == nil) {
            return nil;
        } else {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keyStoreKeyData];
            _keyStoreKey = [unarchiver decodeObjectForKey:self.encryptionKeyDataArchiveKey];
            [unarchiver finishDecoding];
            
            NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
            _keyStoreKey.encryptionKey.key = [SFKeyStoreManager keyStringToData:passcodeEncryptionKey];
            
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
        if (origKeyStoreDict == nil) {
            [self log:SFLogLevelError msg:kKeyStoreDecryptionFailedMessage];
            [self setKeyStoreDictionary:nil withKey:keyStoreKey.encryptionKey];
        } else {
            [self setKeyStoreDictionary:origKeyStoreDict withKey:keyStoreKey.encryptionKey];
        }
        
        // Store the key store key in the keychain.
        NSString *keychainId = self.encryptionKeyKeychainIdentifier;
        SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
        if (keyStoreKey == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store key from the keychain."];
            }
        } else {
            NSData *encryptionKeyData = keyStoreKey.encryptionKey.key;
            keyStoreKey.encryptionKey.key = nil;
            NSMutableData *keyStoreKeyData = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:keyStoreKeyData];
            [archiver encodeObject:keyStoreKey forKey:self.encryptionKeyDataArchiveKey];
            [archiver finishEncoding];
            
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreKeyData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store key to the keychain."];
            }
            keyStoreKey.encryptionKey.key = encryptionKeyData;
        }
        
        _keyStoreKey = [keyStoreKey copy];
    }
}

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel
{
    return [NSString stringWithFormat:@"%@__Passcode", baseKeyLabel];
}

@end
