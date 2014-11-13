//
//  SFEncryptionKeyTests.m
//  SalesforceSecurity
//
//  Created by Dustin Breese on 11/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "SFEncryptionKey.h"


@interface SFEncryptionKeyTests : XCTestCase

@end

@implementation SFEncryptionKeyTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
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

@end
