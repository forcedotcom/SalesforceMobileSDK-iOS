//
//  SFOAuthCredentials.h
//  SalesforceOAuth
//
//  Created by Steve Holly on 17/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFOAuthCredentials+Internal.h"
#import <Security/Security.h>

static NSString * const kSFOAuthAccessGroup         = @"com.salesforce.oauth";
static NSString * const kSFOAuthDefaultProtocol     = @"https";

static NSString * const kSFOAuthServiceAccess       = @"com.salesforce.oauth.access";
static NSString * const kSFOAuthServiceRefresh      = @"com.salesforce.oauth.refresh";

static NSString * const kSFOAuthDefaultDomain       = @"login.salesforce.com";

@implementation SFOAuthCredentials

@synthesize protocol        = _protocol;
@synthesize domain          = _domain;
@synthesize clientId        = _clientId;
@synthesize redirectUri     = _redirectUri;
@synthesize organizationId  = _organizationId;
@synthesize identityUrl     = _identityUrl;
@synthesize userId          = _userId; // cached user ID derived from identityURL
@synthesize instanceUrl     = _instanceUrl;
@synthesize issuedAt        = _issuedAt;

@dynamic refreshToken;  // stored in keychain
@dynamic accessToken;   // stored in keychain

// private

@synthesize tokenQuery = _tokenQuery;

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.protocol       = [coder decodeObjectForKey:@"SFOAuthProtocol"];
        self.domain         = [coder decodeObjectForKey:@"SFOAuthDomain"];
        self.clientId       = [coder decodeObjectForKey:@"SFOAuthClientId"];
        self.redirectUri    = [coder decodeObjectForKey:@"SFOAuthRedirectUri"];
        self.organizationId = [coder decodeObjectForKey:@"SFOAuthOrganizationId"];
        self.identityUrl    = [coder decodeObjectForKey:@"SFOAuthIdentityUrl"];
        self.instanceUrl    = [coder decodeObjectForKey:@"SFOAuthInstanceUrl"];
        self.issuedAt       = [coder decodeObjectForKey:@"SFOAuthIssuedAt"];
        
        [self initKeychainWithIdentifier:self.clientId accessGroup:kSFOAuthAccessGroup];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.protocol       forKey:@"SFOAuthProtocol"];
    [coder encodeObject:self.domain         forKey:@"SFOAuthDomain"];
    [coder encodeObject:self.clientId       forKey:@"SFOAuthClientId"];
    [coder encodeObject:self.redirectUri    forKey:@"SFOAuthRedirectUri"];
    [coder encodeObject:self.organizationId forKey:@"SFOAuthOrganizationId"];
    [coder encodeObject:self.identityUrl    forKey:@"SFOAuthIdentityUrl"];
    [coder encodeObject:self.instanceUrl    forKey:@"SFOAuthInstanceUrl"];
    [coder encodeObject:self.issuedAt       forKey:@"SFOAuthIssuedAt"];
}

