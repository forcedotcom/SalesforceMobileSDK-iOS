//
//  SFOAuthCrypto.h
//  SalesforceOAuth
//
//  Created by Amol Prabhu on 1/16/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>

@interface SFOAuthCrypto : NSObject {
@private
    CCCryptorRef _cryptor;
    size_t _totalLength;
    size_t _filePtr;
    char *_dataOut;
    size_t _dataOutMoved;
    size_t _dataOutLength;
}
/**
 Designated initializer
 @param operation Operation to be performed: encrypt/decrypt
 @param key Key used for encyption/decryption pass `nil` to use the default key
 */
- (id)initWithOperation:(CCOperation)operation key:(NSData *)key;

/**
 Encrypt the passed in data
 @param data input data
 */
- (void)encryptData:(NSData *)data;

/**
 Decrypt the passed in data. Performs the decryption in the current thread
 @param data encrypted input data
 */
- (NSData *)decryptData:(NSData *)data;

/**
 Finalize the the encryption/decryption process
 */
- (NSData *)finalizeCipher;

@end
