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

#import "SFKeyStoreManager.h"
#import "SFPasscodeManager.h"
#import "SFKeyStoreKey.h"

@interface SFKeyStoreManager () <SFPasscodeManagerDelegate>
{
    SFKeyStoreKey *_keyStoreKey;
}

/**
 The dictionary that holds the key store.
 */
@property (nonatomic, strong) NSDictionary *keyStoreDictionary;

/**
 The key store key, used for encrypting and decrypting the key store.
 */
@property (nonatomic, copy) SFKeyStoreKey *keyStoreKey;

/**
 Creates a default key store key from random generated key and IV values.  Used when a passcode
 is not present.
 @return The generated key used to encrypt/decrypt the key store.
 */
- (SFKeyStoreKey *)createDefaultKey;

/**
 Creates a key store key based on the encryption key provided in part by the user's passcode.
 @return A passcode-based key store key used to encrypt/decrypt the key store.
 */
- (SFKeyStoreKey *)createNewPasscodeKey;

/**
 Converts an NSString-based key into NSData.
 @param keyString The key to convert.
 @return The NSData representation of the key.
 */
- (NSData *)keyStringToData:(NSString *)keyString;

/**
 Decrypts an encrypted blob of dictionary data.
 @param dictionaryData The dictionary as encrypted data.
 @param decryptKey The key used to decrypt the data.
 @return The decrypted NSDictionary, or `nil` if the data could not be decrypted.
 */
- (NSDictionary *)decryptDictionaryData:(NSData *)dictionaryData withKey:(SFEncryptionKey *)decryptKey;

/**
 Encrypts the dictionary with the key store key.
 @param dictionary The dictionary to encrypt.
 @return The encrypted NSData representation of the dictionary.
 */
- (NSData *)encryptDictionary:(NSDictionary *)dictionary;

/**
 Retrieves the key store dictionary, decrypting it with the specified key.
 @param decryptKey The key used to decrypt the dictionary.
 @return The decrypted dictionary, or `nil` if the dictionary could not be decrypted.
 */
- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey;

/**
 Creates a keychain ID that should be unique across app installs/re-installs, making sure
 that erroneous keychain data is not present if the app is re-installed.
 @param baseKeychainId The identifier that the keychain key is based on.
 @return An identifier with the base ID and unique data appended to it.
 */
- (NSString *)buildUniqueKeychainId:(NSString *)baseKeychainId;

@end