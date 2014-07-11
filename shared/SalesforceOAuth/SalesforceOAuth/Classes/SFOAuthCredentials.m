/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import <Security/Security.h>
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthCrypto.h"
#import "SFOAuth_UIDevice+Hardware.h"
#import "SFOAuth_NSString+Additions.h"
#import <SalesforceCommonUtils/SFCrypto.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import <SalesforceSecurity/SFSDKCryptoUtils.h>
#import <SalesforceSecurity/SFKeyStoreManager.h>

static NSString * const kSFOAuthArchiveVersion         = @"1.0.3"; // internal version included when archiving via encodeWithCoder

static NSString * const kSFOAuthAccessGroup            = @"com.salesforce.oauth";
static NSString * const kSFOAuthProtocolHttps          = @"https";

NSString * const kSFOAuthServiceAccess          = @"com.salesforce.oauth.access";
NSString * const kSFOAuthServiceRefresh         = @"com.salesforce.oauth.refresh";
NSString * const kSFOAuthServiceActivation      = @"com.salesforce.oauth.activation";

static NSString * const kSFOAuthDefaultDomain          = @"login.salesforce.com";

NSString * const kSFOAuthEncryptionTypeKey = @"com.salesforce.oauth.creds.encryption.type";

@interface SFOAuthCredentials () 

//This property is intentionally readonly in the public header files.
@property (nonatomic, readwrite, strong) NSString *protocol;
    
@end
static NSException * kSFOAuthExceptionNilIdentifier;

@implementation SFOAuthCredentials

@synthesize identifier                = _identifier;
@synthesize domain                    = _domain;
@synthesize clientId                  = _clientId;
@synthesize redirectUri               = _redirectUri;
@synthesize organizationId            = _organizationId; // cached org ID dervied from identityURL
@synthesize identityUrl               = _identityUrl;
@synthesize userId                    = _userId;         // cached user ID derived from identityURL
@synthesize instanceUrl               = _instanceUrl;
@synthesize issuedAt                  = _issuedAt;
@synthesize logLevel                  = _logLevel;
@synthesize protocol                  = _protocol;
@synthesize encrypted                 = _encrypted;
@synthesize legacyIdentityInformation = _legacyIdentityInformation;

@dynamic refreshToken;   // stored in keychain
@dynamic accessToken;    // stored in keychain
@dynamic activationCode; // stored in keychain

+ (void)initialize {
    if (self == [SFOAuthCredentials class]) {
        kSFOAuthExceptionNilIdentifier = [[NSException alloc] initWithName:NSInternalInconsistencyException 
                                                                    reason:@"identifier cannot be nil or empty"
                                                                  userInfo:nil];
    }
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.identifier     = [coder decodeObjectForKey:@"SFOAuthIdentifier"];
        self.domain         = [coder decodeObjectForKey:@"SFOAuthDomain"];
        self.clientId       = [coder decodeObjectForKey:@"SFOAuthClientId"];
        self.redirectUri    = [coder decodeObjectForKey:@"SFOAuthRedirectUri"];
        self.organizationId = [coder decodeObjectForKey:@"SFOAuthOrganizationId"];
        self.identityUrl    = [coder decodeObjectForKey:@"SFOAuthIdentityUrl"];
        self.instanceUrl    = [coder decodeObjectForKey:@"SFOAuthInstanceUrl"];
        self.communityId    = [coder decodeObjectForKey:@"SFOAuthCommunityId"];
        self.communityUrl   = [coder decodeObjectForKey:@"SFOAuthCommunityUrl"];
        self.issuedAt       = [coder decodeObjectForKey:@"SFOAuthIssuedAt"];
        NSString *protocolVal = [coder decodeObjectForKey:@"SFOAuthProtocol"];
        if (nil != protocolVal)
            self.protocol = protocolVal;
        else
            self.protocol = kSFOAuthProtocolHttps;

        _encrypted          = [[coder decodeObjectForKey:@"SFOAuthEncrypted"] boolValue];
        _legacyIdentityInformation = [coder decodeObjectForKey:@"SFOAuthIdentityInformation"];
        [self updateTokenEncryption];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier         forKey:@"SFOAuthIdentifier"];
    [coder encodeObject:self.domain             forKey:@"SFOAuthDomain"];
    [coder encodeObject:self.clientId           forKey:@"SFOAuthClientId"];
    [coder encodeObject:self.redirectUri        forKey:@"SFOAuthRedirectUri"];
    [coder encodeObject:self.organizationId     forKey:@"SFOAuthOrganizationId"];
    [coder encodeObject:self.identityUrl        forKey:@"SFOAuthIdentityUrl"];
    [coder encodeObject:self.instanceUrl        forKey:@"SFOAuthInstanceUrl"];
    [coder encodeObject:self.communityId        forKey:@"SFOAuthCommunityId"];
    [coder encodeObject:self.communityUrl       forKey:@"SFOAuthCommunityUrl"];
    [coder encodeObject:self.issuedAt           forKey:@"SFOAuthIssuedAt"];
    [coder encodeObject:self.protocol           forKey:@"SFOAuthProtocol"];
    [coder encodeObject:kSFOAuthArchiveVersion  forKey:@"SFOAuthArchiveVersion"];
    [coder encodeObject:@(self.isEncrypted)          forKey:@"SFOAuthEncrypted"];
}

