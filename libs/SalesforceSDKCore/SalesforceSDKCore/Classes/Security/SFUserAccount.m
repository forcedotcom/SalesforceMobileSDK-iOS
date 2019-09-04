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
#import "SFSDKAppFeatureMarkers.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFUserAccountIdentity+Internal.h"

static NSString * const kUser_ACCESS_SCOPES       = @"accessScopes";
static NSString * const kUser_CREDENTIALS         = @"credentials";
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
@synthesize communities = _communities;
@synthesize accessScopes = _accessScopes;
@synthesize idData = _idData;

+ (NSSet*)keyPathsForValuesAffectingApiUrl {
    return [NSSet setWithObjects:@"communityId", @"credentials", nil];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    return [self initWithCredentials:[SFOAuthCredentials new]];
}

- (instancetype)initWithCredentials:(SFOAuthCredentials*)credentials {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create(kSyncQueue, DISPATCH_QUEUE_CONCURRENT);
        _observingCredentials = NO;
        [self setCredentialsInternal:credentials];
        _loginState = (credentials.refreshToken.length > 0 ? SFUserAccountLoginStateLoggedIn : SFUserAccountLoginStateNotLoggedIn);
        _accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:_credentials.userId orgId:_credentials.organizationId];
        if (_loginState == SFUserAccountLoginStateLoggedIn) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureOAuth];
        }
    }
    return self;
}

- (void)dealloc {
    if (_observingCredentials) {
        [_credentials removeObserver:self forKeyPath:kCredentialsUserIdPropName];
        [_credentials removeObserver:self forKeyPath:kCredentialsOrgIdPropName];
    }
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:_accessScopes forKey:kUser_ACCESS_SCOPES];
    [encoder encodeObject:_credentials forKey:kUser_CREDENTIALS];
    [encoder encodeObject:_idData forKey:kUser_ID_DATA];
    [encoder encodeObject:_communityId forKey:kUser_COMMUNITY_ID];
    [encoder encodeObject:_communities forKey:kUser_COMMUNITIES];
    [encoder encodeObject:_customData forKey:kUser_CUSTOM_DATA];
    [encoder encodeInteger:_accessRestrictions forKey:kUser_ACCESS_RESTRICTIONS];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create(kSyncQueue, DISPATCH_QUEUE_CONCURRENT);
        _accessScopes     = [decoder decodeObjectOfClass:[NSSet class] forKey:kUser_ACCESS_SCOPES];
         _accountIdentity = [[SFUserAccountIdentity alloc] init];
        SFOAuthCredentials *creds = [decoder decodeObjectOfClass:[SFOAuthCredentials class] forKey:kUser_CREDENTIALS];
        [self setCredentialsInternal:creds];
        _idData           = [decoder decodeObjectOfClass:[SFIdentityData class] forKey:kUser_ID_DATA];
        _communityId      = [decoder decodeObjectOfClass:[NSString class] forKey:kUser_COMMUNITY_ID];
        _communities      = [decoder decodeObjectOfClass:[NSArray class] forKey:kUser_COMMUNITIES];
        _customData       = [[decoder decodeObjectOfClass:[NSDictionary class] forKey:kUser_CUSTOM_DATA] mutableCopy];
        _accessRestrictions = [decoder decodeIntegerForKey:kUser_ACCESS_RESTRICTIONS];
        _loginState = (_credentials.refreshToken.length > 0 ? SFUserAccountLoginStateLoggedIn : SFUserAccountLoginStateNotLoggedIn);
        if (_loginState == SFUserAccountLoginStateLoggedIn) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureOAuth];
        }
    }
    return self;
}

- (SFUserAccountIdentity *)accountIdentity
{
    __block SFUserAccountIdentity *identity = nil;
    dispatch_sync(_syncQueue, ^{
        identity = self->_accountIdentity;
    });
    return identity;
}

- (NSURL*)apiUrl {
    NSString *communityId = _communityId;
    __block NSURL *url = _credentials.apiUrl;
    if (communityId) {
        dispatch_sync(_syncQueue, ^{
            NSURL *communityUrl = [self communityUrlWithId:communityId];
            if (communityUrl) {
                url =  communityUrl;
            }
        });
    }
    return url;
}

- (NSString *)email {
    __block NSString *email = nil;
    SFIdentityData *data = _idData;
    dispatch_sync(_syncQueue, ^{
        email = data.email;
    });
    return email;
}

- (NSString *)fullName {
    __block NSString *fullName = nil;
    SFIdentityData *data = _idData;
    dispatch_sync(_syncQueue, ^{
        fullName = [NSString stringWithFormat:@"%@ %@",data.firstName,data.lastName];
    });
    return fullName;
}

