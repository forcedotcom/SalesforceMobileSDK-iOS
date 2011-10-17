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

#import "SFOAuthCredentials+Internal.h"
#import <Security/Security.h>

static NSString * const kSFOAuthArchiveVersion      = @"1.0"; // internal version included when archiving via encodeWithCoder

static NSString * const kSFOAuthAccessGroup         = @"com.salesforce.oauth";
static NSString * const kSFOAuthProtocolHttps       = @"https";

static NSString * const kSFOAuthServiceAccess       = @"com.salesforce.oauth.access";
static NSString * const kSFOAuthServiceRefresh      = @"com.salesforce.oauth.refresh";
static NSString * const kSFOAuthServiceActivation   = @"com.salesforce.oauth.activation";

static NSString * const kSFOAuthDefaultDomain       = @"login.salesforce.com";

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

@dynamic refreshToken;   // stored in keychain
@dynamic accessToken;    // stored in keychain
@dynamic activationCode; // stored in keychain

// private

@synthesize tokenQuery = _tokenQuery;

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
        
        [self initKeychainWithIdentifier:self.identifier accessGroup:kSFOAuthAccessGroup];
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
    [coder encodeObject:kSFOAuthArchiveVersion  forKey:@"SFOAuthArchiveVersion"];
}

- (id)init {
    self = [super init];
    if (!self) return nil;
    [self release];
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId {
    NSAssert([theIdentifier length] > 0, @"identifier cannot be nil or empty");
    NSAssert([theClientId length] > 0,  @"clientId cannot be nil or empty");
    
    self = [super init];
    if (self) {
        self.identifier     = theIdentifier;
        self.clientId       = theClientId;
        self.domain         = kSFOAuthDefaultDomain;
        self.logLevel       = kSFOAuthLogLevelInfo;
        
        [self initKeychainWithIdentifier:self.identifier accessGroup:kSFOAuthAccessGroup];
    }
    return self;
}

- (void)initKeychainWithIdentifier:(NSString *)theIdentifier accessGroup:(NSString *)accessGroup {
    NSAssert([theIdentifier length] > 0, @"identifier cannot be nil or empty");
    
    _tokenQuery = [[NSMutableDictionary alloc] init];
    [self.tokenQuery setObject:theIdentifier                forKey:(id)kSecAttrAccount];
    [self.tokenQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [self.tokenQuery setObject:(id)kSecMatchLimitOne        forKey:(id)kSecMatchLimit];
    [self.tokenQuery setObject:(id)kCFBooleanTrue           forKey:(id)kSecReturnAttributes];
    // TODO: access group for keychain item sharing amongst apps
}

- (void)dealloc {
    [_domain release];          _domain = nil;
    [_identifier release];      _identifier = nil;
    [_clientId release];        _clientId = nil;
    [_redirectUri release];     _redirectUri = nil;
    [_instanceUrl release];     _instanceUrl = nil;
    [_issuedAt release];        _issuedAt = nil;
    [_organizationId release];  _organizationId = nil;
    [_identityUrl release];     _identityUrl = nil;
    [_userId release];          _userId = nil;
    
    [_tokenQuery release];      _tokenQuery = nil;
    
    [super dealloc];
}

#pragma mark - Public Methods

- (NSString *)accessToken {
    return [self tokenForKey:kSFOAuthServiceAccess];
}

// This setter is exposed publically for unit tests. Other external client code should use the revoke methods.
- (void)setAccessToken:(NSString *)token {
    OSStatus result;
    NSMutableDictionary * dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceAccess];
    if ([token length] > 0) {
        [dict setObject:token forKey:(id)kSecValueData];
        result = [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((CFDictionaryRef)dict); // remove token
    }
    if (errSecSuccess != result && errSecItemNotFound != result) { // errSecItemNotFound is an expected condition
        NSLog(@"%@:setAccessToken: (%ld) %@", [self class], result, [[self class] stringForKeychainResultCode:result]);
    }
}

- (void)setClientId:(NSString *)theClientId {
    NSAssert([theClientId length] > 0,  @"clientId cannot be nil or empty");
    
    if (![theClientId isEqualToString:_clientId]) {
        [_clientId release];
        _clientId = [theClientId copy];
    }
}

- (void)setIdentifier:(NSString *)theIdentifier {
    NSAssert([theIdentifier length] > 0, @"identifier cannot be nil or empty");
    
    if (![theIdentifier isEqualToString:_identifier]) {
        [_identifier release];
        _identifier = [theIdentifier copy];
        [self.tokenQuery setObject:_identifier forKey:(id)kSecAttrAccount];
    }
}

// This setter is exposed publically for unit tests.
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

- (NSString *)protocol {
    return kSFOAuthProtocolHttps;
}

- (NSString *)refreshToken {
    return [self tokenForKey:kSFOAuthServiceRefresh];
}

// This setter is exposed publically for unit tests. Other external client code should use the revoke methods.
- (void)setRefreshToken:(NSString *)token {
    OSStatus result;
    NSMutableDictionary *dict = [self modelKeychainDictionaryForKey:kSFOAuthServiceRefresh];
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
        NSLog(@"%@:setRefreshToken: (%ld) %@", [self class], result, [[self class] stringForKeychainResultCode:result]);
    }
}
    
- (NSString *)activationCode {
    return [self tokenForKey:kSFOAuthServiceActivation];
}
    
// This setter is exposed publically for unit tests. Other external client code should use the revoke methods.
- (void)setActivationCode:(NSString *)token {
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

// This setter is exposed publically for unit tests.
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
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"%@:revokeAccessToken: access token revoked", [self class]);
    }
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"%@:revokeAccessToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt", [self class]);
    }
    self.refreshToken = nil;
    self.instanceUrl  = nil;
    self.issuedAt     = nil;
    self.identityUrl  = nil;
}

