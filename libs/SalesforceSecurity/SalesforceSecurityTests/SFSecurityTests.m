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

static NSUInteger const kNumThreadsInSafetyTest = 100;

@interface SFSecurityTests : XCTestCase
{
    SFKeyStoreManager *mgr;
    BOOL _threadSafetyTestCompleted;
    NSMutableArray *_completedThreads;
}
- (void)keyStoreThreadSafeHelper;
@end

// high level test scenarios (ie, more than a unit test)
@implementation SFSecurityTests

- (void)setUp {
    [super setUp];
    
    [SFLogger setLogLevel:SFLogLevelDebug];
    
    // No passcode, to start.
    [[SFPasscodeManager sharedManager] changePasscode:nil];
    mgr = [SFKeyStoreManager sharedInstance];
}

- (void)tearDown {
    [super tearDown];
}

// Kick off a bunch of threads and, while threads are still doing things, randomly change passcodes.
- (void)testKeyStoreThreadSafety
{
    // set up passcode mgr
    [[SFPasscodeManager sharedManager] changePasscode:@"12345"];

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


#pragma mark - Passcode change tests
- (void)testNoPasscodeToPasscode
{
    // set up the generated keystore
    SFKeyStoreKey *origKeyStoreKey = [mgr createDefaultKey];
    XCTAssertEqual(origKeyStoreKey.keyType, SFKeyStoreKeyTypeGenerated, @"Key store key should be the default generated key.");
    SFEncryptionKey *origEncKey = [mgr keyWithRandomValue];
    [mgr storeKey:origEncKey withKeyType:SFKeyStoreKeyTypeGenerated label:@"origKey"];

    // add a passcode key to the dictionary so that it is migrated over
    SFEncryptionKey *passcodeEncKey = [mgr keyWithRandomValue];
    [mgr storeKey:passcodeEncKey withKeyType:SFKeyStoreKeyTypePasscode label:@"aPasscodeKey"];
    
    // now set a passcode
    NSString *newPasscode = @"IAddedAPasscode!";
    [[SFPasscodeManager sharedManager] changePasscode:newPasscode];
    
    // data should have been migrated to passcode keystore
    SFPasscodeKeyStore *passcodeKeyStore = [mgr passcodeKeyStore];
    NSDictionary *passcodeDictionary = [passcodeKeyStore keyStoreDictionary];
    NSString *label = [passcodeKeyStore keyLabelForString:@"aPasscodeKey"];
    SFKeyStoreKey *key = [passcodeDictionary valueForKey:label];

    XCTAssertEqual(key.keyType, SFKeyStoreKeyTypePasscode, @"Key was not migrated correctly");
}

/*
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
    
    // generate a new key
    NSString *keyName = [NSString stringWithFormat:@"%@%ld", @"threadSafeKeyName", (unsigned long)keyId++];
    SFEncryptionKey *origKey = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
    
    // store it
    [[SFKeyStoreManager sharedInstance] storeKey:origKey withKeyType:SFKeyStoreKeyTypePasscode label:keyName];
    XCTAssertTrue([[SFKeyStoreManager sharedInstance] keyWithLabelAndKeyTypeExists:keyName keyType:SFKeyStoreKeyTypePasscode], @"Key '%@' should exist in the key store.", keyName);
    
    // get it back
    SFEncryptionKey *retrievedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyName keyType:SFKeyStoreKeyTypePasscode autoCreate:NO];
    XCTAssertEqualObjects(origKey, retrievedKey, @"Keys with label '%@' are not equal", keyName);
    
    // remove it
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:keyName keyType:SFKeyStoreKeyTypePasscode];
    XCTAssertFalse([[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyName], @"Key '%@' should no longer exist in key store after removal.", keyName);
    
    // update state so main loop will know when all threads are done
    @synchronized (self) {
        [_completedThreads addObject:keyName];
        if ([_completedThreads count] == kNumThreadsInSafetyTest) {
            _threadSafetyTestCompleted = YES;
        }
    }
}

@end
