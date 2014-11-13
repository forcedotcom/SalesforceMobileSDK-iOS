//
//  SFSecurityTests.m
//  SalesforceSecurity
//
//  Created by Dustin Breese on 11/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "SFKeyStoreKey.h"
#import "SFKeyStoreManager+Internal.h"
#import "SFSDKCryptoUtils.h"
#import "SFPasscodeProviderManager.h"
#import "SFEncryptionKey.h"
#import "SFKeyStore+Internal.h"
#import <SalesforceCommonUtils/NSData+SFAdditions.h>

static NSUInteger const kNumThreadsInSafetyTest = 50;

@interface SFSecurityTests : XCTestCase
{
    BOOL _threadSafetyTestCompleted;
    NSMutableArray *_completedThreads;
}
- (void)keyStoreThreadSafeHelper;
@end

// high level test scenarios will go in this class
// WORK IN PROGRESS.... 
@implementation SFSecurityTests

- (void)setUp {
    [super setUp];

    [SFLogger setLogLevel:SFLogLevelDebug];
    
    // No passcode, to start.
    [[SFPasscodeManager sharedManager] changePasscode:nil];
}

- (void)tearDown {
    [super tearDown];
}

//Kick off a bunch of threads and, while threads are still doing things, randomly change passcodes.
/*
 - (void)testKeyStoreThreadSafety
 {
 // start threads
 _threadSafetyTestCompleted = NO;
 _completedThreads = [NSMutableArray array];
 for (NSInteger i = 0; i < kNumThreadsInSafetyTest; i++) {
 [self performSelectorInBackground:@selector(keyStoreThreadSafeHelper) withObject:nil];
 }
 
 // randomly change passcodes
 
 while (!_threadSafetyTestCompleted) {
 // Passcode change chaos.
 NSUInteger randomInt = arc4random() % 10;
 if (randomInt > 4) {
 [self log:SFLogLevelDebug msg:@"Passcode change chaos: changing passcode."];
 NSString *newPasscode = [[SFSDKCryptoUtils randomByteDataWithLength:32] base64Encode];
 [[SFPasscodeManager sharedManager] changePasscode:newPasscode];
 }
 [self log:SFLogLevelDebug msg:@"## Thread safety test sleeping..."];
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
 }
 NSLog(@"Test completed");
 }
 */

#pragma mark - Passcode change tests
/*
 - (void)testNoPasscodeToPasscode
 {
 SFKeyStoreKey *origKeyStoreKey = [[SFKeyStoreManager sharedInstance]
 XCTAssertEqual(origKeyStoreKey.keyType, SFKeyStoreKeyTypeGenerated, @"Key store key should be the default generated key.");
 SFEncryptionKey *origKey = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
 NSString *origKeyLabel = @"origKey";
 [[SFKeyStoreManager sharedInstance] storeKey:origKey withLabel:origKeyLabel];
 
 NSString *newPasscode = @"IAddedAPasscode!";
 [[SFPasscodeManager sharedManager] changePasscode:newPasscode];
 
 SFKeyStoreKey *updatedKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
 XCTAssertEqual(updatedKeyStoreKey.keyType, SFKeyStoreKeyTypePasscode, @"Key store key should be passcode-based.");
 XCTAssertNotEqualObjects(origKeyStoreKey.encryptionKey, updatedKeyStoreKey.encryptionKey, @"Key store key should have changed with passcode change.");
 SFEncryptionKey *updatedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:origKeyLabel autoCreate:NO];
 XCTAssertEqualObjects(origKey, updatedKey, @"Keys should be equal after passcode change.");
 }
 
 - (void)testPasscodeToNoPasscode
 {
 NSString *origPasscode = @"My orig passcode";
 [[SFPasscodeManager sharedManager] changePasscode:origPasscode];
 SFKeyStoreKey *origPasscodeKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
 XCTAssertEqual(origPasscodeKeyStoreKey.keyType, SFKeyStoreKeyTypePasscode, @"Key store key should be a passcode-based key.");
 
 SFEncryptionKey *origKey = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
 NSString *origKeyLabel = @"origKey";
 [[SFKeyStoreManager sharedInstance] storeKey:origKey withLabel:origKeyLabel];
 
 [[SFPasscodeManager sharedManager] changePasscode:nil];
 
 SFKeyStoreKey *updatedKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
 XCTAssertEqual(updatedKeyStoreKey.keyType, SFKeyStoreKeyTypeGenerated, @"Updated key store key should be generated.");
 XCTAssertNotEqualObjects(updatedKeyStoreKey.encryptionKey, origPasscodeKeyStoreKey.encryptionKey, @"Encryption keys should not be equal after passcode change.");
 SFEncryptionKey *updatedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:origKeyLabel autoCreate:NO];
 XCTAssertEqualObjects(origKey, updatedKey, @"Keys should be equal after passcode change.");
 }
 */

/*
 - (void)testPasscodeToPasscode
 {
 NSString *origPasscode = @"My orig passcode";
 [[SFPasscodeManager sharedManager] changePasscode:origPasscode];
 SFKeyStoreKey *origPasscodeKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
 XCTAssertEqual(origPasscodeKeyStoreKey.keyType, SFKeyStoreKeyTypePasscode, @"Key store key should be a passcode-based key.");
 
 SFEncryptionKey *origKey = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
 NSString *origKeyLabel = @"origKey";
 [[SFKeyStoreManager sharedInstance] storeKey:origKey withLabel:origKeyLabel];
 
 NSString *updatedPasscode = @"Here's a new passcode, whee!";
 [[SFPasscodeManager sharedManager] changePasscode:updatedPasscode];
 
 SFKeyStoreKey *updatedKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
 XCTAssertEqual(updatedKeyStoreKey.keyType, SFKeyStoreKeyTypePasscode, @"Updated key store key should still be a passcode-based key.");
 XCTAssertNotEqualObjects(updatedKeyStoreKey.encryptionKey, origPasscodeKeyStoreKey.encryptionKey, @"Encryption keys should not be equal after passcode change.");
 SFEncryptionKey *updatedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:origKeyLabel autoCreate:NO];
 XCTAssertEqualObjects(origKey, updatedKey, @"Keys should be equal after passcode change.");
 }
 */

#pragma mark - Private methods
- (void)keyStoreThreadSafeHelper
{
    static NSUInteger keyId = 1;
    
    NSString *keyName = [NSString stringWithFormat:@"%@%ld", @"threadSafeKeyName", (unsigned long)keyId++];
    SFEncryptionKey *origKey = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
    [[SFKeyStoreManager sharedInstance] storeKey:origKey withLabel:keyName];
    XCTAssertTrue([[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyName], @"Key '%@' should exist in the key store.", keyName);
    SFEncryptionKey *retrievedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyName autoCreate:NO];
    XCTAssertEqualObjects(origKey, retrievedKey, @"Keys with label '%@' are not equal", keyName);
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:keyName];
    XCTAssertFalse([[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyName], @"Key '%@' should no longer exist in key store after removal.", keyName);
    NSLog(@"KEY CREATED %@", keyName);
    
    @synchronized (self) {
        [_completedThreads addObject:keyName];
        if ([_completedThreads count] == kNumThreadsInSafetyTest) {
            _threadSafetyTestCompleted = YES;
        }
    }
}

@end
