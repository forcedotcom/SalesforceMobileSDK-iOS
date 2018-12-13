/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKCryptoUtils.h"
#import "SFPBKDFData.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+SFAdditions.h"
#import <Security/Security.h>

// Public constants
NSUInteger const kSFPBKDFDefaultNumberOfDerivationRounds = 4000;
NSUInteger const kSFPBKDFDefaultDerivedKeyByteLength = 128;
NSUInteger const kSFPBKDFDefaultSaltByteLength = 32;

// RSA key constants
static NSString * const kSFRSAPublicKeyTagPrefix = @"com.salesforce.rsakey.public";
static NSString * const kSFRSAPrivateKeyTagPrefix = @"com.salesforce.rsakey.private";

@interface SFSDKCryptoUtils ()

/**
 * Executes the encryption/decryption operation (depending on the configuration of the cryptor).
 * @param inData The data to encrypt/decrypt.
 * @param cryptor The CCCryptor doing the encryption/decryption.
 * @param resultData Output parameter containing the encrypted/decrypted result of the operation.
 * @return YES if the operation was successful, NO otherwise.
 */
+ (BOOL)executeCrypt:(NSData *)inData cryptor:(CCCryptorRef)cryptor resultData:(NSData **)resultData;

/**
 * Encrypt the given data using the AES algorithm.
 * @param data The data to encrypt.
 * @param key The encryption key used to encrypt the data.
 * @param keyLength The encryption key length used for key.
 * @param iv The initialization vector data used for the encryption.
 * @return The encrypted data, or `nil` if encryption was not successful.
 */
+ (nullable NSData *)aesEncryptData:(NSData *)data withKey:(NSData *)key keyLength:(NSInteger)keyLength iv:(NSData *)iv;

/**
 * Decrypt the given data using the AES algorithm.
 * @param data The data to decrypt.
 * @param key The decryption key used to decrypt the data.
 * @param keyLength The decryption key length used for key.
 * @param iv The initialization vector data used for the decryption.
 * @return The decrypted data, or `nil` if decryption was not successful.
 */
+ (nullable NSData *)aesDecryptData:(NSData *)data withKey:(NSData *)key keyLength:(NSInteger)keyLength iv:(NSData *)iv;

/**
 * Get RSA key as NSString with given keyTagString and length
 * @param keyTagString The key tag string used to generate the key.
 * @param length The key length used for key
 * @return The key data, or `nil` if no matching key is found
 */
+ (nullable NSData *)getRSAKeyDataWithTag:(NSString *)keyTagString keyLength:(NSUInteger)length;

/**
 * Get RSA SecKeyRef with given keyTagString and length
 * @param keyTagString The key tag string used to generate the key.
 * @param length The key length used for key
 * @return The SecKeyRef, or `nil` if no matching key is found
 */
+ (nullable SecKeyRef)getRSAKeyRefWithTag:(NSString *)keyTagString keyLength:(NSUInteger)length;

/**
 * Export keyData into DER format. Originally from https://blog.wingsofhermes.org/?p=42
 * @param keyData The public key raw data
 * @return The SecKeyRef, or `nil` if failed
 */
+ (nullable NSData *)getRSAPublicKeyAsDER:(NSData *)keyData;

/**
 Helper function for ASN.1 encoding. Originally from https://blog.wingsofhermes.org/?p=42
 @param buf The buffer to encode
 @param length The buffer length
 @return buffer encode length
 */
+ (size_t)encodeLength:(unsigned char *)buf length:(size_t)length;

@end

@implementation SFSDKCryptoUtils

+ (NSData *)randomByteDataWithLength:(NSUInteger)lengthInBytes
{
    NSData *data = [[NSMutableData dataWithLength:lengthInBytes] randomDataOfLength:lengthInBytes];
    return data;
}

+ (SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash
{
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:kSFPBKDFDefaultSaltByteLength];
    return [SFSDKCryptoUtils createPBKDF2DerivedKey:stringToHash
                                               salt:salt
                                   derivationRounds:kSFPBKDFDefaultNumberOfDerivationRounds
                                          keyLength:kSFPBKDFDefaultDerivedKeyByteLength];
}

