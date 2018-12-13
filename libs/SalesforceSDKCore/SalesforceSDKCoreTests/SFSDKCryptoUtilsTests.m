/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKCryptoUtils.h"
#import "SFPBKDFData.h"

@interface SFSDKCryptoUtilsTests : XCTestCase

@end

@implementation SFSDKCryptoUtilsTests

- (void)testRandomDataGenerator
{
    NSUInteger const randomStringByteLength = 32;
    NSUInteger const numDataStrings = 5000;
    
    NSMutableArray *dataStringArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < numDataStrings; i++) {
        [dataStringArray addObject:[SFSDKCryptoUtils randomByteDataWithLength:randomStringByteLength]];
    }
    
    for (NSUInteger i = 0; i < numDataStrings; i++) {
        for (NSUInteger j = i + 1; j < numDataStrings; j++) {
            XCTAssertFalse([[dataStringArray objectAtIndex:i] isEqualToData:[dataStringArray objectAtIndex:j]], @"Random data strings at index %lu and %luu are equal.  Not enough entropy!", (unsigned long)i, (unsigned long)j);
        }
    }
}

- (void)testDefaultPBKDFKeyGenerationProperties
{
    NSString *myString = @"HelloWorld321";
    SFPBKDFData *origData = [SFSDKCryptoUtils createPBKDF2DerivedKey:myString];
    XCTAssertEqual(origData.numDerivationRounds, kSFPBKDFDefaultNumberOfDerivationRounds, @"Expected default number of key generation rounds.");
    XCTAssertEqual([origData.salt length], kSFPBKDFDefaultSaltByteLength, @"Expected default salt length.");
    XCTAssertEqual(origData.derivedKeyLength, kSFPBKDFDefaultDerivedKeyByteLength, @"Expected default derived key length.");
}

- (void)testSamePBKDFKeysWithSameInputs
{
    NSString *initialPasscode = @"Hello123";
    NSString *verifyPasscode = @"Hello123";
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:32];
    NSUInteger numDerivationRounds = 100;
    NSUInteger derivedKeyLength = 128;
    
    SFPBKDFData *initialPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:initialPasscode
                                                                        salt:salt
                                                            derivationRounds:numDerivationRounds
                                                                   keyLength:derivedKeyLength];
    SFPBKDFData *verifyPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:verifyPasscode
                                                                       salt:salt
                                                           derivationRounds:numDerivationRounds
                                                                  keyLength:derivedKeyLength];
    XCTAssertTrue([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with same input parameters should be equal.");
    XCTAssertTrue([initialPBKDFData.salt isEqualToData:verifyPBKDFData.salt], @"Salt data with the same input parameters should be equal.");
    XCTAssertEqual(initialPBKDFData.numDerivationRounds, verifyPBKDFData.numDerivationRounds, @"Number of derivation rounds with the same input parameters should be equal.");
    XCTAssertEqual(initialPBKDFData.derivedKeyLength, verifyPBKDFData.derivedKeyLength, @"Derived key length values with the same input parameters should be equal.");
}

- (void)testDifferentPBKDFKeyWithDifferentSalt
{
    NSString *passcode = @"Hello123";
    NSUInteger saltByteLength = 32;
    NSUInteger numDerivationRounds = 100;
    NSUInteger derivedKeyLength = 128;
    
    NSData *initialSalt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *newSalt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    SFPBKDFData *initialPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                        salt:initialSalt
                                                            derivationRounds:numDerivationRounds
                                                                   keyLength:derivedKeyLength];
    SFPBKDFData *verifyPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                       salt:newSalt
                                                           derivationRounds:numDerivationRounds
                                                                  keyLength:derivedKeyLength];
    XCTAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different salts should not be equal.");
}

- (void)testDifferentPBKDFKeyWithDifferentDerivationRounds
{
    NSString *passcode = @"Hello123";
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:32];
    NSUInteger derivedKeyLength = 128;
    
    NSUInteger initialNumDerivationRounds = 100;
    SFPBKDFData *initialPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                        salt:salt
                                                            derivationRounds:initialNumDerivationRounds
                                                                   keyLength:derivedKeyLength];
    
    NSUInteger newNumDerivationRounds = initialNumDerivationRounds + 1;
    SFPBKDFData *verifyPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                       salt:salt
                                                           derivationRounds:newNumDerivationRounds
                                                                  keyLength:derivedKeyLength];
    XCTAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different derivation rounds should not be equal.");
}

