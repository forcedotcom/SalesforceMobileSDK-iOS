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
#import "SFSDKCryptoUtils.h"
#import <SalesforceCommonUtils/NSData+SFAdditions.h>

static NSUInteger const kNumThreadsInSafetyTest = 100;

@interface SFKeyStoreTests : XCTestCase
{
    BOOL _threadSafetyTestCompleted;
    NSMutableArray *_completedThreads;
}

- (void)keyStoreThreadSafeHelper;

@end

@implementation SFKeyStoreTests

- (void)setUp
{
    [super setUp];
    
    [SFLogger setLogLevel:SFLogLevelDebug];
    
    // No passcode, to start.
    [[SFPasscodeManager sharedManager] changePasscode:nil];
    
    // No key store keys, to start.
    [SFKeyStoreManager sharedInstance].keyStoreKey = [[SFKeyStoreManager sharedInstance] createDefaultKey];
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
    SFEncryptionKey *nonExistentKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel autoCreate:NO];
    XCTAssertNil(nonExistentKey, @"Key with label '%@' should not exist.", keyLabel);
    SFEncryptionKey *keyToStore = [[SFKeyStoreManager sharedInstance] keyWithRandomValue];
    [[SFKeyStoreManager sharedInstance] storeKey:keyToStore withLabel:keyLabel];
    BOOL keyExists = [[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyLabel];
    XCTAssertTrue(keyExists, @"Stored key should be present in the key store.");
    SFEncryptionKey *retrievedKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel autoCreate:NO];
    XCTAssertTrue([keyToStore.key isEqualToData:retrievedKey.key], @"Stored key is not the same as retrieved key.");
    XCTAssertTrue([keyToStore.initializationVector isEqualToData:retrievedKey.initializationVector], @"Stored iv is not the same as retrieved iv.");
    [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:keyLabel];
    keyExists = [[SFKeyStoreManager sharedInstance] keyWithLabelExists:keyLabel];
    XCTAssertFalse(keyExists, @"Removed key should not be present in the key store.");
    nonExistentKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:keyLabel autoCreate:NO];
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

- (void)testKeyStoreThreadSafety
{
    _threadSafetyTestCompleted = NO;
    _completedThreads = [NSMutableArray array];
    for (NSInteger i = 0; i < kNumThreadsInSafetyTest; i++) {
        [self performSelectorInBackground:@selector(keyStoreThreadSafeHelper) withObject:nil];
    }
    
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
}

#pragma mark - Passcode change tests

- (void)testNoPasscodeToPasscode
{
    SFKeyStoreKey *origKeyStoreKey = [SFKeyStoreManager sharedInstance].keyStoreKey;
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
    
    @synchronized (self) {
        [_completedThreads addObject:keyName];
        if ([_completedThreads count] == kNumThreadsInSafetyTest) {
            _threadSafetyTestCompleted = YES;
        }
    }
}

@end