- (NSString *)userName {
    __block NSString *userName = nil;
    SFIdentityData *data = _idData;
    dispatch_sync(_syncQueue, ^{
        userName = [NSString stringWithFormat:@"%@",data.username];
    });
    return userName;
}

- (NSURL*)communityUrlWithId:(NSString *)communityId {
    if (!communityId) {
        return nil;
    }
    __block NSURL *siteUrl = nil;
    SFSDK_USE_DEPRECATED_BEGIN
    dispatch_sync(_syncQueue, ^{
        SFCommunityData *info = [self communityWithId:communityId];
        siteUrl = info.siteUrl;
    });
    SFSDK_USE_DEPRECATED_END
    return siteUrl;
}

- (SFCommunityData*)communityWithId:(NSString*)communityId {
    if (!communityId || !_communities) return nil;
    
    __block SFCommunityData *communityData = nil;
    __block  NSArray<SFCommunityData *> *communitiesCopy = [_communities copy];
    dispatch_sync(_syncQueue, ^{
        for (SFCommunityData *info in communitiesCopy) {
            if ([info.entityId isEqualToString:communityId]) {
                communityData = info;
                break;
            }
        }
    });
    return communityData;
}

- (NSArray<SFCommunityData *> *)communities {
    __block NSArray<SFCommunityData *> *communitiesLocal = nil;
    dispatch_sync(_syncQueue, ^{
        communitiesLocal = self->_communities;
    });
    return communitiesLocal;
}

- (void)setCommunities:(NSArray<SFCommunityData *> *)communities {
    dispatch_barrier_async(_syncQueue, ^{
        self->_communities = communities;
    });
}

- (void)setAccessScopes:(NSSet<NSString *> *)accessScopes {
    dispatch_barrier_async(_syncQueue, ^{
        self->_accessScopes = accessScopes;
    });
}

/** Returns the path to the user's photo.
 */
- (NSString*)photoPath {
    __block NSString *userPhotoPath = nil;
    dispatch_sync(_syncQueue, ^{
        userPhotoPath = [self photoPathInternal];
    });
    return userPhotoPath;
}

- (NSString *)photoPathInternal {
    NSString *userPhotoPath =  [[SFDirectoryManager sharedManager] directoryForOrg:_credentials.organizationId user:_credentials.userId  community:_communityId?:kDefaultCommunityName type:NSLibraryDirectory components:@[@"mobilesdk", @"photos"]];
    [SFDirectoryManager ensureDirectoryExists:userPhotoPath error:nil];
    return [userPhotoPath stringByAppendingPathComponent:[SFDirectoryManager safeStringForDiskRepresentation:_credentials.userId]];
}

- (UIImage*)photo {
    if (nil == _photo) {
        __weak __typeof(self) weakSelf = self;
        dispatch_sync(_syncQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            NSString *photoPath = [strongSelf photoPathInternal];
            NSFileManager *manager = [[NSFileManager alloc] init];
            if ([manager fileExistsAtPath:photoPath]) {
                strongSelf->_photo = [[UIImage alloc] initWithContentsOfFile:photoPath];
            }
        });
    }
    return _photo;
}

- (void)setPhoto:(UIImage *)photo {
    [self setPhoto:photo completion:nil];
}

- (void)setPhoto:(UIImage*)photo completion:(void (^ __nullable)(void))completion {
    dispatch_barrier_async(_syncQueue, ^{
        NSError *error = nil;
        NSString *photoPath = [self photoPathInternal];
        if (photoPath) {
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:photoPath]) {
                if (![fm removeItemAtPath:photoPath error:&error]) {
                    [SFSDKCoreLogger e:[self class] format:@"Unable to remove previous photo from disk: %@", error];
                }
            }
            if (photo) {
                NSData *data = UIImagePNGRepresentation(photo);
                if (![data writeToFile:photoPath options:NSDataWritingAtomic error:&error]) {
                    [SFSDKCoreLogger e:[self class] format:@"Unable to write photo to disk: %@", error];
                }
            }
            [self willChangeValueForKey:@"photo"];
            self->_photo = photo;
            [self didChangeValueForKey:@"photo"];
            if (completion) {
                completion();
            }
        }
    });
}

- (SFIdentityData *) idData{
    __block SFIdentityData *idData = nil;
    dispatch_sync(_syncQueue, ^{
        idData = self->_idData;
    });
    return idData;
}

