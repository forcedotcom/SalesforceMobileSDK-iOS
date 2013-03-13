/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKCryptoUtilsTests.h"
#import "SFSDKCryptoUtils.h"
#import "SFPBKDFData.h"

@implementation SFSDKCryptoUtilsTests

- (void)testRandomDataGenerator
{
    NSUInteger const randomStringByteLength = 32;
    NSUInteger const numDataStrings = 5000;
    
    NSMutableArray *dataStringArray = [NSMutableArray array];
    for (int i = 0; i < numDataStrings; i++) {
        [dataStringArray addObject:[SFSDKCryptoUtils randomByteDataWithLength:randomStringByteLength]];
    }
    
    for (int i = 0; i < numDataStrings; i++) {
        for (int j = i + 1; j < numDataStrings; j++) {
            STAssertFalse([[dataStringArray objectAtIndex:i] isEqualToData:[dataStringArray objectAtIndex:j]], @"Random data strings at index %d and %d are equal.  Not enough entropy!", i, j);
        }
    }
}

- (void)testDefaultPBKDFKeyGenerationProperties
{
    NSString *myString = @"HelloWorld321";
    SFPBKDFData *origData = [SFSDKCryptoUtils createPBKDF2DerivedKey:myString];
    STAssertEquals(origData.numDerivationRounds, kSFPBKDFDefaultNumberOfDerivationRounds, @"Expected default number of key generation rounds.");
    STAssertEquals([origData.salt length], kSFPBKDFDefaultSaltByteLength, @"Expected default salt length.");
    STAssertEquals(origData.derivedKeyLength, kSFPBKDFDefaultDerivedKeyByteLength, @"Expected default derived key length.");
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
    STAssertTrue([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with same input parameters should be equal.");
    STAssertTrue([initialPBKDFData.salt isEqualToData:verifyPBKDFData.salt], @"Salt data with the same input parameters should be equal.");
    STAssertEquals(initialPBKDFData.numDerivationRounds, verifyPBKDFData.numDerivationRounds, @"Number of derivation rounds with the same input parameters should be equal.");
    STAssertEquals(initialPBKDFData.derivedKeyLength, verifyPBKDFData.derivedKeyLength, @"Derived key length values with the same input parameters should be equal.");
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
    STAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different salts should not be equal.");
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
    STAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different derivation rounds should not be equal.");
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
    STAssertFalse([initialPBKDFData.derivedKey isEqualToData:verifyPBKDFData.derivedKey], @"Generated keys with different derived key lengths should not be equal.");
}

@end
