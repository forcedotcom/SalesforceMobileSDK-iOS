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
#import <CommonCrypto/CommonKeyDerivation.h>

/**
 * The default number of PBKDF derivation rounds that will be used to generate a key.
 * This can be overridden by calling [SFSDKCryptoUtils setNumPBKDFDerivationRounds:].
 */
extern NSUInteger const kSFPBKDFDefaultNumberOfDerivationRounds;

/**
 * The default length of a PDKDF derived key, in bytes.  This value can be overridden
 * by calling [SFSDKCryptoUtils 
 */
extern NSUInteger const kSFPBKDFDefaultDerivedKeyByteLength;

/**
 * Various utility methods in support of cryptographic operations.
 */
@interface SFSDKCryptoUtils : NSObject

/**
 * @return The number of derivation rounds used to generate keys with PBKDF.
 */
+ (NSUInteger)numPBKDFDerivationRounds;

/**
 * Sets/overrides the number of derivation rounds that PBKDF functions will use to generate keys.
 * NOTE: Changing this value will change the value of a generated key.  If you have existing
 * keys that were generated with a different value, you need to make allowances for these changes.
 * @param numDerivationRounds The number of derivation rounds to use for key generation.
 */
+ (void)setNumPBKDFDerivationRounds:(NSUInteger)numDerivationRounds;

/**
 * @return The length of a PBKDF derived key, in bytes.
 */
+ (NSUInteger)pbkdfDerivedKeyByteLength;

/**
 * Sets/overrides the length of a PBKDF derived key, in bytes.
 * NOTE: Changing this value will change the value of a generated key.  If you have existing keys
 * that were generated with a different value, you need to make allowances for these changes.
 * @param derivedKeyByteLength The desired length of the derived key.
 */
+ (void)setPBKDFDerivedKeyByteLength:(NSUInteger)derivedKeyByteLength;

/**
 * Creates a random string of bytes (based on arc4random() generation) and returns
 * them as an NSData object.
 * @param lengthInBytes The number of bytes to generate.
 * @return The string of random bytes, as an NSData object.
 */
+ (NSData *)randomByteDataWithLength:(NSUInteger)lengthInBytes;

/**
 * Creates a PBKDF2 derived key from an input key (string) and a salt.
 * Note: Uses the values from [SFSDKCryptoUtils numPBKDFDerivationRounds] and
 * [SFSDKCryptoUtils pbkdfDerivedKeyByteLength] to configure the key generation.
 * @param stringToHash The base string to use for the derived key.
 * @param salt The salt to append to the string.
 * @return An NSData object represnting the derived key in bytes.
 */
+ (NSData *)pbkdf2DerivedKey:(NSString *)stringToHash salt:(NSData *)salt;

@end
