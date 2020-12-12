/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFPBKDFData.h"
#import "SFSecurityLockout.h"
#import "SFSecurityLockout+Internal.h"

@interface SFPasscodeTests : XCTestCase

@end

#pragma mark - SFPasscodeTests

@implementation SFPasscodeTests

- (void)setUp
{
    [super setUp];
    [SFSecurityLockout resetPasscode];
}

- (void)testSerializedPBKDFData
{
    NSString *keyString = @"Testing1234";
    NSString *saltString = @"SaltString1234";
    NSUInteger derivationRounds = 9876;
    NSString *codingKey = @"TestSerializedData";
    NSUInteger derivedKeyLength = 128;
    SFPBKDFData *pbkdfStartData = [[SFPBKDFData alloc] initWithKey:[keyString dataUsingEncoding:NSUTF8StringEncoding] salt:[saltString dataUsingEncoding:NSUTF8StringEncoding] derivationRounds:derivationRounds derivedKeyLength:derivedKeyLength];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:pbkdfStartData forKey:codingKey];
    [archiver finishEncoding];
    NSData *serializedData = archiver.encodedData;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:serializedData error:nil];
    unarchiver.requiresSecureCoding = NO;
    SFPBKDFData *pbkdfEndData = [unarchiver decodeObjectForKey:codingKey];
    [unarchiver finishDecoding];
    NSString *verifyKeyString = [[NSString alloc] initWithData:pbkdfEndData.derivedKey encoding:NSUTF8StringEncoding];
    NSString *verifySaltString = [[NSString alloc] initWithData:pbkdfEndData.salt encoding:NSUTF8StringEncoding];
    XCTAssertTrue([verifyKeyString isEqualToString:keyString], @"Serialized/deserialized keys are not the same.");
    XCTAssertTrue([verifySaltString isEqualToString:saltString], @"Serialized/deserialized salts are not the same.");
    XCTAssertEqual(pbkdfEndData.numDerivationRounds, derivationRounds, @"Serialized/deserialized number of derivation rounds are not the same.");
    XCTAssertEqual(pbkdfEndData.derivedKeyLength, derivedKeyLength, @"Serialized/deserialized derived key length values are not the same.");
}

- (void)testPasscodeSetReset
{
    NSString *passcodeToSet = @"MyNewPasscode";
    XCTAssertFalse([SFSecurityLockout isPasscodeSet], @"No passcode should be set at this point.");
    
    [SFSecurityLockout setPasscode:passcodeToSet];
    XCTAssertTrue([SFSecurityLockout isPasscodeSet], @"Passcode should now be set.");
    
    [SFSecurityLockout resetPasscode];
    XCTAssertFalse([SFSecurityLockout isPasscodeSet], @"Passcode should no longer be set.");
}


@end
