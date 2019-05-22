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

#import "SFPasscodeKeyStore.h"
#import "SFKeyStore+Internal.h"
#import "SFPasscodeManager.h"
#import "SFKeyStoreManager+Internal.h"
#import "SFKeychainItemWrapper.h"

// Keychain and NSCoding constants
static NSString * const kPasscodeKeyStoreKeychainIdentifier = @"com.salesforce.keystore.passcodeKeystoreKeychainId";
static NSString * const kPasscodeKeyStoreDataArchiveKey = @"com.salesforce.keystore.passcodeKeystoreDataArchive";
static NSString * const kPasscodeKeyStoreEncryptionKeyKeychainIdentifier = @"com.salesforce.keystore.passcodeKeystoreEncryptionKeyId";
static NSString * const kPasscodeKeyStoreEncryptionKeyDataArchiveKey = @"com.salesforce.keystore.passcodeKeystoreEncryptionKeyDataArchive";
NSString * const kPasscodeKeyLabelSuffix = @"Passcode";

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
        
        _keyStoreKey = [SFKeyStoreKey fromKeyChain:self.encryptionKeyKeychainIdentifier archiverKey:self.encryptionKeyDataArchiveKey];

        if (_keyStoreKey) {
            NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
            _keyStoreKey.encryptionKey.key = [SFKeyStoreManager keyStringToData:passcodeEncryptionKey];
        }

        return _keyStoreKey;
    }
}

- (void)setKeyStoreKey:(SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        if (keyStoreKey == _keyStoreKey)
            return;
        
        // Update the key store dictionary as part of the key update process.
        NSDictionary *origKeyStoreDict = [self keyStoreDictionaryWithKey:_keyStoreKey];  // Old key.
        if (origKeyStoreDict == nil) {
            [SFSDKCoreLogger e:[self class] format:kKeyStoreDecryptionFailedMessage];
            [self setKeyStoreDictionary:nil withKey:keyStoreKey];
        } else {
            [self setKeyStoreDictionary:origKeyStoreDict withKey:keyStoreKey];
        }
        
        // Store the key store key in the keychain.
        
        // Store the key store key in the keychain.
        if (keyStoreKey == nil) {
            SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:self.encryptionKeyKeychainIdentifier account:nil];
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [SFSDKCoreLogger e:[self class] format:@"Error removing key store key from the keychain."];
            }
        } else {
            NSData *encryptionKeyData = keyStoreKey.encryptionKey.key;
            keyStoreKey.encryptionKey.key = nil;
            OSStatus saveKeyResult = [keyStoreKey toKeyChain:self.encryptionKeyKeychainIdentifier archiverKey:self.encryptionKeyDataArchiveKey];
            if (saveKeyResult != noErr) {
                [SFSDKCoreLogger e:[self class] format:@"Error saving key store key to the keychain."];
            }
            keyStoreKey.encryptionKey.key = encryptionKeyData;
        }
        _keyStoreKey = [keyStoreKey copy];
    }
}

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel
{
    return [NSString stringWithFormat:@"%@__%@", baseKeyLabel, kPasscodeKeyLabelSuffix];
}

@end
