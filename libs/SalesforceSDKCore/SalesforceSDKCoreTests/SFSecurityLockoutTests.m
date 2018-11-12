/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSecurityLockoutTests.h"
#import "SFSecurityLockout+Internal.h"
#import "SFPreferences.h"
#import "SFPasscodeManager.h"

@interface SFSecurityLockoutTests ()

+ (void)cleanupSettings;
- (void)verifyFileSettingsValues:(NSNumber *)legacyTimeoutNum
                 legacyLockedVal:(BOOL)legacyLockedVal
             biometricAllowedVal:(BOOL)biometricAllowedVal;
- (void)verifyKeychainSettingsValues:(NSUInteger)keychainTimeoutVal
                   keychainLockedVal:(BOOL)keychainLockedVal
           keychainPasscodeLengthVal:(NSUInteger*)keychainPasscodeLengthVal;
@end

@implementation SFSecurityLockoutTests

#pragma mark - Tests

+ (void)setUp
{
    [super setUp];
    [SFSecurityLockoutTests cleanupSettings];
}

-(void)tearDown
{
    [SFSecurityLockoutTests cleanupSettings];
    [super tearDown];
}

- (void)testReadWriteLockoutTime
{
    NSNumber *retrievedLockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
    XCTAssertNil(retrievedLockoutTime, @"Retrieved lockout time should not be set at the beginning of the test.");
    NSUInteger randInt = arc4random();
    [SFSecurityLockout writeLockoutTimeToKeychain:@(randInt)];
    retrievedLockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
    XCTAssertEqual(randInt, [retrievedLockoutTime unsignedIntegerValue], @"Lockout time values are not the same.");
}

- (void)testReadWriteIsLocked
{
    NSNumber *retrievedIsLocked = [SFSecurityLockout readIsLockedFromKeychain];
    XCTAssertNil(retrievedIsLocked, @"'Is Locked' should not be set at the beginning of the test.");
    NSUInteger randInt = arc4random();
    BOOL inIsLocked = (randInt % 2 == 0);
    [SFSecurityLockout writeIsLockedToKeychain:@(inIsLocked)];
    retrievedIsLocked = [SFSecurityLockout readIsLockedFromKeychain];
    XCTAssertNotNil(retrievedIsLocked, @"'Is Locked' value should not be nil in the keychain.");
    XCTAssertEqual(inIsLocked, [retrievedIsLocked boolValue], @"'Is Locked' values are not the same.");
}

- (void)testReadWritePasscodeLength
{
    NSNumber *retrivedPasscodeLength = [SFSecurityLockout readPasscodeLengthFromKeychain];
    XCTAssertNil(retrivedPasscodeLength, @"Retrived passcode length should not be set at the beginning of the test.");
    NSUInteger randInt = arc4random();
    [SFSecurityLockout writePasscodeLengthToKeychain:@(randInt)];
    retrivedPasscodeLength = [SFSecurityLockout readPasscodeLengthFromKeychain];
    XCTAssertEqual(randInt, [retrivedPasscodeLength unsignedIntegerValue], @"Passcode length values are not the same.");
}

