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
#import "SFSecureEncryptionKey.h"

@interface SFSecureEncryptionKeyTests : XCTestCase
@end

@implementation SFSecureEncryptionKeyTests


- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// ensures create / retrieve / delete work
-(void)testCreateRetrieveDelete
{
    NSString* keyLabel = @"testExistsCreateDelete";
    
    // Make sure key doesn't exist initially
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should not have been found");

    // Create key
    SFSecureEncryptionKey *key = [SFSecureEncryptionKey createKey:keyLabel];
    XCTAssertNotNil(key, @"Key should have been created");
    
    // Looking for key
    XCTAssertNotNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should have been found");

    // Delete key
    [SFSecureEncryptionKey deleteKey:keyLabel];
    
    // Looking for key even though it has been deleted
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should no longer exists");
}

// ensure newly created key works
- (void)testNewlyCreatedKeyWorks
{
    NSString* keyLabel = @"testNewlyCreatedKeyWorks";
    
    // Make sure key doesn't exist initially
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should not have been found");

    // Create key
    SFSecureEncryptionKey *key = [SFSecureEncryptionKey createKey:keyLabel];
    XCTAssertNotNil(key, @"Key should have been created");
    
    // Check that key works
    XCTAssertTrue([self checkKeyWorks:key], @"Key should have worked");
    
    // Delete key
    [SFSecureEncryptionKey deleteKey:keyLabel];
    
    // Looking for key even though it has been deleted
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should no longer exists");
}

// ensure retrieved key works
- (void)testRetrievedKeyWorks
{
    NSString* keyLabel = @"testRetrievedKeyWorks";
    
    // Make sure key doesn't exist initially
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should not have been found");

    // Create key
    SFSecureEncryptionKey *key = [SFSecureEncryptionKey createKey:keyLabel];
    XCTAssertNotNil(key, @"Key should have been created");

    // Retrieve key
    key = [SFSecureEncryptionKey retrieveKey:keyLabel];
    XCTAssertNotNil(key, @"Key should have been found");

    // Check that key works
    XCTAssertTrue([self checkKeyWorks:key], @"Key should have worked");
    
    // Delete key
    [SFSecureEncryptionKey deleteKey:keyLabel];
    
    // Looking for key even though it has been deleted
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel], @"Key should no longer exists");
}

// ensure we can create multiple keys
- (void) testMultipleKeys
{
    NSString* keyLabel1 = @"testMultipleKeys1";
    NSString* keyLabel2 = @"testMultipleKeys2";
    
    // Make sure keys don't exist initially
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel1], @"Key1 should not have been found");
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel2], @"Key2 should not have been found");
    
    // Create key1
    SFSecureEncryptionKey *key1 = [SFSecureEncryptionKey createKey:keyLabel1];
    XCTAssertNotNil(key1, @"Key1 should have been created");

    // Check only key1 exists
    XCTAssertNotNil([SFSecureEncryptionKey retrieveKey:keyLabel1], @"Key1 should have been found");
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel2], @"Key2 should not have been found");
    
    // Retrieve key1 back and make sure it works
    key1 = [SFSecureEncryptionKey retrieveKey:keyLabel1];
    XCTAssertTrue([self checkKeyWorks:key1], @"Key1 should have worked");

    // Create key2
    SFSecureEncryptionKey *key2 = [SFSecureEncryptionKey createKey:keyLabel2];
    XCTAssertNotNil(key2, @"Key2 should have been created");
    
    // Check keys exists
    XCTAssertNotNil([SFSecureEncryptionKey retrieveKey:keyLabel1], @"Key1 should have been found");
    XCTAssertNotNil([SFSecureEncryptionKey retrieveKey:keyLabel2], @"Key2 should have been found");
    
    // Retrieve key1 and key2 back and make sure they work
    key1 = [SFSecureEncryptionKey retrieveKey:keyLabel1];
    key2 = [SFSecureEncryptionKey retrieveKey:keyLabel2];
    XCTAssertTrue([self checkKeyWorks:key1], @"Key1 should have worked");
    XCTAssertTrue([self checkKeyWorks:key2], @"Key2 should have worked");
    
    // Delete key1
    [SFSecureEncryptionKey deleteKey:keyLabel1];

    // Check only key2 exists
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel1], @"Key1 should not have been found");
    XCTAssertNotNil([SFSecureEncryptionKey retrieveKey:keyLabel2], @"Key2 should have been found");

    // Retrieve key2 back and make sure it works
    key2 = [SFSecureEncryptionKey retrieveKey:keyLabel2];
    XCTAssertTrue([self checkKeyWorks:key2], @"Key2 should have worked");

    // Delete key2
    [SFSecureEncryptionKey deleteKey:keyLabel2];
    
    // Make sure keys no longer exist
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel1], @"Key1 should no longer exist");
    XCTAssertNil([SFSecureEncryptionKey retrieveKey:keyLabel2], @"Key2 should no longer exist");
}

- (BOOL) checkKeyWorks:(SFSecureEncryptionKey*)key
{
    NSString* archiveKey = @"archiveKey";
    NSDictionary *dictionary = @{@"one":@"", @"two":@""};

    // Serialize dictionary into data
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:dictionary forKey:archiveKey];
    [archiver finishEncoding];
    NSData* dictionaryData = archiver.encodedData;
    
    // Encrypt data
    NSData* encryptedData = [key encryptData:dictionaryData];
    
    // Decrypt back data
    NSData* decryptedData = [key decryptData:encryptedData];
    
    // Deserialize decrypted data
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:decryptedData error:nil];
    unarchiver.requiresSecureCoding = NO;
    NSDictionary* decryptedDictionary = [unarchiver decodeObjectForKey:archiveKey];
    [unarchiver finishDecoding];
    
    // Compare against original dictionary
    return [decryptedDictionary isEqualToDictionary:dictionary];
}

@end