- (void)revokeActivationCode {
    self.activationCode = nil;
}

#pragma mark - Private Keychain Methods

// TODO: reuse dictionaries

- (NSMutableDictionary *)modelKeychainDictionaryForKey:(NSString *)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh || key == kSFOAuthServiceActivation, @"invalid key \"%@\"", key);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [dict setObject:self.identifier forKey:(id)kSecAttrAccount];
    [dict setObject:key forKey:(id)kSecAttrService];
    return dict;
}

- (NSString *)tokenForKey:(NSString*)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh || key == kSFOAuthServiceActivation, @"invalid key \"%@\"", key);
    
    OSStatus result;
    NSMutableDictionary *itemDict = nil;
    NSMutableDictionary *outDict = nil;
    
    [self.tokenQuery setObject:key forKey:(id)kSecAttrService];
    result = SecItemCopyMatching((CFDictionaryRef)[NSDictionary dictionaryWithDictionary:self.tokenQuery], (CFTypeRef *)&outDict);
    if (noErr == result) {
        itemDict = [self keychainItemWithConvertedTokenForMatchingItem:outDict];
    } else if (errSecItemNotFound == result) {
        if (self.logLevel < kSFOAuthLogLevelInfo) {
            NSLog(@"%@:tokenForKey: (%ld) no existing \"%@\" item matching \"%@\"", [self class], result, key, self.tokenQuery);
        }
    } else {
        NSLog(@"%@:tokenForKey: (%ld) error retrieving \"%@\" item matching \"%@\"", [self class], result, key, self.tokenQuery);
    }
    [outDict release];
    return [itemDict valueForKey:(id)kSecValueData];
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
        // convert the token data to an NSString
        // first, remove the data key-value
        [returnDict removeObjectForKey:(id)kSecReturnData];
        // second, add the token as an NSString 
        NSString *tokenString = [[NSString alloc] initWithBytes:[tokenData bytes] length:tokenData.length encoding:NSUTF8StringEncoding];
        if (nil != tokenString) {
            [returnDict setObject:tokenString forKey:(id)kSecValueData];
        }
        [tokenString release];
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
    
    OSStatus result;
    NSDictionary *existingDict = nil;
    
    [self.tokenQuery setObject:[dictionary objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
    
    NSMutableDictionary *updateDict = [NSMutableDictionary dictionary];
    NSString *tokenString = [dictionary objectForKey:(id)kSecValueData];
    if (tokenString != nil) {
        // convert string token to data
        [updateDict setObject:[tokenString dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
    }
    
    result = SecItemCopyMatching((CFDictionaryRef)self.tokenQuery, (CFTypeRef *)&existingDict);
    if (noErr == result) {
        // update an existing keychain item
        NSMutableDictionary *updateQuery = [NSMutableDictionary dictionaryWithDictionary:existingDict];
        [updateQuery setObject:[self.tokenQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        result = SecItemUpdate((CFDictionaryRef)updateQuery, (CFDictionaryRef)updateDict);
        if (noErr != result) {
            NSLog(@"%@:writeToKeychain: (%ld) %@ Updating item: %@", 
                  [self class], result, [[self class] stringForKeychainResultCode:result] , updateQuery);
        }
    } else if (errSecItemNotFound == result) {
        // add a new keychain item
        [updateDict setObject:[self.tokenQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
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
