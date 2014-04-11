//
//  SFEncryptionTests.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 4/2/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFKeyStoreManager.h"
#import "SFEncryptionKey.h"

@interface SFEncryptionTests : XCTestCase

@end

@implementation SFEncryptionTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testKeyStorageRetrievalRemoval
{
    NSString *keyLabel = @"testKeyLabel";
    SFEncryptionKey *nonExistentKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel];
    XCTAssertNil(nonExistentKey, @"Key with label '%@' should not exist.", keyLabel);
    SFEncryptionKey *keyToStore = [SFEncryptionKey keyWithRandomValue:32];
    [[SFKeyStoreManager sharedInstance] storeKey:keyToStore withLabel:keyLabel];
    SFEncryptionKey *retrievedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel];
    XCTAssertEqualObjects(keyToStore, retrievedKey, @"Stored key is not the same as retrieved key.");
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:keyLabel];
    nonExistentKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel];
    XCTAssertNil(nonExistentKey, @"Key with label '%@' should not exist after removal.", keyLabel);
}

@end
