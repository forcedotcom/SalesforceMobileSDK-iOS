/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

/**
 This class is responsible for encrypting and decrypting the content data for chatter.
 */

typedef NS_ENUM(NSUInteger, SFCryptoMode) {
    SFCryptoModeInMemory,
    SFCryptoModeDisk
};

typedef NS_ENUM(NSUInteger, SFCryptoOperation) {
    SFCryptoOperationEncrypt,
    SFCryptoOperationDecrypt
};

/** Utility class for data encryption operations. 
 */
@interface SFCrypto : NSObject

/**
 The output file for encrypted/decrypted data in CHCryptoModeDisk mode.
 */
@property(nonatomic, copy) NSString *file;

/**
 Returns the current mode of operation for the CHCrypto class.
 */
@property (nonatomic, readonly) SFCryptoMode mode;

/**
 Initializer. Calls the designated initializer, passing nil to <code>iv</code>.
 @param operation Operation to be performed encrypt/decrypt.
 @param key Key used for encyption/decryption. Pass nil to use the default key.
 @param mode Mode which determines whether to perform operation in memory at once or in chunks writing to the disk.
 */
- (id)initWithOperation:(SFCryptoOperation)operation key:(NSData *)key mode:(SFCryptoMode)mode;

/**
 Designated initializer.
 @param operation Operation to be performed encrypt/decrypt.
 @param key Key used for encyption/decryption pass nil to use the default key.
 @param iv Initialization vector. If set to nil, uses the default initialization vector.
 @param mode Mode which determines whether to perform operation in memory at once or in chunks writing to the disk.
 */
- (id)initWithOperation:(SFCryptoOperation)operation key:(NSData *)key iv:(NSData*)iv mode:(SFCryptoMode)mode;

/**
 Encrypts or decrypts the passed in data. The input data is assumed to be passed in as a chunk.
 This method requires a call to <code>- finalizeCipher</code>.
 @param inData Input data.
 */
- (void)cryptData:(NSData *)inData;

/**
 Decrypts the passed in data initializer, performing the decryption in memory.
 @param data Encrypted input data.
 @return Decrypted data.
 */
- (NSData *)decryptDataInMemory:(NSData *)data;

/**
 Encrypts the passed in data initializer, performing the encryption in memory.
 @param data Input data.
 @return Encrypted data.
 */
- (NSData *)encryptDataInMemory:(NSData *)data;

/**
 Finalizes the encryption/decryption process.
 */
- (BOOL)finalizeCipher;

/**
 Decrypts a file.
 @param inputFile Name of the encrypted file.
 @param outputFile Name of the decrypted file.
 @result YES if the file was successfully decrypted; NO otherwise.
 */
-(BOOL) decrypt:(NSString *)inputFile to:(NSString *)outputFile;

/**
 Creates a secret key, based in part on the input key.
 @param key The base key which will seed the return key.
 @result The secret key, based on the input key.
 */
+ (NSData *)secretWithKey:(NSString *)key;

/**
 Returns a unique identifier associated with this app install.  The identifier will
 remain the same for the lifetime of the app's installation on the device.  If the
 app is uninstalled, a new identifier will be created if it is ever reinstalled.
 @result A unique identifier for the app install on the particular device.
 */
+ (NSString *)baseAppIdentifier;

/**
 Whether or not the base app identifier has been configured for this app install.
 @result YES if the base app ID has already been configured, NO otherwise.
 */
+ (BOOL)baseAppIdentifierIsConfigured;

/**
 Whether or not the base app identifier was configured at some point during this launch of
 the app.
 @result YES if the base app ID was configured during this app launch; NO otherwise.
 */
+ (BOOL)baseAppIdentifierConfiguredThisLaunch;

/**
 Returns whether we have an initialization vector used for encryption stored in the keychain.
 */
+ (BOOL)hasInitializationVector;

@end