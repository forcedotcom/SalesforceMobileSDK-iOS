/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthCrypto.h"
#import "SFSDKCryptoUtils.h"
#import "SFKeyStoreManager.h"
#import "SFKeychainItemWrapper.h"
#import "SFCrypto.h"
#import "UIDevice+SFHardware.h"
#import "NSString+SFAdditions.h"

NSString * const kSFOAuthEncryptionTypeKey = @"com.salesforce.oauth.creds.encryption.type";

@implementation SFOAuthKeychainCredentials

@dynamic refreshToken;   // stored in keychain
@dynamic accessToken;    // stored in keychain
@dynamic activationCode; // stored in keychain

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self updateTokenEncryption];
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    self = [super initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted];
    if (self) {
        [self updateTokenEncryption];
    }
    return self;
}

#pragma mark - Public Methods

- (NSString *)accessToken {
    return [self accessTokenWithSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceAccess]];
}

- (void)setAccessToken:(NSString *)token {
    [self setAccessToken:token withSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceAccess]];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [standardUserDefaults synchronize];
}

- (NSString *)refreshToken {
    return [self refreshTokenWithSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
}

- (void)setRefreshToken:(NSString *)token {
    [self setRefreshToken:token withSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [standardUserDefaults synchronize];
}

- (NSString *)activationCode {
    NSData *activationCodeData = [self tokenForService:kSFOAuthServiceActivation];
    if (!activationCodeData) {
        return nil;
    }
    return [[NSString alloc] initWithData:activationCodeData encoding:NSUTF8StringEncoding];
}

// This setter is exposed publicly for unit tests. Other external client code should use the revoke methods.
- (void)setActivationCode:(NSString *)token {
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:kSFOAuthServiceActivation];
    if (!updateSucceeded) {
        [self log:SFLogLevelWarning format:@"%@:%@ - Failed to update legacy activation code.", [self class], NSStringFromSelector(_cmd)];
    }
}

#pragma mark - Private Keychain Methods

- (NSData *)tokenForService:(NSString *)service
{
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    
    SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:service account:self.identifier];
    NSData *tokenData = [keychainItem valueData];
    return tokenData;
}

- (NSString *)accessTokenWithKey:(NSData *)key {
    NSData *accessTokenData = [self tokenForService:kSFOAuthServiceAccess];
    if (!accessTokenData) {
        return nil;
    }
    if (self.isEncrypted) {
        SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOADecrypt key:key];
        NSData *decryptedData = [cipher decryptData:accessTokenData];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:accessTokenData encoding:NSUTF8StringEncoding];
    }
}

- (NSString *)accessTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *accessTokenData = [self tokenForService:kSFOAuthServiceAccess];
    if (!accessTokenData) {
        return nil;
    }
    
    if (self.isEncrypted) {
        NSData *decryptedData = [SFSDKCryptoUtils aes256DecryptData:accessTokenData
                                                            withKey:encryptionKey.key
                                                                 iv:encryptionKey.initializationVector];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:accessTokenData encoding:NSUTF8StringEncoding];
    }
}

- (void)setAccessToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            tokenData = [SFSDKCryptoUtils aes256EncryptData:tokenData
                                                    withKey:encryptionKey.key
                                                         iv:encryptionKey.initializationVector];
        }
    }
    
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:kSFOAuthServiceAccess];
    if (!updateSucceeded) {
        [self log:SFLogLevelWarning format:@"%@:%@ - Failed to update access token.", [self class], NSStringFromSelector(_cmd)];
    }
}

// Only for unit tests of legacy functionality.  Do not use in app code!
- (void)setAccessToken:(NSString *)token withKey:(NSData *)key {
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    
    
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOAEncrypt key:key];
            [cipher encryptData:tokenData];
            tokenData = [cipher finalizeCipher];
        }
    }
    
    BOOL updateSucceeded = [self updateKeychainWithTokenData:tokenData forService:kSFOAuthServiceAccess];
    if (!updateSucceeded) {
        [self log:SFLogLevelWarning format:@"%@:%@ - Failed to update legacy access token.", [self class], NSStringFromSelector(_cmd)];
    }
}

- (NSString *)refreshTokenWithKey:(NSData *)key {
    NSData *refreshTokenData = [self tokenForService:kSFOAuthServiceRefresh];
    if (!refreshTokenData) {
        return nil;
    }
    if (self.isEncrypted) {
        SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOADecrypt key:key];
        NSData *decryptedData = [cipher decryptData:refreshTokenData];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:refreshTokenData encoding:NSUTF8StringEncoding];
    }
}

- (NSString *)refreshTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *refreshTokenData = [self tokenForService:kSFOAuthServiceRefresh];
    if (!refreshTokenData) {
        return nil;
    }
    
    if (self.isEncrypted) {
        NSData *decryptedData = [SFSDKCryptoUtils aes256DecryptData:refreshTokenData
                                                            withKey:encryptionKey.key
                                                                 iv:encryptionKey.initializationVector];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithData:refreshTokenData encoding:NSUTF8StringEncoding];
    }
}

- (void)setRefreshToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)encryptionKey {
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            tokenData = [SFSDKCryptoUtils aes256EncryptData:tokenData
                                                    withKey:encryptionKey.key
                                                         iv:encryptionKey.initializationVector];
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
        [self log:SFLogLevelWarning format:@"%@:%@ - Failed to update refresh token.", [self class], NSStringFromSelector(_cmd)];
    }
}

