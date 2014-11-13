//
//  SFKeyStoreTests.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 5/1/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFEncryptionKey.h"
#import "SFKeyStore+Internal.h"
#import "SFKeyStoreManager+Internal.h"
#import <SalesforceCommonUtils/NSData+SFAdditions.h>

@interface SFKeyStoreTests : XCTestCase
{
    SFKeyStoreManager *mgr;
}
@end

@implementation SFKeyStoreTests


- (void)setUp
{
    [super setUp];
    
    [SFLogger setLogLevel:SFLogLevelDebug];
    
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
    [keyStore setKeyStoreKey:key];
    
    NSDictionary *dict = [keyStore keyStoreDictionary];
    XCTAssertNotNil(dict, @"Dictionary should not be null");
    XCTAssertEqual(0, [dict count], @"Dictionary should be empty");
}

// ensures we can set and get the dictionary
-(void)testSetAndGetDictionary {
    SFEncryptionKey *encKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *key = [[SFKeyStoreKey alloc] initWithKey:encKey type:SFKeyStoreKeyTypeGenerated];
    
    SFKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    [keyStore setKeyStoreKey:key];
    
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"one", @"uno", @"two", @"dos", nil];
    
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
    [keyStore setKeyStoreKey:key];
    
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"one", @"uno", @"two", @"dos", nil];
    
    // set
    [keyStore setKeyStoreDictionary:data withKey:encKey];
    
    // get
    SFEncryptionKey *badEncKey = [mgr keyWithRandomValue];
    NSDictionary *retrievedData = [keyStore keyStoreDictionaryWithKey:badEncKey];
    
    XCTAssertNil(retrievedData, @"Data retrieved with wrong enc key should be nil");
}
@end
