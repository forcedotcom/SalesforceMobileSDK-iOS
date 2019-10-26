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

#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SFSDKPushNotificationDecryption.h"
#import "SFSDKPushNotificationDecryption+Internal.h"
#import "SFSDKPushNotificationFieldsConstants.h"
#import "SFSDKPushNotificationError.h"
#import "SFSDKPushNotificationEncryptionConstants.h"

@implementation SFSDKPushNotificationDecryption

#pragma mark - Public Methods

+ (BOOL)decryptNotificationContent:(UNMutableNotificationContent *)notificationContent
                             error:(NSError **)error {
    if ([notificationContent.userInfo[kRemoteNotificationKeyEncrypted] boolValue] == NO) {
        // Not encrypted. No action necessary.
        return YES;
    }
    
    NSError *dataValidationError = nil;
    BOOL validData = [self validateNotificationUserInfo:notificationContent.userInfo error:&dataValidationError];
    if (!validData) {
        return NO;
    }
    
    NSString *secret = notificationContent.userInfo[kRemoteNotificationKeySecret];
    NSError *decryptSecretError = nil;
    SFEncryptionKey *encryptionKey = [self getAESKeyFromSecret:secret error:&decryptSecretError];
    if (encryptionKey == nil) {
        if (error) {
            *error = decryptSecretError;
        }
        return NO;
    }
    
    NSString *encryptedContent = notificationContent.userInfo[kRemoteNotificationKeyContent];
    NSError *decryptContentError = nil;
    NSString *contentString = [self aesDecryptString:encryptedContent withKey:encryptionKey error:&decryptContentError];
    if (contentString == nil) {
        if (error) {
            *error = decryptContentError;
        }
        return NO;
    }
    
    id contentDict = [SFJsonUtils objectFromJSONString:contentString];
    if (contentDict == nil || ![contentDict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorInvalidContentFormat description:@"Decrypted content is not a valid JSON dictionary."];
        }
        return NO;
    }
    
    // Apply decrypted content.
    NSMutableDictionary *updateUserInfo = [notificationContent.userInfo mutableCopy];
    for (NSString *itemKey in contentDict) {
        updateUserInfo[itemKey] = contentDict[itemKey];
    }
    [updateUserInfo removeObjectForKey:kRemoteNotificationKeyContent];
    notificationContent.userInfo = [updateUserInfo copy];
    
    // Apply alert.
    notificationContent.title = notificationContent.userInfo[kRemoteNotificationKeyAlertTitle];
    notificationContent.body = notificationContent.userInfo[kRemoteNotificationKeyAlertBody];
    
    // Update alert body string.
    NSDictionary *apsDict = notificationContent.userInfo[kRemoteNotificationKeyAps];
    NSDictionary *alertDict = apsDict[kRemoteNotificationKeyAlert];
    
    NSMutableDictionary *updateAlertDict = [alertDict mutableCopy];
    id remoteNotificationBody = alertDict[kRemoteNotificationKeyBody];
    if (remoteNotificationBody != nil) {
        updateAlertDict[kRemoteNotificationKeyBody] = notificationContent.body;
    }
    id remoteNotificationTitle = alertDict[kRemoteNotificationKeyTitle];
    if (remoteNotificationTitle != nil) {
        updateAlertDict[kRemoteNotificationKeyTitle] = notificationContent.title;
    }
    NSMutableDictionary *updateApsDict = [apsDict mutableCopy];
    updateApsDict[kRemoteNotificationKeyAlert] = [updateAlertDict copy];
    updateUserInfo = [notificationContent.userInfo mutableCopy];
    updateUserInfo[kRemoteNotificationKeyAps] = [updateApsDict copy];
    notificationContent.userInfo = [updateUserInfo copy];

    return YES;
}

#pragma mark - Private methods

+ (BOOL)validateNotificationUserInfo:(NSDictionary *)userInfo error:(NSError **)error {
    id secret = userInfo[kRemoteNotificationKeySecret];
    if (secret == nil || ![secret isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoEncryptedSecret description:@"No secret data in the notification content."];
        }
        return NO;
    }
    
    id encryptedContent = userInfo[kRemoteNotificationKeyContent];
    if (encryptedContent == nil || ![encryptedContent isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoEncryptedContent description:@"No content data in the notification content."];
        }
        return NO;
    }
    
    id apsDict = userInfo[kRemoteNotificationKeyAps];
    if (apsDict == nil || ![apsDict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoApsDictionary description:@"No aps data in the notification content."];
        }
        return NO;
    }
    id alertDict = apsDict[kRemoteNotificationKeyAlert];
    if (alertDict == nil || ![alertDict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoApsAlertDictionary description:@"No alert data in the aps content of the notification."];
        }
        return NO;
    }
    
    id title = alertDict[kRemoteNotificationKeyTitle];
    if (title == nil || ![title isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoApsAlertTitle description:@"No alert title in the notification content."];
        }
        return NO;
    }
    
    id body = alertDict[kRemoteNotificationKeyBody];
    if (body == nil || ![body isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorNoApsAlertBody description:@"No alert body in the notification content."];
        }
        return NO;
    }
    
    return YES;
}

+ (nonnull NSError *)pushErrorWithCode:(NSInteger)code description:(nonnull NSString *)description {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: description };
    NSError *error = [[NSError alloc] initWithDomain:SFSDKPushNotificationErrorDomain code:code userInfo:userInfo];
    return error;
}

+ (SFEncryptionKey *)getAESKeyFromSecret:(NSString *)secret error:(NSError **)error {
    NSData *secretData = [[NSData alloc] initWithBase64EncodedString:secret options:0];
    if (secretData == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorMalformedSecretData description:@"Encrypted secret is an invalid Base64 string."];
        }
        return nil;
    }
    SecKeyRef privateKeyRef = [SFSDKCryptoUtils getRSAPrivateKeyRefWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength];
    if (privateKeyRef == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorPrivateRSAKeyNotFound description:@"Could not retrieve private RSA key for encrypted notification."];
        }
        return nil;
    }
    NSData *decryptedData = [SFSDKCryptoUtils decryptUsingRSAforData:secretData withKeyRef:privateKeyRef];
    CFRelease(privateKeyRef);
    if (decryptedData == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorSecretDecryptionFailed description:@"Failed to decrypt secret with RSA private key."];
        }
        return nil;
    }
    
    NSData *keyData = [decryptedData subdataWithRange:NSMakeRange(0, 16)];
    NSData *ivData = [decryptedData subdataWithRange:NSMakeRange(16, 16)];
    return [[SFEncryptionKey alloc] initWithData:keyData initializationVector:ivData];
}

+ (NSString *)aesDecryptString:(NSString *)encryptedString withKey:(SFEncryptionKey *)key error:(NSError **)error {
    NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
    if (encryptedData == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorMalformedContentData description:@"Encrypted content is an invalid Base64 string."];
        }
        return nil;
    }
    
    NSData *decryptedData = [SFSDKCryptoUtils aes128DecryptData:encryptedData withKey:key.key iv:key.initializationVector];
    if (decryptedData == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorContentDecryptionFailed description:@"Failed to decrypt content with symmetric secret key."];
        }
        return nil;
    }
    
    NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    if (decryptedString == nil) {
        if (error) {
            *error = [self pushErrorWithCode:SFSDKPushNotificationErrorContentDecryptionFailed description:@"Failed to decrypt content with symmetric secret key."];
        }
        return nil;
    }
    return decryptedString;
}

@end