- (void)setIdData:(SFIdentityData *)idData {
    dispatch_barrier_async(_syncQueue, ^{
        if (idData != self->_idData) {
            self->_idData = idData;
        }
    });
}

- (SFOAuthCredentials *)credentials {
    __block SFOAuthCredentials *creds = nil;
    dispatch_sync(_syncQueue, ^{
        creds = self->_credentials;
    });
    return creds;
}

- (void)setCredentials:(SFOAuthCredentials *)credentials
{
    dispatch_barrier_async(_syncQueue, ^{
        [self setCredentialsInternal:credentials];
    });
}
    
- (void)setCredentialsInternal:(SFOAuthCredentials *)credentials {
    SFOAuthCredentials *currentCredentials = _credentials;
    SFUserAccountIdentity *accIdentity =  _accountIdentity;
    if (credentials != currentCredentials) {
        if (_observingCredentials) {
            [currentCredentials removeObserver:self  forKeyPath:kCredentialsUserIdPropName];
            [currentCredentials removeObserver:self  forKeyPath:kCredentialsOrgIdPropName];
            _observingCredentials = NO;
        }
        if (credentials != nil) {
            [credentials addObserver:self forKeyPath:kCredentialsUserIdPropName options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
            [credentials addObserver:self forKeyPath:kCredentialsOrgIdPropName options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
            _observingCredentials = YES;
        }
        _credentials = credentials;
        if (accIdentity) {
            accIdentity.userId = credentials.userId;
            accIdentity.orgId =  credentials.organizationId;
        }
    }
}

- (void)setCustomDataObject:(id<NSCoding>)object forKey:(id<NSCopying>)key {
    dispatch_barrier_async(_syncQueue, ^{
        if(!self->_customData) {
            self->_customData = [NSMutableDictionary dictionary];
        }
        [self->_customData setObject:object forKey:key];
    });
}

- (void)removeCustomDataObjectForKey:(id)key {
    dispatch_barrier_async(_syncQueue, ^{
        if(!self->_customData) {
            self->_customData = [NSMutableDictionary dictionary];
        }
        [self->_customData removeObjectForKey:key];
    });
}

- (id)customDataObjectForKey:(id)key {
    __block id object;
    dispatch_barrier_sync(_syncQueue, ^{
        if(!self->_customData) {
            self->_customData = [NSMutableDictionary dictionary];
        }
        object = [self->_customData objectForKey:key];
    });
    return object;
}

- (BOOL)transitionToLoginState:(SFUserAccountLoginState)newLoginState {
    __block BOOL transitionSucceeded;
    dispatch_barrier_sync(_syncQueue, ^{
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
    return _credentials.accessToken != nil && _idData != nil;
}



- (NSString*)description {
    NSString *theUserName = @"*****";
    NSString *theFullName = @"*****";
    
#ifdef DEBUG
    theUserName = _idData.username;
    theFullName = [NSString stringWithFormat:@"%@ %@",_idData.firstName,_idData.lastName];
#endif
    
    NSString * s = [NSString stringWithFormat:@"<SFUserAccount username=%@ fullName=%@ accessScopes=%@ credentials=%@, community=%@>",
                    theUserName, theFullName, _accessScopes, _credentials, _communityId];
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

NSString *SFKeyForGlobalScope() {
    return  SFKeyForUserIdAndScope(nil,nil,nil,SFUserAccountScopeGlobal);
}

NSString *SFKeyForUserAndScope(SFUserAccount *user, SFUserAccountScope scope) {
    return  SFKeyForUserIdAndScope(user.credentials.userId,user.credentials.organizationId,user.credentials.communityId,scope);
}

NSString *SFKeyForUserIdAndScope(NSString *userId,NSString *orgId,NSString *communityId, SFUserAccountScope scope) {
    NSString *key = @"";
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

//#pragma mark - Credentials property changes

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!(object == _credentials && ([keyPath isEqualToString:kCredentialsUserIdPropName] || [keyPath isEqualToString:kCredentialsOrgIdPropName]))) {
        return;
    }
    
    NSString *oldKey = change[NSKeyValueChangeOldKey];
    NSString *newKey = change[NSKeyValueChangeNewKey];
    if ([oldKey isEqual:[NSNull null]]) oldKey = nil;
    if ([newKey isEqual:[NSNull null]]) newKey = nil;
    SFUserAccountIdentity *identity = _accountIdentity;
    if ([keyPath isEqualToString:kCredentialsUserIdPropName]) {
        identity.userId = newKey;
    } else if ([keyPath isEqualToString:kCredentialsOrgIdPropName]) {
        identity.orgId = newKey;
    }
}

@end
