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

#import "SFCryptoStreamTestUtils.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

@implementation SFCryptoStreamTestUtils

+ (NSData *)defaultKeyWithSize:(size_t)keySize {
    NSString *key = @"defaultKey";
    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CC_SHA256([key UTF8String], (CC_LONG)[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSData *keyData = [NSData dataWithBytes:digest length:keySize];
    return keyData;
}

+ (NSData *)defaultInitializationVectorWithBlockSize:(size_t)blockSize {
    NSString *storageKey = [NSString stringWithFormat:@"iv_%ld", blockSize];
    NSData *iv = [[NSUserDefaults standardUserDefaults] objectForKey:storageKey];
    if (!iv) {
        NSMutableData *data = [[NSMutableData alloc] initWithLength:blockSize];
        int result = SecRandomCopyBytes(kSecRandomDefault, blockSize, [data mutableBytes]);
        NSAssert(result == 0, @"Failed to generate random bytes.");
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:storageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        iv = data;
    }
    return iv;
}

+ (NSData *)defaultTestDataWithSize:(size_t)testDataSize {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:testDataSize];
    Byte *bytes = data.mutableBytes;
    for (NSUInteger i = 0; i < testDataSize; ++i) {
        bytes[i] = i;
    }
    return data;
}

+ (NSData *)encryptDecryptData:(NSData *)data
                   usingCrypto:(CCCryptorRef)crypto
      withInitializationVector:(NSData *)iv {
    CCStatus baseResetStatus = CCCryptorReset(crypto, iv.bytes);
    NSAssert(baseResetStatus == kCCSuccess, @"SFCryptoStreamTestUtils: Failed to reset crypto.");
    size_t baseDataTotalSize = CCCryptorGetOutputLength(crypto,
                                                        [data length],
                                                        true/*final*/);
    NSMutableData *baseData = [[NSMutableData alloc] initWithLength:baseDataTotalSize];
    size_t baseBytesMoved = 0;
    CCStatus baseUpdateStatus = CCCryptorUpdate(crypto,
                                                data.bytes,
                                                data.length,
                                                baseData.mutableBytes,
                                                baseData.length,
                                                &baseBytesMoved);
    NSAssert(baseUpdateStatus == kCCSuccess, @"SFCryptoStreamTestUtils: failed to crypt data.");
    baseData.length = baseBytesMoved; //trims if necessary
    
    NSMutableData *finalData = [[NSMutableData alloc] initWithLength:baseDataTotalSize - baseBytesMoved];
    size_t finalBytesMoved = 0;
    CCStatus baseFinalStatus = CCCryptorFinal(crypto,
                                              finalData.mutableBytes,
                                              finalData.length,
                                              &finalBytesMoved);
    NSAssert(baseFinalStatus == kCCSuccess, @"SFCryptoStreamTestUtils: failed to finalize crypt.");
    finalData.length = finalBytesMoved;
    [baseData appendData:finalData];
    return baseData;
}

+ (NSString *)filePathForFileName:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

@end
