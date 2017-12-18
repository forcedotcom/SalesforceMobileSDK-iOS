/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import <XCTest/XCTest.h>
#import "SFCryptChunks.h"
#import "SFEncryptStream.h"
#import "SFDecryptStream.h"
#import "SFCryptoStreamTestUtils.h"


@interface SFEncryptDecryptStreamTests : XCTestCase

@end


@interface SFCryptChunks (Testing)

@property (nonatomic, assign, readonly) CCCryptorRef cryptor;

@end


@interface SFEncryptStream (Testing)

@property (nonatomic, strong, readonly) SFCryptChunks *cryptChunks;

@end


@interface SFDecryptStream (Testing)

@property (nonatomic, strong, readonly) SFCryptChunks *cryptChunks;

@end


@implementation SFEncryptDecryptStreamTests

- (void)testEncryptsIntegralCipherBlockSizeExact {
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize];
}

- (void)testEncryptsIntegralCipherBlockSizeMultiple {
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 3];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 10];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 42];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 1098];
}

- (void)testEncryptsArbitrarySizeBiggerThanCipherBlockSize {
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize + 1];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize + 7];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize + 83];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize + 331];
}

- (void)testEncryptsArbitrarySizeSmallerThanCipherBlockSize {
    [self performTestWithDataLen:0];
    [self performTestWithDataLen:1];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize / 2];
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize - 1];
}

- (void)testWithHugeDataSize {
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 10000];
    [self performTestWithDataLen:(SFCryptChunksCipherBlockSize * 10000) + 7];
    //these take a while (~30s):
    [self performTestWithDataLen:SFCryptChunksCipherBlockSize * 100000];
    [self performTestWithDataLen:(SFCryptChunksCipherBlockSize * 100000) + 13];
}

#pragma mark - The actual test code

- (void)performTestWithDataLen:(NSUInteger)testLen {
    NSArray *dataChunksToTest = @[@(SFCryptChunksCipherBlockSize/2),
                                  @(SFCryptChunksCipherBlockSize-1),
                                  @(SFCryptChunksCipherBlockSize+1),
                                  @(SFCryptChunksCipherBlockSize),
                                  @1, // yup, 1 byte buffer.
                                  @(SFCryptChunksCipherBlockSize*10)];
    // Test with each individually
    for (int i = 0; i < dataChunksToTest.count; ++i) {
        [self performTestWithDataLen:testLen useDataChunks:@[dataChunksToTest[i]]];
    }
    
    // Test using all sizes in sequence
    [self performTestWithDataLen:testLen useDataChunks:dataChunksToTest];
    
    // Test using all sizes in inverted-sequence
    [self performTestWithDataLen:testLen useDataChunks:[[dataChunksToTest reverseObjectEnumerator] allObjects]];
    
    // Test with a gigant buffer
    [self performTestWithDataLen:testLen useDataChunks:@[@(SFCryptChunksCipherBlockSize*100000)]];
}

- (void)performTestWithDataLen:(NSUInteger)testLen useDataChunks:(NSArray *)chunksLen {
    NSData *testData = [SFCryptoStreamTestUtils defaultTestDataWithSize:testLen];
    NSData *iv = [SFCryptoStreamTestUtils defaultInitializationVectorWithBlockSize:SFCryptChunksCipherBlockSize];
    NSData *key = [SFCryptoStreamTestUtils defaultKeyWithSize:kCCKeySizeAES256];
    NSString *filePath = [SFCryptoStreamTestUtils filePathForFileName:[[NSUUID UUID] UUIDString]]; //where the encrypted file will be written
    NSUInteger __block useChunkLen = 0;
    void (^incrementUseChunkLen)(void) = ^{
        if (++useChunkLen >= chunksLen.count) useChunkLen = 0;
    };
    void (^performEncryption)(SFEncryptStream *) = ^(SFEncryptStream *encryptStream) {
        [encryptStream setupWithKey:key andInitializationVector:iv];
        [encryptStream open];
        NSRange encryptChunkRange = {0};
        while (encryptChunkRange.location < testData.length) {
            encryptChunkRange.location += encryptChunkRange.length;
            encryptChunkRange.length = [chunksLen[useChunkLen] unsignedIntegerValue];
            incrementUseChunkLen();
            
            // Trim len if necessary
            if (encryptChunkRange.location + encryptChunkRange.length > testData.length) {
                encryptChunkRange.length = testData.length - encryptChunkRange.location;
            }
            
            // Write a chunk of bytes
            [encryptStream write:&(testData.bytes[encryptChunkRange.location])
                       maxLength:encryptChunkRange.length];
        }
        [encryptStream close];
    };
    NSData *(^performDecryption)(SFDecryptStream *) = ^(SFDecryptStream *decryptStream) {
        [decryptStream setupWithKey:key andInitializationVector:iv];
        [decryptStream open];
        NSMutableData *decryptedData = [[NSMutableData alloc] init];
        while ([decryptStream hasBytesAvailable]) {
            incrementUseChunkLen();
            NSMutableData *decryptedChunk = [[NSMutableData alloc] initWithLength:[chunksLen[useChunkLen] unsignedIntegerValue]];
            NSInteger bytesDecrypted = [decryptStream read:decryptedChunk.mutableBytes maxLength:decryptedChunk.length];
            decryptedChunk.length = bytesDecrypted;
            [decryptedData appendData:decryptedChunk];
        }
        [decryptStream close];
        return decryptedData;
    };
    
    // Encrypt in memory
    SFEncryptStream *encryptInMemoryStream = [[SFEncryptStream alloc] initToMemory];
    performEncryption(encryptInMemoryStream);
    NSData *encryptedInMemoryResult = [encryptInMemoryStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    
    // Encrypt to file via stream
    SFEncryptStream *encryptToFileStream = [[SFEncryptStream alloc] initToFileAtPath:filePath append:NO];
    performEncryption(encryptToFileStream);
    NSData *encryptedToFileResult = [NSData dataWithContentsOfFile:filePath];
    
    // Sanity encryption comparison
    NSData *encryptedBaseData = [SFCryptoStreamTestUtils encryptDecryptData:testData
                                                                usingCrypto:encryptToFileStream.cryptChunks.cryptor
                                                   withInitializationVector:iv];
    XCTAssertEqualObjects(encryptedInMemoryResult, encryptedBaseData);
    XCTAssertEqualObjects(encryptedToFileResult, encryptedBaseData);
    
    
    // Decrypt in memory
    SFDecryptStream *decryptInMemoryStream = [[SFDecryptStream alloc] initWithData:encryptedBaseData];
    NSData *decryptedInMemoryResult = performDecryption(decryptInMemoryStream);
    
    // Decrypt from file via stream
    SFDecryptStream *decryptFromFileStream = [[SFDecryptStream alloc] initWithFileAtPath:filePath];
    NSData *decryptedFromFileResult = performDecryption(decryptFromFileStream);
    
    // Sanity decryption comparison
    NSData *decryptedBaseData = [SFCryptoStreamTestUtils encryptDecryptData:encryptedToFileResult
                                                          usingCrypto:decryptFromFileStream.cryptChunks.cryptor
                                             withInitializationVector:iv];
    XCTAssertEqualObjects(decryptedInMemoryResult, decryptedBaseData);
    XCTAssertEqualObjects(decryptedFromFileResult, decryptedBaseData);
    
    
    // Finally check if inital data is equal to final decrypted data
    XCTAssertEqualObjects(testData, decryptedFromFileResult);
}

@end
