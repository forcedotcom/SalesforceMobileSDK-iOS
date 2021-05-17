/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKOAuthConstants.h"

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

@implementation SFOAuthCredentials

@synthesize identifier                = _identifier;
@synthesize domain                    = _domain;
@synthesize clientId                  = _clientId;
@synthesize redirectUri               = _redirectUri;
@synthesize organizationId            = _organizationId; // cached org ID derived from identityURL
@synthesize identityUrl               = _identityUrl;
@synthesize userId                    = _userId;         // cached user ID derived from identityURL
@synthesize instanceUrl               = _instanceUrl;
@synthesize issuedAt                  = _issuedAt;
@synthesize protocol                  = _protocol;
@synthesize encrypted                 = _encrypted;
@synthesize additionalOAuthFields     = _additionalOAuthFields;
@synthesize jwt                       = _jwt;

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)coder {
    NSString *clusterClassName = [coder decodeObjectOfClass:[NSString class] forKey:kSFOAuthClusterImplementationKey];
    _credentialsChangeSet = [NSMutableDictionary new];
    if (clusterClassName.length == 0) {
        // Legacy credentials class (which doesn't have a persisted implementation class)
        // should default to SFOAuthKeychainCredentials.
        clusterClassName = @"SFOAuthKeychainCredentials";
    }
    Class clusterClass = NSClassFromString(clusterClassName) ?: self.class;
    if ([self isMemberOfClass:clusterClass]) {
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
            if (nil != protocolVal) {
                self.protocol = protocolVal;
            } else {
                self.protocol = kSFOAuthProtocolHttps;
            }
            NSNumber *encryptedBool = [coder decodeObjectOfClass:[NSNumber class] forKey:@"SFOAuthEncrypted"];
            _encrypted = (encryptedBool
                          ? [encryptedBool boolValue]
                          : [coder decodeBoolForKey:@"SFOAuthEncrypted"]);
            if ([self isMemberOfClass:[SFOAuthCredentials class]]) {
                self.refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthRefreshToken"];
                self.accessToken  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthAccessToken"];
                self.lightningDomain  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthLightningDomain"];
                self.lightningSid  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthLightningSID"];
                self.vfDomain  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthVFDomain"];
                self.vfSid  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthVFSID"];
                self.contentDomain  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthContentDomain"];
                self.contentSid  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthContentSID"];
                self.csrfToken  = [coder decodeObjectOfClass:[NSString class] forKey:@"SFOAuthCSRFToken"];
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
    [coder encodeObject:self.lightningDomain    forKey:@"SFOAuthLightningDomain"];
    [coder encodeObject:self.lightningSid       forKey:@"SFOAuthLightningSID"];
    [coder encodeObject:self.vfDomain           forKey:@"SFOAuthVFDomain"];
    [coder encodeObject:self.vfSid              forKey:@"SFOAuthVFSID"];
    [coder encodeObject:self.contentDomain      forKey:@"SFOAuthContentDomain"];
    [coder encodeObject:self.contentSid         forKey:@"SFOAuthContentSID"];
    [coder encodeObject:self.csrfToken          forKey:@"SFOAuthCSRFToken"];
    [coder encodeObject:kSFOAuthArchiveVersion  forKey:@"SFOAuthArchiveVersion"];
    [coder encodeObject:@(self.isEncrypted)     forKey:@"SFOAuthEncrypted"];
    [coder encodeObject:self.additionalOAuthFields forKey:@"SFOAuthAdditionalFields"];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString*)theClientId encrypted:(BOOL)encrypted {
    return [self initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted storageType:SFOAuthCredentialsStorageTypeKeychain];
}

- (instancetype)initWithIdentifier:(NSString *)theIdentifier clientId:(NSString *)theClientId encrypted:(BOOL)encrypted storageType:(SFOAuthCredentialsStorageType)type {
    Class targetClass;
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
            self.protocol             = kSFOAuthProtocolHttps;
            _encrypted                = encrypted;
        }
    } else {
        self = [[targetClass alloc] initWithIdentifier:theIdentifier clientId:theClientId encrypted:encrypted storageType:type];
    }
    _credentialsChangeSet = [NSMutableDictionary new];
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    SFOAuthCredentials *copyCreds = [[[self class] allocWithZone:zone] initWithIdentifier:self.identifier clientId:self.clientId encrypted:self.encrypted];
    copyCreds.protocol = self.protocol;
    copyCreds.domain = self.domain;
    copyCreds.redirectUri = self.redirectUri;
    copyCreds.jwt = self.jwt;
    copyCreds.refreshToken = self.refreshToken;
    copyCreds.accessToken = self.accessToken;
    copyCreds.instanceUrl = self.instanceUrl;
    copyCreds.communityId = self.communityId;
    copyCreds.communityUrl = self.communityUrl;
    copyCreds.issuedAt = self.issuedAt;

    // NB: Intentionally ordering the copying of these, because setting the identity URL automatically
    // sets the OrgID and UserID.  This ensures the values stay in sync.
    copyCreds.identityUrl = self.identityUrl;
    copyCreds.organizationId = self.organizationId;
    copyCreds.userId = self.userId;
    copyCreds.lightningDomain = self.lightningDomain;
    copyCreds.lightningSid = self.lightningSid;
    copyCreds.vfDomain = self.vfDomain;
    copyCreds.vfSid = self.vfSid;
    copyCreds.contentDomain = self.contentDomain;
    copyCreds.contentSid = self.contentSid;
    copyCreds.csrfToken = self.csrfToken;
    copyCreds.additionalOAuthFields = [self.additionalOAuthFields copy];
    return copyCreds;
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
                [SFSDKCoreLogger d:[self class] format:@"%@:setIdentityUrl: invalid identityUrl: %@", [self class], _identityUrl];
                return;
            }
            self.userId = pathComps[pathComps.count - 1];
            self.organizationId = pathComps[pathComps.count - 2];
        } else {
            [SFSDKCoreLogger d:[self class] format:@"%@:setIdentityUrl: invalid or nil identityUrl: %@", [self class], _identityUrl];
        }
    }
}

