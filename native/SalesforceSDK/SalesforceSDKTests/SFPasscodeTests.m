//
//  SFPasscodeTests.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 2/1/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import "SFPasscodeTests.h"
#import "SFPBKDFData.h"

@implementation SFPasscodeTests

- (void)testSerializedData
{
    NSString *keyString = @"Testing1234";
    NSString *saltString = @"SaltString1234";
    NSUInteger derivationRounds = 9876;
    NSString *codingKey = @"TestSerializedData";
    NSUInteger derivedKeyLength = 128;
    SFPBKDFData *pbkdfStartData = [[SFPBKDFData alloc] initWithKey:[keyString dataUsingEncoding:NSUTF8StringEncoding] salt:[saltString dataUsingEncoding:NSUTF8StringEncoding] derivationRounds:derivationRounds derivedKeyLength:derivedKeyLength];
    NSMutableData *serializedData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:serializedData];
    [archiver encodeObject:pbkdfStartData forKey:codingKey];
    [archiver finishEncoding];
    
    [archiver release];
    [pbkdfStartData release];
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:serializedData];
    SFPBKDFData *pbkdfEndData = [unarchiver decodeObjectForKey:codingKey];
    [unarchiver finishDecoding];
    NSString *verifyKeyString = [[NSString alloc] initWithData:pbkdfEndData.derivedKey encoding:NSUTF8StringEncoding];
    NSString *verifySaltString = [[NSString alloc] initWithData:pbkdfEndData.salt encoding:NSUTF8StringEncoding];
    STAssertTrue([verifyKeyString isEqualToString:keyString], @"Serialized/deserialized keys are not the same.");
    STAssertTrue([verifySaltString isEqualToString:saltString], @"Serialized/deserialized salts are not the same.");
    STAssertEquals(pbkdfEndData.numDerivationRounds, derivationRounds, @"Serialized/deserialized number of derivation rounds are not the same.");
    STAssertEquals(pbkdfEndData.derivedKeyLength, derivedKeyLength, @"Serialized/deserialized derived key length values are not the same.");
    
    [unarchiver release];
    [verifyKeyString release];
    [verifySaltString release];
}

@end
