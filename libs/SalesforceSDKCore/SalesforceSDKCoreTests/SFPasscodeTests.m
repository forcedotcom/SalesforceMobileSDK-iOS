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
#import "SFPasscodeManager.h"
#import "SFPasscodeManager+Internal.h"
#import "SFPasscodeProviderManager.h"
#import "SFPasscodeProviderManager+Internal.h"
#import "SFSHA256PasscodeProvider.h"
#import "SFPBKDF2PasscodeProvider.h"

@interface SFPasscodeTests : XCTestCase

@end

#pragma mark - MockPasscodeProvider

@interface MockPasscodeProvider : NSObject <SFPasscodeProvider>

@end

@implementation MockPasscodeProvider
@synthesize providerName = _providerName;
- (id)initWithProviderName:(NSString *)providerName
{
    self = [super init];
    if (self) {
        _providerName = [providerName copy];
    }
    return self;
}
- (void)resetPasscodeData { /* Not implemented. */ }
- (BOOL)verifyPasscode:(NSString *)passcode { /* Not implemented. */ return YES; }
- (NSString *)hashedVerificationPasscode { /* Not implemented. */ return @""; }
- (void)setVerificationPasscode:(NSString *)newPasscode { /* Not implemented. */ }
- (NSString *)generateEncryptionKey:(NSString *)passcode { /* Not implemented. */ return @""; }
@end

#pragma mark - SFPasscodeTests

@implementation SFPasscodeTests

- (void)setUp
{
    [super setUp];
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;

    [[SFPasscodeManager sharedManager] resetPasscode];
    [SFPasscodeProviderManager resetCurrentPasscodeProviderName];
}

- (void)testSerializedPBKDFData
{
    NSString *keyString = @"Testing1234";
    NSString *saltString = @"SaltString1234";
    NSUInteger derivationRounds = 9876;
    NSString *codingKey = @"TestSerializedData";
    NSUInteger derivedKeyLength = 128;
    SFPBKDFData *pbkdfStartData = [[SFPBKDFData alloc] initWithKey:[keyString dataUsingEncoding:NSUTF8StringEncoding] salt:[saltString dataUsingEncoding:NSUTF8StringEncoding] derivationRounds:derivationRounds derivedKeyLength:derivedKeyLength];
    NSMutableData *serializedData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:serializedData];
    [archiver encodeObject:pbkdfStartData forKey:codingKey];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:serializedData];
    SFPBKDFData *pbkdfEndData = [unarchiver decodeObjectForKey:codingKey];
    [unarchiver finishDecoding];
    NSString *verifyKeyString = [[NSString alloc] initWithData:pbkdfEndData.derivedKey encoding:NSUTF8StringEncoding];
    NSString *verifySaltString = [[NSString alloc] initWithData:pbkdfEndData.salt encoding:NSUTF8StringEncoding];
    XCTAssertTrue([verifyKeyString isEqualToString:keyString], @"Serialized/deserialized keys are not the same.");
    XCTAssertTrue([verifySaltString isEqualToString:saltString], @"Serialized/deserialized salts are not the same.");
    XCTAssertEqual(pbkdfEndData.numDerivationRounds, derivationRounds, @"Serialized/deserialized number of derivation rounds are not the same.");
    XCTAssertEqual(pbkdfEndData.derivedKeyLength, derivedKeyLength, @"Serialized/deserialized derived key length values are not the same.");
}

- (void)testDefaultPasscodeProviderIsSHA256
{
    id<SFPasscodeProvider> defaultProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    NSString *defaultProviderName = [SFPasscodeProviderManager currentPasscodeProviderName];
    XCTAssertTrue([defaultProvider isKindOfClass:[SFSHA256PasscodeProvider class]], @"Default passcode provider should be SHA-256.");
    XCTAssertTrue([defaultProviderName isEqualToString:kSFPasscodeProviderSHA256], @"Default passcode provider name should be %@.", kSFPasscodeProviderSHA256);
}

- (void)testChangeCurrentPasscodeProvider
{
    [SFPasscodeProviderManager setCurrentPasscodeProviderByName:kSFPasscodeProviderPBKDF2];
    id<SFPasscodeProvider> updatedProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    NSString *updatedProviderName = [SFPasscodeProviderManager currentPasscodeProviderName];
    XCTAssertTrue([updatedProvider isKindOfClass:[SFPBKDF2PasscodeProvider class]], @"Current passcode provider should be an instance of the PBKDF2 provider.");
    XCTAssertTrue([updatedProviderName isEqualToString:kSFPasscodeProviderPBKDF2], @"Current provider name should be %@.", kSFPasscodeProviderPBKDF2);
}

- (void)testNonexistentPasscodeProvider
{
    NSString *nonexistentProviderName = @"dfkgfgjflsjgljfg___IDoNotExist";
    id<SFPasscodeProvider> nonexisentProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:nonexistentProviderName];
    XCTAssertNil(nonexisentProvider, @"passcodeProviderForProviderName should return nil for non-existent provider.");
}

- (void)testAddRemovePasscodeProvider
{
    NSString *mockProviderName = @"MyMockPasscodeProvider";
    id<SFPasscodeProvider> nonConfiguredProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:mockProviderName];
    XCTAssertNil(nonConfiguredProvider, @"Passcode provider '%@' should not be configured.", mockProviderName);
    
    MockPasscodeProvider *mpp = [[MockPasscodeProvider alloc] initWithProviderName:mockProviderName];
    [SFPasscodeProviderManager addPasscodeProvider:mpp];
    id<SFPasscodeProvider> configuredProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:mockProviderName];
    XCTAssertNotNil(configuredProvider, @"Passcode provider '%@' should be configured.", mockProviderName);
    
    [SFPasscodeProviderManager removePasscodeProviderWithName:mockProviderName];
    nonConfiguredProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:mockProviderName];
    XCTAssertNil(nonConfiguredProvider, @"Passcode provider '%@' should no longer be configured.", mockProviderName);
}

