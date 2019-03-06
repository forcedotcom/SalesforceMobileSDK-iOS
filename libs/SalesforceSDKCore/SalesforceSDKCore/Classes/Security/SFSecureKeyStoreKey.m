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

@property (nonatomic, strong) NSData *appTag;
@property (nonatomic, strong) NSString *label;
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

#pragma mark - Factory methods and constructor

+ (instancetype) createKey:(NSString*)appTag label:(NSString*)label
{
    [SFSecureKeyStoreKey deleteKey:appTag label:label];     // Delete existing key if any
    return [[SFSecureKeyStoreKey alloc] initWithAppTag:appTag label:label autoCreate:YES];
}

+ (instancetype) retrieveKey:(NSString*)appTag label:(NSString*)label
{
    return [[SFSecureKeyStoreKey alloc] initWithAppTag:appTag label:label autoCreate:NO];
}

+ (void) deleteKey:(NSString*)appTag label:(NSString*)label
{
    SFSecureKeyStoreKey* key = [SFSecureKeyStoreKey retrieveKey:appTag label:label];
    if (key) {
        [key deletePublicKey];
        [key deletePrivateKey];
        [key log:@"Deleted key from keychain" status:errSecSuccess];
    }
}

- (instancetype) initWithAppTag:(NSString*)appTag label:(NSString*)label autoCreate:(BOOL)autoCreate
{
    self = [super init];
    if (self) {
        self.appTag = [appTag dataUsingEncoding:NSUTF8StringEncoding];
        self.label = label;
        
        // Use existing key pair if available
        if ([self readPublicKey] == errSecSuccess && [self readPrivateKey] == errSecSuccess) {
            [self log:@"Found existing key" status:errSecSuccess];
            return self;
        }
        
        // Does not exist and should not be auto created
        if (!autoCreate) {
            return nil;
        }

        // Does not exist and should be auto created
        BOOL useEnclave = [SFSecureKeyStoreKey isSecureEnclaveAvailable];
        OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef) [self keyPairAttributes], &publicKeyRef, &privateKeyRef);
        [self log:[NSString stringWithFormat:@"Created key pair (%@using enclave)", useEnclave ? @"" : @"NOT "] status:status];

        // Creation failed
        if (status != errSecSuccess) {
            return nil;
        }
    }
    return self;
}

- (void) dealloc {
    if (privateKeyRef) CFRelease(privateKeyRef);
    if (publicKeyRef) CFRelease(publicKeyRef);
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    SFSecureKeyStoreKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.label = [self.label copy];
    [keyCopy readPublicKey];
    [keyCopy readPrivateKey];
    [self log:@"Copied key" status:errSecSuccess];
    return keyCopy;
}

#pragma mark - Methods to read / write from / to key chain

+ (nullable instancetype)fromKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    return [[SFSecureKeyStoreKey alloc] initWithAppTag:keychainId label:archiverKey autoCreate:NO];
}
    
- (OSStatus) toKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey {
    return [self saveKey];
}

