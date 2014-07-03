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

#import <CommonCrypto/CommonCryptor.h>
#import "SFOAuthCrypto.h"

static const CCAlgorithm    kCryptoAlgorithm    = kCCAlgorithmAES128;
static const size_t         kCryptoBlockSize    = kCCBlockSizeAES128;
static const size_t         kCryptoKeySize      = kCCKeySizeAES256;

@interface SFOAuthCrypto () {
    CCCryptorRef _cryptor;
    size_t _totalLength;
    size_t _filePtr;
    char * _dataOut;
    size_t _dataOutMoved;
    size_t _dataOutLength;
}

@property (nonatomic, copy) NSMutableData *dataBuffer;
@property (nonatomic) CCCryptorStatus status;

- (void)doCipher:(NSData *)inData;

@end

@implementation SFOAuthCrypto 

@synthesize dataBuffer = _dataBuffer;
@synthesize status = _status;

#pragma mark - Object Lifecycle

- (id)initWithOperation:(SFOAuthCryptoOperation)operation key:(NSData *)key {
    if (self = [super init]) {
        char keyPtr[kCryptoKeySize + 1];
        bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
        
        // Fetch key data
        [key getBytes:keyPtr length:sizeof(keyPtr)];
        
        CCOperation ccOp = (SFOAEncrypt == operation) ? kCCEncrypt : kCCDecrypt;
        CCCryptorStatus cryptStatus = CCCryptorCreate(ccOp, kCryptoAlgorithm, kCCOptionPKCS7Padding,
                                                      keyPtr, kCryptoKeySize,
                                                      NULL, 
                                                      &_cryptor);
        
        if (cryptStatus != kCCSuccess) {
            [self log:SFLogLevelDebug format:@"%@:initWithOperation: CCCryptorCreate failed (%d)", [self class], cryptStatus];
            return nil;
        }
        _dataBuffer = [[NSMutableData alloc] init];
        _totalLength = 0; // Keeps track of the total length of the output buffer
        _filePtr = 0;   // Maintains the file pointer for the output buffer
        
    }
    return self;
}

- (void)dealloc {
    _dataBuffer = nil;
    if (_dataOut) free(_dataOut); _dataOut = NULL;
    if (_cryptor) CCCryptorRelease(_cryptor); _cryptor = NULL;
}

#pragma mark - Implementation

- (NSData *)decryptData:(NSData *)data {
    NSData *decryptedData = nil;
    if (data) {
        [self doCipher:data];
        decryptedData = [self finalizeCipher];
    }
    return decryptedData;
}

- (void)encryptData:(NSData *)inData {
    if (inData) {
        [self doCipher:inData];
    }
}

- (NSData *)finalizeCipher {
    // Finalize encryption/decryption.
    self.status = CCCryptorFinal(_cryptor, _dataOut, _dataOutLength, &_dataOutMoved);
    _totalLength += _dataOutMoved;
    
    if (self.status != kCCSuccess) {
        [self log:SFLogLevelDebug format:@"%@:finalizeCipher: Failed in cipher finalization (%d)", [self class], self.status];
        CCCryptorRelease(_cryptor); _cryptor = NULL;
        free(_dataOut); _dataOut = NULL;
        return nil;
    }
    
    // In the case of encryption, expand the buffer if it required some padding (an encrypted buffer will
    // always be a multiple of the algorithm block size).
    // In the case of decryption, truncate our buffer in case the encrypted buffer contained some padding.
    [self.dataBuffer setLength:_totalLength];
    
    // Copy the bytes from the temporary _dataOut buffer (filled by the CCCryptoFinal function) to our class buffer.
    NSRange bytesRange = NSMakeRange(_filePtr, (NSUInteger) _dataOutMoved);
    [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
    
    CCCryptorRelease(_cryptor); _cryptor = NULL;
    free(_dataOut); _dataOut = NULL;
    
    return [NSData dataWithData:self.dataBuffer];
}

- (void)doCipher:(NSData *)inData  {
    NSAssert(inData, @"inData cannot be nil");
    
    size_t dataInLength = [inData length];
    _dataOutLength = kCryptoBlockSize; // set default data out length to block size
    
    size_t tmpDataOutLength = CCCryptorGetOutputLength(_cryptor, dataInLength, FALSE);
    if (tmpDataOutLength > 0) {
        _dataOutLength = tmpDataOutLength;
    }
    NSInteger startByte = 0; // Maintains the pointer for the input buffer
    
    char *dataIn = malloc(dataInLength);
    
    if (_dataOut != nil) {
        free(_dataOut);
    }
    _dataOut = malloc(_dataOutLength);
    
    // Get the chunk to be ciphered from the input buffer
    NSRange bytesRange = NSMakeRange((NSUInteger) startByte, (NSUInteger) dataInLength);
    [inData getBytes:dataIn range:bytesRange];
    
    CCCryptorStatus cryptStatus = CCCryptorUpdate(_cryptor, dataIn, dataInLength, _dataOut, _dataOutLength, &_dataOutMoved);
    
    if ( cryptStatus != kCCSuccess) {
        [self log:SFLogLevelDebug format:@"%@:doCipher: CCCryptorUpdate failed (%d)", [self class], cryptStatus];
    }
    
    // Write the ciphered buffer into the output buffer
    bytesRange = NSMakeRange(_filePtr, (NSUInteger) _dataOutMoved);
    _totalLength += _dataOutMoved;
    _filePtr += _dataOutMoved;
    
    [self.dataBuffer setLength:_totalLength];
    [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
    
    free(dataIn);
}

@end
