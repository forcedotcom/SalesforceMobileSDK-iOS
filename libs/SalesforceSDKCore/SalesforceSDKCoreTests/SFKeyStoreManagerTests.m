/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFKeyStoreManager+Internal.h"

@interface SFKeyStoreManagerTests : XCTestCase
{
    SFKeyStoreManager *mgr;
}
@end

@implementation SFKeyStoreManagerTests

- (void)setUp {
    [super setUp];
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    
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
    XCTAssertEqual(mgr1, mgr2, @"References should be the same.");
}

// ensure storing a key, we can check to see if the key exists
- (void)testStoreKeyGetsBackOriginal {
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    [mgr storeKey:key withKeyType:SFKeyStoreKeyTypeGenerated label:@"key"];
    
    XCTAssertTrue([mgr keyWithLabelAndKeyTypeExists:@"key" keyType:SFKeyStoreKeyTypeGenerated], @"Key type should exist.");
}

// ensure removing a key works
- (void)testRemoveKey {
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    [mgr storeKey:key withKeyType:SFKeyStoreKeyTypeGenerated label:@"key"];
    [mgr removeKeyWithLabel:@"key" keyType:SFKeyStoreKeyTypeGenerated];
    
    XCTAssertFalse([mgr keyWithLabelAndKeyTypeExists:@"key" keyType:SFKeyStoreKeyTypeGenerated], @"Key type should no longer exist.");
}

// ensure we handle nil values
- (void)testRetrieveKeyWithNilValues {
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel: nil autoCreate: NO];
    XCTAssertNil(key, @"Key should be nil with a nil label");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForGeneratedStore {
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: NO];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreateForPasscodeStore {
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: NO];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, create one if it does not exist for generated key store
- (void)testRetrieveKeyCreateNewForGenerated {
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated autoCreate: YES];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypeGenerated  autoCreate: NO];
    XCTAssertEqualObjects(key, existingKey, @"Keys should be the same");
}

// retrieve key with label, create one if it does not exist for passcode key store
- (void)testRetrieveKeyCreateNewForPasscode {
    // first, we set up the passcode store
    [[SFPasscodeManager sharedManager] resetPasscode];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode autoCreate: YES];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[mgr retrieveKeyWithLabel:@"myLabel" keyType:SFKeyStoreKeyTypePasscode  autoCreate: NO];
    XCTAssertEqualObjects(key, existingKey, @"Keys should be the same");
}

// when nil values for old and new are observed, keystore info should be cleared.
- (void)testObserveKeyChangesOldAndNewKeyNil {
    // make sure the keystore key is set so we can verify it is nil'ed
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    SFKeyStoreKey *ksKey = [[SFKeyStoreKey alloc] initWithKey:key type:SFKeyStoreKeyTypePasscode];
    mgr.passcodeKeyStore.keyStoreKey = ksKey;
    mgr.passcodeKeyStore.keyStoreDictionary = @{@"somkey":@"someobj"};
    XCTAssertNotNil([mgr.passcodeKeyStore keyStoreKey], @"Key store key should be available");
    XCTAssertEqual(1, [mgr.passcodeKeyStore.keyStoreDictionary count], @"Key store dictionary should be available");

    // when we invoke, key store key and dictionary should be nil'ed
    NSDictionary *change = @{NSKeyValueChangeOldKey:[NSNull null], NSKeyValueChangeNewKey:[NSNull null]};
    [mgr observeValueForKeyPath:@"encryptionKey" ofObject:[SFPasscodeManager sharedManager] change:change context:nil];
    XCTAssertNil(mgr.passcodeKeyStore.keyStoreKey, @"Key store key should have been reset");
    XCTAssertEqual(0, [mgr.passcodeKeyStore.keyStoreDictionary count], @"Key store dictionary should be empty");
}

// default key should be a generated type
- (void)testDefaultKeyIsGeneratedType
{
    SFKeyStoreKey *origKeyStoreKey = [mgr createDefaultKey];
    XCTAssertEqual(origKeyStoreKey.keyType, SFKeyStoreKeyTypeGenerated, @"Key store key should be the default generated key.");
}
@end
