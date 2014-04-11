//
//  SFEncryptionKey.h
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFEncryptionKey : NSObject <NSCoding>

+ (instancetype)keyWithRandomValue:(NSUInteger)keySizeInBytes;
+ (instancetype)keyWithDataValue:(NSData *)keyValueData;

@property (nonatomic, copy) NSData *dataValue;

/**
 The base64 representation of the data value.
 */
@property (nonatomic, readonly) NSString *stringRepesentation;

@end
