/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFCryptChunks.h"
#import <CommonCrypto/CommonCrypto.h>

size_t const SFCryptChunksCipherBlockSize = kCCBlockSizeAES128;
uint32_t const SFCryptChunksCipherAlgorithm = kCCAlgorithmAES;
size_t const SFCryptChunksCipherKeySize = kCCKeySizeAES256;
uint32_t const SFCryptChunksCipherOptions = kCCOptionPKCS7Padding;

@interface SFCryptChunks()

@property (nonatomic, assign) CCCryptorRef cryptor;
@property (nonatomic, assign, readwrite) BOOL cryptFinalized;

@end

@implementation SFCryptChunks

#pragma mark - Lifecycle

- (instancetype)initForEncryptionWithKey:(NSData *)key
                    initializationVector:(nullable NSData *)iv {
    return [self initWithKey:key initializationVector:iv operation:kCCEncrypt];
}

- (instancetype)initForDecryptionWithKey:(NSData *)key
                    initializationVector:(NSData *)iv {
    return [self initWithKey:key initializationVector:iv operation:kCCDecrypt];
}

- (instancetype)initWithKey:(NSData *)key
       initializationVector:(nullable NSData *)iv
                  operation:(CCOperation)operation {
    if ((self = [super init])) {
        // For compatibility with SFCrypto, fill/truncate key if necessary.
        uint8_t keyPtr[SFCryptChunksCipherKeySize] = {0};
        [key getBytes:keyPtr length:SFCryptChunksCipherKeySize];
        if (key.length != SFCryptChunksCipherKeySize) {
            // (in the future this should probably be an assertion instead).
            NSLog(@"SFCryptChunks - (warning) Key size is %lu when it should be %zu.", (unsigned long) key.length, SFCryptChunksCipherKeySize);
        }
        
        NSAssert(!iv || [iv length] == SFCryptChunksCipherBlockSize, @"SFCryptChunks - invalid initialization vector size.");
        CCCryptorStatus status = CCCryptorCreate(operation,
                                                 SFCryptChunksCipherAlgorithm,
                                                 SFCryptChunksCipherOptions,
                                                 keyPtr,
                                                 SFCryptChunksCipherKeySize,
                                                 [iv bytes],
                                                 &_cryptor);
        if (status != kCCSuccess) {
            NSLog(@"SFCryptChunks - failed to initialize cryptor, CCCryptorStatus: %i.", status);
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    CCCryptorRelease(_cryptor), _cryptor = NULL;
}


#pragma mark - Public

- (void)cryptBuffer:(const uint8_t *)buffer bufferLen:(size_t)len {
    /*
     From CommonCryptor.h: "For block ciphers, the output size will
     always be less than or equal to the input size plus the size
     of one block.", SFCryptChunks uses AES which is a block cipher algorithm.
     */
    const size_t kMaxOutLen = SFCryptChunksCipherBlockSize * 2;
    uint8_t outBuffer[kMaxOutLen];
    const size_t kMaxInLen = kMaxOutLen - SFCryptChunksCipherBlockSize;
    NSRange inBufferWindow;
    inBufferWindow.location = 0;
    inBufferWindow.length = MIN(kMaxInLen, len);
    while (inBufferWindow.location < len) {
        const uint8_t *inBuffer = &(buffer[inBufferWindow.location]);
        size_t cryptedCount = 0;
        CCStatus result = CCCryptorUpdate(self.cryptor,
                                          inBuffer,
                                          inBufferWindow.length,
                                          outBuffer,
                                          kMaxOutLen,
                                          &cryptedCount);
        NSAssert(result == kCCSuccess, @"SFCryptChunks - error on CCCryptorUpdate call.");
        if (cryptedCount > 0) {
            [self.delegate cryptChunk:self chunkResult:outBuffer bufferLen:cryptedCount];
        }
        // Move window
        inBufferWindow.location += inBufferWindow.length;
        inBufferWindow.length = MIN(kMaxInLen, len - inBufferWindow.location);
    }
}

- (void)finalizeCrypt {
    if (!self.cryptFinalized) {
        self.cryptFinalized = YES;
        uint8_t outBuffer[SFCryptChunksCipherBlockSize]; // the max output size of CCCryptorFinal is 1 cipher block size.
        size_t cryptedCount = 0;
        CCStatus result = CCCryptorFinal(self.cryptor,
                                         outBuffer,
                                         SFCryptChunksCipherBlockSize,
                                         &cryptedCount);
        NSAssert(result == kCCSuccess, @"SFCryptChunks - error on CCCryptorFinal call.");
        if (cryptedCount > 0) {
            [self.delegate cryptChunk:self chunkResult:outBuffer bufferLen:cryptedCount];
        }
    }
}

@end
