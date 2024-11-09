/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthKeychainCredentials.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKCryptoUtils.h"
#import "UIDevice+SFHardware.h"
#import "NSString+SFAdditions.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

@implementation SFOAuthKeychainCredentials

@dynamic refreshToken;   // stored in keychain
@dynamic accessToken;    // stored in keychain

- (id)initWithCoder:(NSCoder *)coder {
    return [super initWithCoder:coder];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    return [super initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - Public Methods

- (NSString *)accessToken {
    return [self decryptedTokenForService:kSFOAuthServiceAccess];
}

- (void)setAccessToken:(NSString *)token {
    [self encryptToken:token forService:kSFOAuthServiceAccess];
}

- (NSString *)refreshToken {
    return [self decryptedTokenForService:kSFOAuthServiceRefresh];
}

- (void)setRefreshToken:(NSString *)token {
    [self encryptToken:token forService:kSFOAuthServiceRefresh];
}

- (NSString *)lightningSid {
    return [self decryptedTokenForService:kSFOAuthServiceLightningSid];
}

- (void)setLightningSid:(NSString *)sid {
    [self encryptToken:sid forService:kSFOAuthServiceLightningSid];
}

- (NSString *)vfSid {
    return [self decryptedTokenForService:kSFOAuthServiceVfSid];
}

- (void)setVfSid:(NSString *)sid {
    [self encryptToken:sid forService:kSFOAuthServiceVfSid];
}

- (NSString *)contentSid {
    return [self decryptedTokenForService:kSFOAuthServiceContentSid];
}

- (void)setContentSid:(NSString *)sid {
    [self encryptToken:sid forService:kSFOAuthServiceContentSid];
}

- (NSString *)csrfToken {
    return [self decryptedTokenForService:kSFOAuthServiceCsrf];
}

- (void)setCsrfToken:(NSString *)token {
    [self encryptToken:token forService:kSFOAuthServiceCsrf];
}


#pragma mark - Private Keychain Methods
- (NSData *)tokenForService:(NSString *)service
{
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    SFSDKKeychainResult *result = [SFSDKKeychainHelper createIfNotPresentWithService:service account:self.identifier];
    NSData *tokenData = result.data;
    if (result.error) {
        [SFSDKCoreLogger e:[self class] format:@"Could not read %@ from keychain, %@", service, result.error];
    }
    return tokenData;
}

- (NSString *)decryptedTokenForService:(NSString *)service {
    NSData* encryptionKey = [self encryptionKeyForService:service];
    NSData *data = [self tokenForService:service];
    if (!data) {
        return nil;
    }
    
    if (self.isEncrypted) {
        NSData *decryptedData = [SFSDKEncryptor decryptData:data key:encryptionKey error:nil];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
}

- (void)encryptToken:(NSString *)token forService:(NSString *)service {
    NSData* encryptionKey = [self encryptionKeyForService:service];
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            tokenData = [SFSDKEncryptor encryptData:tokenData key:encryptionKey error:nil];
        }
    }
    
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:service];
    if (!updateSucceeded) {
        [SFSDKCoreLogger w:[self class] format:@"%@:%@ - Failed to update %@.", [self class], service];
    }
}

- (BOOL)updateKeychainWithTokenData:(NSData *)tokenData forService:(NSString *)service
{
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    SFSDKKeychainResult *result = [SFSDKKeychainHelper createIfNotPresentWithService:service account:self.identifier];
    if (tokenData != nil) {
        result = [SFSDKKeychainHelper writeWithService:service data:tokenData account:self.identifier];
        if (!result.success) {
            [SFSDKCoreLogger w:[self class] format:@"%@:%@ - Error saving token data to keychain: %@", [self class], NSStringFromSelector(_cmd), result.error];
        }
    } else {
        result = [SFSDKKeychainHelper resetWithService:service account:self.identifier];
        if (!result.success) {
            [SFSDKCoreLogger w:[self class] format:@"%@:%@ - Error resetting tokenData in keychain: %@", [self class], NSStringFromSelector(_cmd), result.error];
        }
    }
    
    return result.success;
}

- (NSData *)encryptionKeyForService:(NSString *)service {
    NSData *keyForService = [SFSDKKeyGenerator encryptionKeyFor:service error:nil];
    return keyForService;
}

@end
