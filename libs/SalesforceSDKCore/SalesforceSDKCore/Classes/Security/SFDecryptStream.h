//
//  SFDecryptStream.h
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFCryptChunks.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * SFDecryptStream is an input stream that decrypts data right after it is read.
 * SFCryptChunks is used to perform the decryption.
 */
@interface SFDecryptStream : NSInputStream <SFCryptChunksDelegate>

/**
 *  Setup for decryption. You must call this method before using the stream.
 *  @param key the cipher key.
 *  @param iv  the initialization vector, must be size of `SFCryptChunksCipherBlockSize`.
 */
- (void)setupWithKey:(NSData *)key andInitializationVector:(nullable NSData *)iv;

@end

NS_ASSUME_NONNULL_END