// Only for unit tests of legacy functionality.  Do not use in app code!
- (void)setRefreshToken:(NSString *)token withKey:(NSData *)key {
    NSData *tokenData = ([token length] > 0 ? [token dataUsingEncoding:NSUTF8StringEncoding] : nil);
    if (tokenData != nil) {
        if (self.isEncrypted) {
            SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOAEncrypt key:key];
            [cipher encryptData:tokenData];
            tokenData = [cipher finalizeCipher];
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
        [self log:SFLogLevelWarning format:@"%@:%@ - Failed to update legacy refresh token.", [self class], NSStringFromSelector(_cmd)];
    }
}

- (BOOL)updateKeychainWithTokenData:(NSData *)tokenData forService:(NSString *)service
{
    if (!([self.identifier length] > 0)) {
        @throw SFOAuthInvalidIdentifierException();
    }
    
    
    SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:service account:self.identifier];
    BOOL keychainOperationSuccessful;
    if (tokenData != nil) {
        OSStatus result = [keychainItem setValueData:tokenData];
        keychainOperationSuccessful = (result == errSecSuccess || result == errSecItemNotFound);
        if (!keychainOperationSuccessful) { // errSecItemNotFound is an expected condition
            [self log:SFLogLevelWarning format:@"%@:%@ - Error saving token data to keychain: %@", [self class], NSStringFromSelector(_cmd), [SFKeychainItemWrapper keychainErrorCodeString:result]];
        }
    } else {
        keychainOperationSuccessful = [keychainItem resetKeychainItem];
        if (!keychainOperationSuccessful) {
            [self log:SFLogLevelWarning format:@"%@:%@ - Error resetting keychain data.", [self class], NSStringFromSelector(_cmd)];
        }
    }
    
    return keychainOperationSuccessful;
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
    SFEncryptionKey *keyForService = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:service keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
    return keyForService;
}

- (NSData *)keyWithSeed:(NSString *)seed service:(NSString *)service
{
    NSString *strSecret = [seed stringByAppendingString:service];
    return [strSecret sha256];
}

- (void)updateTokenEncryption
{
    // Convert encryption keys to latest format--currently kSFOAuthCredsEncryptionTypeKeyStore--if
    // it's in an older format, and if it's possible.  It won't be possible, for instance, to convert
    // MAC address-based keys if the user is on iOS 7 or above, and we'll reset the tokens to nil;
    
    if (!self.isEncrypted) return;
    SFOAuthCredsEncryptionType encType = (SFOAuthCredsEncryptionType)[[NSUserDefaults standardUserDefaults] integerForKey:kSFOAuthEncryptionTypeKey];
    if (encType == kSFOAuthCredsEncryptionTypeKeyStore) return;
    
    // Try to convert the old tokens to the new format.
    NSString *origAccessToken;
    NSString *origRefreshToken;
    switch (encType) {
        case kSFOAuthCredsEncryptionTypeNotSet:
        case kSFOAuthCredsEncryptionTypeMac:
            [self log:SFLogLevelDebug msg:@"Token encryption type either not set, or based on MAC address."];
            origAccessToken = [self accessTokenWithKey:[self keyMacForService:kSFOAuthServiceAccess]];
            origRefreshToken = [self refreshTokenWithKey:[self keyMacForService:kSFOAuthServiceRefresh]];
            break;
        case kSFOAuthCredsEncryptionTypeIdForVendor:
            [self log:SFLogLevelDebug msg:@"Token encryption based on identifier for vendor."];
            origAccessToken = [self accessTokenWithKey:[self keyVendorIdForService:kSFOAuthServiceAccess]];
            origRefreshToken = [self refreshTokenWithKey:[self keyVendorIdForService:kSFOAuthServiceRefresh]];
            break;
        case kSFOAuthCredsEncryptionTypeBaseAppId:
            [self log:SFLogLevelDebug msg:@"Token encryption based on base application identifier."];
            origAccessToken = [self accessTokenWithKey:[self keyBaseAppIdForService:kSFOAuthServiceAccess]];
            origRefreshToken = [self refreshTokenWithKey:[self keyBaseAppIdForService:kSFOAuthServiceRefresh]];
            break;
        default:  // Some undefined enum value?
            [self log:SFLogLevelDebug format:@"Unknown token encryption.  Enum value '%d'", encType];
            origAccessToken = nil;
            origRefreshToken = nil;
    }
    
    if ([origAccessToken length] > 0) {
        [self log:SFLogLevelDebug msg:@"SFOAuthCredentials: Old access token encryption format detected.  Updating encryption."];
        self.accessToken = origAccessToken;  // Default setter automatically uses updated encryption method.
    } else {
        [self log:SFLogLevelDebug msg:@"SFOAuthCredentials: Either access token does not exist, or could not decrypt access token with old encryption format.  Clearing the credentials."];
        self.accessToken = nil;
    }
    
    if ([origRefreshToken length] > 0) {
        [self log:SFLogLevelDebug msg:@"SFOAuthCredentials: Old refresh token encryption format detected.  Updating encryption."];
        self.refreshToken = origRefreshToken;  // Default setter automatically uses updated encryption method.
    } else {
        [self log:SFLogLevelDebug msg:@"SFOAuthCredentials: Either refresh token does not exist, or could not decrypt refresh token with old encryption format.  Clearing the credentials."];
        self.refreshToken = nil;
    }
}

@end
