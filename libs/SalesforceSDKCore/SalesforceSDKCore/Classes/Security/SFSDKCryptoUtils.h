/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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
+ (SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash
                                   salt:(NSData *)salt
                       derivationRounds:(NSUInteger)numDerivationRounds
                              keyLength:(NSUInteger)derivedKeyLength;

/**
 * Encrypt the given data using the AES-256 algorithm.
 * @param data The data to encrypt.
 * @param key The encryption key used to encrypt the data.
 * @param iv The initialization vector data used for the encryption.
 * @return The encrypted data, or `nil` if encryption was not successful.
 */
+ (NSData *)aes256EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES-256 algorithm.
 * @param data The data to decrypt.
 * @param key The decryption key used to decrypt the data.
 * @param iv The initialization vector data used for the decryption.
 * @return The decrypted data, or `nil` if decryption was not successful.
 */
+ (NSData *)aes256DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv;

@end
