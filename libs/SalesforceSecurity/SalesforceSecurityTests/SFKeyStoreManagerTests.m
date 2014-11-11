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

@end

@implementation SFKeyStoreManagerTests

- (void)setUp {
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
    
    // initialize passcode mgr
    [[SFPasscodeManager sharedManager] changePasscode: nil];
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

// ensure we handle nil values
- (void)testRetrieveKeyWithNilValues {
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel: nil autoCreate: false];
    XCTAssertNil(key, @"Key should be nil with a nil label");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForGeneratedStore {
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated];
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: false];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForPasscodeStore {
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode];
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: false];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, create one if it does not exist for generated key store
- (void)testRetrieveKeyCreateNewForGenerated {
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated];
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: true];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated  autoCreate: false];
    NSLog(@"KEY: %@", key.keyAsString);
    NSLog(@"KE2: %@", existingKey.keyAsString);
    XCTAssertEqualObjects(key.keyAsString, existingKey.keyAsString, @"Keys should be the same");
}

// retrieve key with label, create one if it does not exist for passcode key store
- (void)testRetrieveKeyCreateNewForPasscode {
    // first, we set up the passcode store
    [[SFPasscodeManager sharedManager] resetPasscode];
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:@"myLabel"  keyType:SFKeyStoreKeyTypePasscode];
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: true];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode  autoCreate: false];
    NSLog(@"KEY: %@", key.keyAsString);
    NSLog(@"KE2: %@", existingKey.keyAsString);
    XCTAssertEqualObjects(key.keyAsString, existingKey.keyAsString, @"Keys should be the same");
}

/*
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
*/
@end
