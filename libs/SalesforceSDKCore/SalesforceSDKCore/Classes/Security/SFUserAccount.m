/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccount+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFDirectoryManager.h"
#import "SFOAuthCredentials.h"
#import "SFCommunityData.h"
#import "SFIdentityData.h"
#import "SFSDKAppFeatureMarkers.h"

static NSString * const kUser_ACCESS_SCOPES       = @"accessScopes";
static NSString * const kUser_CREDENTIALS         = @"credentials";
static NSString * const kUser_EMAIL               = @"email";
static NSString * const kUser_FULL_NAME           = @"fullName";
static NSString * const kUser_ORGANIZATION_NAME   = @"organizationName";
static NSString * const kUser_USER_NAME           = @"userName";
static NSString * const kUser_COMMUNITY_ID        = @"communityId";
static NSString * const kUser_COMMUNITIES         = @"communities";
static NSString * const kUser_ID_DATA             = @"idData";
static NSString * const kUser_CUSTOM_DATA         = @"customData";
static NSString * const kUser_ACCESS_RESTRICTIONS = @"accessRestrictions";
static NSString * const kCredentialsUserIdPropName = @"userId";
static NSString * const kCredentialsOrgIdPropName = @"organizationId";
static NSString * const kSFAppFeatureOAuth = @"UA";

static const char * kSyncQueue = "com.salesforce.mobilesdk.sfuseraccount.syncqueue";
/** Key that identifies the global scope
 */
static NSString * const kGlobalScopingKey = @"-global-";

@interface SFUserAccount ()
{
    BOOL _observingCredentials;
    dispatch_queue_t _syncQueue;

}

@property (nonatomic, strong) NSMutableDictionary *customData;

- (id)initWithCoder:(NSCoder*)decoder NS_DESIGNATED_INITIALIZER;

@end

@implementation SFUserAccount

@synthesize photo = _photo;
@synthesize accountIdentity = _accountIdentity;
@synthesize credentials = _credentials;

+ (NSSet*)keyPathsForValuesAffectingApiUrl {
    return [NSSet setWithObjects:@"communityId", @"credentials", nil];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    return [self initWithCredentials:[SFOAuthCredentials new]];
}

- (instancetype)initWithCredentials:(SFOAuthCredentials*) credentials {
    self = [super init];
    if (self) {
        _observingCredentials = NO;
        self.credentials = credentials;
        _loginState = (credentials.refreshToken.length > 0 ? SFUserAccountLoginStateLoggedIn : SFUserAccountLoginStateNotLoggedIn);
        _syncQueue = dispatch_queue_create(kSyncQueue, NULL);
        if (_loginState == SFUserAccountLoginStateLoggedIn) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureOAuth];
        }
    }
    return self;
}

- (void)dealloc {
    if (_observingCredentials) {
        [self.credentials removeObserver:self forKeyPath:kCredentialsUserIdPropName];
        [self.credentials removeObserver:self forKeyPath:kCredentialsOrgIdPropName];
    }
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
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_syncQueue, ^{
        [encoder encodeObject:weakSelf.customData forKey:kUser_CUSTOM_DATA];
    });
    
    [encoder encodeInteger:_accessRestrictions forKey:kUser_ACCESS_RESTRICTIONS];
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (self) {
        _accessScopes     = [decoder decodeObjectOfClass:[NSSet class] forKey:kUser_ACCESS_SCOPES];
        _email            = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_EMAIL];
        _fullName         = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_FULL_NAME];
        _credentials      = [decoder decodeObjectOfClass:[SFOAuthCredentials class] forKey:kUser_CREDENTIALS];
        _idData           = [decoder decodeObjectOfClass:[SFIdentityData class] forKey:kUser_ID_DATA];
        _organizationName = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_ORGANIZATION_NAME];
        _userName         = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_USER_NAME];
        _communityId      = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_COMMUNITY_ID];
        _communities      = [decoder decodeObjectOfClass:[NSArray class] forKey:kUser_COMMUNITIES];
        _customData       = [[decoder decodeObjectOfClass:[NSDictionary class] forKey:kUser_CUSTOM_DATA] mutableCopy];
        _accessRestrictions = [decoder decodeIntegerForKey:kUser_ACCESS_RESTRICTIONS];
        _loginState = (_credentials.refreshToken.length > 0 ? SFUserAccountLoginStateLoggedIn : SFUserAccountLoginStateNotLoggedIn);
        _syncQueue = dispatch_queue_create(kSyncQueue, NULL);
        if (_loginState == SFUserAccountLoginStateLoggedIn) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureOAuth];
        }
	}
	return self;
}

