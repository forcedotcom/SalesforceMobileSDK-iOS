//
//  SFSecurityLockoutTests.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 12/17/13.
//  Copyright (c) 2013-present, salesforce.com. All rights reserved.
//

#import "SFSecurityLockoutTests.h"
#import "SFSecurityLockout+Internal.h"

@interface SFSecurityLockoutTests ()

+ (void)cleanupSettings;
- (void)verifySettingsValues:(NSNumber *)legacyTimeoutNum
             legacyLockedVal:(BOOL)legacyLockedVal
          keychainTimeoutVal:(NSUInteger)keychainTimeoutVal
           keychainLockedVal:(BOOL)keychainLockedVal;

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

- (void)testSettingsUpgrade
{
    [SFSecurityLockout class];  // Make sure initialize call for SFSecurityLockout is out of the way.
    
    // No initial values: Defaults migrated to keychain.
    [SFSecurityLockoutTests cleanupSettings];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:nil legacyLockedVal:NO keychainTimeoutVal:kDefaultLockoutTime keychainLockedVal:NO];
    
    // Initial legacy values, no keychain values: Legacy values migrated to keychain.
    [SFSecurityLockoutTests cleanupSettings];
    NSUInteger timeoutVal = arc4random();
    NSNumber *legacyTimeoutNum = @(timeoutVal);
    BOOL legacyLockedVal = (arc4random() % 2 == 0);
    [[NSUserDefaults standardUserDefaults] setObject:legacyTimeoutNum forKey:kSecurityTimeoutLegacyKey];
    [[NSUserDefaults standardUserDefaults] setBool:legacyLockedVal forKey:kSecurityIsLockedLegacyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:legacyTimeoutNum legacyLockedVal:legacyLockedVal keychainTimeoutVal:timeoutVal keychainLockedVal:legacyLockedVal];
    
    // Keychain values already defined: No further migration of values.
    [SFSecurityLockoutTests cleanupSettings];
    NSNumber *keychainTimeoutNum = @(arc4random());
    NSNumber *keychainLockedNum = [NSNumber numberWithBool:(arc4random() % 2 == 0)];
    [SFSecurityLockout writeIsLockedToKeychain:keychainLockedNum];
    [SFSecurityLockout writeLockoutTimeToKeychain:keychainTimeoutNum];
    [SFSecurityLockout upgradeSettings];
    [self verifySettingsValues:nil legacyLockedVal:NO keychainTimeoutVal:[keychainTimeoutNum unsignedIntegerValue] keychainLockedVal:[keychainLockedNum boolValue]];
}

#pragma mark - Helper methods

+ (void)cleanupSettings
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
    XCTAssertEqualObjects(legacyTimeoutNum, [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutLegacyKey], @"Legacy timeout values do not match.");
    XCTAssertEqual(legacyLockedVal, [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedLegacyKey], @"Legacy locked values do not match.");
    NSNumber *keychainTimeoutNum = @(keychainTimeoutVal);
    XCTAssertEqualObjects(keychainTimeoutNum, [SFSecurityLockout readLockoutTimeFromKeychain], @"Keychain timeout values do not match.");
    NSNumber *keychainLockedNum = @(keychainLockedVal);
    XCTAssertEqualObjects(keychainLockedNum, [SFSecurityLockout readIsLockedFromKeychain], @"Keychain locked values do not match.");
}

@end