+ (SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash
                                   salt:(NSData *)salt
                       derivationRounds:(NSUInteger)numDerivationRounds
                              keyLength:(NSUInteger)derivedKeyLength
{
    NSData *stringToHashAsData = [stringToHash dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char key[derivedKeyLength];
    int result = CCKeyDerivationPBKDF(kCCPBKDF2, [stringToHashAsData bytes], [stringToHashAsData length], [salt bytes], [salt length], kCCPRFHmacAlgSHA256, (uint)numDerivationRounds, key, derivedKeyLength);
    
    if (result != 0) {
        // Error
        return nil;
    } else {
        NSData *keyData = [NSData dataWithBytes:key length:derivedKeyLength];
        SFPBKDFData *returnPBKDFData = [[SFPBKDFData alloc] initWithKey:keyData salt:salt derivationRounds:numDerivationRounds derivedKeyLength:derivedKeyLength];
        return returnPBKDFData;
    }
}

+ (NSData *)aes128EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv
{
    return [self aesEncryptData:data withKey:key keyLength:kCCKeySizeAES128 iv:iv];
}

+ (NSData *)aes128DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv
{
    return [self aesDecryptData:data withKey:key keyLength:kCCKeySizeAES128 iv:iv];
}

+ (NSData *)aes256EncryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv
{
    return [self aesEncryptData:data withKey:key keyLength:kCCKeySizeAES256 iv:iv];
}

+ (NSData *)aes256DecryptData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv
{
    return [self aesDecryptData:data withKey:key keyLength:kCCKeySizeAES256 iv:iv];
}

+ (nullable NSData *)getRSAPrivateKeyDataWithName:(NSString *)keyName keyLength:(NSUInteger)length
{
    NSString *tagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPrivateKeyTagPrefix, keyName];
    return [self getRSAKeyDataWithTag:tagString keyLength:length];
}

+ (nullable NSString *)getRSAPublicKeyStringWithName:(NSString *)keyName keyLength:(NSUInteger)length
{
    NSString *tagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPublicKeyTagPrefix, keyName];
    NSData *keyBits = [self getRSAKeyDataWithTag:tagString keyLength:length];
    if (keyBits != nil) {
        NSData *pemData = [self getRSAPublicKeyAsDER:keyBits];
        if (pemData != nil) {
            return [pemData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

+ (nullable SecKeyRef)getRSAPublicKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length
{
    NSString *tagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPublicKeyTagPrefix, keyName];
    return [self getRSAKeyRefWithTag:tagString keyLength:length];
}

+ (nullable SecKeyRef)getRSAPrivateKeyRefWithName:(NSString *)keyName keyLength:(NSUInteger)length
{
    NSString *tagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPrivateKeyTagPrefix, keyName];

    return [self getRSAKeyRefWithTag:tagString keyLength:length];
}

+ (nullable NSData*)encryptUsingRSAforData:(NSData *)data withKeyRef:(SecKeyRef)keyRef
{
    uint8_t *bytes = (uint8_t*)[data bytes];
    size_t blockSize = SecKeyGetBlockSize(keyRef);
    
    uint8_t cipherText[blockSize];
    size_t cipherLength = blockSize;
    OSStatus status = SecKeyEncrypt(keyRef, kSecPaddingPKCS1, bytes, [data length], &cipherText[0], &cipherLength);

    if (status != errSecSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"encryptUsingRSAforData failed with status code: %d", status];
        return nil;
    }
    
    NSData *encryptedData = [NSData dataWithBytes:cipherText length:cipherLength];
    return encryptedData;

}

+ (nullable NSData*)decryptUsingRSAforData:(NSData *)data withKeyRef:(SecKeyRef)keyRef
{
    size_t blockSize = SecKeyGetBlockSize(keyRef);
    size_t cipherLength = [data length];
    uint8_t *cipherText = (uint8_t*)[data bytes];
    
    uint8_t plainText[blockSize];
    size_t plainLength = blockSize;
    OSStatus status = SecKeyDecrypt(keyRef, kSecPaddingPKCS1, &cipherText[0], cipherLength, &plainText[0], &plainLength );
    
    if (status != errSecSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"decryptUsingRSAforData failed with status code: %d", status];
        return nil;
    }
    
    NSData *decryptedData = [NSData dataWithBytes:plainText length:plainLength];
    return decryptedData;
}

#pragma mark - Private methods

