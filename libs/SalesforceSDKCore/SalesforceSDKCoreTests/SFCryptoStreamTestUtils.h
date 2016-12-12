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
