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
#import <CommonCrypto/CommonCryptor.h>

@interface SFOAuthCrypto : NSObject {
@private
    CCCryptorRef _cryptor;
    size_t _totalLength;
    size_t _filePtr;
    char *_dataOut;
    size_t _dataOutMoved;
    size_t _dataOutLength;
}
/**
 Designated initializer
 @param operation Operation to be performed: encrypt/decrypt
 @param key Key used for encyption/decryption pass `nil` to use the default key
 */
- (id)initWithOperation:(CCOperation)operation key:(NSData *)key;

/**
 Encrypt the passed in data
 @param data input data
 */
- (void)encryptData:(NSData *)data;

/**
 Decrypt the passed in data. Performs the decryption in the current thread
 @param data encrypted input data
 */
- (NSData *)decryptData:(NSData *)data;

/**
 Finalize the the encryption/decryption process
 */
- (NSData *)finalizeCipher;

@end
