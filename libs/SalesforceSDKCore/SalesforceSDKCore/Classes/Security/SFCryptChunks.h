//
//  SFCryptChunks.h
//  SFCryptoStream
//
//  Created by Joao Neves on 4/6/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
@class SFCryptChunks;

NS_ASSUME_NONNULL_BEGIN

// The cipher block size used by SFCryptChunks.
extern size_t const SFCryptChunksCipherBlockSize;
// The cipher algorithm used by SFCryptChunks.
extern CCAlgorithm const SFCryptChunksCipherAlgorithm;
// The cipher options used in the cipher algorithm used by SFCryptChunks.
extern CCOptions const SFCryptChunksCipherOptions;

/**
 *  SFCryptChunksDelegate
 */
@protocol SFCryptChunksDelegate <NSObject>
@required
/**
 *  Encrypted / Decrypted chunk results. 
 *  This method may be invoked none to multiple times - until all result is informed to delegate.
 *  @param cryptChunks  the instance sending this message.
 *  @param buffer       the chunk results buffer.
 *  @param len          the chunk results buffer length.
 */
- (void)cryptChunk:(SFCryptChunks *)cryptChunks chunkResult:(uint8_t *)buffer bufferLen:(size_t)len;

@end

/**
 *  SFCryptChunks performs encryption / decryption in chunks, using a fixed size buffer in the stack.
 *  It does not allocate any memory to perform the encryption / decryption,
 *  the size of memory used (by SFCryptChunks) is O(1) regardless of the input / output data size.
 *  
 *  Basic usage is:
 *      1. Create an instance giving it a key and setting a delegate to consume results;
 *      2. Pass encrypted / decrypted data in as many times needed;
 *      3. Handle results via the delegate methods as you pass data in;
 *      4. When done passing data in, call the finalize crypt method (this is a very important step).
 */
@interface SFCryptChunks : NSObject

/**
 *  Initializes a SFCryptChunks that uses algorithm specified in `SFCryptChunksCipherAlgorithm`
 *  and options specified in `SFCryptChunksCipherOptions`.
 *  @param key      the cipher key.
 *  @param iv       the initialization vector, must be size of `SFCryptChunksCipherBlockSize`.
 *  @param operation whether it will encrypt or decrypt.
 *  @return a SFCryptChunks ready for encryption or decryption.
 */
- (instancetype)initWithKey:(NSData *)key
       initializationVector:(nullable NSData *)iv
                  operation:(CCOperation)operation;

/**
 *  The delegate to receive crypt results.
 */
@property (nonatomic, weak) id<SFCryptChunksDelegate> delegate;

/**
 *  A data buffer to be encrypted / decrypted. You may pass a buffer of any size here,
 *  the delegate will then be called with results as many times as needed:
 *      - the delegate may be called multiple times with chunk results; or
 *      - the delegate may not be called at all, if there isn't enough data to produce a result.
 *  This method utilizes a stack memory buffer the size of 2 cipher blocks.
 *  @param buffer the buffer data to be encrypted or decrypted.
 *  @param len    the buffer size.
 */
- (void)cryptBuffer:(const uint8_t *)buffer bufferLen:(size_t)len;

/**
 *  Whether or not the crypt operation completed. 
 *  Once complete, this object must be disposed.
 */
@property (nonatomic, assign, readonly) BOOL cryptFinalized;

/**
 *  Finalizes the crypt operation. The delegate may be called with chunk results if the final crypt produced any results.
 *  The final result is never bigger than the cipher block size.
 *  This method utilizes a stack memory buffer the size of 1 cipher block.
 */
- (void)finalizeCrypt;

@end

NS_ASSUME_NONNULL_END
