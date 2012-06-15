/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

typedef void (^SFDecryptionCompletionBlock) (NSData *data, CCCryptorStatus status);
typedef enum {
    SFCryptoModeInMemory,
    SFCryptoModeDisk
    
} SFCryptoMode;

/**
 This class is responsible for encryption and decryption facilities that can be used by mobile apps.
 */
@interface SFCrypto : NSObject {
    CCCryptorRef _cryptor;
    size_t _totalLength;
    size_t _filePtr;
    char *_dataOut;
    size_t _dataOutMoved;
    size_t _dataOutLength;
}

/**
 The file to write the encrypted/decrypted data to used in SFCryptoModeDisk mode
 */
@property(nonatomic, copy) NSString *file;

/**
 Returns the current mode of operation of the SFCrypto class
 */
@property (nonatomic, readonly) SFCryptoMode mode;

/**
 Designated initializer
 @param operation operation to be performed encrypt/decrypt
 @param key Key used for encyption/decryption pass nil to use the default key
 @param mode Mode which determines whether to perform operation in memory at once or in chunks writing to the disk
 */
- (id)initWithOperation:(CCOperation)operation key:(NSData *)key mode:(SFCryptoMode)mode;

/**
 Encrypts or decrypts the passed in data, the input data is assumed to be passed in as a chunk
 Method requires finalizeCipher to be called
 @param data input data
 */
- (void)cryptData:(NSData *)inData;

/**
 Decrypt the passed in data initializer, performs the decryption in memory
 @param data encrypted input data
 */
- (NSData *)decryptDataInMemory:(NSData *)data;

/**
 Encrypt the passed in data initializer, performs the encryption in memory
 @param data input data
 */
- (NSData *)encryptDataInMemory:(NSData *)data;

/**
 Finalize the the encryption/decryption process
 */
- (BOOL)finalizeCipher;

@end
