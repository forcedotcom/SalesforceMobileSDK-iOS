/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

#import "SFPBKDFData.h"

// For NSCoding.
static NSString * const kSFPBKDFDataDerivedKeyCodingKey          = @"derivedKeyCodingKey";
static NSString * const kSFPBKDFDataSaltCodingKey                = @"saltCodingKey";
static NSString * const kSFPBKDFDataNumDerivationRoundsCodingKey = @"numDerivationRoundsCodingKey";
static NSString * const kSFPBKDFDataDerivedKeyLengthCodingKey    = @"derivedKeyLengthCodingKey";

@implementation SFPBKDFData

@synthesize derivedKey = _derivedKey;
@synthesize salt = _salt;
@synthesize numDerivationRounds = _numDerivationRounds;
@synthesize derivedKeyLength = _derivedKeyLength;

#pragma mark - init / dealloc / etc.

- (id)initWithKey:(NSData *)key salt:(NSData *)salt derivationRounds:(NSUInteger)derivationRounds derivedKeyLength:(NSUInteger)derivedKeyLength
{
    self = [super init];
    if (self) {
        self.derivedKey = key;
        self.salt = salt;
        self.numDerivationRounds = derivationRounds;
        self.derivedKeyLength = derivedKeyLength;
    }
    return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.derivedKey != nil) {
        [aCoder encodeObject:self.derivedKey forKey:kSFPBKDFDataDerivedKeyCodingKey];
    }
    [aCoder encodeObject:self.salt forKey:kSFPBKDFDataSaltCodingKey];
    NSNumber *derivationRoundsObj = @(self.numDerivationRounds);
    [aCoder encodeObject:derivationRoundsObj forKey:kSFPBKDFDataNumDerivationRoundsCodingKey];
    NSNumber *derivedKeyLengthObj = @(self.derivedKeyLength);
    [aCoder encodeObject:derivedKeyLengthObj forKey:kSFPBKDFDataDerivedKeyLengthCodingKey];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.derivedKey = [aDecoder decodeObjectForKey:kSFPBKDFDataDerivedKeyCodingKey];
        self.salt = [aDecoder decodeObjectForKey:kSFPBKDFDataSaltCodingKey];
        NSNumber *derivationRoundsObj = [aDecoder decodeObjectForKey:kSFPBKDFDataNumDerivationRoundsCodingKey];
        self.numDerivationRounds = [derivationRoundsObj unsignedIntegerValue];
        NSNumber *derivedKeyLengthObj = [aDecoder decodeObjectForKey:kSFPBKDFDataDerivedKeyLengthCodingKey];
        self.derivedKeyLength = [derivedKeyLengthObj unsignedIntegerValue];
    }
    
    return self;
}

@end