// This setter is exposed publicly for unit tests.
- (void)setUserId:(NSString *)userId {
    if (userId && ![userId isEqualToString:_userId]) {
        _userId = [userId copy];
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
    [SFSDKCoreLogger d:[self class] format:@"%@:revokeAccessToken: access token revoked", [self class]];
    self.accessToken = nil;
}

- (void)revokeRefreshToken {
    if (!([self.identifier length] > 0)) @throw SFOAuthInvalidIdentifierException();
    [SFSDKCoreLogger d:[self class] format:@"%@:revokeRefreshToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt fields", [self class]];
    self.refreshToken = nil;
    self.instanceUrl  = nil;
    self.communityId  = nil;
    self.communityUrl = nil;
    self.issuedAt     = nil;
    self.identityUrl  = nil;
    self.lightningDomain = nil;
    self.lightningSid = nil;
    self.vfDomain = nil;
    self.vfSid = nil;
    self.contentDomain = nil;
    self.contentSid = nil;
    self.csrfToken = nil;
}

- (void)setPropertyForKey:(NSString *) propertyName withValue:(id) newValue {
    id oldValue = [self valueForKey:propertyName];
    if (newValue) {
        if (![newValue isEqual:oldValue]) {
            @synchronized (_credentialsChangeSet) {
                _credentialsChangeSet[propertyName] = @[oldValue == nil ? [NSNull null] : oldValue, newValue];
            }
        }
    }
    [self setValue:newValue forKey:propertyName];
}

- (void)resetCredentialsChangeSet {
    if (_credentialsChangeSet) {
        @synchronized (_credentialsChangeSet) {
            [_credentialsChangeSet removeAllObjects];
        }
    }
}

- (BOOL)hasPropertyValueChangedForKey:(NSString *) key {
    return [_credentialsChangeSet objectForKey:key] != nil;
}

- (NSURL *)overrideDomainIfNeeded {
    NSString *refreshDomain = self.communityId ? self.communityUrl.absoluteString : self.domain;
    NSString *protocolHost = self.communityId ? refreshDomain : [NSString stringWithFormat:@"%@://%@", self.protocol, refreshDomain];
    return [NSURL URLWithString:protocolHost];
}

/** Update the credentials using the provided oauth parameters.
 This method only update the following parameters:
 - identityUrl
 - accessToken
 - instanceUrl
 - issuedAt
 - communityId
 - communityUrl
 */
- (void)updateCredentials:(NSDictionary *) params {
    if (params[kSFOAuthAccessToken]) {
        [self setPropertyForKey:@"accessToken" withValue:params[kSFOAuthAccessToken]];
    }
    if (params[kSFOAuthIssuedAt]) {
        self.issuedAt = [SFSDKOAuth2 timestampStringToDate:params[kSFOAuthIssuedAt]];
    }
    if (params[kSFOAuthInstanceUrl]) {
        [self setPropertyForKey:@"instanceUrl" withValue:[NSURL URLWithString:params[kSFOAuthInstanceUrl]]];
    }
    if (params[kSFOAuthId]) {
        [self setPropertyForKey:@"identityUrl" withValue:[NSURL URLWithString:params[kSFOAuthId]]];
    }
    if (params[kSFOAuthCommunityId]) {
        [self setPropertyForKey:@"communityId" withValue:params[kSFOAuthCommunityId]];
    }
    if (params[kSFOAuthCommunityUrl]) {
        [self setPropertyForKey:@"communityUrl" withValue:[NSURL URLWithString:params[kSFOAuthCommunityUrl]]];
    }
    if (params[kSFOAuthRefreshToken]) {
        [self setPropertyForKey:@"refreshToken" withValue:params[kSFOAuthRefreshToken]];
    }
    if (params[kSFOAuthLightningDomain]) {
        self.lightningDomain = params[kSFOAuthLightningDomain];
    }
    if (params[kSFOAuthLightningSID]) {
        self.lightningSid = params[kSFOAuthLightningSID];
    }
    if (params[kSFOAuthVFDomain]) {
        self.vfDomain = params[kSFOAuthVFDomain];
    }
    if (params[kSFOAuthVFSID]) {
        self.vfSid = params[kSFOAuthVFSID];
    }
    if (params[kSFOAuthContentDomain]) {
        self.contentDomain = params[kSFOAuthContentDomain];
    }
    if (params[kSFOAuthContentSID]) {
        self.contentSid = params[kSFOAuthContentSID];
    }
    if (params[kSFOAuthCSRFToken]) {
        self.csrfToken = params[kSFOAuthCSRFToken];
    }
}

@end
