//
//  SFCryptoTestUtils.h
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Utilities for crypto stream testing.
 */
@interface SFCryptoStreamTestUtils : NSObject

/**
 *  The default test key bounded by a size.
 *  @param keySize the key size.
 *  @return the default test key data.
 */
+ (NSData *)defaultKeyWithSize:(size_t)keySize;

/**
 *  The default initialization vector bounded by a size.
 *  @param blockSize the iv size.
 *  @return the default test iv data.
 */
+ (NSData *)defaultInitializationVectorWithBlockSize:(size_t)blockSize;

/**
 *  The default test data bounded by a size.
 *  @param testDataSize the test data size.
 *  @return the default test data.
 */
+ (NSData *)defaultTestDataWithSize:(size_t)testDataSize;

/**
 *  Encrypt or decrypted in one-shot, based on the operation type of `crypto`.
 *  @param data   the data to be encrypted/decrypted.
 *  @param crypto a crypto reference to be used in the operation.
 *  @param iv     the initialization vector desired to be used.
 *  @return the encrypted/decrypted result.
 */
+ (NSData *)encryptDecryptData:(NSData *)data
                   usingCrypto:(CCCryptorRef)crypto
      withInitializationVector:(NSData *)iv;

/**
 *  A file path where test files are stored.
 *  @param fileName the file name.
 *  @return the complete path to reach the test file name passed.
 */
+ (NSString *)filePathForFileName:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
