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

static NSString * const kSFOAuthArchiveVersion      = @"1.0.3"; // internal version included when archiving via encodeWithCoder

static NSString * const kSFOAuthAccessGroup         = @"com.salesforce.oauth";
static NSString * const kSFOAuthProtocolHttps       = @"https";

static NSString * const kSFOAuthServiceAccess       = @"com.salesforce.oauth.access";
static NSString * const kSFOAuthServiceRefresh      = @"com.salesforce.oauth.refresh";
static NSString * const kSFOAuthServiceActivation   = @"com.salesforce.oauth.activation";

static NSString * const kSFOAuthDefaultDomain       = @"login.salesforce.com";


@interface SFOAuthCredentials () 

//This property is intentionally readonly in the public header files.
@property (nonatomic, readwrite, retain) NSString *protocol;
    
@end
static NSException * kSFOAuthExceptionNilIdentifier;

@implementation SFOAuthCredentials

@synthesize identifier      = _identifier;
@synthesize domain          = _domain;
@synthesize clientId        = _clientId;
@synthesize redirectUri     = _redirectUri;
@synthesize organizationId  = _organizationId; // cached org ID dervied from identityURL
@synthesize identityUrl     = _identityUrl;
@synthesize userId          = _userId;         // cached user ID derived from identityURL
@synthesize instanceUrl     = _instanceUrl;
@synthesize issuedAt        = _issuedAt;
@synthesize logLevel        = _logLevel;
@synthesize protocol        = _protocol;
@synthesize encrypted     = _encrypted;

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
        self.issuedAt       = [coder decodeObjectForKey:@"SFOAuthIssuedAt"];
        NSString *protocolVal = [coder decodeObjectForKey:@"SFOAuthProtocol"];
        if (nil != protocolVal)
            self.protocol = protocolVal;
        else
            self.protocol = kSFOAuthProtocolHttps;

        _encrypted          = [[coder decodeObjectForKey:@"SFOAuthEncrypted"] boolValue];
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
    [coder encodeObject:self.issuedAt           forKey:@"SFOAuthIssuedAt"];
    [coder encodeObject:self.protocol           forKey:@"SFOAuthProtocol"];

    [coder encodeObject:kSFOAuthArchiveVersion  forKey:@"SFOAuthArchiveVersion"];
    [coder encodeObject:[NSNumber numberWithBool:self.isEncrypted]          forKey:@"SFOAuthEncrypted"];
}

- (id)init {
    return [self initWithIdentifier:nil clientId:nil encrypted:YES];
}

- (id)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    self = [super init];
    if (self) {
        self.identifier     = theIdentifier;
        self.clientId       = theClientId;
        self.domain         = kSFOAuthDefaultDomain;
        self.logLevel       = kSFOAuthLogLevelInfo;
        self.protocol       = kSFOAuthProtocolHttps;
        _encrypted          = encrypted;
    }
    return self;
}

- (void)dealloc {
    [_clientId release];        _clientId = nil;
    [_domain release];          _domain = nil;
    [_identifier release];      _identifier = nil;
    [_identityUrl release];     _identityUrl = nil;
    [_instanceUrl release];     _instanceUrl = nil;
    [_issuedAt release];        _issuedAt = nil;
    [_organizationId release];  _organizationId = nil;
    [_redirectUri release];     _redirectUri = nil;
    [_userId release];          _userId = nil;
    [_protocol release];        _protocol = nil;
    
    [super dealloc];
}

#pragma mark - Public Methods

- (NSString *)accessToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *accessTokenData = [self tokenForKey:kSFOAuthServiceAccess];
    if (!accessTokenData) {
        return nil;
    }
    if (self.isEncrypted) {
        NSString *macAddress = [[UIDevice currentDevice] macaddress];
        NSString *strSecret = [macAddress stringByAppendingString:kSFOAuthServiceAccess];
        NSData *secretData = [strSecret sha256];
        
        SFOAuthCrypto *cipher = [[[SFOAuthCrypto alloc] initWithOperation:kCCDecrypt key:secretData] autorelease];
        NSData *decryptedData = [cipher decryptData:accessTokenData];
        return [[[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding] autorelease];
    [_protocol release];        _protocol = nil;
    } else {
        return [[[NSString alloc] initWithData:accessTokenData encoding:NSUTF8StringEncoding] autorelease];
    }
}

