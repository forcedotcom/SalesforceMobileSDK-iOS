/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

@class SFPBKDFData;

/**
 * Default number of PBKDF derivation rounds used to generate a key.
 */
extern NSUInteger const kSFPBKDFDefaultNumberOfDerivationRounds;

/**
 * Default length in bytes of a PDKDF derived key.
 */
extern NSUInteger const kSFPBKDFDefaultDerivedKeyByteLength;

/**
 * Default length in bytes for random-generated salt data.
 */
extern NSUInteger const kSFPBKDFDefaultSaltByteLength;

/**
 * Various utility methods that support cryptographic operations.
 */
@interface SFSDKCryptoUtils : NSObject

/**
 * Creates a random string of bytes (based on `arc4random()` generation) and returns
 * them as an `NSData` object.
 * @param lengthInBytes Number of bytes to generate.
 * @return `NSData` object containing a string of random bytes.
 */
+ (NSData *)randomByteDataWithLength:(NSUInteger)lengthInBytes;

/**
 * Creates a PBKDF2 derived key from an input key string. Uses default values for the
 * random-generated salt data and its length, the number of derivation rounds, and the
 * derived key length.
 * @param stringToHash Plain-text string used to generate the key.
 * @return The derived key.
 */
+ (nullable NSData *)pbkdf2DerivedKey:(NSString *)stringToHash;

/**
 * Creates a PBKDF2-derived key from an input key string, a salt, number of derivation
 * rounds, and the given derived key length.
 * @param stringToHash Base string to use for the derived key.
 * @param salt Salt to append to the string.
 * @param numDerivationRounds Number of derivation rounds used to generate the key.
 * @param derivedKeyLength Requested derived key length.
 * @return The derived key.
 */
+ (nullable NSData *)pbkdf2DerivedKey:(NSString *)stringToHash
                                 salt:(NSData *)salt
                     derivationRounds:(NSUInteger)numDerivationRounds
                            keyLength:(NSUInteger)derivedKeyLength;

/**
 * Encrypt the given data using the AES-128 algorithm.
 * @param data Data to encrypt.
 * @param key Key used to encrypt the data.
 * @param iv Initialization vector data used for the encryption.
 * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
 */
+ (nullable NSData *)aes128EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES-128 algorithm.
 * @param data Data to decrypt.
 * @param key Key used to decrypt the data.
 * @param iv Initialization vector data used for the decryption.
 * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
 */
+ (nullable NSData *)aes128DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Encrypt the given data using the AES-256 algorithm.
 * @param data Data to encrypt.
 * @param key Key used to encrypt the data.
 * @param iv Initialization vector data used for the encryption.
 * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
 */
+ (nullable NSData *)aes256EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES-256 algorithm.
 * @param data Data to decrypt.
 * @param key Key used to decrypt the data.
 * @param iv Initialization vector data used for the decryption.
 * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
 */
+ (nullable NSData *)aes256DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Create asymmetric keys (public/private key pairs) using RSA algorithm with given key name and length.
 * @param keyName Name of key.
 * @param length Length of key.
 */
+ (void)createRSAKeyPairWithName:(NSString *)keyName keyLength:(NSUInteger)length accessibleAttribute:(CFTypeRef)accessibleAttribute;

/**
 * Retrieve an RSA public key as `NSString` with given key name and length.
 * @param keyName Name of key.
 * @param length Length of key.
 * @return Key string, or `nil` if no matching key is found.
 */
+ (nullable NSString *)getRSAPublicKeyStringWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Retrieve an RSA private key as `NSData` with given key name and length.
 * @param keyName Name of key.
 * @param length Length of key.
 * @return `NSData` object containing the key data, or `nil` if no matching key is found.
 */
+ (nullable NSData *)getRSAPrivateKeyDataWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Get RSA public `SecKeyRef` with given key name and length.
 * @param keyName Name of key.
 * @param length Length of key.
 * @return `SecKeyRef` object, or `nil` if no matching key is found.
 */
+ (nullable SecKeyRef)getRSAPublicKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Get RSA private `SecKeyRef` with given key name and length.
 * @param keyName Name of key.
 * @param length Length of key.
 * @return `SecKeyRef` object, or `nil` if no matching key is found.
 */
+ (nullable SecKeyRef)getRSAPrivateKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Encrypt data with given `SecKeyRef` using the RSA `pkcs1` algorithm.
 * @param data Data to encrypt
 * @param keyRef Keyref used in encryption
 * @return `NSData` object containing the encrypted Data, or `nil` if encryption failed.
 */
+ (nullable NSData*)encryptUsingRSAforData:(NSData *)data withKeyRef:(SecKeyRef)keyRef;

/**
 * Decrypt data with given `SecKeyRef` using the RSA `pkcs1` algorithm.
 * @param data Data to decrypt
 * @param keyRef Keyref used in decryption
 * @return `NSData` object containing the decrypted Data, or `nil` if decryption failed.
 */
+ (nullable NSData*)decryptUsingRSAforData:(NSData * )data withKeyRef:(SecKeyRef)keyRef;

/**
 * Check for availability of the secure enclave.
 * @return YES if secure enclave is available.
 */
+ (BOOL) isSecureEnclaveAvailable;

/**
 * Create asymmetric keys (public/private key pairs) using the EC algorithm with given key name.
 * @param keyName Name of key.
 * @return YES if successful.
 */
+ (BOOL)createECKeyPairWithName:(NSString *)keyName accessibleAttribute:(CFTypeRef)accessibleAttribute useSecureEnclave:(BOOL)useSecureEnclave;

/**
 * Delete an EC key pair created with `createECKeyPairWithName:accessibleAttribute:useSecureEnclase:`.
 * @param keyName Name of key.
 * @return YES if successful.
 */
+ (BOOL)deleteECKeyPairWithName:(NSString *)keyName;

/**
 * Get EC public `SecKeyRef` with the given key name.
 * @param keyName Name of key.
 * @return `SecKeyRef` object, or `nil` if no matching key is found.
 */
+ (nullable SecKeyRef)getECPublicKeyRefWithName:(NSString *)keyName;

/**
 * Get EC private `SecKeyRef` with the given key name.
 * @param keyName Name of key.
 * @return `SecKeyRef` object, or `nil` if no matching key is found.
 */
+ (nullable SecKeyRef)getECPrivateKeyRefWithName:(NSString *)keyName;

/**
 * Encrypt data with the given `SecKeyRef` using the EC algorithm.
 * @param data Data to encrypt.
 * @param keyRef Keyref used in encryption.
 * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
 */
+ (nullable NSData*)encryptUsingECforData:(NSData *)data withKeyRef:(SecKeyRef)keyRef;

/**
 * Decrypt data with the given `SecKeyRef` using the EC algorithm.
 * @param data Data to decrypt.
 * @param keyRef Keyref used in decryption.
 * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
 */
+ (nullable NSData*)decryptUsingECforData:(NSData * )data withKeyRef:(SecKeyRef)keyRef;

@end

NS_ASSUME_NONNULL_END
