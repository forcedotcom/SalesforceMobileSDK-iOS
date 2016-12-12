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
#import "SFKeyStore+Internal.h"
#import "SFKeyStoreManager+Internal.h"

@interface SFKeyStoreTests : XCTestCase
{
    SFKeyStoreManager *mgr;
}
@end

@implementation SFKeyStoreTests


- (void)setUp
{
    [super setUp];
    
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    
    mgr = [SFKeyStoreManager sharedInstance];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// ensure we get an empty/initialized dictionary
-(void)testGetKeyStoreDictionaryDefaultsToEmpty {
    // set up the keystore
    SFEncryptionKey *encKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *key = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypeGenerated];

    SFKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    keyStore.keyStoreKey = key;
    
    NSDictionary *dict = keyStore.keyStoreDictionary;
    XCTAssertNotNil(dict, @"Dictionary should not be null");
    XCTAssertEqual(0, [dict count], @"Dictionary should be empty");
}

// ensures we can set and get the dictionary
-(void)testSetAndGetDictionary {
    SFEncryptionKey *encKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *key = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypeGenerated];
    
    SFKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    keyStore.keyStoreKey = key;
    
    NSDictionary *data = @{@"one":@"", @"two":@""};
    
    // set
    [keyStore setKeyStoreDictionary:data withKey:encKey];
    
    // get
    NSDictionary *retrievedData = [keyStore keyStoreDictionaryWithKey:encKey];
    
    XCTAssertTrue([data isEqualToDictionary:retrievedData], @"Dictionaries should be equal");
}

// try to decrpt with bad enc key
-(void)testAttemptToDecryptWithBadEncKey {
    SFEncryptionKey *encKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *key = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypeGenerated];
    
    SFKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    keyStore.keyStoreKey = key;
    
    NSDictionary *data = @{@"one":@"", @"two":@""};
    
    // set
    [keyStore setKeyStoreDictionary:data withKey:encKey];
    
    // get
    SFEncryptionKey *badEncKey = [mgr keyWithRandomValue];
    NSDictionary *retrievedData = [keyStore keyStoreDictionaryWithKey:badEncKey];
    
    XCTAssertNil(retrievedData, @"Data retrieved with wrong enc key should be nil");
}
@end