// This setter is exposed publicly for unit tests. Other external client code should use the revoke methods.
- (void)setAccessToken:(NSString *)token {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary * dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceAccess];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            NSString *macAddress = [[UIDevice currentDevice] macaddress];
            NSString *strSecret = [macAddress stringByAppendingString:kSFOAuthServiceAccess];
            NSData *secretData = [strSecret sha256];
            
            SFOAuthCrypto *cipher = [[[SFOAuthCrypto alloc] initWithOperation:kCCEncrypt key:secretData] autorelease];
            [cipher encryptData:[token dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *encryptedData = [cipher finalizeCipher];
            [dict setObject:encryptedData forKey:(id)kSecValueData];
        } else {
            [dict setObject:token forKey:(id)kSecValueData];
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((CFDictionaryRef)dict); // remove token
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        NSLog(@"%@:setAccessToken: (%ld) %@", [self class], result, [[self class] stringForKeychainResultCode:result]);
    }
}

- (NSString *)clientId {
    @synchronized(self) {
        return [[_clientId copy] autorelease];
    }
}

- (void)setClientId:(NSString *)theClientId {
    @synchronized(self) {
        if (![theClientId isEqualToString:_clientId]) {
            [_clientId release];
            _clientId = [theClientId copy];
        }
    }
}

- (NSString *)identifier {
    @synchronized(self) {
        return [[_identifier copy] autorelease];
    }
}

- (void)setIdentifier:(NSString *)theIdentifier {
    @synchronized(self) {
        if (![theIdentifier isEqualToString:_identifier]) {
            [_identifier release];
            _identifier = [theIdentifier copy];
        }
    }
}

// This setter is exposed publicly for unit tests.
- (void)setIdentityUrl:(NSURL *)identityUrl {
    if (![identityUrl isEqual:_identityUrl]) {
        [_identityUrl release];
        _identityUrl = [identityUrl copy];
        
        [_userId release];         _userId = nil;
        [_organizationId release]; _organizationId = nil;
        
        if (_identityUrl.path) {
            NSArray *pathComps = [_identityUrl.path componentsSeparatedByString:@"/"];
            if (pathComps.count < 2) {
                NSLog(@"%@:setIdentityUrl: invalid identityUrl: %@", [self class], _identityUrl);
                return;
            }
            self.userId = [pathComps objectAtIndex:pathComps.count - 1];
            self.organizationId = [pathComps objectAtIndex:pathComps.count - 2];
        }
    }
}



- (NSString *)refreshToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *refreshTokenData = [self tokenForKey:kSFOAuthServiceRefresh];
    if (!refreshTokenData) {
        return nil;
    }
    if (self.isEncrypted) {
        NSString *macAddress = [[UIDevice currentDevice] macaddress];
        NSString *strSecret = [macAddress stringByAppendingString:kSFOAuthServiceRefresh];
        NSData *secretData = [strSecret sha256];
        
        SFOAuthCrypto *cipher = [[[SFOAuthCrypto alloc] initWithOperation:kCCDecrypt key:secretData] autorelease];
        NSData *decryptedData = [cipher decryptData:refreshTokenData];
        return [[[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding] autorelease];
    } else {
        return [[[NSString alloc] initWithData:refreshTokenData encoding:NSUTF8StringEncoding] autorelease];
    }
}

// This setter is exposed publicly for unit tests. Other external client code should use the revoke methods.
- (void)setRefreshToken:(NSString *)token {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceRefresh];
    if ([token length] > 0) {
        if (self.isEncrypted) {
            NSString *macAddress = [[UIDevice currentDevice] macaddress];
            NSString *strSecret = [macAddress stringByAppendingString:kSFOAuthServiceRefresh];
            NSData *secretData = [strSecret sha256];
            
            SFOAuthCrypto *cipher = [[[SFOAuthCrypto alloc] initWithOperation:kCCEncrypt key:secretData] autorelease];
            [cipher encryptData:[token dataUsingEncoding:NSUTF8StringEncoding]];
            NSData *encryptedData = [cipher finalizeCipher];
            [dict setObject:encryptedData forKey:(id)kSecValueData];
        } else {
            [dict setObject:token forKey:(id)kSecValueData];
        }
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((CFDictionaryRef)dict); // remove token
        self.instanceUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        NSLog(@"%@:setRefreshToken: (%ld) %@", [self class], result, [[self class] stringForKeychainResultCode:result]);
    }
}
    
