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

// Other constants
static NSString * const kSecureKeyStorePrivateLabelSuffix = @"private";
static NSString * const kSecureKeyStorePublicLabelSuffix = @"public";

@interface SFSecureKeyStoreKey () {
    SecKeyRef publicKeyRef;
    SecKeyRef privateKeyRef;
}

@property (nonatomic, strong) NSString *label;

@end

@implementation SFSecureKeyStoreKey

#pragma mark - Factory methods and constructor

+ (instancetype) createKey:(NSString*)label
{
    [SFSDKCryptoUtils deleteECKeyPairWithName:label]; // Delete existing key if any
    return [[SFSecureKeyStoreKey alloc] initWithLabel:label autoCreate:YES];
}

+ (instancetype) retrieveKey:(NSString*)label
{
    return [[SFSecureKeyStoreKey alloc] initWithLabel:label autoCreate:NO];
}

+ (void) deleteKey:(NSString*)label
{
    [SFSDKCryptoUtils deleteECKeyPairWithName:label];
}

- (instancetype) initWithLabel:(NSString*)label autoCreate:(BOOL)autoCreate
{
    self = [super init];
    if (self) {
        self.label = label;
        
        // Use existing key pair if available
        if ([self getKeyRefs]) {
            return self;
        }
        
        // Does not exist and should not be auto created
        if (!autoCreate) {
            return nil;
        }

        // Does not exist and should be auto created
        [SFSDKCryptoUtils createECKeyPairWithName:label
                              accessibleAttribute:kSecAttrAccessibleAlways
                                 useSecureEnclave:[SFSDKCryptoUtils isSecureEnclaveAvailable]];

        // Creation successful
        if ([self getKeyRefs]) {
            return self;
        }
        // Creation failed
        else {
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
    [keyCopy getKeyRefs];
    return keyCopy;
}

#pragma mark - Methods to read / write from / to key chain

+ (nullable instancetype)fromKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    return [[SFSecureKeyStoreKey alloc] initWithLabel:keychainId autoCreate:NO];
}
    
- (OSStatus) toKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey {
    // key is created in the keychain - nothing to do here
    return errSecSuccess;
}


#pragma mark - Methods to encrypt / decrypt data

- (NSData*)encryptData:(NSData *)dataToEncrypt
{
    return [SFSDKCryptoUtils encryptUsingECforData:dataToEncrypt withKeyRef:publicKeyRef];
}

- (NSData*)decryptData:(NSData *)dataToDecrypt
{
    return [SFSDKCryptoUtils decryptUsingECforData:dataToDecrypt withKeyRef:privateKeyRef];
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

- (BOOL) getKeyRefs
{
    publicKeyRef = [SFSDKCryptoUtils getECPublicKeyRefWithName:self.label];
    privateKeyRef = [SFSDKCryptoUtils getECPrivateKeyRefWithName:self.label];

    return (privateKeyRef && publicKeyRef);
}
@end
