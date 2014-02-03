//
//  SFUserAccount.m
//
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFUserAccount.h"
#import "SFUserAccount+Internal.h"
#import "SFUserAccountManager.h"
#import <SalesforceOAuth/SFOAuthCredentials.h>
#import <SalesforceCommonUtils/SFLogger.h>

NSString *kCommunityEntityIdKey = @"id";
NSString *kCommunityNameKey = @"name";
NSString *kCommunitySiteUrlKey = @"siteUrl";

static NSString * const kUser_ACCESS_SCOPES     = @"accessScopes";
static NSString * const kUser_CREDENTIALS       = @"credentials";
static NSString * const kUser_EMAIL             = @"email";
static NSString * const kUser_FULL_NAME         = @"fullName";
static NSString * const kUser_ORGANIZATION_ID   = @"organizationId";
static NSString * const kUser_ORGANIZATION_NAME = @"organizationName";
static NSString * const kUser_SESSION_EXPIRES   = @"sessionExpiresAt";
static NSString * const kUser_USER_NAME         = @"userName";
static NSString * const kUser_COMMUNITY_ID      = @"communityId";
static NSString * const kUser_COMMUNITIES       = @"communities";

@implementation SFUserAccount

@synthesize accessScopes        = _accessScopes;
@synthesize credentials         = _credentials;
@synthesize email               = _email;
@synthesize organizationId      = _organizationId;
@synthesize organizationName    = _organizationName;
@synthesize fullName            = _fullName;
@synthesize userName            = _userName;
@synthesize sessionExpiresAt    = _sessionExpiresAt; // private

+ (void)initialize {
    [self setVersion:1];
}

- (id)init {
    return [self initWithIdentifier:[SFUserAccountManager defaultClientIdentifier]];
}

- (id)initWithIdentifier:(NSString*)identifier {
    self = [super init];
    if (self) {
        NSString *clientId = [SFUserAccountManager defaultClientIdentifier];
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:clientId encrypted:YES];
        [SFUserAccountManager applyCurrentLogLevel:creds];
        self.credentials = creds;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:_accessScopes forKey:kUser_ACCESS_SCOPES];
    [encoder encodeObject:_email forKey:kUser_EMAIL];
    [encoder encodeObject:_fullName forKey:kUser_FULL_NAME];
    [encoder encodeObject:_organizationId forKey:kUser_ORGANIZATION_ID];
    [encoder encodeObject:_organizationName forKey:kUser_ORGANIZATION_NAME];
    [encoder encodeObject:_sessionExpiresAt forKey:kUser_SESSION_EXPIRES];
    [encoder encodeObject:_userName forKey:kUser_USER_NAME];
    [encoder encodeObject:_credentials forKey:kUser_CREDENTIALS];
    [encoder encodeObject:self.communityId forKey:kUser_COMMUNITY_ID];
    [encoder encodeObject:self.communities forKey:kUser_COMMUNITIES];
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (self) {
        _accessScopes = [decoder decodeObjectForKey:kUser_ACCESS_SCOPES];
        _email = [decoder decodeObjectForKey:kUser_EMAIL];
        _fullName = [decoder decodeObjectForKey:kUser_FULL_NAME];
        _credentials = [decoder decodeObjectForKey:kUser_CREDENTIALS];
        _organizationId = [decoder decodeObjectForKey:kUser_ORGANIZATION_ID];
        _organizationName = [decoder decodeObjectForKey:kUser_ORGANIZATION_NAME];
        _sessionExpiresAt = [decoder decodeObjectForKey:kUser_SESSION_EXPIRES];
        _userName = [decoder decodeObjectForKey:kUser_USER_NAME];
        switch ([decoder versionForClassName:NSStringFromClass([self class])]) {
            case 0: // Version before community support
                self.communityId = nil;
                self.communities = nil;
                break;
                
            case 1: // Community support
                self.communityId = [decoder decodeObjectForKey:kUser_COMMUNITY_ID];
                self.communities = [decoder decodeObjectForKey:kUser_COMMUNITIES];
                break;
        };
	}
	return self;
}

- (void)setCommunityId:(NSString *)communityId {
    if (nil == communityId) {
        _communityId = nil;
#warning TODO for now we use the identityUrl to build the internal community but let's check with the oauth team if we can have it in a better way
        NSURL *identityUrl = self.credentials.identityUrl;
        self.credentials.instanceUrl = [[NSURL alloc] initWithScheme:[identityUrl scheme] host:[identityUrl host] path:@"/"];
    } else {
        NSDictionary *communityInfo = [self communityWithId:communityId];
        _communityId = communityInfo[kCommunityEntityIdKey];
        self.credentials.instanceUrl = communityInfo[kCommunitySiteUrlKey];
    }
}

- (NSDictionary*)communityWithId:(NSString*)communityId {
    for (NSDictionary *info in self.communities) {
        if ([info[kCommunityEntityIdKey] isEqualToString:communityId]) {
            return info;
        }
    }
    return nil;
}

- (NSString*)description {
    NSString * s = [NSString stringWithFormat:@"<SFUserAccount username=%@ fullName=%@ accessScopes=%@ credentials=%@, community=%@>",
                    self.userName, self.fullName, self.accessScopes, self.credentials, self.communityId];
    return s;
}

#pragma mark -
#pragma mark Public

- (BOOL)isSessionValid {
    return (self.credentials.accessToken != nil);
}

@end
