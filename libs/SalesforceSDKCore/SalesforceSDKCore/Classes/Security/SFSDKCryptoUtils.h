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

NS_ASSUME_NONNULL_BEGIN

@class SFPBKDFData;

/**
 * The default number of PBKDF derivation rounds that will be used to generate a key.
 */
extern NSUInteger const kSFPBKDFDefaultNumberOfDerivationRounds;

/**
 * The default length of a PDKDF derived key, in bytes.
 */
extern NSUInteger const kSFPBKDFDefaultDerivedKeyByteLength;

/**
 * The default length in bytes for random-generated salt data.
 */
extern NSUInteger const kSFPBKDFDefaultSaltByteLength;

/**
 * Various utility methods in support of cryptographic operations.
 */
@interface SFSDKCryptoUtils : NSObject

/**
 * Creates a random string of bytes (based on arc4random() generation) and returns
 * them as an NSData object.
 * @param lengthInBytes The number of bytes to generate.
 * @return The string of random bytes, as an NSData object.
 */
+ (NSData *)randomByteDataWithLength:(NSUInteger)lengthInBytes;

/**
 * Creates a PBKDF2 derived key from an input key (string), using default values for the
 * random-generated salt data and its length, the number of derivation rounds, and the
 * derived key length.
 * @param stringToHash The plaintext string used to generate the key.
 * @return An SFPBKDFData object representing the derived key.
 */
+ (SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash;

/**
 * Creates a PBKDF2 derived key from an input key (string), a salt, number of derivation
 * rounds, and desired derived key length.
 * @param stringToHash The base string to use for the derived key.
 * @param salt The salt to append to the string.
 * @param numDerivationRounds The number of derivation rounds used to generate the key.
 * @param derivedKeyLength The desired derived key length.
 * @return An SFPBKDFData object representing the derived key.
 */
+ (nullable SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash
                                   salt:(NSData *)salt
                       derivationRounds:(NSUInteger)numDerivationRounds
                              keyLength:(NSUInteger)derivedKeyLength;

/**
 * Encrypt the given data using the AES-128 algorithm.
 * @param data The data to encrypt.
 * @param key The encryption key used to encrypt the data.
 * @param iv The initialization vector data used for the encryption.
 * @return The encrypted data, or `nil` if encryption was not successful.
 */
+ (nullable NSData *)aes128EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES-128 algorithm.
 * @param data The data to decrypt.
 * @param key The decryption key used to decrypt the data.
 * @param iv The initialization vector data used for the decryption.
 * @return The decrypted data, or `nil` if decryption was not successful.
 */
+ (nullable NSData *)aes128DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Encrypt the given data using the AES-256 algorithm.
 * @param data The data to encrypt.
 * @param key The encryption key used to encrypt the data.
 * @param iv The initialization vector data used for the encryption.
 * @return The encrypted data, or `nil` if encryption was not successful.
 */
+ (nullable NSData *)aes256EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES-256 algorithm.
 * @param data The data to decrypt.
 * @param key The decryption key used to decrypt the data.
 * @param iv The initialization vector data used for the decryption.
 * @return The decrypted data, or `nil` if decryption was not successful.
 */
+ (nullable NSData *)aes256DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Create asymmetric keys (public/private key pairs) using RSA algorithm with given keyName and length
 * @param keyName The name string used to generate the key.
 * @param length The key length used for key
 */
+ (void)createRSAKeyPairWithName:(NSString *)keyName keyLength:(NSUInteger)length accessibleAttribute:(CFTypeRef)accessibleAttribute;

/**
 * Get RSA public key as NSString with given keyName and length
 * @param keyName The name string used to generate the key.
 * @param length The key length used for key
 * @return The key string, or `nil` if no matching key is found
 */
+ (nullable NSString *)getRSAPublicKeyStringWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Get RSA private key as NSData with given keyName and length
 * @param keyName The name string used to generate the key.
 * @param length The key length used for key
 * @return The key data, or `nil` if no matching key is found
 */
+ (nullable NSData *)getRSAPrivateKeyDataWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Get RSA public SecKeyRef with given keyName and length
 * @param keyName The name string used to generate the key.
 * @param length The key length used for key
 * @return The SecKeyRef, or `nil` if no matching key is found
 */
+ (nullable SecKeyRef)getRSAPublicKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Get RSA private SecKeyRef with given keyName and length
 * @param keyName The name string used to generate the key.
 * @param length The key length used for key
 * @return The SecKeyRef, or `nil` if no matching key is found
 */
+ (nullable SecKeyRef)getRSAPrivateKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length;

/**
 * Encrypt data with givien SecKeyRef using RSA pkcs1 algorithm
 * @param data The data to encrypt
 * @param keyRef The keyref used in encryption
 * @return The encrypted Dataa, or `nil` if encryption failed
 */
+ (nullable NSData*)encryptUsingRSAforData:(NSData *)data withKeyRef:(SecKeyRef)keyRef;

/**
 * Decrypt data with givien SecKeyRef using RSA pkcs1 algorithm
 * @param data The data to decypt
 * @param keyRef The keyref used in decryption
 * @return The decypted Data, or `nil` if decryption failed
 */
+ (nullable NSData*)decryptUsingRSAforData:(NSData * )data withKeyRef:(SecKeyRef)keyRef;

@end

NS_ASSUME_NONNULL_END
