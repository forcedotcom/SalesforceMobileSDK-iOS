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

#import "SFSecureEncryptionKey.h"
#import "SFSDKCryptoUtils.h"
#import "NSData+SFAdditions.h"

// NSCoding constants
static NSString * const kSecureEncryptionKeyCodingValue = @"com.salesforce.encryption.securekey.label";

@interface SFSecureEncryptionKey () {
    SecKeyRef publicKeyRef;
    SecKeyRef privateKeyRef;
}

@property (nonatomic, strong) NSString *label;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation SFSecureEncryptionKey
#pragma clang diagnostic pop

#pragma mark - Factory methods and constructor

+ (instancetype) createKey:(NSString*)label
{
    [SFSDKCryptoUtils deleteECKeyPairWithName:label]; // Delete existing key if any
    return [[SFSecureEncryptionKey alloc] initWithLabel:label autoCreate:YES];
}

+ (instancetype) retrieveKey:(NSString*)label
{
    return [[SFSecureEncryptionKey alloc] initWithLabel:label autoCreate:NO];
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
        BOOL useEnclave = [SFSDKCryptoUtils isSecureEnclaveAvailable];
        [SFSDKCryptoUtils createECKeyPairWithName:label
                              accessibleAttribute:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                                 useSecureEnclave:useEnclave];
        
        // Creation successful
        if ([self getKeyRefs]) {
            [SFSDKCoreLogger i:[self class] format:@"Creating secure key %@using secure enclave", useEnclave ? @"" : @"NOT "];
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

#pragma mark - Methods for NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    SFSecureEncryptionKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.label = [self.label copy];
    if ([keyCopy getKeyRefs]) {
        return keyCopy;
    } else {
        return nil;
    }
}

#pragma mark - Methods for NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.label = [aDecoder decodeObjectForKey:kSecureEncryptionKeyCodingValue];
        
        if ([self getKeyRefs]) {
            return self;
        }
        else {
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.label forKey:kSecureEncryptionKeyCodingValue];
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

#pragma mark - SFEncryptionKey methods not supported by SFSecureKeyStoreKey

- (id)initWithData:(NSData *)keyData initializationVector:(nullable NSData *)iv;
{
    @throw [self notSupportedExceptionFor:NSStringFromSelector(_cmd)];
}

- (NSData*) key
{
    @throw [self notSupportedExceptionFor:NSStringFromSelector(_cmd)];
}

- (NSData*) initializationVector
{
    @throw [self notSupportedExceptionFor:NSStringFromSelector(_cmd)];
}

- (NSString*) keyAsString
{
    @throw [self notSupportedExceptionFor:NSStringFromSelector(_cmd)];
}

- (NSString*) initializationVectorAsString
{
    @throw [self notSupportedExceptionFor:NSStringFromSelector(_cmd)];
}

#pragma mark - Misc private methods

- (BOOL) getKeyRefs
{
    publicKeyRef = [SFSDKCryptoUtils getECPublicKeyRefWithName:self.label];
    privateKeyRef = [SFSDKCryptoUtils getECPrivateKeyRefWithName:self.label];
    
    return (privateKeyRef && publicKeyRef);
}

- (NSException*) notSupportedExceptionFor:(NSString*)methodName
{
    return [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%@ not supported on SFSecureEncryptionKey.", methodName]
                                 userInfo:nil];
    
}
@end
