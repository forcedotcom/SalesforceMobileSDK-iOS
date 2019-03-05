/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

// Other constants
static NSString * const kSecureKeyStorePrivateLabelSuffix = @"private";
static NSString * const kSecureKeyStorePublicLabelSuffix = @"public";

@interface SFSecureKeyStoreKey () {
    SecKeyRef publicKeyRef;
    SecKeyRef privateKeyRef;
}

@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readonly) NSString *privateLabel;
@property (nonatomic, strong, readonly) NSString *publicLabel;

@end

@implementation SFSecureKeyStoreKey

#pragma mark - Utility method

+ (BOOL) isSecureEnclaveAvailable
{
#if TARGET_OS_SIMULATOR
    return NO;
#else
    LAContext *context = [[LAContext alloc] init];
    return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
#endif
}

#pragma mark - Factory method and constructor

+ (instancetype) createKey
{
    NSString* randomLabel = [[SFSDKCryptoUtils randomByteDataWithLength:32] base64Encode];
    return [[SFSecureKeyStoreKey alloc] initWithLabel:randomLabel autoCreate:YES];
}

- (instancetype) initWithLabel:(NSString*)label autoCreate:(BOOL)autoCreate
{
    self = [super init];
    if (self) {
        self.label = label;
        
        // Use existing key pair if available
        if ([self readPublicKey] == errSecSuccess && [self readPrivateKey] == errSecSuccess) {
            return self;
        }
        
        // Does not exist and should not be auto created
        if (!autoCreate) {
            return nil;
        }

        // Does not exist and should be auto created
        NSString* token = (id) ([SFSecureKeyStoreKey isSecureEnclaveAvailable] ? kSecAttrTokenIDSecureEnclave : kSecAttrTokenID);
        NSDictionary* attributes = @{ (id)kSecAttrKeyType:             (id)kSecAttrKeyTypeECSECPrimeRandom,
                                      (id)kSecAttrKeySizeInBits:       @256,
                                      (id)kSecAttrTokenID:             token,
                                      (id)kSecPrivateKeyAttrs:         [self privateKeyParams],
                                      (id)kSecPublicKeyAttrs:          [self publicKeyParams],
                                      };
    
        OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKeyRef, &privateKeyRef);
        if ([self logErrorIfAny:@"Failed to generate key pair" status:status]) {
            return nil;
        }
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    SFSecureKeyStoreKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.label = [self.label copy];
    [keyCopy readPublicKey];
    [keyCopy readPrivateKey];
    return keyCopy;
}

#pragma mark - Methods to read / write from / to key chain

+ (nullable instancetype)fromKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    return [[SFSecureKeyStoreKey alloc] initWithLabel:archiverKey autoCreate:NO];
}
    
- (OSStatus) toKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    NSDictionary* savePublicKeyDict = @{ (id)kSecClass:              (id)kSecClassKey,
                                         (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPublic,
                                         (id)kSecAttrKeyType:        (id)kSecAttrKeyTypeECSECPrimeRandom,
                                         (id)kSecAttrLabel:          self.publicLabel,
                                         (id)kSecValueRef:           (__bridge id)publicKeyRef,
                                         (id)kSecReturnData:         @YES };
    
    CFTypeRef keyBits;
    OSStatus err =  SecItemAdd((__bridge CFDictionaryRef)savePublicKeyDict, &keyBits);
    while (err == errSecDuplicateItem)
    {
        err = SecItemDelete((__bridge CFDictionaryRef)savePublicKeyDict);
    }
    return SecItemAdd((__bridge CFDictionaryRef)savePublicKeyDict, &keyBits);
}

- (void) deleteKey {
    [self deletePublicKey];
    [self deletePrivateKey];
}

#pragma mark - Methods to encrypt / decrypt data

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

#pragma mark - SFKeyStoreKey methods not supported by SFSecureKeyStoreKey

- (instancetype) initWithKey:(SFEncryptionKey *)key
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%@ not supported on SFSecureKeyStoreKey.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
    
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%@ not supported on SFSecureKeyStoreKey.", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}


#pragma mark - Misc private methods

- (NSString*)privateLabel
{
    return [NSString stringWithFormat:@"%@_%@", self.label, kSecureKeyStorePrivateLabelSuffix];
}

- (NSString*)publicLabel
{
    return [NSString stringWithFormat:@"%@_%@", self.label, kSecureKeyStorePublicLabelSuffix];
}

- (OSStatus) readPrivateKey
{
    NSDictionary* query = @{ (id)kSecClass:        (id)kSecClassKey,
                             (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
                             (id)kSecAttrLabel:    self.privateLabel,
                             (id)kSecReturnRef:    @YES };
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKeyRef);
    return status;
}

- (OSStatus) readPublicKey
{
    NSDictionary* query = @{ (id)kSecClass:        (id)kSecClassKey,
                             (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
                             (id)kSecAttrLabel:    self.publicLabel,
                             (id)kSecReturnRef:    @YES };
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&publicKeyRef);
    return status;
}

- (void) deletePublicKey {
    NSDictionary* query = @{ (id)kSecClass:        (id)kSecClassKey,
                             (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
                             (id)kSecAttrLabel:    self.publicLabel };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    while (status == errSecDuplicateItem)
    {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
}

- (void) deletePrivateKey {
    NSDictionary* query = @{ (id)kSecClass:        (id)kSecClassKey,
                             (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
                             (id)kSecAttrLabel:    self.privateLabel };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    while (status == errSecDuplicateItem)
    {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
}

- (NSDictionary*) publicKeyParams {
    return @{
             (id)kSecAttrLabel: self.publicLabel
             };
}

- (NSDictionary*) privateKeyParams {

    NSMutableDictionary* privateKeyParams =  [NSMutableDictionary new];
    privateKeyParams[(id)kSecAttrIsPermanent] = @YES;
    privateKeyParams[(id)kSecAttrLabel] = self.privateLabel;
    
    if ([SFSecureKeyStoreKey isSecureEnclaveAvailable]) {
        CFErrorRef errorRef = NULL;
        SecAccessControlRef privateAccess = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                            kSecAccessControlPrivateKeyUsage,
                                                                            &errorRef);
        
        privateKeyParams[(id)kSecAttrAccessControl] = (__bridge id)privateAccess;
        
        if ([self logErrorIfAny:@"Failed to create key access control" errorRef:errorRef]) {
            // TODO should throw exception
        }
    }

    return privateKeyParams;
}

/**
 Log error if any
 @param errorRef a CFErrorRef
 @return YES if there was an error
 */
- (BOOL) logErrorIfAny:(NSString*)message errorRef:(CFErrorRef)errorRef
{
    if (errorRef != errSecSuccess) {
        NSError *error = CFBridgingRelease(errorRef);  // ARC takes ownership
        [SFSDKCoreLogger e:[self class] format:[NSString stringWithFormat:@"%@ error=%@", message, error]];
        return YES;
    }
    return NO;
}

/**
 Log error if any
 @param status a OSStatus
 @return YES if there was an error
 */
- (BOOL) logErrorIfAny:(NSString*)message status:(OSStatus)status
{
    if (status != errSecSuccess) {
        [SFSDKCoreLogger e:[self class] format:[NSString stringWithFormat:@"%@ error=%d", message, status]];
        return YES;
    }
    return NO;
}


@end
