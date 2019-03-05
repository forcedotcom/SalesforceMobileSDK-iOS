/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

@interface SFSecureKeyStoreTests : XCTestCase
@end

@implementation SFSecureKeyStoreTests


- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// ensures we can set and get the dictionary
-(void)testSetAndGetDictionary {
    SFSecureKeyStoreKey *key = [SFSecureKeyStoreKey createKey];
    
    SFKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    keyStore.keyStoreKey = key;
    
    NSDictionary *data = @{@"one":@"", @"two":@""};
    
    // set
    [keyStore setKeyStoreDictionary:data withKey:key];
    
    // get
    NSDictionary *retrievedData = [keyStore keyStoreDictionaryWithKey:key];
    
    XCTAssertTrue([data isEqualToDictionary:retrievedData], @"Dictionaries should be equal");
}

// ensures we can read / write / delete key to key chain
-(void)testReadWriteDeleteFromKeyChain
{
    NSString* keyLabel = @"testKey";
    
    // Make sure key doesn't exist initially
    SFSecureKeyStoreKey *key1 = [[SFSecureKeyStoreKey alloc] initWithLabel:keyLabel autoCreate:NO];
    XCTAssertNil(key1, @"Key should not exist");
    
    // Create key
    SFSecureKeyStoreKey *key2 = [[SFSecureKeyStoreKey alloc] initWithLabel:keyLabel autoCreate:YES];
    XCTAssertNotNil(key2, @"Key should have been created");
    XCTAssertTrue([self checkKeyWorks:key2], @"Newly created key should have worked");

//    // Try to retrieve key even though it was never saved
//    SFSecureKeyStoreKey *key3 = [[SFSecureKeyStoreKey alloc] initWithLabel:keyLabel autoCreate:NO];
//    XCTAssertNil(key3, @"Key should not have been found");
    
    // save key
    [key2 toKeyChain:@"blah" archiverKey:@"blah"];
    SFSecureKeyStoreKey *key4 = [[SFSecureKeyStoreKey alloc] initWithLabel:keyLabel autoCreate:NO];
    XCTAssertNotNil(key4, @"Key should have been found");
    XCTAssertTrue([self checkKeyWorks:key4], @"Retrieved key should have worked");

    // Delete key
    [key4 deleteKey];
    SFSecureKeyStoreKey *key5 = [[SFSecureKeyStoreKey alloc] initWithLabel:keyLabel autoCreate:NO];
    XCTAssertNil(key5, @"Key should no longer exist");
}

- (BOOL) checkKeyWorks:(SFSecureKeyStoreKey*)key
{
    NSString* archiveKey = @"archiveKey";
    NSDictionary *dictionary = @{@"one":@"", @"two":@""};

    // Serialize dictionary into data
    NSMutableData *dictionaryData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dictionaryData];
    [archiver encodeObject:dictionary forKey:archiveKey];
    [archiver finishEncoding];
    
    // Encrypt data
    NSData* encryptedData = [key encryptData:dictionaryData];
    
    // Decrypt back data
    NSData* decryptedData = [key decryptData:encryptedData];
    
    // Deserialize decrypted data
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:decryptedData];
    NSDictionary* decryptedDictionary = [unarchiver decodeObjectForKey:archiveKey];
    [unarchiver finishDecoding];
    
    // Compare against original dictionary
    return [decryptedDictionary isEqualToDictionary:dictionary];
}

@end
