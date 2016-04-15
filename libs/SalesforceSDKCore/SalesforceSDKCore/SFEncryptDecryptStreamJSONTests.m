//
//  SFEncryptDecryptStreamJSONTests.m
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFEncryptStream.h"
#import "SFDecryptStream.h"
#import "SFCryptoStreamTestUtils.h"


@interface SFEncryptDecryptStreamJSONTests : XCTestCase

@end


@implementation SFEncryptDecryptStreamJSONTests

#pragma mark Dictionary

- (void)testSimpleJSONDictionary {
    NSDictionary *root = @{@"key1": @"value1",
                           @"key2": @15,
                           @"key3": [NSNull null]};
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testComplexJSONDictionary {
    NSDictionary *root = @{@"key1": @"value1",
                           @"key2": @15,
                           @"key3": [NSNull null],
                           @"key4": @[@1, @2, @{@"keyA": @"valueA",
                                                @"keyB": [NSNull null],
                                                @"keyC": @[[NSNull null], @2]}],
                           @"key5": @{},
                           @"key6": @[]
                           };
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testHugeJSONDictionary {
    NSArray *assortedObjects = @[@17, @[], @{@"key1": @"value1"}, [NSNull null], @"aStr"];
    NSMutableDictionary *root = [[NSMutableDictionary alloc] init];
    for (int i = 0; i < 1000; ++i) {
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        root[key] = assortedObjects[i % assortedObjects.count];
    }
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testEmptyJSONDictionary {
    NSDictionary *root = @{};
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testMalformedJSONDictionary {
    NSDictionary *root = @{@[@1,@2]: @"invalid key",
                           @"invalid number": @(NAN)};
    XCTAssertFalse([NSJSONSerialization isValidJSONObject:root]);
    XCTAssertThrows([self performTestWithJSONObject:root]);
}


#pragma mark Array

- (void)testSimpleJSONArray {
    NSArray *root = @[@"value1", @15, [NSNull null]];
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testComplexJSONArray {
    NSArray *root = @[@"value1", @15, [NSNull null], @{@"key1": @"value1", @"key2": @[@1, @2]}, @{}, [NSNull null], @[@[]]];
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testHugeJSONArray {
    NSArray *assortedObjects = @[@17, @[], @{@"key1": @"value1"}, [NSNull null], @"aStr"];
    NSMutableArray *root = [[NSMutableArray alloc] init];
    for (int i = 0; i < 1000; ++i) {
        [root addObject:assortedObjects[i % assortedObjects.count]];
    }
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testEmptyJSONArray {
    NSArray *root = @[];
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testMalformedJSONArray {
    NSArray *root = @[@(NAN), @(INFINITY), @"someString"];
    XCTAssertFalse([NSJSONSerialization isValidJSONObject:root]);
    XCTAssertThrows([self performTestWithJSONObject:root]);
}


#pragma mark General

- (void)testHugeStringInJSONObject {
    NSMutableDictionary *root = [@{@"key1": @"normal value",
                                   @"key2": @22,
                                   @"key3": [NSNull null]
                                   } mutableCopy];
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i < 1000; ++i) {
        [str appendString:@"abcdefghijklmnopqrstuvxwyzABCDEFGHIJKLMNOPQRSTUVXWYZ1234567890"];
    }
    root[@"key4"] = str;
    id decryptedResultingObject = [self performTestWithJSONObject:root];
    XCTAssertEqualObjects(root, decryptedResultingObject);
}

- (void)testMalformedJSONRoot {
    NSString *root = @"a string";
    XCTAssertFalse([NSJSONSerialization isValidJSONObject:root]);
    XCTAssertThrows([self performTestWithJSONObject:root]);
}

- (void)testMalformedJSONWithInvalidObject {
    NSDictionary *root = @{@"key1": @"value1",
                           @"key2": [[UIView alloc] initWithFrame:CGRectZero]};
    XCTAssertFalse([NSJSONSerialization isValidJSONObject:root]);
    XCTAssertThrows([self performTestWithJSONObject:root]);
}


#pragma mark - The actual test code

- (id)performTestWithJSONObject:(id)object {
    NSData *iv = [SFCryptoStreamTestUtils defaultInitializationVectorWithBlockSize:kCCBlockSizeAES128];
    NSData *key = [SFCryptoStreamTestUtils defaultKeyWithSize:kCCKeySizeAES256];
    void (^performEncryption)(SFEncryptStream *) = ^(SFEncryptStream *encryptStream) {
        [encryptStream setupWithKey:key andInitializationVector:iv];
        [encryptStream open];
        NSError *toJSONError = nil;
        NSInteger __unused bytesWritten = [NSJSONSerialization writeJSONObject:object
                                                                      toStream:encryptStream
                                                                       options:0
                                                                         error:&toJSONError];
        if (toJSONError) {
            NSLog(@"Error on serializing JSON object: %@.", toJSONError);
        }
        [encryptStream close];
    };
    id (^performDecryption)(SFDecryptStream *) = ^(SFDecryptStream *decryptStream) {
        [decryptStream setupWithKey:key andInitializationVector:iv];
        [decryptStream open];
        NSError *fromJSONError = nil;
        id decryptedObject = [NSJSONSerialization JSONObjectWithStream:decryptStream
                                                               options:0
                                                                 error:&fromJSONError];
        if (fromJSONError) {
            NSLog(@"Error on de-serializing JSON object: %@.", fromJSONError);
        }
        [decryptStream close];
        return decryptedObject;
    };
    
    // Test stream to memory
    SFEncryptStream *encryptToMemory = [[SFEncryptStream alloc] initToMemory];
    performEncryption(encryptToMemory);
    NSData *encryptedData = [encryptToMemory propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    SFDecryptStream *decryptFromMemory = [[SFDecryptStream alloc] initWithData:encryptedData];
    id decryptedObjectFromMemory = performDecryption(decryptFromMemory);
    
    // Test stream to file
    NSString *filePath = [SFCryptoStreamTestUtils filePathForFileName:[[NSUUID UUID] UUIDString]];
    SFEncryptStream *encryptToFile = [[SFEncryptStream alloc] initToFileAtPath:filePath append:NO];
    performEncryption(encryptToFile);
    SFDecryptStream *decryptFromFile = [[SFDecryptStream alloc] initWithFileAtPath:filePath];
    id decryptedObjectFromFile = performDecryption(decryptFromFile);
    
    XCTAssertEqualObjects(decryptedObjectFromMemory, decryptedObjectFromFile, @"Streams produced different results!");
    return decryptedObjectFromMemory;
}

@end
