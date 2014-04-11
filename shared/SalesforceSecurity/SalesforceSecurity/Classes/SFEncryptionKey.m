//
//  SFEncryptionKey.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFEncryptionKey.h"
#import "SFSDKCryptoUtils.h"

static NSString * const kEncryptionKeyCodingValue = @"com.salesforce.encryption.key";

@interface SFEncryptionKey ()

- (id)initWithData:(NSData *)keyData;

@end

@implementation SFEncryptionKey

@synthesize dataValue = _dataValue;

- (id)initWithData:(NSData *)keyData
{
    self = [super init];
    if (self) {
        self.dataValue = keyData;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.dataValue = [aDecoder decodeObjectForKey:kEncryptionKeyCodingValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.dataValue forKey:kEncryptionKeyCodingValue];
}

+ (instancetype)keyWithRandomValue:(NSUInteger)keySizeInBytes
{
    if (keySizeInBytes == 0)
        return nil;
    
    NSData *keyData = [SFSDKCryptoUtils randomByteDataWithLength:keySizeInBytes];
    SFEncryptionKey *key = [[[self class] alloc] initWithData:keyData];
    return key;
}

+ (instancetype)keyWithDataValue:(NSData *)keyValueData
{
    SFEncryptionKey *key = [[[self class] alloc] initWithData:keyValueData];
    return key;
}

- (NSString *)stringRepesentation
{
    if (!self.dataValue) return nil;
    [self.dataValue isEqual:nil];
    return [self.dataValue base64Encoding];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[self class]])
        return NO;
    
    SFEncryptionKey *keyObj = (SFEncryptionKey *)object;
    if (_dataValue == nil && keyObj.dataValue == nil)
        return YES;
    
    return [_dataValue isEqual:keyObj.dataValue];
}

- (NSUInteger)hash
{
    if (_dataValue)
        return [_dataValue hash];
    else
        return [super hash];
}

@end
