/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
@class SFCryptChunks;

NS_ASSUME_NONNULL_BEGIN

// The cipher block size used by SFCryptChunks.
extern size_t const SFCryptChunksCipherBlockSize;
// The cipher algorithm used by SFCryptChunks.
extern uint32_t const SFCryptChunksCipherAlgorithm;
// The cipher key size used by SFCryptChunks.
extern size_t const SFCryptChunksCipherKeySize;
// The cipher options used in the cipher algorithm used by SFCryptChunks.
extern uint32_t const SFCryptChunksCipherOptions;

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
 *  Initializes a SFCryptChunks for encryption that uses algorithm specified in `SFCryptChunksCipherAlgorithm`
 *  and options specified in `SFCryptChunksCipherOptions`.
 *  @param key      the cipher key.
 *  @param iv       the initialization vector, must be size of `SFCryptChunksCipherBlockSize`.
 *  @return a SFCryptChunks ready for encryption.
 */
- (instancetype)initForEncryptionWithKey:(NSData *)key
                    initializationVector:(nullable NSData *)iv;

/**
 *  Initializes a SFCryptChunks for decryption that uses algorithm specified in `SFCryptChunksCipherAlgorithm`
 *  and options specified in `SFCryptChunksCipherOptions`.
 *  @param key      the cipher key.
 *  @param iv       the initialization vector, must be size of `SFCryptChunksCipherBlockSize`.
 *  @return a SFCryptChunks ready for decryption.
 */
- (instancetype)initForDecryptionWithKey:(NSData *)key
                    initializationVector:(nullable NSData *)iv;

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