- (NSString *)activationCode {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    NSData *activationCodeData = [self tokenForKey:kSFOAuthServiceActivation];
    if (!activationCodeData) {
        return nil;
    }
    return [[[NSString alloc] initWithData:activationCodeData encoding:NSUTF8StringEncoding] autorelease];
}
    
// This setter is exposed publicly for unit tests. Other external client code should use the revoke methods.
- (void)setActivationCode:(NSString *)token {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceActivation];
    if ([token length] > 0) {
        [dict setObject:token forKey:(id)kSecValueData];
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((CFDictionaryRef)dict); // remove token
        self.instanceUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        NSLog(@"%@:setActivationCode: (%ld) %@", [self class], result, [[self class] stringForKeychainResultCode:result]);
    }
}

// This setter is exposed publicly for unit tests.
- (void)setUserId:(NSString *)userId {
    //ensure we only use the first 15 chars of any user ID,
    //since some sources might set 15 char, some might set 18 char
    NSString *truncUserId = [userId substringToIndex:MIN([userId length], 15)]; 
    if (![truncUserId isEqualToString:_userId]) {
        [_userId release];
        _userId = [truncUserId copy];
    }
}

- (NSString *)description {
    NSString *format = @"<%@ identifier=\"%@\" clientId=\"%@\" domain=\"%@\" identityUrl=\"%@\" instanceUrl=\"%@\" "
                       @"issuedAt=\"%@\" organizationId=\"%@\" protocol=\"%@\" redirectUri=\"%@\">";
    return [NSString stringWithFormat:format, [self class], 
            self.identifier, self.clientId, self.domain, self.identityUrl, self.instanceUrl, 
            self.issuedAt, self.organizationId, self.protocol, self.redirectUri];
}

- (void)revoke {
    [self revokeAccessToken];
    [self revokeRefreshToken];
}

- (void)revokeAccessToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"%@:revokeAccessToken: access token revoked", [self class]);
    }
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
    if (!([self.identifier length] > 0)) @throw kSFOAuthExceptionNilIdentifier;
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"%@:revokeRefreshToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt fields", [self class]);
    }
    self.refreshToken = nil;
    self.instanceUrl  = nil;
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
    [dict setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [dict setObject:self.identifier forKey:(id)kSecAttrAccount];
    [dict setObject:key forKey:(id)kSecAttrService];
    return dict;
}

- (NSData *)tokenForKey:(NSString*)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh || key == kSFOAuthServiceActivation, @"invalid key \"%@\"", key);
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    OSStatus result;
    NSMutableDictionary *itemDict = nil;
    NSMutableDictionary *outDict = nil;
    
    NSMutableDictionary *theTokenQuery = self.tokenQuery;
    [theTokenQuery setObject:key forKey:(id)kSecAttrService];
    
    result = SecItemCopyMatching((CFDictionaryRef)[NSDictionary dictionaryWithDictionary:theTokenQuery], (CFTypeRef *)&outDict);
    if (noErr == result) {
        itemDict = [self keychainItemWithConvertedTokenForMatchingItem:outDict];
    } else if (errSecItemNotFound == result) {
        if (self.logLevel < kSFOAuthLogLevelInfo) {
            NSLog(@"%@:tokenForKey: (%ld) no existing \"%@\" item matching \"%@\"", [self class], result, key, theTokenQuery);
        }
    } else {
        NSLog(@"%@:tokenForKey: (%ld) error retrieving \"%@\" item matching \"%@\"", [self class], result, key, theTokenQuery);
    }
    [outDict release];
    return [itemDict objectForKey:(id)kSecValueData];
}