- (void)testDifferentPBKDFKeyWithDifferentDerivedKeyLength
{
    NSString *passcode = @"Hello123";
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:32];
    NSUInteger numDerivationRounds = 100;
    
    NSUInteger initialDerivedKeyLength = 128;
    SFPBKDFData *initialPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                        salt:salt
                                                            derivationRounds:numDerivationRounds
                                                                   keyLength:initialDerivedKeyLength];
    
    NSUInteger newDerivedKeyLength = initialDerivedKeyLength + 1;
    SFPBKDFData *verifyPBKDFData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                       salt:salt
                                                           derivationRounds:numDerivationRounds
                                                                  keyLength:newDerivedKeyLength];
    XCTAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different derived key lengths should not be equal.");
}

- (void)testAes256EncryptionDecryption
{
    NSData *origData = [@"The quick brown fox..." dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [@"My encryption key" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ivData = [@"Here's an iv staging string" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *encryptedData = [SFSDKCryptoUtils aes256EncryptData:origData withKey:keyData iv:ivData];
    XCTAssertFalse([encryptedData isEqualToData:origData], @"Encrypted data should not be the same as original data.");
    
    // Clean decryption should pass.
    NSData *decryptedData = [SFSDKCryptoUtils aes256DecryptData:encryptedData withKey:keyData iv:ivData];
    XCTAssertTrue([decryptedData isEqualToData:origData], @"Decrypted data should match original data.");
    
    // Bad decryption key data should return different data.
    NSData *badKey = [@"The wrong key" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *badIv = [@"The wrong iv" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *badDecryptData = [SFSDKCryptoUtils aes256DecryptData:encryptedData withKey:badKey iv:ivData];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong encryption key should return different data on decrypt.");
    badDecryptData = [SFSDKCryptoUtils aes256DecryptData:encryptedData withKey:keyData iv:badIv];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong initialization vector should return different data on decrypt.");
    badDecryptData = [SFSDKCryptoUtils aes256DecryptData:encryptedData withKey:badKey iv:badIv];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong key and initialization vector should return different data on decrypt.");
}

- (void)testAes128EncryptionDecryption
{
    NSData *origData = [@"The quick brown fox..." dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [@"My encryption key" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ivData = [@"Here's an iv staging string" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *encryptedData = [SFSDKCryptoUtils aes128EncryptData:origData withKey:keyData iv:ivData];
    XCTAssertFalse([encryptedData isEqualToData:origData], @"Encrypted data should not be the same as original data.");
    
    // Clean decryption should pass.
    NSData *decryptedData = [SFSDKCryptoUtils aes128DecryptData:encryptedData withKey:keyData iv:ivData];
    XCTAssertTrue([decryptedData isEqualToData:origData], @"Decrypted data should match original data.");
    
    // Bad decryption key data should return different data.
    NSData *badKey = [@"The wrong key" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *badIv = [@"The wrong iv" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *badDecryptData = [SFSDKCryptoUtils aes128DecryptData:encryptedData withKey:badKey iv:ivData];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong encryption key should return different data on decrypt.");
    badDecryptData = [SFSDKCryptoUtils aes128DecryptData:encryptedData withKey:keyData iv:badIv];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong initialization vector should return different data on decrypt.");
    badDecryptData = [SFSDKCryptoUtils aes128DecryptData:encryptedData withKey:badKey iv:badIv];
    XCTAssertFalse([badDecryptData isEqualToData:origData], @"Wrong key and initialization vector should return different data on decrypt.");
}

- (void)testRSAKeyGeneration
{
    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test" keyLength:2048 accessibleAttribute:kSecAttrAccessibleAlways];
    NSData *privateKeyData = [SFSDKCryptoUtils getRSAPrivateKeyDataWithName:@"test" keyLength:2048];
    XCTAssertNotNil(privateKeyData);
    NSString *publicKeyString = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:@"test" keyLength:2048];
    XCTAssertNotNil(publicKeyString);
}

- (void)testRSAKeyGenerationDifferentKey
{
    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test1" keyLength:2048 accessibleAttribute:kSecAttrAccessibleAlways];
    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test2" keyLength:2048 accessibleAttribute:kSecAttrAccessibleAlways];

    NSData *privateKeyData1 = [SFSDKCryptoUtils getRSAPrivateKeyDataWithName:@"test1" keyLength:2048];
    XCTAssertNotNil(privateKeyData1);

    NSData *privateKeyData2 = [SFSDKCryptoUtils getRSAPrivateKeyDataWithName:@"test2" keyLength:2048];
    XCTAssertNotNil(privateKeyData2);

    XCTAssertFalse([privateKeyData1 isEqualToData:privateKeyData2], @"should get different private key data with different keynames");

    NSString *public1KeyString = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:@"test1" keyLength:2048];
    XCTAssertFalse([public1KeyString isEqualToString:@""]);

    NSString *public2KeyString = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:@"test2" keyLength:2048];
    XCTAssertFalse([public2KeyString isEqualToString:@""]);

    XCTAssertFalse([public1KeyString isEqualToString:public2KeyString], @"should get different public key strings with different keynames");

    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test1" keyLength:1024 accessibleAttribute:kSecAttrAccessibleAlways];

    NSData *privateKeyData3 = [SFSDKCryptoUtils getRSAPrivateKeyDataWithName:@"test1" keyLength:1024];
    XCTAssertNotNil(privateKeyData3);

    NSString *public3KeyString = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:@"test1" keyLength:1024];
    XCTAssertFalse([public3KeyString isEqualToString:@""]);

    XCTAssertFalse([public3KeyString isEqualToString:public1KeyString], @"should get different public key strings with different sizes");
    XCTAssertFalse([privateKeyData3 isEqualToData:privateKeyData1], @"should get different private key strings with different sizes");

}

- (void)testRSAEncryptionAndDecryption
{
    size_t keySize = 2048;

    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test" keyLength:keySize accessibleAttribute:kSecAttrAccessibleAlways];

    SecKeyRef publicKeyRef = [SFSDKCryptoUtils getRSAPublicKeyRefWithName:@"test" keyLength:keySize];
    SecKeyRef privateKeyRef = [SFSDKCryptoUtils getRSAPrivateKeyRefWithName:@"test" keyLength:keySize];
    
    // Encrypt data
    NSString *testString = @"This is a test";
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [SFSDKCryptoUtils encryptUsingRSAforData:testData withKeyRef:publicKeyRef];
    
    // Decrypt data
    NSData *decryptedData = [SFSDKCryptoUtils decryptUsingRSAforData:encryptedData withKeyRef:privateKeyRef];
    NSString *result = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    XCTAssertTrue([testString isEqualToString:result]);
}

- (void)testRSAEncryptionAndDecryptionForData
{
    size_t keySize = 2048;
    
    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test" keyLength:keySize accessibleAttribute:kSecAttrAccessibleAlways];
    
    SecKeyRef publicKeyRef = [SFSDKCryptoUtils getRSAPublicKeyRefWithName:@"test" keyLength:keySize];
    SecKeyRef privateKeyRef = [SFSDKCryptoUtils getRSAPrivateKeyRefWithName:@"test" keyLength:keySize];

    NSUInteger byteDataInt = 123456;
    NSData *testData = [NSData dataWithBytes:&byteDataInt length:sizeof(NSUInteger)];
    NSData *encryptedData = [SFSDKCryptoUtils encryptUsingRSAforData:testData withKeyRef:publicKeyRef];
    
    NSData *decryptedData = [SFSDKCryptoUtils decryptUsingRSAforData:encryptedData withKeyRef:privateKeyRef];
    XCTAssertEqualObjects(testData, decryptedData, @"Data objects are not the same data.");
}

- (void)testRSAEncryptionAndDecryptionWrongKeys
{
    size_t keySize = 2048;

    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test1" keyLength:keySize accessibleAttribute:kSecAttrAccessibleAlways];
    [SFSDKCryptoUtils createRSAKeyPairWithName:@"test" keyLength:keySize accessibleAttribute:kSecAttrAccessibleAlways];

    SecKeyRef publicKeyRef = [SFSDKCryptoUtils getRSAPublicKeyRefWithName:@"test1" keyLength:keySize];
    SecKeyRef privateKeyRef = [SFSDKCryptoUtils getRSAPrivateKeyRefWithName:@"test" keyLength:keySize];
    
    // Encrypt data
    NSString *testString = @"This is a test";
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [SFSDKCryptoUtils encryptUsingRSAforData:testData withKeyRef:publicKeyRef];
    
    // Decrypt data
    NSData *decryptedData = [SFSDKCryptoUtils decryptUsingRSAforData:encryptedData withKeyRef:privateKeyRef];
    NSString *result = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    XCTAssertFalse([testString isEqualToString:result]);
}
@end
