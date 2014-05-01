//
//  SFKeyStoreTests.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 5/1/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFEncryptionKey.h"
#import "SFKeyStoreManager+Internal.h"

@interface SFKeyStoreTests : XCTestCase

@end

@implementation SFKeyStoreTests

- (void)setUp
{
    [super setUp];
    
    // No key store keys, to start.
    [SFKeyStoreManager sharedInstance].keyStoreDictionary = nil;
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
    SFEncryptionKey *keyToStore = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
    [[SFKeyStoreManager sharedInstance] storeKey:keyToStore withLabel:keyLabel];
    BOOL keyExists = [[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyLabel];
    XCTAssertTrue(keyExists, @"Stored key should be present in the key store.");
    SFEncryptionKey *retrievedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel];
    XCTAssertTrue([keyToStore.key isEqualToData:retrievedKey.key], @"Stored key is not the same as retrieved key.");
    XCTAssertTrue([keyToStore.initializationVector isEqualToData:retrievedKey.initializationVector], @"Stored iv is not the same as retrieved iv.");
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:keyLabel];
    keyExists = [[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyLabel];
    XCTAssertFalse(keyExists, @"Removed key should not be present in the key store.");
    nonExistentKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel];
    XCTAssertNil(nonExistentKey, @"Key with label '%@' should not exist after removal.", keyLabel);
}

- (void)testKeyEquality
{
    SFEncryptionKey *key1 = [[SFEncryptionKey alloc] initWithData:[@"keyData" dataUsingEncoding:NSUTF8StringEncoding]
                                             initializationVector:[@"ivData" dataUsingEncoding:NSUTF8StringEncoding]];
    SFEncryptionKey *key2 = [[SFEncryptionKey alloc] initWithData:[@"keyData" dataUsingEncoding:NSUTF8StringEncoding]
                                             initializationVector:[@"ivData" dataUsingEncoding:NSUTF8StringEncoding]];
    SFEncryptionKey *key3 = [[SFEncryptionKey alloc] initWithData:[@"otherKeyData" dataUsingEncoding:NSUTF8StringEncoding]
                                             initializationVector:[@"otherIvData" dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(key1, key2, @"Objects should be equal, with identical keys and iv's.");
    XCTAssertNotEqualObjects(key1, key3, @"Object with different keys and iv's should not be equal.");
}

- (void)testKeyStringRepresentations
{
    SFEncryptionKey *key1 = [[SFEncryptionKey alloc] initWithData:[@"keyData" dataUsingEncoding:NSUTF8StringEncoding]
                                             initializationVector:[@"ivData" dataUsingEncoding:NSUTF8StringEncoding]];
    SFEncryptionKey *key2 = [[SFEncryptionKey alloc] initWithData:[@"keyData" dataUsingEncoding:NSUTF8StringEncoding]
                                             initializationVector:[@"ivData" dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(key1.keyAsString, key2.keyAsString, @"Key string representation should be the same.");
    XCTAssertEqualObjects(key1.initializationVectorAsString, key2.initializationVectorAsString, @"IV string representation should be the same.");
}

- (void)testBadDictionaryDecrypt
{
    // Key store needs some value, before decrypting.
    SFEncryptionKey *someKey = [[SFEncryptionKey alloc] initWithData:[@"myKey" dataUsingEncoding:NSUTF8StringEncoding]
                                                initializationVector:[@"myIv" dataUsingEncoding:NSUTF8StringEncoding]];
    [[SFKeyStoreManager sharedInstance] storeKey:someKey withLabel:@"someKey"];
    
    // Try to decrypt non-empty key store with a bad key.
    SFEncryptionKey *badKey = [[SFEncryptionKey alloc] initWithData:[@"badKey" dataUsingEncoding:NSUTF8StringEncoding] initializationVector:[@"badIv" dataUsingEncoding:NSUTF8StringEncoding]];
    NSDictionary *badDict = [[SFKeyStoreManager sharedInstance] keyStoreDictionaryWithKey:badKey];
    XCTAssertNil(badDict, @"If dictionary can't be decrypted, it should be nil.");
}

@end