- (NSMutableDictionary *)tokenQuery {
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    NSMutableDictionary *tokenQuery = [[[NSMutableDictionary alloc] init] autorelease];
    [tokenQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [tokenQuery setObject:(id)kSecMatchLimitOne        forKey:(id)kSecMatchLimit];
    [tokenQuery setObject:(id)kCFBooleanTrue           forKey:(id)kSecReturnAttributes];
    [tokenQuery setObject:self.identifier              forKey:(id)kSecAttrAccount];
    // TODO: kSecAttrAccessGroup for keychain item sharing amongst apps
    return tokenQuery;
}

- (NSMutableDictionary *)keychainItemWithConvertedTokenForMatchingItem:(NSDictionary *)matchDict {
    NSAssert(nil != matchDict, @"matchDict can't be nil");
    
    OSStatus result;
    NSData *tokenData = nil;
    NSMutableDictionary *returnDict = [NSMutableDictionary dictionaryWithDictionary:matchDict];
    [returnDict setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [returnDict setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    
    result = SecItemCopyMatching((CFDictionaryRef)returnDict, (CFTypeRef *)&tokenData);
    if (noErr == result) {
        // first, remove the data key-value
        [returnDict removeObjectForKey:(id)kSecReturnData];
        if (tokenData) {
             [returnDict setObject:tokenData forKey:(id)kSecValueData];
        }
        
    } else if (errSecItemNotFound == result) {
        NSLog(@"%@:keychainItemWithConvertedTokenForMatchingItem: (%ld) no match for item \"%@\"", [self class], result, returnDict);
    } else {
        NSLog(@"%@:keychainItemWithConvertedTokenForMatchingItem: (%ld) error copying item \"%@\"", [self class], result, returnDict);
    }
    [tokenData release];
    return returnDict;
}

- (OSStatus)writeToKeychain:(NSMutableDictionary *)dictionary {
    NSAssert(dictionary, @"dictionary cannot be nil");
    NSAssert([self.identifier length] > 0, @"identifier cannot be nil or empty");
    
    OSStatus result;
    NSDictionary *existingDict = nil;
    
    NSMutableDictionary *theTokenQuery = self.tokenQuery;
    [theTokenQuery setObject:[dictionary objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
    
    NSMutableDictionary *updateDict = [NSMutableDictionary dictionary];
    NSObject *obj = [dictionary objectForKey:(id)kSecValueData];
    if (obj) {
        if ([obj isKindOfClass:[NSString class]]) {
            // convert string token to data
            NSString *tokenString = [dictionary objectForKey:(id)kSecValueData];
            [updateDict setObject:[tokenString dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
        } else {
            [updateDict setObject:obj forKey:(id)kSecValueData];
        }
    }
    [updateDict setObject:(id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly forKey:(id)kSecAttrAccessible];
    
    result = SecItemCopyMatching((CFDictionaryRef)theTokenQuery, (CFTypeRef *)&existingDict);
    if (noErr == result) {
        // update an existing keychain item
        NSMutableDictionary *updateQuery = [NSMutableDictionary dictionaryWithDictionary:existingDict];
        [updateQuery setObject:[theTokenQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        result = SecItemUpdate((CFDictionaryRef)updateQuery, (CFDictionaryRef)updateDict);
        if (noErr != result) {
            NSLog(@"%@:writeToKeychain: (%ld) %@ Updating item: %@", 
                  [self class], result, [[self class] stringForKeychainResultCode:result] , updateQuery);
        }
    } else if (errSecItemNotFound == result) {
        // add a new keychain item
        [updateDict setObject:[theTokenQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        [updateDict setObject:self.identifier forKey:(id)kSecAttrAccount];
        [updateDict setObject:[dictionary objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
        // TODO: [updateDict setObject:self.accessGroup forKey:(id)kSecAttrAccessGroup];
        result = SecItemAdd((CFDictionaryRef)updateDict, NULL);
        if (noErr != result) {
            NSLog(@"%@:writeToKeychain: (%ld) error adding item: %@", [self class], result, updateDict);
        }
    } else {
        NSLog(@"%@:writeToKeychain: (%ld) error copying item: %@", [self class], result, dictionary);
    }
    return result;
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
            s = [NSString stringWithFormat:@"%ld", code];
            break;
    }
    return s;
}

@end