- (SFUserAccountIdentity *)accountIdentity
{
    if (_accountIdentity == nil) {
        _accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:self.credentials.userId orgId:self.credentials.organizationId];
    }
    
    return _accountIdentity;
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
        NSFileManager *manager = [[NSFileManager alloc] init];
        if ([manager fileExistsAtPath:photoPath]) {
            _photo = [[UIImage alloc] initWithContentsOfFile:photoPath];
        }
    }
    return _photo;
}

- (void)setPhoto:(UIImage *)photo {
    NSError *error = nil;
    NSString *photoPath = [self photoPath];
    if (photoPath) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:photoPath]) {
            if (![fm removeItemAtPath:photoPath error:&error]) {
                [SFSDKCoreLogger e:[self class] format:@"Unable to remove previous photo from disk: %@", error];
            }
        }
        NSData *data = UIImagePNGRepresentation(photo);
        if (![data writeToFile:photoPath options:NSDataWritingAtomic error:&error]) {
            [SFSDKCoreLogger e:[self class] format:@"Unable to write photo to disk: %@", error];
        }
        
        [self willChangeValueForKey:@"photo"];
        _photo = photo;
        [self didChangeValueForKey:@"photo"];
    }
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

- (void)setCredentials:(SFOAuthCredentials *)credentials
{
    if (credentials != _credentials) {
        if (_observingCredentials) {
            [_credentials removeObserver:self forKeyPath:kCredentialsUserIdPropName];
            [_credentials removeObserver:self forKeyPath:kCredentialsOrgIdPropName];
            _observingCredentials = NO;
        }
        if (credentials != nil) {
            [credentials addObserver:self forKeyPath:kCredentialsUserIdPropName options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
            [credentials addObserver:self forKeyPath:kCredentialsOrgIdPropName options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
            _observingCredentials = YES;
        }
        
        _credentials = credentials;
        self.accountIdentity.userId = _credentials.userId;
        self.accountIdentity.orgId = _credentials.organizationId;
    }
}

- (void)setCustomDataObject:(id<NSCoding>)object forKey:(id<NSCopying>)key {
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_syncQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf.customData) {
            strongSelf.customData = [NSMutableDictionary dictionary];
        }
        [strongSelf.customData setObject:object forKey:key];
    });
}

- (void)removeCustomDataObjectForKey:(id)key {
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_syncQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf.customData) {
            strongSelf.customData = [NSMutableDictionary dictionary];
        }
        [strongSelf.customData removeObjectForKey:key];
    });
}

- (id)customDataObjectForKey:(id)key {
    __weak __typeof(self) weakSelf = self;
    __block id object;
    dispatch_sync(_syncQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf.customData) {
            strongSelf.customData = [NSMutableDictionary dictionary];
        }
        object = [strongSelf.customData objectForKey:key];
    });
    return object;
}

