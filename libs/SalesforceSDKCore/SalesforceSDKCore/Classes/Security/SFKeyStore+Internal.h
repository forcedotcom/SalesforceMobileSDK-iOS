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

#import "SFKeyStore.h"

static NSString * const kKeyStoreDecryptionFailedMessage = @"Could not decrypt key store with existing key store key.  Key store is invalid.";

@interface SFKeyStore ()

/**
 The store's keychain identifier.
 */
@property (nonatomic, readonly) NSString *storeKeychainIdentifier;

/**
 The store's data archive key for serialization/deserialization.
 */
@property (nonatomic, readonly) NSString *storeDataArchiveKey;

/**
 The store's encryption key keychain identifier.
 */
@property (nonatomic, readonly) NSString *encryptionKeyKeychainIdentifier;

/**
 The store's encryption key data archive key for serialization/deserialization.
 */
@property (nonatomic, readonly) NSString *encryptionKeyDataArchiveKey;

/**
 Creates a keychain ID that should be unique across app installs/re-installs, making sure
 that erroneous keychain data is not present if the app is re-installed.
 @param baseKeychainId The identifier that the keychain key is based on.
 @return An identifier with the base ID and unique data appended to it.
 */
- (NSString *)buildUniqueKeychainId:(NSString *)baseKeychainId;

/**
 Retrieves the key store dictionary, decrypting it with the specified key.
 @param decryptKey The key used to decrypt the dictionary.
 @return The decrypted dictionary, or `nil` if the dictionary could not be decrypted.
 */
- (NSDictionary *)keyStoreDictionaryWithKey:(SFEncryptionKey *)decryptKey;

/**
 Sets the key store dictionary, encrypting it with the specified key.
 @param keyStoreDictionary The new/updated dictionary to set.
 @param theEncryptionKey The key used to encrypt the database.
 */
- (void)setKeyStoreDictionary:(NSDictionary *)keyStoreDictionary withKey:(SFEncryptionKey *)theEncryptionKey;

@end