- (OSStatus) saveKey {
    [self deletePublicKey];
    NSDictionary* savePublicKeyDict = @{ (id)kSecClass:              (id)kSecClassKey,
                                         (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPublic,
                                         (id)kSecAttrKeyType:        (id)kSecAttrKeyTypeECSECPrimeRandom,
                                         (id)kSecAttrLabel:          self.publicLabel,
                                         (id)kSecAttrApplicationTag: self.appTag,
                                         (id)kSecValueRef:           (__bridge id)publicKeyRef,
                                         (id)kSecReturnData:         @YES };
    
    CFTypeRef keyBits;
    OSStatus status =  SecItemAdd((__bridge CFDictionaryRef)savePublicKeyDict, &keyBits);
    [self log:@"Saved key to keychain" status:status];
    return status;
}

#pragma mark - Methods to encrypt / decrypt data

- (NSData*)encryptData:(NSData *)dataToEncrypt
{
    CFErrorRef errorRef = NULL;
    CFDataRef encryptedData = SecKeyCreateEncryptedData(publicKeyRef,
                                                        kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM,
                                                        (CFDataRef)dataToEncrypt,
                                                        &errorRef);
    [self log:@"Encrypted data" errorRef:errorRef];
    return (__bridge_transfer NSData*) encryptedData;
}

- (NSData*)decryptData:(NSData *)dataToDecrypt
{
    CFErrorRef errorRef = NULL;
    CFDataRef decryptedData = SecKeyCreateDecryptedData(privateKeyRef,
                                                        kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM,
                                                        (CFDataRef)dataToDecrypt,
                                                        &errorRef);
    [self log:@"Decrypted data" errorRef:errorRef];
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
    NSDictionary* query = @{ (id)kSecClass:              (id)kSecClassKey,
                             (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPrivate,
                             (id)kSecAttrLabel:          self.privateLabel,
//                             (id)kSecAttrApplicationTag: self.appTag,
                             (id)kSecReturnRef:          @YES };
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKeyRef);
    [self log:@"Read private key" status:status];
    return status;
}

- (OSStatus) readPublicKey
{
    NSDictionary* query = @{ (id)kSecClass:              (id)kSecClassKey,
                             (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPublic,
                             (id)kSecAttrLabel:          self.publicLabel,
                             (id)kSecAttrApplicationTag: self.appTag,
                             (id)kSecReturnRef:          @YES };
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&publicKeyRef);
    [self log:@"Read public key" status:status];
    return status;
}

- (OSStatus) deletePublicKey {
    NSDictionary* query = @{ (id)kSecClass:              (id)kSecClassKey,
                             (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPublic,
                             (id)kSecAttrLabel:          self.publicLabel,
                             (id)kSecAttrApplicationTag: self.appTag,
                             };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    while (status == errSecDuplicateItem)
    {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
    [self log:@"Deleted public key" status:status];
    return status;
}

- (OSStatus) deletePrivateKey {
    NSDictionary* query = @{ (id)kSecClass:              (id)kSecClassKey,
                             (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPrivate,
                             (id)kSecAttrLabel:          self.privateLabel,
//                             (id)kSecAttrApplicationTag: self.appTag,
                             };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    while (status == errSecDuplicateItem)
    {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
    [self log:@"Deleted private key" status:status];
    return status;
}

- (NSDictionary*) keyPairAttributes {
    NSMutableDictionary* keyPairAttributes =  [NSMutableDictionary new];
    keyPairAttributes[(id)kSecAttrKeyType] = (id)kSecAttrKeyTypeECSECPrimeRandom;
    keyPairAttributes[(id)kSecAttrKeySizeInBits] = @256;
    keyPairAttributes[(id)kSecPrivateKeyAttrs] = [self privateKeyParams];

    if ([SFSecureKeyStoreKey isSecureEnclaveAvailable]) {
        keyPairAttributes[(id)kSecAttrTokenID] = (id)kSecAttrTokenIDSecureEnclave;
    }

    return keyPairAttributes;
}

- (NSDictionary*) privateKeyParams {

    NSMutableDictionary* privateKeyParams =  [NSMutableDictionary new];
    privateKeyParams[(id)kSecAttrIsPermanent] = @YES;
    privateKeyParams[(id)kSecAttrLabel] = self.privateLabel;
//    privateKeyParams[(id)kSecAttrApplicationTag] = self.appTag;
    
    if ([SFSecureKeyStoreKey isSecureEnclaveAvailable]) {
        CFErrorRef errorRef = NULL;
        SecAccessControlRef privateAccess = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                            kSecAccessControlPrivateKeyUsage,
                                                                            &errorRef);
        if (errorRef == errSecSuccess) {
            privateKeyParams[(id)kSecAttrAccessControl] = (__bridge id)privateAccess;
        }
        [self log:@"Create private access control" errorRef:errorRef];
    }

    return privateKeyParams;
}

/**
 Log info/error message given error (a CFErrorRef)
 @param message a message
 @param errorRef a CFErrorRef
 */
- (void) log:(NSString*)message errorRef:(CFErrorRef)errorRef
{
    if (errorRef == errSecSuccess) {
        [SFSDKCoreLogger i:[self class] format:@"SUCCESS (%@) %@", self.label, message];
    } else {
        NSError *error = CFBridgingRelease(errorRef);  // ARC takes ownership
        [SFSDKCoreLogger e:[self class] format:@"FAILURE (%@) %@: error=%@", self.label, message, error];
    }
}

/**
 Log info/error message given status (a OSStatus)
 @param message a message
 @param status a OSStatus
 */
- (void) log:(NSString*)message status:(OSStatus)status
{
    if (status == errSecSuccess) {
        [SFSDKCoreLogger i:[self class] format:@"SUCCESS (%@) %@", self.label, message];
    } else {
        [SFSDKCoreLogger e:[self class] format:@"FAILURE (%@) %@: error=%d", self.label, message, status];
    }
}

@end
