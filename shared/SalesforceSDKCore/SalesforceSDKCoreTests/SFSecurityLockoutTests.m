//
//  SFSecurityLockoutTests.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 12/17/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import "SFSecurityLockoutTests.h"
#import "SFSecurityLockout+Internal.h"

@interface SFSecurityLockoutTests ()

- (void)cleanupSettings;
- (void)verifySettingsValues:(NSNumber *)legacyTimeoutNum
             legacyLockedVal:(BOOL)legacyLockedVal
          keychainTimeoutVal:(NSUInteger)keychainTimeoutVal
           keychainLockedVal:(BOOL)keychainLockedVal;

@end

@implementation SFSecurityLockoutTests

#pragma mark - Tests

- (void)setUp
{
    [super setUp];
    [self cleanupSettings];
}

- (void)testReadWriteLockoutTime
{
    NSNumber *retrievedLockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
    STAssertNil(retrievedLockoutTime, @"Retrieved lockout time should not be set at the beginning of the test.");
    NSUInteger randInt = arc4random();
    [SFSecurityLockout writeLockoutTimeToKeychain:@(randInt)];
    retrievedLockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
    STAssertEquals(randInt, [retrievedLockoutTime unsignedIntegerValue], @"Lockout time values are not the same.");
}

- (void)testReadWriteIsLocked
{
    NSNumber *retrievedIsLocked = [SFSecurityLockout readIsLockedFromKeychain];
    STAssertNil(retrievedIsLocked, @"'Is Locked' should not be set at the beginning of the test.");
    NSUInteger randInt = arc4random();
    BOOL inIsLocked = (randInt % 2 == 0);
    [SFSecurityLockout writeIsLockedToKeychain:@(inIsLocked)];
    retrievedIsLocked = [SFSecurityLockout readIsLockedFromKeychain];
    STAssertNotNil(retrievedIsLocked, @"'Is Locked' value should not be nil in the keychain.");
    STAssertEquals(inIsLocked, [retrievedIsLocked boolValue], @"'Is Locked' values are not the same.");
}

- (void)testSettingsUpgrade
{
    [SFSecurityLockout class];  // Make sure initialize call for SFSecurityLockout is out of the way.
    
    // No initial values: Defaults migrated to keychain.
    [self cleanupSettings];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:nil legacyLockedVal:NO keychainTimeoutVal:kDefaultLockoutTime keychainLockedVal:NO];
    
    // Initial legacy values, no keychain values: Legacy values migrated to keychain.
    [self cleanupSettings];
    NSUInteger timeoutVal = arc4random();
    NSNumber *legacyTimeoutNum = @(timeoutVal);
    BOOL legacyLockedVal = (arc4random() % 2 == 0);
    [[NSUserDefaults standardUserDefaults] setObject:legacyTimeoutNum forKey:kSecurityTimeoutLegacyKey];
    [[NSUserDefaults standardUserDefaults] setBool:legacyLockedVal forKey:kSecurityIsLockedLegacyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:legacyTimeoutNum legacyLockedVal:legacyLockedVal keychainTimeoutVal:timeoutVal keychainLockedVal:legacyLockedVal];
    
    // Keychain values already defined: No further migration of values.
    [self cleanupSettings];
    NSNumber *keychainTimeoutNum = @(arc4random());
    NSNumber *keychainLockedNum = [NSNumber numberWithBool:(arc4random() % 2 == 0)];
    [SFSecurityLockout writeIsLockedToKeychain:keychainLockedNum];
    [SFSecurityLockout writeLockoutTimeToKeychain:keychainTimeoutNum];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:nil legacyLockedVal:NO keychainTimeoutVal:[keychainTimeoutNum unsignedIntegerValue] keychainLockedVal:[keychainLockedNum boolValue]];
}

#pragma mark - Helper methods

- (void)cleanupSettings
{
    [SFSecurityLockout writeLockoutTimeToKeychain:nil];
    [SFSecurityLockout writeIsLockedToKeychain:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSecurityTimeoutLegacyKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kSecurityIsLockedLegacyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)verifySettingsValues:(NSNumber *)legacyTimeoutNum
             legacyLockedVal:(BOOL)legacyLockedVal
          keychainTimeoutVal:(NSUInteger)keychainTimeoutVal
           keychainLockedVal:(BOOL)keychainLockedVal
{
    STAssertEqualObjects(legacyTimeoutNum, [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutLegacyKey], @"Legacy timeout values do not match.");
    STAssertEquals(legacyLockedVal, [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedLegacyKey], @"Legacy locked values do not match.");
    NSNumber *keychainTimeoutNum = @(keychainTimeoutVal);
    STAssertEqualObjects(keychainTimeoutNum, [SFSecurityLockout readLockoutTimeFromKeychain], @"Keychain timeout values do not match.");
    NSNumber *keychainLockedNum = @(keychainLockedVal);
    STAssertEqualObjects(keychainLockedNum, [SFSecurityLockout readIsLockedFromKeychain], @"Keychain locked values do not match.");
}

@end