+ (BOOL)executeCrypt:(NSData *)inData cryptor:(CCCryptorRef)cryptor resultData:(NSData **)resultData
{
    size_t buffersize = CCCryptorGetOutputLength(cryptor, (size_t)[inData length], true);
	void *buffer = malloc(buffersize);
	size_t bufferused = 0;
    size_t totalbytes = 0;
	CCCryptorStatus status = CCCryptorUpdate(cryptor, [inData bytes], (size_t)[inData length], buffer, buffersize, &bufferused);
	if (status != kCCSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"CCCryptorUpdate() failed with status code: %d", status];
		free(buffer);
		return NO;
	}
    
    totalbytes += bufferused;
	
	status = CCCryptorFinal(cryptor, buffer + bufferused, buffersize - bufferused, &bufferused);
	if (status != kCCSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"CCCryptoFinal() failed with status code: %d", status];
		free(buffer);
		return NO;
	}
    
    totalbytes += bufferused;
	
    if (resultData != nil)
        *resultData = [NSData dataWithBytesNoCopy:buffer length:totalbytes];
    else
        free(buffer);
    
	return YES;
}

+ (NSData *)aesEncryptData:(NSData *)data withKey:(NSData *)key keyLength:(NSInteger)keyLength iv:(NSData *)iv
{
    // Ensure the proper key, IV sizes.
    if (key == nil) {
        [SFSDKCoreLogger e:[self class] format:@"aesEncryptData: encryption key is nil.  Cannot encrypt data."];
        return nil;
    }
    NSMutableData *mutableKey = [key mutableCopy];
    [mutableKey setLength:keyLength];
    NSMutableData *mutableIv = [iv mutableCopy];
    [mutableIv setLength:kCCBlockSizeAES128];
    
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreate(kCCEncrypt,
                                             kCCAlgorithmAES,
                                             kCCOptionPKCS7Padding,
                                             [mutableKey bytes],
                                             [mutableKey length],
                                             [mutableIv bytes],
                                             &cryptor);
    if (status != kCCSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"Error creating encryption cryptor with CCCryptorCreate().  Status code: %d", status];
        return nil;
    }
    
    NSData *resultData = nil;
    BOOL executeCryptSuccess = [self executeCrypt:data cryptor:cryptor resultData:&resultData];
    CCCryptorRelease(cryptor);
    return (executeCryptSuccess ? resultData : nil);
}

+ (NSData *)aesDecryptData:(NSData *)data withKey:(NSData *)key keyLength:(NSInteger)keyLength iv:(NSData *)iv
{
    // Ensure the proper key, IV sizes.
    if (key == nil) {
        [SFSDKCoreLogger e:[self class] format:@"aesDecryptData: decryption key is nil.  Cannot decrypt data."];
        return nil;
    }
    NSMutableData *mutableKey = [key mutableCopy];
    [mutableKey setLength:keyLength];
    NSMutableData *mutableIv = [iv mutableCopy];
    [mutableIv setLength:kCCBlockSizeAES128];
    
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreate(kCCDecrypt,
                                             kCCAlgorithmAES,
                                             kCCOptionPKCS7Padding,
                                             [mutableKey bytes],
                                             [mutableKey length],
                                             [mutableIv bytes],
                                             &cryptor);
    if (status != kCCSuccess) {
        [SFSDKCoreLogger e:[self class] format:@"Error creating decryption cryptor with CCCryptorCreate().  Status code: %d", status];
        return nil;
    }
    
    NSData *resultData = nil;
    BOOL executeCryptSuccess = [self executeCrypt:data cryptor:cryptor resultData:&resultData];
    CCCryptorRelease(cryptor);
    return (executeCryptSuccess ? resultData : nil);
}

+ (void)createRSAKeyPairWithName:(NSString *)keyName keyLength:(NSUInteger)length accessibleAttribute:(CFTypeRef)accessibleAttribute;
{
    NSString *privateTagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPrivateKeyTagPrefix, keyName];
    NSData *privateTag = [privateTagString dataUsingEncoding:NSUTF8StringEncoding];
                          
    NSString *publicTagString = [NSString stringWithFormat:@"%@.%@", kSFRSAPublicKeyTagPrefix, keyName];
    NSData *publicTag = [publicTagString dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *attributes =
    @{ (id)kSecAttrKeyType:               (id)kSecAttrKeyTypeRSA,
       (id)kSecAttrKeySizeInBits:         [NSNumber numberWithUnsignedInteger:length],
       (id)kSecPrivateKeyAttrs:
           @{ (id)kSecAttrIsPermanent:    @YES,
              (id)kSecAttrApplicationTag: privateTag,
              (id)kSecAttrAccessible: (__bridge id)accessibleAttribute,
              },
       (id)kSecPublicKeyAttrs:
           @{ (id)kSecAttrIsPermanent:    @YES,
              (id)kSecAttrApplicationTag: publicTag,
              (id)kSecAttrAccessible: (__bridge id)accessibleAttribute,
              },

       };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes,
                                                 &error);
    if (privateKey == nil) {
        NSError *err = CFBridgingRelease(error);
        // Handle the error. . .
        [SFSDKCoreLogger e:[self class] format:@"Error creating RSA private Key with name %@ and length %d.  Error code: %@", keyName, length, err.localizedDescription];
        return;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);

    if (publicKey == nil) {
        [SFSDKCoreLogger e:[self class] format:@"Error creating RSA public key with name %@ and length %d.", keyName, length];
    }
    
    if (publicKey != nil)  {
        CFRelease(publicKey);
    }
    if (privateKey != nil) {
        CFRelease(privateKey);
    }
}

