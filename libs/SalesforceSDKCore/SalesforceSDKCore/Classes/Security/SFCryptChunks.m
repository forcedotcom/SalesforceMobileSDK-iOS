//
//  SFCryptChunks.m
//  SFCryptoStream
//
//  Created by Joao Neves on 4/6/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import "SFCryptChunks.h"

size_t const SFCryptChunksCipherBlockSize = kCCBlockSizeAES128;
CCAlgorithm const SFCryptChunksCipherAlgorithm = kCCAlgorithmAES;
CCOptions const SFCryptChunksCipherOptions = kCCOptionPKCS7Padding;

@interface SFCryptChunks()

@property (nonatomic, assign) CCCryptorRef cryptor;
@property (nonatomic, assign, readwrite) BOOL cryptFinalized;

@end

@implementation SFCryptChunks

#pragma mark - Lifecycle

- (instancetype)initWithKey:(NSData *)key
       initializationVector:(nullable NSData *)iv
                  operation:(CCOperation)operation {
    if ((self = [super init])) {
        NSAssert(!iv || [iv length] == SFCryptChunksCipherBlockSize, @"SFCryptChunks - invalid initialization vector size.");
        CCCryptorStatus status = CCCryptorCreate(operation,
                                                 SFCryptChunksCipherAlgorithm,
                                                 SFCryptChunksCipherOptions,
                                                 [key bytes],
                                                 [key length],
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
