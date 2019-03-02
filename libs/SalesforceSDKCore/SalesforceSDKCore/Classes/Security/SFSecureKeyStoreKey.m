/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSecureKeyStoreKey.h"
#import "SFSDKCryptoUtils.h"
#import "NSData+SFAdditions.h"
#include "TargetConditionals.h"
#import <LocalAuthentication/LocalAuthentication.h>

// NSCoding constants
static NSString * const kSecureKeyStoreKeyLabel = @"com.salesforce.keystore.secureKeyStoreKeyLabel";

@interface SFSecureKeyStoreKey () {
    SecKeyRef publicKeyRef;
    SecKeyRef privateKeyRef;
}

@property (nonatomic, strong, readwrite) NSString *label;

@end

@implementation SFSecureKeyStoreKey

+ (BOOL) isSecureEnclaveAvailable
{
#if TARGET_OS_SIMULATOR
    return NO;
#else
    LAContext *context = [[LAContext alloc] init];
    return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
#endif
}

+ (instancetype) createKey
{
    NSString* randomLabel = [[SFSDKCryptoUtils randomByteDataWithLength:32] base64Encode];
    return [[SFSecureKeyStoreKey alloc] initWithLabel:randomLabel];
}

- (instancetype) initWithKey:(SFEncryptionKey *)key
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%@ not supported on SFSecureKeyStoreKey.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
    
}

- (instancetype) initWithLabel:(NSString*)label
{
    self = [super init];
    if (self) {
        self.label = label;

        CFErrorRef error = NULL;
        SecAccessControlRef privateAccess = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                            kSecAccessControlPrivateKeyUsage,
                                                                            &error);
        // TODO deal with error
        //        if (error != errSecSuccess) {
        //            NSError *err = CFBridgingRelease(error);  // ARC takes ownership
        //            [SFSDKCoreLogger e:[self class] format:@"Failed to generate key: %@", err];
        //            self = nil;
        //        }


        NSDictionary* attributes = @{ (id)kSecAttrKeyType:             (id)kSecAttrKeyTypeECSECPrimeRandom,
                                      (id)kSecAttrKeySizeInBits:       @256,
                                      (id)kSecAttrTokenID:             (id)kSecAttrTokenIDSecureEnclave,
                                      (id)kSecPrivateKeyAttrs:
                                          @{ (id)kSecAttrIsPermanent:    @YES,
                                             (id)kSecAttrApplicationTag: label,
                                             (id)kSecAttrAccessControl:  (__bridge id)privateAccess,
                                             },
                                      };
    
        OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKeyRef, &privateKeyRef);
            
        if (status != errSecSuccess) {
            [SFSDKCoreLogger e:[self class] format:@"Failed to generate key pair: %d", status];
            self = nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.label forKey:kSecureKeyStoreKeyLabel];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    SFSecureKeyStoreKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.label = [self.label copy];
    return keyCopy;
}

+ (nullable instancetype)fromKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    // TODO implement method
    return nil;
}

- (OSStatus) toKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    // TODO implement method
    return noErr;
}

- (NSData*)encryptData:(NSData *)dataToEncrypt
{
    CFErrorRef error = NULL;
    CFDataRef encryptedData = SecKeyCreateEncryptedData(publicKeyRef,
                                                        kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM,
                                                        (CFDataRef)dataToEncrypt,
                                                        &error);
    // TODO deal with error
    return (__bridge_transfer NSData*) encryptedData;
}

- (NSData*)decryptData:(NSData *)dataToDecrypt
{
    CFErrorRef error = NULL;
    CFDataRef decryptedData = SecKeyCreateDecryptedData(privateKeyRef,
                                                        kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM,
                                                        (CFDataRef)dataToDecrypt,
                                                        &error);
    // TODO deal with error
    return (__bridge_transfer NSData*) decryptedData;
}

@end