- (id)init {
    self = [super init];
    if (!self) return nil;
    [self release];
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithIdentifier:(NSString *)anIdentifier {
    NSAssert([anIdentifier length] > 0, @"identifier cannot be nil or empty");
    
    self = [super init];
    if (self) {
        self.clientId       = anIdentifier;
        self.protocol       = kSFOAuthDefaultProtocol;
        self.domain         = kSFOAuthDefaultDomain;
        
        [self initKeychainWithIdentifier:self.clientId accessGroup:kSFOAuthAccessGroup];
    }
    return self;
}

- (void)initKeychainWithIdentifier:(NSString *)identifier accessGroup:(NSString *)accessGroup {
    _tokenQuery = [[NSMutableDictionary alloc] init];
    [self.tokenQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [self.tokenQuery setObject:identifier                   forKey:(id)kSecAttrAccount];
    [self.tokenQuery setObject:(id)kSecMatchLimitOne        forKey:(id)kSecMatchLimit];
    [self.tokenQuery setObject:(id)kCFBooleanTrue           forKey:(id)kSecReturnAttributes];
    
    // TODO: access group
}

- (void)dealloc {
    [_protocol release];        _protocol = nil;
    [_domain release];          _domain = nil;
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
}

- (void)setClientId:(NSString *)identifier {
    [_clientId autorelease];
    _clientId = [identifier copy];
    if (_clientId != nil) {
        [self.tokenQuery setObject:_clientId forKey:(id)kSecAttrAccount];
    }
}

// This setter is exposed publically for unit tests.
- (void)setIdentityUrl:(NSURL *)identityUrl {
    if (![identityUrl isEqual:_identityUrl]) {
        [_identityUrl autorelease];
        _identityUrl = [identityUrl copy];
        
        [_userId autorelease]; _userId = nil;
        if (_identityUrl.path) {
            NSRange r = [_identityUrl.path rangeOfString:@"/" options:NSBackwardsSearch];
            if (r.location != NSNotFound) {
                self.userId = [_identityUrl.path substringFromIndex:r.location + r.length];
            }
        }
    }
}

- (void)setProtocol:(NSString *)protocol {
    NSString *lc = [protocol lowercaseString];
    if (!([lc isEqualToString:@"http"] || [lc isEqualToString:@"https"])) {
        NSException *exp = [NSException exceptionWithName:NSInvalidArgumentException reason:@"protocol must be http or https" userInfo:nil];
        @throw exp;
    }
    if (![protocol isEqualToString:_protocol]) {
        [_protocol autorelease];
        _protocol = [protocol copy];
    }
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
        [self writeToKeychain:dict];
    } else {
        result = SecItemDelete((CFDictionaryRef)dict); // remove token
        self.instanceUrl = nil;
        self.issuedAt    = nil;
        self.identityUrl = nil;
    }
}

// This setter is exposed publically for unit tests.
- (void)setUserId:(NSString *)userId {
    //ensure we only use the first 15 chars of any user ID,
    //since some sources might set 15 char, some might set 18 char
    NSString *truncUserId = [userId substringToIndex:MIN([userId length], 15)]; 
    if (![truncUserId isEqualToString:_userId]) {
        [_userId autorelease];
        _userId = [truncUserId copy];
    }
}

- (NSString *)description {
    NSString *format = @"<%@ domain=\"%@\" instanceURL=\"%@\" issuedAt=\"%@\" organizationId=\"%@\" protocol=\"%@\" redirectUri=\"%@\" identityURL=\"%@\">";
    return [NSString stringWithFormat:format, [self class], 
            self.domain, self.instanceUrl, self.issuedAt, self.organizationId, self.protocol, self.redirectUri, self.identityUrl];
}

- (void)revoke {
    [self revokeAccessToken];
    [self revokeRefreshToken];
}

- (void)revokeAccessToken {
#if SFOAUTH_LOG_VERBOSE
    NSLog(@"%@:revokeAccessToken: access token revoked", [self class]);
#endif
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
#if SFOAUTH_LOG_VERBOSE
    NSLog(@"%@:revokeAccessToken: refresh token revoked. instanceUrl, issuedAt, userId cleared", [self class]);
#endif
    self.refreshToken = nil;
    self.instanceUrl  = nil;
    self.issuedAt     = nil;
    self.identityUrl  = nil;
}

#pragma mark - Private Keychain Methods

// TODO: reuse dictionaries

- (NSMutableDictionary *)modelKeychainDictionaryForKey:(NSString *)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh, @"invalid key \"%@\"", key);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [dict setObject:self.clientId forKey:(id)kSecAttrAccount];
    [dict setObject:key forKey:(id)kSecAttrService];
    return dict;
}

- (NSString *)tokenForKey:(NSString*)key {
    NSAssert(key == kSFOAuthServiceAccess || key == kSFOAuthServiceRefresh, @"invalid key \"%@\"", key);
    
    OSStatus result;
    NSMutableDictionary *itemDict = nil;
    NSMutableDictionary *outDict = nil;
    
    [self.tokenQuery setObject:key forKey:(id)kSecAttrService];
    result = SecItemCopyMatching((CFDictionaryRef)[NSDictionary dictionaryWithDictionary:self.tokenQuery], (CFTypeRef *)&outDict);
    if (noErr == result) {
        itemDict = [self keychainItemWithConvertedTokenForMatchingItem:outDict];
    } else if (errSecItemNotFound == result) {
#if SFOAUTH_LOG_VERBOSE
        NSLog(@"SFOAuthCredentials:tokenForKey: (%ld) no existing \"%@\" item matching \"%@\"", result, key, self.tokenQuery);
#endif
    } else {
        NSLog(@"SFOAuthCredentials:tokenForKey: (%ld) error retrieving \"%@\" item matching \"%@\"", result, key, self.tokenQuery);
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
        NSLog(@"SFOAuthCredentials:keychainItemWithConvertedTokenForMatchingItem: (%ld) no match for item \"%@\"", result, returnDict);
    } else {
        NSLog(@"SFOAuthCredentials:keychainItemWithConvertedTokenForMatchingItem: (%ld) error copying item \"%@\"", result, returnDict);
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
            NSLog(@"SFOAuthCredentials:writeToKeychain: (%ld) error updating item: %@", result, updateQuery);
        }
    } else if (errSecItemNotFound == result) {
        // add a new keychain item
        [updateDict setObject:[self.tokenQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        [updateDict setObject:self.clientId forKey:(id)kSecAttrAccount];
        [updateDict setObject:[dictionary objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
        // TODO: [updateDict setObject:self.accessGroup forKey:(id)kSecAttrAccessGroup];
        result = SecItemAdd((CFDictionaryRef)updateDict, NULL);
        if (noErr != result) {
            NSLog(@"SFOAuthCredentials:writeToKeychain: (%ld) error adding item: %@", result, updateDict);
        }
    } else {
        NSLog(@"SFOAuthCredentials:writeToKeychain: (%ld) error copying item: %@", result, dictionary);
    }
    return result;
}

@end
