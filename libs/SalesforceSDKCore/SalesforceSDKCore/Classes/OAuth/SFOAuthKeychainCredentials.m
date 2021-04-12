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
#import "SFKeyStoreManager.h"
#import "SFCrypto.h"
#import "UIDevice+SFHardware.h"
#import "NSString+SFAdditions.h"
#import  <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
NSString * const kSFOAuthEncryptionTypeKey = @"com.salesforce.oauth.creds.encryption.type";

@implementation SFOAuthKeychainCredentials

@dynamic refreshToken;   // stored in keychain
@dynamic accessToken;    // stored in keychain

- (id)initWithCoder:(NSCoder *)coder {
    return [super initWithCoder:coder];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    return [super initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted];
}

#pragma mark - Public Methods

- (NSString *)accessToken {
    return [self accessTokenWithSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceAccess]];
}

- (void)setAccessToken:(NSString *)token {
    [self setAccessToken:token withSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceAccess]];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults msdkUserDefaults];
    [standardUserDefaults setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [standardUserDefaults synchronize];
}

- (NSString *)refreshToken {
    return [self refreshTokenWithSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
}

- (void)setRefreshToken:(NSString *)token {
    [self setRefreshToken:token withSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults msdkUserDefaults];
    [standardUserDefaults setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [standardUserDefaults synchronize];
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

- (NSString *)accessTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *accessTokenData = [self tokenForService:kSFOAuthServiceAccess];
    if (!accessTokenData) {
        return nil;
    }
    
    if (self.isEncrypted) {
        NSData *decryptedData = [encryptionKey decryptData:accessTokenData];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:accessTokenData encoding:NSUTF8StringEncoding];
    }
}

- (void)setAccessToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            tokenData = [encryptionKey encryptData:tokenData];
        }
    }
    
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:kSFOAuthServiceAccess];
    if (!updateSucceeded) {
        [SFSDKCoreLogger w:[self class] format:@"%@:%@ - Failed to update access token.", [self class], NSStringFromSelector(_cmd)];
    }
}

- (NSString *)refreshTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *refreshTokenData = [self tokenForService:kSFOAuthServiceRefresh];
    if (!refreshTokenData) {
        return nil;
    }
    
    if (self.isEncrypted) {
        NSData *decryptedData = [encryptionKey decryptData:refreshTokenData];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:refreshTokenData encoding:NSUTF8StringEncoding];
    }
}

- (void)setRefreshToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            tokenData = [encryptionKey encryptData:tokenData];
        }
    } else {
        self.instanceUrl = nil;
        self.communityId  = nil;
        self.communityUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
    
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:kSFOAuthServiceRefresh];
    if (!updateSucceeded) {
        [SFSDKCoreLogger w:[self class] format:@"%@:%@ - Failed to update refresh token.", [self class], NSStringFromSelector(_cmd)];
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

- (NSData *)keyMacForService:(NSString *)service
{
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
    NSString *macAddress = [[UIDevice currentDevice] macaddress];
    return [self keyWithSeed:macAddress service:service];
#else
#warning OS X equivalent not yet implemented
    return nil;
#endif
}

- (NSData *)keyVendorIdForService:(NSString *)service
{
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
    NSString *idForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return [self keyWithSeed:idForVendor service:service];
#else
#warning OS X equivalent not yet implemented
    return nil;
#endif
}

- (NSData *)keyBaseAppIdForService:(NSString *)service
{
    NSString *baseAppId = [SFCrypto baseAppIdentifier];
    return [self keyWithSeed:baseAppId service:service];
}

- (SFEncryptionKey *)keyStoreKeyForService:(NSString *)service
{
    SFEncryptionKey *keyForService = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:service autoCreate:YES];
    return keyForService;
}

- (NSData *)keyWithSeed:(NSString *)seed service:(NSString *)service
{
    NSString *strSecret = [seed stringByAppendingString:service];
    return [strSecret sha256];
}

@end
