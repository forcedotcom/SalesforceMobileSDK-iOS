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

@implementation SFSDKCryptoUtilsTests

- (void)testDefaultStaticProperties
{
    STAssertEquals([SFSDKCryptoUtils numPBKDFDerivationRounds], kSFPBKDFDefaultNumberOfDerivationRounds, @"Expected default value for number of PBKDF key derivation rounds.");
    STAssertEquals([SFSDKCryptoUtils pbkdfDerivedKeyByteLength], kSFPBKDFDefaultDerivedKeyByteLength, @"Expected default value for default derived key length.");
}

- (void)testPropertyGettersSetters
{
    NSUInteger newDerivationRounds = arc4random();
    NSUInteger newDerivedKeyByteLength = arc4random();
    
    [SFSDKCryptoUtils setNumPBKDFDerivationRounds:newDerivationRounds];
    STAssertEquals([SFSDKCryptoUtils numPBKDFDerivationRounds], newDerivationRounds, @"Expected updated value for number of derivation rounds.");
    [SFSDKCryptoUtils setNumPBKDFDerivationRounds:kSFPBKDFDefaultNumberOfDerivationRounds];
    
    [SFSDKCryptoUtils setPBKDFDerivedKeyByteLength:newDerivedKeyByteLength];
    STAssertEquals([SFSDKCryptoUtils pbkdfDerivedKeyByteLength], newDerivedKeyByteLength, @"Expected updated value for derived key byte length.");
    [SFSDKCryptoUtils setPBKDFDerivedKeyByteLength:kSFPBKDFDefaultDerivedKeyByteLength];
}

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

- (void)testSamePBKDFKeysWithSameInputs
{
    NSString *initialPasscode = @"Hello123";
    NSString *verifyPasscode = @"Hello123";
    NSUInteger saltByteLength = 32;
    
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *initialPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:initialPasscode salt:salt];
    NSData *verifyPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:verifyPasscode salt:salt];
    STAssertTrue([initialPBKDFData isEqualToData:verifyPBKDFData], @"Generated keys with same input parameters should be equal.");
}

- (void)testDifferentPBKDFKeyWithDifferentSalt
{
    NSString *passcode = @"Hello123";
    NSUInteger saltByteLength = 32;
    
    NSData *initialSalt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *newSalt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *initialPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:initialSalt];
    NSData *verifyPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:newSalt];
    STAssertFalse([initialPBKDFData isEqualToData:verifyPBKDFData], @"Generated keys with different salts should not be equal.");
}

- (void)testDifferentPBKDFKeyWithDifferentDerivationRounds
{
    NSString *passcode = @"Hello123";
    NSUInteger saltByteLength = 32;
    
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *initialPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:salt];
    
    [SFSDKCryptoUtils setNumPBKDFDerivationRounds:([SFSDKCryptoUtils numPBKDFDerivationRounds] + 1)];
    NSData *verifyPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:salt];
    STAssertFalse([initialPBKDFData isEqualToData:verifyPBKDFData], @"Generated keys with different derivation rounds should not be equal.");
    
    [SFSDKCryptoUtils setNumPBKDFDerivationRounds:kSFPBKDFDefaultNumberOfDerivationRounds];
}

- (void)testDifferentPBKDFKeyWithDifferentDerivedKeyLength
{
    NSString *passcode = @"Hello123";
    NSUInteger saltByteLength = 32;
    
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:saltByteLength];
    NSData *initialPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:salt];
    
    [SFSDKCryptoUtils setPBKDFDerivedKeyByteLength:([SFSDKCryptoUtils pbkdfDerivedKeyByteLength] + 1)];
    NSData *verifyPBKDFData = [SFSDKCryptoUtils pbkdf2DerivedKey:passcode salt:salt];
    STAssertFalse([initialPBKDFData isEqualToData:verifyPBKDFData], @"Generated keys with different derived key lengths should not be equal.");
    
    [SFSDKCryptoUtils setPBKDFDerivedKeyByteLength:kSFPBKDFDefaultDerivedKeyByteLength];
}

@end
