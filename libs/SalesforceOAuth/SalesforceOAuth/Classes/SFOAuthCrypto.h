/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 Author: Amol Prabhu
 
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

typedef NS_ENUM(NSUInteger, SFOAuthCryptoOperation) {
    SFOAEncrypt = 0,
    SFOADecrypt
};

/**
 Provides a wrapper for cryptographic services.
 @warning Once the `decryptData` or `finalizeCipher` method is called this object cannot be reused.
 */
@interface SFOAuthCrypto : NSObject

/**
 Initializes a new `SFOAuthCrypto` object to perform the specified cryptographic operation.
 @param operation Operation to be performed: `SFOAuthCryptoEncrypt` or `SFOAuthCryptoDecrypt`
 @param key Key used for encyption/decryption. `nil` may be specified to use the default key.
 */
- (id)initWithOperation:(SFOAuthCryptoOperation)operation key:(NSData *)key;

/**
 Encrypts the supplied data. To complete the encryption process and retrieve the encrypted data, call `finalizeCipher`.
 @param data Unencrypted data to encrypt.
 */
- (void)encryptData:(NSData *)data;

/**
 Returns a decrypted representation of the supplied data if the data can be decrypted using the current key. Returns `nil`
 if decryption fails. Decryption is performed on the current thread.
 
 @warning After this method is called this object must no longer be used.
 
 @param data Encrypted data to decrypt.
 */
- (NSData *)decryptData:(NSData *)data;

/**
 Finalizes the the data encryption process and returns the encrypted data.
 
 @warning After this method is called this object must no longer be used.
 */
- (NSData *)finalizeCipher;

@end
