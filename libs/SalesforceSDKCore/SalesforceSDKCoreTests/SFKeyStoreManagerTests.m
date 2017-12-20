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
    [mgr storeKey:key withLabel:@"key"];
    
    XCTAssertTrue([mgr keyWithLabelExists:@"key"], @"Key type should exist.");
}

// ensure removing a key works
- (void)testRemoveKey {
    SFEncryptionKey *key =  [mgr keyWithRandomValue];
    [mgr storeKey:key withLabel:@"key"];
    [mgr removeKeyWithLabel:@"key"];
    
    XCTAssertFalse([mgr keyWithLabelExists:@"key"], @"Key type should no longer exist.");
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

// ensure we handle nil values
- (void)testRetrieveKeyWithNilValues {
    SFEncryptionKey *key =[[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel: nil autoCreate: NO];
    XCTAssertNil(key, @"Key should be nil with a nil label");
}

#pragma clang diagnostic pop

// retrieve key with label, do not create one by default.
- (void)testRetrieveKeyButDontCreate {
    [mgr removeKeyWithLabel:@"myLabel"];
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" autoCreate: NO];
    XCTAssertNil(key, @"Should not have created key");
}

// retrieve key with label, create one if it does not exist
- (void)testRetrieveKeyCreateNew {
    SFEncryptionKey *key =[mgr retrieveKeyWithLabel:@"myLabel" autoCreate: YES];
    XCTAssertNotNil(key, @"Should have created key");
    
    // get it again to ensure it exists for real
    SFEncryptionKey *existingKey =[mgr retrieveKeyWithLabel:@"myLabel" autoCreate: NO];
    XCTAssertEqualObjects(key, existingKey, @"Keys should be the same");
}

@end
