//
//  SFKeyStoreKeychainManager.h
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFEncryptionKey.h"

extern NSString * const kSFKeyStoreManagerErrorDomain;

@interface SFKeyStoreManager : NSObject

+ (instancetype)sharedInstance;

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel;
- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel;
- (void)removeKeyWithLabel:(NSString *)keyLabel;
- (BOOL)keyWithLabelExists:(NSString *)keyLabel;

@end
