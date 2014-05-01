//
//  SFEncryptionKey.h
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFEncryptionKey : NSObject <NSCoding>

- (id)initWithData:(NSData *)keyData initializationVector:(NSData *)iv;

@property (nonatomic, copy) NSData *key;
@property (nonatomic, copy) NSData *initializationVector;

/**
 The base64 representation of the key data.
 */
@property (nonatomic, readonly) NSString *keyAsString;

/**
 The base64 representation of the initialization vector data.
 */
@property (nonatomic, readonly) NSString *initializationVectorAsString;

@end
