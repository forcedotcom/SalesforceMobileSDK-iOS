//
//  SFCryptoTestUtils.m
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

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
