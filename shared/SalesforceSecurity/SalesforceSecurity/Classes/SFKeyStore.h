//
//  SFKeyStore.h
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 5/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFKeyStoreKey.h"

@interface SFKeyStore : NSObject

/**
 The key store key, used for encrypting and decrypting the key store.
 */
@property (nonatomic, copy) SFKeyStoreKey *keyStoreKey;

/**
 The dictionary that holds the key store data.
 */
@property (nonatomic, strong) NSDictionary *keyStoreDictionary;

@property (nonatomic, readonly) BOOL keyStoreAvailable;
@property (nonatomic, readonly) BOOL keyStoreActive;

- (NSString *)keyLabelForString:(NSString *)baseKeyLabel;

@end