- (id)init {
    return [self initWithIdentifier:nil clientId:nil encrypted:YES];
}

- (id)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    self = [super init];
    if (self) {
        self.identifier           = theIdentifier;
        self.clientId             = theClientId;
        self.domain               = kSFOAuthDefaultDomain;
        self.logLevel             = kSFOAuthLogLevelInfo;
        self.protocol             = kSFOAuthProtocolHttps;
        _encrypted                = encrypted;
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
    [[NSUserDefaults standardUserDefaults] setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)clientId {
    @synchronized(self) {
        return [_clientId copy];
    }
}

- (NSURL *)apiUrl {
    if (nil != self.communityUrl) {
        return self.communityUrl;
    }
    return self.instanceUrl;
}

- (void)setClientId:(NSString *)theClientId {
    @synchronized(self) {
        if (![theClientId isEqualToString:_clientId]) {
            _clientId = [theClientId copy];
        }
    }
}

- (NSString *)identifier {
    @synchronized(self) {
        return [_identifier copy];
    }
}

- (void)setIdentifier:(NSString *)theIdentifier {
    @synchronized(self) {
        if (![theIdentifier isEqualToString:_identifier]) {
            _identifier = [theIdentifier copy];
        }
    }
}

// This setter is exposed publicly for unit tests.
- (void)setIdentityUrl:(NSURL *)identityUrl {
    if (![identityUrl isEqual:_identityUrl]) {
        _identityUrl = [identityUrl copy];
        
                 _userId = nil;
         _organizationId = nil;
        
        if (_identityUrl.path) {
            NSArray *pathComps = [_identityUrl.path componentsSeparatedByString:@"/"];
            if (pathComps.count < 2) {
                [self log:SFLogLevelDebug format:@"%@:setIdentityUrl: invalid identityUrl: %@", [self class], _identityUrl];
                return;
            }
            self.userId = pathComps[pathComps.count - 1];
            self.organizationId = pathComps[pathComps.count - 2];
        } else {
            [self log:SFLogLevelDebug format:@"%@:setIdentityUrl: invalid or nil identityUrl: %@", [self class], _identityUrl];
        }
    }
}

- (NSString *)refreshToken {
    return [self refreshTokenWithSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
}

- (void)setRefreshToken:(NSString *)token {
    [self setRefreshToken:token withSFEncryptionKey:[self keyStoreKeyForService:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] setInteger:kSFOAuthCredsEncryptionTypeKeyStore forKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)activationCode {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *activationCodeData = [self tokenForKey:kSFOAuthServiceActivation];
    if (!activationCodeData) {
        return nil;
    }
    return [[NSString alloc] initWithData:activationCodeData encoding:NSUTF8StringEncoding];
}
    
// This setter is exposed publicly for unit tests. Other external client code should use the revoke methods.
- (void)setActivationCode:(NSString *)token {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceActivation];
    if ([token length] > 0) {
        dict[(__bridge id)kSecValueData] = token;
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((__bridge CFDictionaryRef)dict); // remove token
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        [self log:SFLogLevelDebug format:@"%@:setActivationCode: (%d) %@", [self class], (int)result, [[self class] stringForKeychainResultCode:result]];
    }
}

// This setter is exposed publicly for unit tests.
- (void)setUserId:(NSString *)userId {
    //ensure we only use the first 15 chars of any user ID,
    //since some sources might set 15 char, some might set 18 char
    NSString *truncUserId = [userId substringToIndex:MIN([userId length], 15)]; 
    if (![truncUserId isEqualToString:_userId]) {
        _userId = [truncUserId copy];
    }
}

- (NSString *)description {
    NSString *format = @"<%@ identifier=\"%@\" clientId=\"%@\" domain=\"%@\" identityUrl=\"%@\" instanceUrl=\"%@\" "
                       @"communityId=\"%@\" communityUrl=\"%@\" "
                       @"issuedAt=\"%@\" organizationId=\"%@\" protocol=\"%@\" redirectUri=\"%@\">";
    return [NSString stringWithFormat:format, [self class], 
            self.identifier, self.clientId, self.domain, self.identityUrl, self.instanceUrl,
            self.communityId, self.communityUrl,
            self.issuedAt, self.organizationId, self.protocol, self.redirectUri];
}

- (void)revoke {
    [self revokeAccessToken];
    [self revokeRefreshToken];
}

- (void)revokeAccessToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        [self log:SFLogLevelDebug format:@"%@:revokeAccessToken: access token revoked", [self class]];
    }
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        [self log:SFLogLevelDebug format:@"%@:revokeRefreshToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt fields", [self class]];
    }
    self.refreshToken = nil;
    self.instanceUrl  = nil;
    self.communityId  = nil;
    self.communityUrl = nil;
    self.issuedAt     = nil;
    self.identityUrl  = nil;
}