- (void)testSettingsUpgrade
{
    [SFSecurityLockout class];  // Make sure initialize call for SFSecurityLockout is out of the way.
    
    // No initial values: Defaults migrated to keychain.
    [SFSecurityLockoutTests cleanupSettings];
    [SFSecurityLockout upgradeSettings];
    [self verifyFileSettingsValues:nil legacyLockedVal:NO biometricAllowedVal:YES];
    [self verifyKeychainSettingsValues:kDefaultLockoutTime keychainLockedVal:NO keychainPasscodeLengthVal:nil];
    
    // Initial legacy values, no keychain values: Legacy values migrated to keychain.
    [SFSecurityLockoutTests cleanupSettings];
    NSUInteger timeoutVal = arc4random();
    NSNumber *legacyTimeoutNum = @(timeoutVal);
    BOOL legacyLockedVal = (arc4random() % 2 == 0);
    BOOL biometricAllowedVal = (arc4random() % 2 == 0);
    [[NSUserDefaults standardUserDefaults] setObject:legacyTimeoutNum forKey:kSecurityTimeoutLegacyKey];
    [[NSUserDefaults standardUserDefaults] setBool:legacyLockedVal forKey:kSecurityIsLockedLegacyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[SFPreferences globalPreferences] setBool:biometricAllowedVal forKey:kBiometricUnlockAllowedKey];
    [[SFPreferences globalPreferences] synchronize];
    [SFSecurityLockout upgradeSettings];
    [self verifyFileSettingsValues:legacyTimeoutNum legacyLockedVal:legacyLockedVal biometricAllowedVal:biometricAllowedVal];
    [self verifyKeychainSettingsValues:[legacyTimeoutNum unsignedIntegerValue] keychainLockedVal:legacyLockedVal keychainPasscodeLengthVal:nil];
    
    // Keychain values already defined: No further migration of values.
    [SFSecurityLockoutTests cleanupSettings];
    NSNumber *keychainTimeoutNum = @(arc4random());
    NSNumber *keychainLockedNum = [NSNumber numberWithBool:(arc4random() % 2 == 0)];
    NSUInteger passcodeLength = (arc4random() % 8);
    [SFSecurityLockout writeIsLockedToKeychain:keychainLockedNum];
    [SFSecurityLockout writeLockoutTimeToKeychain:keychainTimeoutNum];
    [SFSecurityLockout writePasscodeLengthToKeychain:[NSNumber numberWithUnsignedInteger:passcodeLength]];
    [SFSecurityLockout upgradeSettings];
    [self verifyFileSettingsValues:nil legacyLockedVal:NO biometricAllowedVal:YES];
    [self verifyKeychainSettingsValues:[keychainTimeoutNum unsignedIntegerValue] keychainLockedVal:[keychainLockedNum boolValue] keychainPasscodeLengthVal:&passcodeLength];
}

#pragma mark - Helper methods

+ (void)cleanupSettings
{
    [SFSecurityLockout writeLockoutTimeToKeychain:nil];
    [SFSecurityLockout writeIsLockedToKeychain:nil];
    [SFSecurityLockout writePasscodeLengthToKeychain:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSecurityTimeoutLegacyKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kSecurityIsLockedLegacyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[SFPreferences globalPreferences] removeObjectForKey:kBiometricUnlockAllowedKey];
    [[SFPreferences globalPreferences] synchronize];
}

- (void)verifyFileSettingsValues:(NSNumber *)legacyTimeoutNum
                 legacyLockedVal:(BOOL)legacyLockedVal
             biometricAllowedVal:(BOOL)biometricAllowedVal;
{
    XCTAssertEqualObjects(legacyTimeoutNum, [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutLegacyKey], @"Legacy timeout values do not match.");
    XCTAssertEqual(legacyLockedVal, [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedLegacyKey], @"Legacy locked values do not match.");
    // Read value directly because [SFSecurityLockout biometricUnlockAllowed] takes takes device biometric into affect
    BOOL bioAllowed = [[SFPreferences globalPreferences] boolForKey:kBiometricUnlockAllowedKey];
    XCTAssertEqual(biometricAllowedVal, bioAllowed, @"Stored Biometric unlock allowed values do not match.");
}

- (void)verifyKeychainSettingsValues:(NSUInteger)keychainTimeoutVal
                   keychainLockedVal:(BOOL)keychainLockedVal
           keychainPasscodeLengthVal:(NSUInteger*)keychainPasscodeLengthVal
{
    NSNumber *keychainTimeoutNum = @(keychainTimeoutVal);
    XCTAssertEqualObjects(keychainTimeoutNum, [SFSecurityLockout readLockoutTimeFromKeychain], @"Keychain timeout values do not match.");
    NSNumber *keychainLockedNum = @(keychainLockedVal);
    XCTAssertEqualObjects(keychainLockedNum, [SFSecurityLockout readIsLockedFromKeychain], @"Keychain locked values do not match.");
    NSNumber *keychainPasscodeNum = (keychainPasscodeLengthVal) ? [NSNumber numberWithUnsignedInteger:*keychainPasscodeLengthVal] : nil;
    XCTAssertEqualObjects(keychainPasscodeNum, [SFSecurityLockout readPasscodeLengthFromKeychain], @"Keychain passcode length values do not match.");
}

@end
