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

#import "SFGeneratedKeyStore.h"
#import "SFKeyStore+Internal.h"
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>

// Keychain and NSCoding constants
static NSString * const kGeneratedKeyStoreKeychainIdentifier = @"com.salesforce.keystore.generatedKeystoreKeychainId";
static NSString * const kGeneratedKeyStoreDataArchiveKey = @"com.salesforce.keystore.generatedKeystoreDataArchive";
static NSString * const kGeneratedKeyStoreEncryptionKeyKeychainIdentifier = @"com.salesforce.keystore.generatedKeystoreEncryptionKeyId";
static NSString * const kGeneratedKeyStoreEncryptionKeyDataArchiveKey = @"com.salesforce.keystore.generatedKeystoreEncryptionKeyDataArchive";
NSString * const kGeneratedKeyLabelSuffix = @"Generated";

@interface SFGeneratedKeyStore ()
{
    SFKeyStoreKey *_keyStoreKey;
}

@end

@implementation SFGeneratedKeyStore

- (NSString *)storeDataArchiveKey
{
    return kGeneratedKeyStoreDataArchiveKey;
}

- (NSString *)storeKeychainIdentifier
{
    return [self buildUniqueKeychainId:kGeneratedKeyStoreKeychainIdentifier];
}

- (NSString *)encryptionKeyDataArchiveKey
{
    return kGeneratedKeyStoreEncryptionKeyDataArchiveKey;
}

- (NSString *)encryptionKeyKeychainIdentifier
{
    return [self buildUniqueKeychainId:kGeneratedKeyStoreEncryptionKeyKeychainIdentifier];
}

- (BOOL)keyStoreAvailable
{
    return YES;
}

- (BOOL)keyStoreEnabled
{
    return YES;
}

- (SFKeyStoreKey *)keyStoreKey
{
    @synchronized (self) {
        if (_keyStoreKey != nil)
            return _keyStoreKey;
        
        _keyStoreKey = [SFKeyStoreKey fromKeyChain:self.encryptionKeyKeychainIdentifier archiverKey:self.encryptionKeyDataArchiveKey];
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
            if (_keyStoreKey != nil) {
                [SFSDKCoreLogger e:[self class] format:kKeyStoreDecryptionFailedMessage];
            }
            [self setKeyStoreDictionary:nil withKey:keyStoreKey];
        } else {
            [self setKeyStoreDictionary:origKeyStoreDict withKey:keyStoreKey];
        }
    
        // Store the key store key in the keychain.
        if (keyStoreKey == nil) {
            SFSDKKeychainResult *result = [SFSDKKeychainHelper createIfNotPresentWithService:self.encryptionKeyKeychainIdentifier account:nil];
            if (!result.success) {
                [SFSDKCoreLogger e:[self class] format:@"Error removing key store key %@ from the keychain.", self.encryptionKeyKeychainIdentifier];
            }
        } else {
            OSStatus saveKeyResult = [keyStoreKey toKeyChain:self.encryptionKeyKeychainIdentifier archiverKey:self.encryptionKeyDataArchiveKey];
            if (saveKeyResult != noErr) {
                [SFSDKCoreLogger e:[self class] format:@"Error saving key store key  %@ to the keychain.", self.encryptionKeyKeychainIdentifier];
            }
        }
        
        _keyStoreKey = [keyStoreKey copy];
    }
}

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel
{
    return [NSString stringWithFormat:@"%@__%@", baseKeyLabel, kGeneratedKeyLabelSuffix];
}

@end