- (void)revokeActivationCode {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    self.activationCode = nil;
}

#pragma mark - Private Keychain Methods

- (NSMutableDictionary *)modelKeychainDictionaryForKey:(NSString *)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh || key == kSFOAuthServiceActivation, @"invalid key \"%@\"", key);
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    dict[(__bridge id)kSecAttrAccount] = self.identifier;
    dict[(__bridge id)kSecAttrService] = key;
    return dict;
}

- (NSData *)tokenForKey:(NSString*)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh || key == kSFOAuthServiceActivation, @"invalid key \"%@\"", key);
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    OSStatus result;
    NSMutableDictionary *itemDict = nil;
    NSMutableDictionary *outDict = nil;
    
    NSMutableDictionary *theTokenQuery = self.tokenQuery;
    theTokenQuery[(__bridge id)kSecAttrService] = key;
    
    result = SecItemCopyMatching((__bridge CFDictionaryRef)[NSDictionary dictionaryWithDictionary:theTokenQuery], (void *)&outDict);
    if (noErr == result) {
        itemDict = [self keychainItemWithConvertedTokenForMatchingItem:outDict];
    } else if (errSecItemNotFound == result) {
        if (self.logLevel < kSFOAuthLogLevelInfo) {
            [self log:SFLogLevelDebug format:@"%@:tokenForKey: (%d) no existing \"%@\" item matching \"%@\"", [self class], (int)result, key, theTokenQuery];
        }
    } else {
        [self log:SFLogLevelDebug format:@"%@:tokenForKey: (%d) error retrieving \"%@\" item matching \"%@\"", [self class], (int)result, key, theTokenQuery];
    }
    return itemDict[(__bridge id)kSecValueData];
}

- (NSString *)accessTokenWithKey:(NSData *)key {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *accessTokenData = [self tokenForKey:kSFOAuthServiceAccess];
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
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *accessTokenData = [self tokenForKey:kSFOAuthServiceAccess];
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
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary * dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceAccess];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            NSData *encryptedData = [SFSDKCryptoUtils aes256EncryptData:[token dataUsingEncoding:NSUTF8StringEncoding]
                                                                withKey:encryptionKey.key
                                                                     iv:encryptionKey.initializationVector];
            dict[(__bridge id)kSecValueData] = encryptedData;
        } else {
            dict[(__bridge id)kSecValueData] = token;
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((__bridge CFDictionaryRef)dict); // remove token
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        [self log:SFLogLevelDebug format:@"%@:setAccessToken: (%d) %@", [self class], (int)result, [[self class] stringForKeychainResultCode:result]];
    }
}

