//
//  SFPasscodeData.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 1/31/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import "SFPBKDFData.h"

// For NSCoding.
NSString * const kSFPBKDFDataDerivedKeyCodingKey          = @"derivedKeyCodingKey";
NSString * const kSFPBKDFDataSaltCodingKey                = @"saltCodingKey";
NSString * const kSFPBKDFDataNumDerivationRoundsCodingKey = @"numDerivationRounds";

@implementation SFPBKDFData

@synthesize derivedKey = _derivedKey;
@synthesize salt = _salt;
@synthesize numDerivationRounds = _numDerivationRounds;

#pragma mark - init / dealloc / etc.

- (id)initWithKey:(NSData *)key salt:(NSData *)salt derivationRounds:(NSUInteger)derivationRounds
{
    self = [super init];
    if (self) {
        self.derivedKey = key;
        self.salt = salt;
        self.numDerivationRounds = derivationRounds;
    }
    return self;
}

- (void)dealloc
{
    self.derivedKey = nil;
    self.salt = nil;
    [super dealloc];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.derivedKey forKey:kSFPBKDFDataDerivedKeyCodingKey];
    [aCoder encodeObject:self.salt forKey:kSFPBKDFDataSaltCodingKey];
    NSNumber *derivationRoundsObj = [NSNumber numberWithUnsignedInteger:self.numDerivationRounds];
    [aCoder encodeObject:derivationRoundsObj forKey:kSFPBKDFDataNumDerivationRoundsCodingKey];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.derivedKey = [aDecoder decodeObjectForKey:kSFPBKDFDataDerivedKeyCodingKey];
        self.salt = [aDecoder decodeObjectForKey:kSFPBKDFDataSaltCodingKey];
        NSNumber *derivationRoundsObj = [aDecoder decodeObjectForKey:kSFPBKDFDataNumDerivationRoundsCodingKey];
        self.numDerivationRounds = [derivationRoundsObj unsignedIntegerValue];
    }
    
    return self;
}

@end