- (BOOL)transitionToLoginState:(SFUserAccountLoginState)newLoginState {
    __block BOOL transitionSucceeded;
    dispatch_sync(_syncQueue, ^{
        switch (newLoginState) {
            case SFUserAccountLoginStateLoggedIn:
                transitionSucceeded = (self.loginState == SFUserAccountLoginStateNotLoggedIn || self.loginState == SFUserAccountLoginStateLoggedIn);
                break;
            case SFUserAccountLoginStateNotLoggedIn:
                transitionSucceeded = (self.loginState == SFUserAccountLoginStateNotLoggedIn || self.loginState == SFUserAccountLoginStateLoggingOut);
                break;
            case SFUserAccountLoginStateLoggingOut:
                transitionSucceeded = (self.loginState == SFUserAccountLoginStateLoggedIn);
                break;
            default:
                transitionSucceeded = NO;
        }
        if (transitionSucceeded) {
            self.loginState = newLoginState;
        } else {
            [SFSDKCoreLogger w:[self class] format:@"%@ Invalid login state transition from '%@' to '%@'. No action taken.", NSStringFromSelector(_cmd), [[self class] loginStateDescriptionFromLoginState:self.loginState], [[self class] loginStateDescriptionFromLoginState:newLoginState]];
        }
    });
    return transitionSucceeded;
}

- (BOOL)isSessionValid {

    // A session is considered "valid" when the user
    // has an access token as well as the identity data
    return self.credentials.accessToken != nil && self.idData != nil;
}



- (NSString*)description {
    NSString *theUserName = @"*****";
    NSString *theFullName = @"*****";
    
#ifdef DEBUG
    theUserName = self.userName;
    theFullName = self.fullName;
#endif
    
    NSString * s = [NSString stringWithFormat:@"<SFUserAccount username=%@ fullName=%@ accessScopes=%@ credentials=%@, community=%@>",
                    theUserName, theFullName, self.accessScopes, self.credentials, self.communityId];
    return s;
}

+ (NSString *)loginStateDescriptionFromLoginState:(SFUserAccountLoginState)loginState {
    switch (loginState) {
        case SFUserAccountLoginStateLoggedIn:
            return @"SFUserAccountLoginStateLoggedIn";
        case SFUserAccountLoginStateLoggingOut:
            return @"SFUserAccountLoginStateLoggingOut";
        case SFUserAccountLoginStateNotLoggedIn:
            return @"SFUserAccountLoginStateNotLoggedIn";
        default:
            return [NSString stringWithFormat:@"Unknown login state (code: %lu)", (unsigned long)loginState];
    }
}

NSString *SFKeyForUserAndScope(SFUserAccount *user, SFUserAccountScope scope) {
    return  SFKeyForUserIdAndScope(user.credentials.userId,user.credentials.organizationId,user.credentials.communityId,scope);
}

NSString *SFKeyForUserIdAndScope(NSString *userId,NSString *orgId, NSString *communityId, SFUserAccountScope scope) {
    NSString *key = nil;
    switch (scope) {
        case SFUserAccountScopeGlobal:
            key = kGlobalScopingKey;
            break;
            
        case SFUserAccountScopeOrg:
            if (orgId != nil) {
                key = orgId;
            }
            break;
            
        case SFUserAccountScopeUser:
            if (orgId != nil && userId != nil) {
                key = [NSString stringWithFormat:@"%@-%@", orgId, userId];
            }
            break;
            
        case SFUserAccountScopeCommunity:
            if (orgId != nil && userId != nil) {
                key = [NSString stringWithFormat:@"%@-%@-%@", orgId, userId, communityId];
            }
            break;
    }
    
    return key;
}

#pragma mark - Credentials property changes
// Disable automatic KVO notificaiton for the photo property, as we implement manual KVO in setPhoto
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"photo"]) {
        return NO;
    }
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!(object == self.credentials && ([keyPath isEqualToString:kCredentialsUserIdPropName] || [keyPath isEqualToString:kCredentialsOrgIdPropName]))) {
        return;
    }
    
    NSString *oldKey = change[NSKeyValueChangeOldKey];
    NSString *newKey = change[NSKeyValueChangeNewKey];
    if ([oldKey isEqual:[NSNull null]]) oldKey = nil;
    if ([newKey isEqual:[NSNull null]]) newKey = nil;
    
    if ([keyPath isEqualToString:kCredentialsUserIdPropName]) {
        self.accountIdentity.userId = newKey;
    } else if ([keyPath isEqualToString:kCredentialsOrgIdPropName]) {
        self.accountIdentity.orgId = newKey;
    }
}

@end