// Only for unit tests of legacy functionality.  Do not use in app code!
- (void)setAccessToken:(NSString *)token withKey:(NSData *)key {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary * dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceAccess];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOAEncrypt key:key];
            [cipher encryptData:[token dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *encryptedData = [cipher finalizeCipher];
            dict[(__bridge id)kSecValueData] = encryptedData;
        } else {
            dict[(__bridge id)kSecValueData] = token;
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((__bridge CFDictionaryRef)dict); // remove token
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        [self log:SFLogLevelDebug format:@"%@:setAccessToken: (%d) %@", [self class], (int)result, [[self class] stringForKeychainResultCode:result]];
    }
}

- (NSString *)refreshTokenWithKey:(NSData *)key {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *refreshTokenData = [self tokenForKey:kSFOAuthServiceRefresh];
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
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *refreshTokenData = [self tokenForKey:kSFOAuthServiceRefresh];
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
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceRefresh];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            NSData *encryptedData = [SFSDKCryptoUtils aes256EncryptData:[token dataUsingEncoding:NSUTF8StringEncoding]
                                                                withKey:encryptionKey.key
                                                                     iv:encryptionKey.initializationVector];
            dict[(__bridge id)kSecValueData] = encryptedData;
        } else {
            dict[(__bridge id)kSecValueData] = token;
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((__bridge CFDictionaryRef)dict); // remove token
        self.instanceUrl = nil;
        self.communityId  = nil;
        self.communityUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        [self log:SFLogLevelDebug format:@"%@:setRefreshToken: (%d) %@", [self class], (int)result, [[self class] stringForKeychainResultCode:result]];
    }
}

// Only for unit tests of legacy functionality.  Do not use in app code!
- (void)setRefreshToken:(NSString *)token withKey:(NSData *)key {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceRefresh];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            SFOAuthCrypto *cipher = [[SFOAuthCrypto alloc] initWithOperation:SFOAEncrypt key:key];
            [cipher encryptData:[token dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *encryptedData = [cipher finalizeCipher];
            dict[(__bridge id)kSecValueData] = encryptedData;
        } else {
            dict[(__bridge id)kSecValueData] = token;
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((__bridge CFDictionaryRef)dict); // remove token
        self.instanceUrl = nil;
        self.communityId  = nil;
        self.communityUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        [self log:SFLogLevelDebug format:@"%@:setRefreshToken: (%d) %@", [self class], (int)result, [[self class] stringForKeychainResultCode:result]];
    }
}

- (NSMutableDictionary *)tokenQuery {
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    NSMutableDictionary *tokenQuery = [[NSMutableDictionary alloc] init];
    tokenQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    tokenQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    tokenQuery[(__bridge id)kSecReturnAttributes] = (id)kCFBooleanTrue;
    tokenQuery[(__bridge id)kSecAttrAccount] = self.identifier;
    // TODO: kSecAttrAccessGroup for keychain item sharing amongst apps
    return tokenQuery;
}

