/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccount.h"
#import "SFUserAccountManager.h"
#import "SFDirectoryManager.h"

#import <SalesforceOAuth/SFOAuthCredentials.h>
#import <SalesforceCommonUtils/SFLogger.h>

static NSString * const kUser_ACCESS_SCOPES     = @"accessScopes";
static NSString * const kUser_CREDENTIALS       = @"credentials";
static NSString * const kUser_EMAIL             = @"email";
static NSString * const kUser_FULL_NAME         = @"fullName";
static NSString * const kUser_ORGANIZATION_NAME = @"organizationName";
static NSString * const kUser_USER_NAME         = @"userName";
static NSString * const kUser_COMMUNITY_ID      = @"communityId";
static NSString * const kUser_COMMUNITIES       = @"communities";
static NSString * const kUser_ID_DATA           = @"idData";
static NSString * const kUser_CUSTOM_DATA       = @"customData";

/** Key that identifies the global scope
 */
static NSString * const kGlobalScopingKey = @"-global-";

@interface SFUserAccount ()

@property (nonatomic, strong) NSMutableDictionary *customData;

@end

@implementation SFUserAccount

@synthesize photo = _photo;

+ (NSSet*)keyPathsForValuesAffectingApiUrl {
    return [NSSet setWithObjects:@"communityId", @"credentials", nil];
}

- (id)init {
    return [self initWithIdentifier:[SFUserAccountManager sharedInstance].oauthClientId];
}

- (id)initWithIdentifier:(NSString*)identifier {
    self = [super init];
    if (self) {
        NSString *clientId = [SFUserAccountManager sharedInstance].oauthClientId;
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
    [encoder encodeObject:_organizationName forKey:kUser_ORGANIZATION_NAME];
    [encoder encodeObject:_userName forKey:kUser_USER_NAME];
    [encoder encodeObject:_credentials forKey:kUser_CREDENTIALS];
    [encoder encodeObject:_idData forKey:kUser_ID_DATA];
    [encoder encodeObject:_communityId forKey:kUser_COMMUNITY_ID];
    [encoder encodeObject:_communities forKey:kUser_COMMUNITIES];
    [encoder encodeObject:_customData forKey:kUser_CUSTOM_DATA];
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (self) {
        _accessScopes = [decoder decodeObjectForKey:kUser_ACCESS_SCOPES];
        _email = [decoder decodeObjectForKey:kUser_EMAIL];
        _fullName = [decoder decodeObjectForKey:kUser_FULL_NAME];
        _credentials = [decoder decodeObjectForKey:kUser_CREDENTIALS];
        _idData = [decoder decodeObjectForKey:kUser_ID_DATA];
        _organizationName = [decoder decodeObjectForKey:kUser_ORGANIZATION_NAME];
        _userName = [decoder decodeObjectForKey:kUser_USER_NAME];
        _communityId = [decoder decodeObjectForKey:kUser_COMMUNITY_ID];
        _communities = [decoder decodeObjectForKey:kUser_COMMUNITIES];
        _customData = [decoder decodeObjectForKey:kUser_CUSTOM_DATA];
	}
	return self;
}

- (NSURL*)apiUrl {
    if (self.communityId) {
        NSURL *communityUrl = [self communityUrlWithId:self.communityId];
        if (communityUrl) {
            return communityUrl;
        }
    }
    return self.credentials.apiUrl;
}

- (NSURL*)communityUrlWithId:(NSString *)communityId {
    if (!communityId) {
        return nil;
    }
    
    SFCommunityData *info = [self communityWithId:communityId];
    return info.siteUrl;
}

- (SFCommunityData*)communityWithId:(NSString*)communityId {
    for (SFCommunityData *info in self.communities) {
        if ([info.entityId isEqualToString:communityId]) {
            return info;
        }
    }
    return nil;
}

/** Returns the path to the user's photo.
 */
- (NSString*)photoPath {
    NSString *userPhotoPath = [[SFDirectoryManager sharedManager] directoryForUser:self type:NSLibraryDirectory components:@[@"mobilesdk", @"photos"]];
    [SFDirectoryManager ensureDirectoryExists:userPhotoPath error:nil];
    return [userPhotoPath stringByAppendingPathComponent:[SFDirectoryManager safeStringForDiskRepresentation:self.credentials.userId]];
}

- (UIImage*)photo {
    if (nil == _photo) {
        NSString *photoPath = [self photoPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:photoPath]) {
            _photo = [[UIImage alloc] initWithContentsOfFile:photoPath];
        }
    }
    return _photo;
}

- (void)setPhoto:(UIImage *)photo {
    NSError *error = nil;
    NSString *photoPath = [self photoPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:photoPath]) {
        if (![fm removeItemAtPath:photoPath error:&error]) {
            [self log:SFLogLevelError format:@"Unable to remove previous photo from disk: %@", error];
        }
    }
    
    NSData *data = UIImagePNGRepresentation(photo);
    if (![data writeToFile:photoPath options:NSDataWritingAtomic error:&error]) {
        [self log:SFLogLevelError format:@"Unable to write photo to disk: %@", error];
    }
    
    [self willChangeValueForKey:@"photo"];
    _photo = photo;
    [self didChangeValueForKey:@"photo"];
}

- (void)setIdData:(SFIdentityData *)idData {
    if (idData != _idData) {
        _idData = idData;
    }
    
    // Set other account properties from latest identity data.
    self.fullName = idData.displayName;
    self.email = idData.email;
    self.userName = idData.username;
}

- (void)setCustomDataObject:(id<NSCoding>)object forKey:(id<NSCopying>)key {
    if (!self.customData) {
        self.customData = [NSMutableDictionary dictionary];
    }
    
    [self.customData setObject:object forKey:key];
}

- (void)removeCustomDataObjectForKey:(id)key {
    if (!self.customData) {
        self.customData = [NSMutableDictionary dictionary];
    }
    
    [self.customData removeObjectForKey:key];
}

- (id)customDataObjectForKey:(id)key {
    if (!self.customData) {
        self.customData = [NSMutableDictionary dictionary];
    }
    
    return [self.customData objectForKey:key];
}

- (BOOL)isSessionValid {
    // A session is considered "valid" when the user
    // has an access token as well as the identity data
    return self.credentials.accessToken != nil && self.idData != nil;
}

- (NSString*)description {
    NSString * s = [NSString stringWithFormat:@"<SFUserAccount username=%@ fullName=%@ accessScopes=%@ credentials=%@, community=%@>",
                    self.userName, self.fullName, self.accessScopes, self.credentials, self.communityId];
    return s;
}

NSString *SFKeyForUserAndScope(SFUserAccount *user, SFUserAccountScope scope) {
    NSString *key = nil;
    switch (scope) {
        case SFUserAccountScopeGlobal:
            key = kGlobalScopingKey;
            break;
            
        case SFUserAccountScopeOrg:
            if (user.credentials.organizationId != nil) {
                key = user.credentials.organizationId;
            }
            break;
            
        case SFUserAccountScopeUser:
            if (user.credentials.organizationId != nil && user.credentials.userId != nil) {
                key = [NSString stringWithFormat:@"%@-%@", user.credentials.organizationId, user.credentials.userId];
            }
            break;
            
        case SFUserAccountScopeCommunity:
            if (user.credentials.organizationId != nil && user.credentials.userId != nil) {
                key = [NSString stringWithFormat:@"%@-%@-%@", user.credentials.organizationId, user.credentials.userId, user.communityId];
            }
            break;
    }
    
    return key;
}

@end
