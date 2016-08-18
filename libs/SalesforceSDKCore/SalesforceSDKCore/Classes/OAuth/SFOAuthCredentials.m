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

static NSString * const kSFOAuthArchiveVersion         = @"1.0.3"; // internal version included when archiving via encodeWithCoder

static NSString * const kSFOAuthAccessGroup            = @"com.salesforce.oauth";
static NSString * const kSFOAuthProtocolHttps          = @"https";

NSString * const kSFOAuthServiceAccess          = @"com.salesforce.oauth.access";
NSString * const kSFOAuthServiceRefresh         = @"com.salesforce.oauth.refresh";
NSString * const kSFOAuthServiceActivation      = @"com.salesforce.oauth.activation";

static NSString * const kSFOAuthDefaultDomain          = @"login.salesforce.com";

static NSString * const kSFOAuthClusterImplementationKey = @"SFOAuthClusterImplementation";

NSException * SFOAuthInvalidIdentifierException() {
    return [[NSException alloc] initWithName:NSInternalInconsistencyException
                                      reason:@"identifier cannot be nil or empty"
                                    userInfo:nil];
}

@interface SFOAuthCredentials () 

//This property is intentionally readonly in the public header files.
@property (nonatomic, readwrite, strong) NSString *protocol;
    
@end

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
@synthesize additionalOAuthFields     = _additionalOAuthFields;
@synthesize jwt                       = _jwt;

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)coder {
    NSString *clusterClassName = [coder decodeObjectOfClass:[NSString class] forKey:kSFOAuthClusterImplementationKey];
    if (clusterClassName.length == 0) {
        // Legacy credentials class (which doesn't have a persisted implementation class)
        // should default to SFOAuthKeychainCredentials.
        clusterClassName = @"SFOAuthKeychainCredentials";
    }
    
    Class clusterClass = NSClassFromString(clusterClassName) ?: self.class;
    if ([self isMemberOfClass:clusterClass])  {
        self = [super init];
        if (self) {
            self.identifier     = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthIdentifier"];
            self.domain         = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthDomain"];
            self.clientId       = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthClientId"];
            self.redirectUri    = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthRedirectUri"];
            self.organizationId = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthOrganizationId"];
            self.identityUrl    = [coder decodeObjectOfClass:[NSURL class]    forKey:@"SFOAuthIdentityUrl"];
            self.instanceUrl    = [coder decodeObjectOfClass:[NSURL class]    forKey:@"SFOAuthInstanceUrl"];
            self.communityId    = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthCommunityId"];
            self.communityUrl   = [coder decodeObjectOfClass:[NSURL class]    forKey:@"SFOAuthCommunityUrl"];
            self.issuedAt       = [coder decodeObjectOfClass:[NSDate class]   forKey:@"SFOAuthIssuedAt"];
            self.additionalOAuthFields = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"SFOAuthAdditionalFields"];
            
            NSString *protocolVal = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthProtocol"];
            if (nil != protocolVal)
                self.protocol = protocolVal;
            else
                self.protocol = kSFOAuthProtocolHttps;
            
            NSNumber *encryptedBool = [coder decodeObjectOfClass:[NSNumber class] forKey:@"SFOAuthEncrypted"];
            _encrypted = (encryptedBool
                          ? [encryptedBool boolValue]
                          : [coder decodeBoolForKey:@"SFOAuthEncrypted"]);
            _legacyIdentityInformation = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"SFOAuthIdentityInformation"];
            
            if ([self isMemberOfClass:[SFOAuthCredentials class]]) {
                self.refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthRefreshToken"];
                self.accessToken  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthAccessToken"];
            }
        }
    } else {
        self = [[clusterClass alloc] initWithCoder:coder];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:NSStringFromClass(self.class) forKey:kSFOAuthClusterImplementationKey];
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
    [coder encodeObject:@(self.isEncrypted)     forKey:@"SFOAuthEncrypted"];
    [coder encodeObject:self.additionalOAuthFields forKey:@"SFOAuthAdditionalFields"];
   
}

- (id)init {
    return [self initWithIdentifier:nil clientId:nil encrypted:YES];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    return [self initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted storageType:SFOAuthCredentialsStorageTypeKeychain];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString *)theClientId encrypted:(BOOL)encrypted storageType:(SFOAuthCredentialsStorageType)type {
    Class targetClass = self.class;
    switch (type) {
        case SFOAuthCredentialsStorageTypeNone:
            targetClass = NSClassFromString(@"SFOAuthCredentials");
            break;
            
        case SFOAuthCredentialsStorageTypeKeychain:
        default:
            targetClass = NSClassFromString(@"SFOAuthKeychainCredentials");
            break;
    }
    
    if ([self isMemberOfClass:targetClass]) {
        self = [super init];
        if (self) {
            self.identifier           = theIdentifier;
            self.clientId             = theClientId;
            self.domain               = kSFOAuthDefaultDomain;
            self.logLevel             = kSFOAuthLogLevelInfo;
            self.protocol             = kSFOAuthProtocolHttps;
            _encrypted                = encrypted;
        }
    } else {
        self = [[targetClass alloc] initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted storageType:type];
    }
    return self;
}

#pragma mark - Public Methods

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
    NSString *format = @"<%@: %p, identifier=\"%@\" clientId=\"%@\" domain=\"%@\" identityUrl=\"%@\" instanceUrl=\"%@\" "
                       @"communityId=\"%@\" communityUrl=\"%@\" "
                       @"issuedAt=\"%@\" organizationId=\"%@\" protocol=\"%@\" redirectUri=\"%@\">";
    return [NSString stringWithFormat:format, NSStringFromClass(self.class), self,
            self.identifier, self.clientId, self.domain, self.identityUrl, self.instanceUrl,
            self.communityId, self.communityUrl,
            self.issuedAt, self.organizationId, self.protocol, self.redirectUri];
}

- (void)revoke {
    [self revokeAccessToken];
    [self revokeRefreshToken];
}

- (void)revokeAccessToken {
    if (!([self.identifier length] > 0)) @throw SFOAuthInvalidIdentifierException();
    if (self.logLevel < kSFOAuthLogLevelWarning) {
        [self log:SFLogLevelDebug format:@"%@:revokeAccessToken: access token revoked", [self class]];
    }
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
    if (!([self.identifier length] > 0)) @throw SFOAuthInvalidIdentifierException();
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
    if (!([self.identifier length] > 0)) @throw SFOAuthInvalidIdentifierException();
    self.activationCode = nil;
}

@end