- (NSMutableDictionary *)keychainItemWithConvertedTokenForMatchingItem:(NSDictionary *)matchDict {
    NSAssert(nil != matchDict, @"matchDict can't be nil");
    
    OSStatus result;
    NSData *tokenData = nil;
    NSMutableDictionary *returnDict = [NSMutableDictionary dictionaryWithDictionary:matchDict];
    returnDict[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
    returnDict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    
    result = SecItemCopyMatching((__bridge CFDictionaryRef)returnDict, (void *)&tokenData);
    if (noErr == result) {
        // first, remove the data key-value
        [returnDict removeObjectForKey:(__bridge id)kSecReturnData];
        if (tokenData) {
             returnDict[(__bridge id)kSecValueData] = tokenData;
        }
        
    } else if (errSecItemNotFound == result) {
        [self log:SFLogLevelDebug format:@"%@:keychainItemWithConvertedTokenForMatchingItem: (%d) no match for item \"%@\"", [self class], (int)result, returnDict];
    } else {
        [self log:SFLogLevelDebug format:@"%@:keychainItemWithConvertedTokenForMatchingItem: (%d) error copying item \"%@\"", [self class], (int)result, returnDict];
    }
    return returnDict;
}

- (OSStatus)writeToKeychain:(NSMutableDictionary *)dictionary {
    NSAssert(dictionary, @"dictionary cannot be nil");
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    OSStatus result;
    NSDictionary *existingDict = nil;
    
    NSMutableDictionary *theTokenQuery = self.tokenQuery;
    theTokenQuery[(__bridge id)kSecAttrService] = dictionary[(__bridge id)kSecAttrService];
    
    NSMutableDictionary *updateDict = [NSMutableDictionary dictionary];
    NSObject *obj = dictionary[(__bridge id)kSecValueData];
    if (obj) {
        if ([obj isKindOfClass:[NSString class]]) {
            // convert string token to data
            NSString *tokenString = dictionary[(__bridge id)kSecValueData];
            updateDict[(__bridge id)kSecValueData] = [tokenString dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            updateDict[(__bridge id)kSecValueData] = obj;
        }
    }
    updateDict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    
    result = SecItemCopyMatching((__bridge CFDictionaryRef)theTokenQuery, (void *)&existingDict);
    if (noErr == result) {
        // update an existing keychain item
        NSMutableDictionary *updateQuery = [NSMutableDictionary dictionaryWithDictionary:existingDict];
        updateQuery[(__bridge id)kSecClass] = theTokenQuery[(__bridge id)kSecClass];
        result = SecItemUpdate((__bridge CFDictionaryRef)updateQuery, (__bridge CFDictionaryRef)updateDict);
        if (noErr != result) {
            [self log:SFLogLevelDebug format:@"%@:writeToKeychain: (%d) %@ Updating item: %@",
                    [self class], (int)result, [[self class] stringForKeychainResultCode:result] , updateQuery];
        }
    } else if (errSecItemNotFound == result) {
        // add a new keychain item
        updateDict[(__bridge id)kSecClass] = theTokenQuery[(__bridge id)kSecClass];
        updateDict[(__bridge id)kSecAttrAccount] = self.identifier;
        updateDict[(__bridge id)kSecAttrService] = dictionary[(__bridge id)kSecAttrService];
        // TODO: [updateDict setObject:self.accessGroup forKey:(id)kSecAttrAccessGroup];
        result = SecItemAdd((__bridge CFDictionaryRef)updateDict, NULL);
        if (noErr != result) {
            [self log:SFLogLevelDebug format:@"%@:writeToKeychain: (%d) error adding item: %@", [self class], (int)result, updateDict];
        }
    } else {
        [self log:SFLogLevelDebug format:@"%@:writeToKeychain: (%d) error copying item: %@", [self class], (int)result, dictionary];
    }
    return result;
}

- (NSData *)keyMacForService:(NSString *)service
{
    NSString *macAddress = [[UIDevice currentDevice] macaddress];
    return [self keyWithSeed:macAddress service:service];
}

- (NSData *)keyVendorIdForService:(NSString *)service
{
    NSString *idForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return [self keyWithSeed:idForVendor service:service];
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
            [self log:SFLogLevelDebug msg:@"Token encryption based on MAC address."];
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

+ (NSString *)stringForKeychainResultCode:(OSStatus)code {
    NSString *s;
    switch (code) {
        case errSecSuccess:
            s = @"errSecSuccess";
            break;
        case errSecUnimplemented:
            s = @"errSecUnimplemented";
            break;
        case errSecParam:
            s = @"errSecParam";
            break;
        case errSecAllocate:
            s = @"errSecAllocate";
            break;
        case errSecNotAvailable:
            s = @"errSecNotAvailable";
            break;
        case errSecAuthFailed:
            s = @"errSecAuthFailed";
            break;
        case errSecDuplicateItem:
            s = @"errSecDuplicateItem";
            break;
        case errSecItemNotFound:
            s = @"errSecItemNotFound";
            break;
        case errSecInteractionNotAllowed:
            s = @"errSecInteractionNotAllowed";
            break;
        case errSecDecode:
            s = @"errSecDecode";
            break;
        default:
            s = [NSString stringWithFormat:@"%d", (int)code];
            break;
    }
    return s;
}

@end
