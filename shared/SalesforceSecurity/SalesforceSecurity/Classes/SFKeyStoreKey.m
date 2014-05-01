//
//  SFKeyStoreKey.m
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 4/28/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFKeyStoreKey.h"

static NSString * const kKeyStoreKeyDataArchiveKey = @"com.salesforce.keystore.keyStoreKeyDataArchive";
static NSString * const kKeyStoreKeyTypeDataArchiveKey = @"com.salesforce.keystore.keyStoreKeyTypeDataArchive";

@implementation SFKeyStoreKey

@synthesize encryptionKey = _encryptionKey;
@synthesize keyType = _keyType;

- (id)initWithKey:(SFEncryptionKey *)key type:(SFKeyStoreKeyType)keyType
{
    self = [super init];
    if (self) {
        self.encryptionKey = key;
        self.keyType = keyType;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.encryptionKey = [aDecoder decodeObjectForKey:kKeyStoreKeyDataArchiveKey];
        NSNumber *keyTypeNum = [aDecoder decodeObjectForKey:kKeyStoreKeyTypeDataArchiveKey];
        self.keyType = [keyTypeNum unsignedIntegerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.encryptionKey forKey:kKeyStoreKeyDataArchiveKey];
    NSNumber *keyTypeNum = [NSNumber numberWithUnsignedInteger:self.keyType];
    [aCoder encodeObject:keyTypeNum forKey:kKeyStoreKeyTypeDataArchiveKey];
}

@end
