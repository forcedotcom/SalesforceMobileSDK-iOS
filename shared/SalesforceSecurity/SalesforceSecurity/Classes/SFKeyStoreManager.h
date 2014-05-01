//
//  SFKeyStoreKeychainManager.h
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFEncryptionKey.h"

@interface SFKeyStoreManager : NSObject

+ (instancetype)sharedInstance;

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel;
- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel;
- (void)removeKeyWithLabel:(NSString *)keyLabel;
- (BOOL)keyWithLabelExists:(NSString *)keyLabel;

/**
 Returns a key with a random value for the key and initialization vector.  The key size
 will be the size for the AES-256 algorithm (kCCKeySizeAES256), and the initialization
 vector will be the block size associated with AES encryption (kCCBlockSizeAES128).
 @return An instance of SFEncryptionKey with the described values.
 */
- (SFEncryptionKey *)keyWithRandomValue;

@end
