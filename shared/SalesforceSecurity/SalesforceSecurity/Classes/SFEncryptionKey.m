//
//  SFEncryptionKey.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFEncryptionKey.h"

static NSString * const kEncryptionKeyCodingValue = @"com.salesforce.encryption.key.data";
static NSString * const kInitializationVectorCodingValue = @"com.salesforce.encryption.key.iv";

@implementation SFEncryptionKey

@synthesize key = _key;
@synthesize initializationVector = _initializationVector;

- (id)initWithData:(NSData *)key initializationVector:(NSData *)iv
{
    self = [super init];
    if (self) {
        self.key = key;
        self.initializationVector = iv;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.key = [aDecoder decodeObjectForKey:kEncryptionKeyCodingValue];
        self.initializationVector = [aDecoder decodeObjectForKey:kInitializationVectorCodingValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.key forKey:kEncryptionKeyCodingValue];
    [aCoder encodeObject:self.initializationVector forKey:kInitializationVectorCodingValue];
}

- (NSString *)keyAsString
{
    if (!self.key) return nil;
    // TODO: Replace with [NSData base64EncodedStringWithOptions:] when iOS7 is baseline.
    return [self.key base64Encoding];
}

- (NSString *)initializationVectorAsString
{
    if (!self.initializationVector) return nil;
    // TODO: Replace with [NSData base64EncodedStringWithOptions:] when iOS7 is baseline.
    return [self.initializationVector base64Encoding];
}

@end
