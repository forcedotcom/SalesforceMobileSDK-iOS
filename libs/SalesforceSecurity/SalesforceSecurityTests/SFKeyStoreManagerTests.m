//
//  SFKeyStoreManagerTests.m
//  SalesforceSecurity
//
//  Created by Dustin Breese on 11/11/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <SalesforceCommonUtils/NSData+SFAdditions.h>
#import "SFKeyStoreManager+Internal.h"

@interface SFKeyStoreManagerTests : XCTestCase
{
    SFKeyStoreManager *mgr;
}
@end

@implementation SFKeyStoreManagerTests

- (void)setUp {
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
    
    // initialize passcode mgr
    [[SFPasscodeManager sharedManager] changePasscode: nil];
    
    mgr = [SFKeyStoreManager sharedInstance];
}

- (void)tearDown {
    
    [super tearDown];
}


// ensure we get the same reference back for the shared instance
- (void)testSingleton {
    SFKeyStoreManager *mgr1 = [SFKeyStoreManager sharedInstance];
    SFKeyStoreManager *mgr2 = [SFKeyStoreManager sharedInstance];
    XCTAssertTrue(mgr1 == mgr2, @"References should be the same.");
}

// ensure storing a key, we can check to see if the key exists
- (void)testStoreKeyGetsBackOriginal {
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    [mgr storeKey:key withKeyType:SFKeyStoreKeyTypeGenerated label:@"key"];
    
    XCTAssertTrue([mgr keyWithLabelAndKeyTypeExists:@"key" keyType:SFKeyStoreKeyTypeGenerated], @"Key type should exist.");
}

// ensure removnig a key works
- (void)testRemoveKey {
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    [mgr storeKey:key withKeyType:SFKeyStoreKeyTypeGenerated label:@"key"];
    [mgr removeKeyWithLabel:@"key" keyType:SFKeyStoreKeyTypeGenerated];
    
    XCTAssertFalse([mgr keyWithLabelAndKeyTypeExists:@"key" keyType:SFKeyStoreKeyTypeGenerated], @"Key type should no longer exist.");
}

// ensure we handle nil values
- (void)testRetrieveKeyWithNilValues {
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel: nil autoCreate: false];
    XCTAssertNil(key, @"Key should be nil with a nil label");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForGeneratedStore {
    [mgr removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: false];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForPasscodeStore {
    [mgr removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: false];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, create one if it does not exist for generated key store
- (void)testRetrieveKeyCreateNewForGenerated {
    [mgr removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: true];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated  autoCreate: false];
    XCTAssertEqualObjects(key.keyAsString, existingKey.keyAsString, @"Keys should be the same");
}

// retrieve key with label, create one if it does not exist for passcode key store
- (void)testRetrieveKeyCreateNewForPasscode {
    // first, we set up the passcode store
    [[SFPasscodeManager sharedManager] resetPasscode];
    [mgr removeKeyWithLabel:@"myLabel"  keyType:SFKeyStoreKeyTypePasscode];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: true];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode  autoCreate: false];
    XCTAssertEqualObjects(key.keyAsString, existingKey.keyAsString, @"Keys should be the same");
}

// when nil values for old and new are observed, keystore info should be cleared.
- (void)testObserveKeyChangesOldAndNewKeyNil {
    SFPasscodeKeyStore *store = [mgr passcodeKeyStore];

    // make sure the keystore key is set so we can verify it is nil'ed
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    SFKeyStoreKey *ksKey = [[SFKeyStoreKey alloc] initWithKey:key type:SFKeyStoreKeyTypePasscode];
    [store setKeyStoreKey:ksKey];
    [store setKeyStoreDictionary: [NSDictionary dictionaryWithObject:@"someobj" forKey:@"somekey"]];
    XCTAssertNotNil([[mgr passcodeKeyStore] keyStoreKey], @"Key store key should be available");
    XCTAssertEqual(1, [[[mgr passcodeKeyStore] keyStoreDictionary] count], @"Key store dictionary should be available");

    // when we invoke, key store key and dictionary should be nil'ed
    NSDictionary *change = [NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], NSKeyValueChangeOldKey, [NSNull null], NSKeyValueChangeNewKey, nil];
    [mgr observeValueForKeyPath:@"encryptionKey" ofObject:[SFPasscodeManager sharedManager] change:change context:nil];
    XCTAssertNil(mgr.passcodeKeyStore.keyStoreKey, @"Key store key should have been reset");
    XCTAssertEqual(0, [[[mgr passcodeKeyStore] keyStoreDictionary] count], @"Key store dictionary should be empty");
}
@end