+(nullable NSData *)getRSAKeyDataWithTag:(NSString *)keyTagString keyLength:(NSUInteger)length {
    NSData *tag = [keyTagString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *getquery = @{ (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: tag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                (id)kSecReturnData: @YES,
                                (id)kSecAttrKeySizeInBits: [NSNumber numberWithUnsignedInteger:length],
                                };
    
    NSData *keyBits = nil;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                          (CFTypeRef *)&result);
    if (status != errSecSuccess) {
        if (status == errSecItemNotFound) {
            return nil;
        }
        if (status != errSecSuccess) {
            // Handle the error. . .
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            [SFSDKCoreLogger e:[self class] format:@"Error getting RSA key with tag %@ and length %d. Error code: %@", keyTagString, length, error.localizedDescription];
            return nil;
        }
    }
    
    if (result != nil) {
        keyBits = CFBridgingRelease(result);
    }
    return keyBits;
}

+(nullable SecKeyRef)getRSAKeyRefWithTag:(NSString *)keyTagString keyLength:(NSUInteger)length {
    NSData *tag = [keyTagString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *getquery = @{ (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: tag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                (id)kSecReturnRef: @YES,
                                (id)kSecAttrKeySizeInBits: [NSNumber numberWithUnsignedInteger:length],
                                };
    
    SecKeyRef keyRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                          (CFTypeRef *)&keyRef);
    if (status != errSecSuccess) {
        if (status == errSecItemNotFound) {
            return nil;
        }
        if (status != errSecSuccess) {
            // Handle the error. . .
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            [SFSDKCoreLogger e:[self class] format:@"Error getting RSA SecKeyRef with tag %@ and length %d. Error code: %@", keyTagString, length, error.localizedDescription];
            return nil;
        }
    }
    return keyRef;
}

+ (NSData *)getRSAPublicKeyAsDER:(NSData *)keyData {
    // Sequence of length 0xd made up of OID followed by NULL
    static const unsigned char _encodedRSAEncryptionOID[15] = {
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
    };
    
    NSData *publicKeyBits = keyData;
    
    // encoded RSA public key
    unsigned char builder[15];
    NSMutableData * encKey = [[NSMutableData alloc] init];
    unsigned long bitstringEncLength;
    
    // encode bitstring
    if  ([publicKeyBits length ] + 1  < 128 )
        bitstringEncLength = 1 ;
    else
        bitstringEncLength = (([publicKeyBits length ] + 1 ) / 256 ) + 2 ;
    
    // Overall we have a sequence of a certain length
    // ASN.1 encoding representing a SEQUENCE
    builder[0] = 0x30;
    
    // Build up overall size made up of -
    // size of OID + size of bitstring encoding + size of actual key
    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
    [publicKeyBits length];

    size_t j = [self encodeLength:&builder[1] length:i];
    [encKey appendBytes:builder length:j + 1];
    
    // First part of the sequence is the OID
    [encKey appendBytes:_encodedRSAEncryptionOID
                 length:sizeof(_encodedRSAEncryptionOID)];
    
    // Now add the bitstring
    builder[0] = 0x03;
    j = [self encodeLength:&builder[1] length:[publicKeyBits length] + 1];
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];
    
    // Now the actual key
    [encKey appendData:publicKeyBits];
    
    return encKey;
}

+ (size_t)encodeLength:(unsigned char *)buf length:(size_t)length {
    
    // encode length in ASN.1 DER format
    if (length < 128) {
        buf[0] = length;
        return 1;
    }
    
    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; j++) {
        buf[i - j] = length & 0xFF;
        length = length >> 8;
    }
    
    return i + 1;
}

@end
