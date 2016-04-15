//
//  SFEncryptStream.h
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFCryptChunks.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  SFEncryptStream is an output stream that encrypts data before it is written out.
 *  SFCryptChunks is used to perform the encryption.
 */
@interface SFEncryptStream : NSOutputStream <SFCryptChunksDelegate>

/**
 *  Setup for encryption. You must call this method before using the stream.
 *  @param key the cipher key.
 *  @param iv  the initialization vector, must be size of `SFCryptChunksCipherBlockSize`.
 */
- (void)setupWithKey:(NSData *)key andInitializationVector:(nullable NSData *)iv;

@end

NS_ASSUME_NONNULL_END