- (void)testPasscodeSetReset
{
    NSString *passcodeToSet = @"MyNewPasscode";
    for (NSString *passcodeProviderName in [NSArray arrayWithObjects:kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2, nil]) {
        XCTAssertFalse([[SFPasscodeManager sharedManager] passcodeIsSet], @"For '%@': No passcode should be set at this point.", passcodeProviderName);
        
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToSet];
        XCTAssertTrue([[SFPasscodeManager sharedManager] passcodeIsSet], @"For '%@': Passcode should now be set.", passcodeProviderName);
        XCTAssertNotNil([SFPasscodeManager sharedManager].encryptionKey, @"For '%@': Encryption key should have been set as part of setPasscode.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] resetPasscode];
        XCTAssertFalse([[SFPasscodeManager sharedManager] passcodeIsSet], @"For '%@': Passcode should no longer be set.", passcodeProviderName);
        XCTAssertNil([SFPasscodeManager sharedManager].encryptionKey, @"For '%@': Encryption key should no longer bet set.", passcodeProviderName);
    }
}

- (void)testEncryptionKeyRepeatabilityForSetPasscode
{
    NSString *passcodeToSet = @"WOoHooPasscode!";
    NSString *passcodeToVerify = @"WOoHooPasscode!";
    for (NSString *passcodeProviderName in [NSArray arrayWithObjects:kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2, nil]) {
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToSet];
        XCTAssertTrue([[SFPasscodeManager sharedManager] passcodeIsSet], @"For '%@': Passcode should now be set.", passcodeProviderName);
        NSString *initialEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertNotNil(initialEncryptionKey, @"For '%@': Encryption key should have been set as part of setPasscode.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToVerify];
        NSString *encryptionKeyToVerify = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertTrue([initialEncryptionKey isEqualToString:encryptionKeyToVerify], @"For '%@': Encryption keys are not the same for same passcode.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] resetPasscode];
    }
}

- (void)testEncryptionKeyDifferenceForSetPasscode
{
    NSString *passcodeToSet = @"WOoHooPasscode!";
    NSString *passcodeToVerify = @"SchmooSchmooPasscode!";
    for (NSString *passcodeProviderName in [NSArray arrayWithObjects:kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2, nil]) {
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToSet];
        XCTAssertTrue([[SFPasscodeManager sharedManager] passcodeIsSet], @"For '%@': Passcode should now be set.", passcodeProviderName);
        NSString *initialEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertNotNil(initialEncryptionKey, @"For '%@': Encryption key should have been set as part of setPasscode.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToVerify];
        NSString *encryptionKeyToVerify = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertFalse([initialEncryptionKey isEqualToString:encryptionKeyToVerify], @"For '%@': Encryption keys should not be the same for different passcodes.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] resetPasscode];
    }
}

- (void)testEncryptionKeyRepeatabilityForSetEncryptionKeyForPasscode
{
    NSString *passcodeToSet = @"WOoHooPasscode!";
    NSString *passcodeToVerify = @"WOoHooPasscode!";
    for (NSString *passcodeProviderName in [NSArray arrayWithObjects:kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2, nil]) {
        // Set the verification passcode first.
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToSet];  // Encryption key is set now too.
        NSString *initialEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertNotNil(initialEncryptionKey, @"For '%@': Encryption key should have been set as part of setting the passcode.", passcodeProviderName);
        
        // Clear the encryption passcode (it's only in memory), to simulate re-staging on the
        // app restart boundary.
        [[SFPasscodeManager sharedManager] setEncryptionKey:nil];
        
        [[SFPasscodeManager sharedManager] setEncryptionKeyForPasscode:passcodeToVerify];
        NSString *encryptionKeyToVerify = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertTrue([initialEncryptionKey isEqualToString:encryptionKeyToVerify], @"For '%@': Encryption keys are not the same for same passcode.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] resetPasscode];
    }
}

- (void)testEncryptionKeyDifferenceForSetEncryptionKeyForPasscode
{
    NSString *passcodeToSet = @"WOoHooPasscode!";
    NSString *passcodeToVerify = @"SchmooSchmooPasscode!";
    for (NSString *passcodeProviderName in [NSArray arrayWithObjects:kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2, nil]) {
        // Set the verification passcode first.
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        [[SFPasscodeManager sharedManager] setPasscode:passcodeToSet];  // Encryption key is set now too.
        NSString *initialEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertNotNil(initialEncryptionKey, @"For '%@': Encryption key should have been set as part of setting the passcode.", passcodeProviderName);
        
        // Clear the encryption passcode (it's only in memory), to simulate re-staging on the
        // app restart boundary.
        [[SFPasscodeManager sharedManager] setEncryptionKey:nil];
        
        [[SFPasscodeManager sharedManager] setEncryptionKeyForPasscode:passcodeToVerify];
        NSString *encryptionKeyToVerify = [SFPasscodeManager sharedManager].encryptionKey;
        XCTAssertFalse([initialEncryptionKey isEqualToString:encryptionKeyToVerify], @"For '%@': Encryption keys should not be the same for different passcodes.", passcodeProviderName);
        
        [[SFPasscodeManager sharedManager] resetPasscode];
    }
}

@end
