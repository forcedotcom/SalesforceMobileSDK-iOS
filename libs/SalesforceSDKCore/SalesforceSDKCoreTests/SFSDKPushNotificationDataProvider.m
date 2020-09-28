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

#import <SalesforceSDKCore/SFSDKPushNotificationFieldsConstants.h>
#import <SalesforceSDKCore/SFEncryptionKey.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SFSDKPushNotificationDataProvider.h"
#import "SFSDKPushNotificationEncryptionConstants.h"

static NSUInteger const kEncryptionKeyLengthBytes = 16;
static NSUInteger const kEncryptionIVLengthBytes = 16;

@implementation SFSDKPushNotificationDataProvider

- (instancetype)initWithContentJSON:(NSString *)contentJSON {
    self = [super init];
    if (self) {
        if (contentJSON != nil) {
            _contentJSONData = [contentJSON dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    return self;
}

- (instancetype)initWithContentObj:(id)contentObj {
    self = [super init];
    if (self) {
        if (contentObj != nil) {
            _contentJSONData = [SFJsonUtils JSONDataRepresentation:contentObj];
        }
    }
    return self;
}

- (NSDictionary *)userInfoDict {
    SFEncryptionKey *key = [self createEncryptionKey];
    NSDictionary *userInfo = @{ kRemoteNotificationKeyEncrypted: @YES,
                                kRemoteNotificationKeySecret: [self encryptKeyUsingRSAPublicKey:key],
                                kRemoteNotificationKeyAps: @{
                                        kRemoteNotificationKeyAlert: @{
                                                kRemoteNotificationKeyTitle:@"Title",
                                                kRemoteNotificationKeyBody:@"Body",
                                                @"key1": @"value1"
                                                }
                                        }
                                };
    NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];
    if (_contentJSONData != nil) {
        mutableUserInfo[kRemoteNotificationKeyContent] = [self encryptContentUsingKey:key];
    }
    return [mutableUserInfo copy];
}

- (nonnull SFEncryptionKey *)createEncryptionKey {
    NSData *keyBytes = [SFSDKCryptoUtils randomByteDataWithLength:kEncryptionKeyLengthBytes];
    NSData *ivBytes = [SFSDKCryptoUtils randomByteDataWithLength:kEncryptionIVLengthBytes];
    return [[SFEncryptionKey alloc] initWithData:keyBytes initializationVector:ivBytes];
}

- (nonnull NSString *)encryptKeyUsingRSAPublicKey:(nonnull SFEncryptionKey *)key {
    NSMutableData *fullKeyData = [[NSMutableData alloc] initWithData:key.key];
    [fullKeyData appendData:key.initializationVector];
    
    SecKeyRef publicKeyRef = [self getPublicKeyRef];
    NSData *encryptedKeyData = [SFSDKCryptoUtils encryptUsingRSAforData:fullKeyData withKeyRef:publicKeyRef];
    CFRelease(publicKeyRef);
    return [encryptedKeyData base64EncodedStringWithOptions:0];
}

- (nonnull NSString *)encryptContentUsingKey:(nonnull SFEncryptionKey *)key {
    NSAssert(_contentJSONData != nil, @"Content object must not be nil in this method.");
    NSData *encryptedContentData = [SFSDKCryptoUtils aes128EncryptData:_contentJSONData withKey:key.key iv:key.initializationVector];
    return [encryptedContentData base64EncodedStringWithOptions:0];
}

- (nonnull SecKeyRef)getPublicKeyRef {
    SecKeyRef publicKeyRef = [SFSDKCryptoUtils getRSAPublicKeyRefWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength];
    if (publicKeyRef == NULL) {
        [SFSDKCryptoUtils createRSAKeyPairWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength accessibleAttribute:kSecAttrAccessibleAfterFirstUnlock];
        publicKeyRef = [SFSDKCryptoUtils getRSAPublicKeyRefWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength];
        NSAssert(publicKeyRef != NULL, @"Could not get RSA public key.");
    }
    return publicKeyRef;
}

@end
