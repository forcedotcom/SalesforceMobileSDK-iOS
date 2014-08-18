/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSyncMetadataManager.h"
#import <SalesforceSDKCore/SFUserAccount.h>

// Default API version.
static NSString * kDefaultApiVersion = @"v29.0";

// Error constants.
static NSInteger kSFNetworkRequestFailedDueToNoModification = 304;
NSInteger const SFMetadataManagerErrorCode = -9001;
NSString * const SFMetadataManagerErrorDomain = @"SFDefaultMetadataManagerErrorDomain";

// Maximum number of results.
static NSInteger const kSFMetadataMaximumLimit = 200;

// Default cache refresh interval.
static NSTimeInterval kSFMetadataRefreshInterval = 60 * 60 * 24;

// Cache constants.
NSString * const kSFMRUCacheType= @"recent_objects";
NSString * const kSFMetadataCacheType= @"metadata";
NSString * const kSFSmartScopeObjectTypes = @"smart_search_scopes";
NSString * const kSFMRUObjectsByObjectType = @"mru_for_%@";
NSString * const kSFAllObjects = @"all_objects";
NSString * const kSFAllSearchableObjects = @"all_searchable_objects";
NSString * const kSFObjectByType = @"object_info_%@";
NSString * const kSFObjectLayoutByType = @"object_layout_%@";

// REST request constants.
static NSString *const kSFMetadataRestApiPath = @"services/data";

@interface SFSmartSyncMetadataManager ()

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, strong) SFSmartSyncNetworkManager *networkManager;
@property (nonatomic, strong) SFSmartSyncCacheManager *cacheManager;
@property (nonatomic, assign) BOOL cacheEnabled;
@property (nonatomic, assign) BOOL encryptCache;

- (BOOL)shouldCallCompletionBlock:(id)completionBlock completionBlockInvoked:(BOOL)completionBlockInvoked cachePolicy:(SFDataCachePolicy)cachePolicy;
- (NSError *)errorWithDescription:(NSString *)errorMessage;
- (BOOL)shouldCacheData:(SFDataCachePolicy)cachePolicy;
- (BOOL)shouldIgnoreCache:(SFDataCachePolicy)cachePolicy;
- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes name:(NSString *)name;
- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes keyPrefix:(NSString *)keyPrefix;
- (NSDictionary *)requestHeader:(NSDate *)cacheTime;

- (void)cacheObject:(id)object cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey;
- (NSObject * )cachedObject:(SFDataCachePolicy)cachePolicy cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey objectClass:(Class)objectClass containedObjectClass:(Class)objectClass cachedTime:(out NSDate **)cachedTime;
- (void)addObject:(NSObject *)object toArray:(NSMutableArray *)array;
- (NSString *)returnFieldsForObjectType:(SFObjectType *)objectType;
- (NSString *)objectIdsForObjects:(NSArray *)objects;
- (NSDictionary *)findObject:(NSString *)objectId inList:(NSArray *)objects;
- (NSArray *)filterSearchableObjects:(NSArray *)allObjects;

@end

@implementation SFSmartSyncMetadataManager

static NSMutableDictionary *metadataMgrList = nil;

+ (id)sharedInstance:(SFUserAccount *)user {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        metadataMgrList = [[NSMutableDictionary alloc] init];
	});
    @synchronized([SFSmartSyncMetadataManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            id metadataMgr = [metadataMgrList objectForKey:key];
            if (!metadataMgr) {
                metadataMgr = [[SFSmartSyncMetadataManager alloc] init:user];
                [metadataMgrList setObject:metadataMgr forKey:key];
            }
            return metadataMgr;
        } else {
            return nil;
        }
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
    @synchronized([SFSmartSyncMetadataManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            [metadataMgrList removeObjectForKey:key];
        }
    }
}

- (id)init:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        self.networkManager = [SFSmartSyncNetworkManager sharedInstance:user];
        self.cacheManager = [SFSmartSyncCacheManager sharedInstance:user];
        self.apiVersion = kDefaultApiVersion;
        self.cacheEnabled = YES;
        self.encryptCache = YES;
    }
    return self;
}

- (void)setNetworkManager:(SFSmartSyncNetworkManager *)networkManager {
    self.networkManager = networkManager;
}

- (void)setCacheManager:(SFSmartSyncCacheManager *)cacheManager {
    self.cacheManager = cacheManager;
}

- (void)setApiVersion:(NSString *)apiVersion {
    self.apiVersion = apiVersion;
}

- (void)loadSmartScopeObjectTypes:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan completionBlock:(void(^)(NSArray *results, BOOL isDataFromCache))completionBlock error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (!self.networkManager) {
        errorMessage = @"remoteServiceManager not specified";
    }
    if (nil != errorMessage) {
        errorMessage = [NSString stringWithFormat:@"Unable to load recently searched object types [%@]", errorMessage];
        [self log:SFLogLevelError msg:errorMessage];
        if (errorBlock) {
            NSError *error = [self errorWithDescription:errorMessage];
            if (errorBlock) {
                errorBlock(error);
            }
        }
        return;
    }
    NSString *cacheType = kSFMRUCacheType;
    NSString *cacheKey = kSFSmartScopeObjectTypes;
    if (cachePolicy == SFDataCachePolicyInvalidateCacheDontReload) {

        // Invalidates the cache.
        [self.cacheManager removeCache:kSFMetadataCacheType cacheKey:cacheKey];
        return;
    }

    // Checks the cache first.
    NSDate *cachedTime = nil;
    NSArray *cachedData = (NSArray *)[self cachedObject:cachePolicy cacheType:cacheType cacheKey:cacheKey objectClass:[NSArray class] containedObjectClass:[SFObjectType class] cachedTime:&cachedTime];
    __block BOOL completionBlockInvoked = NO;
    if (cachedData && cachedData.count > 0 && cachePolicy != SFDataCachePolicyReloadAndReturnCacheOnFailure) {
        completionBlockInvoked = YES;
        if (completionBlock) {
            completionBlock(cachedData, YES);
        }
    }

    // Checks to see if we need to refresh the cache.
    if (![self.cacheManager needToReloadCache:(nil != cachedData) cachePolicy:cachePolicy lastCachedTime:cachedTime refreshIfOlderThan:refreshCacheIfOlderThan]) {

        // No need to refresh the cache, hence returns directly.
        if (!completionBlockInvoked && completionBlock) {
            completionBlock(cachedData, YES);
        }
        return;
    }
    SFDataCachePolicy dataPolicy = SFDataCachePolicyReturnCacheDataAndReloadIfExpired;
    if ([self shouldIgnoreCache:cachePolicy]) {
        dataPolicy = cachePolicy;
    }
    void(^invokeErrorBlock)(NSError *error) = ^(NSError *error) {
        if (error.code != kSFNetworkRequestFailedDueToNoModification) {
            [self log:SFLogLevelError format:@"Failed to get recently access object types, %@", [error localizedDescription]];
        }
        if (error.code == kSFNetworkRequestFailedDueToNoModification) {
            if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
                completionBlock(cachedData, YES);
            }
        } else if (!completionBlockInvoked && cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
            if (completionBlock) {
                completionBlock(cachedData, YES);
            }
        } else  if (errorBlock && !completionBlockInvoked) {
            errorBlock(error);
        }
    };

    // Loads the object layouts.
    void (^loadObjectLayouts)(NSArray *objectTypes, NSArray *searchableObjects) = ^ (NSArray *objectTypes, NSArray *searchableObjects){
        [self loadObjectTypesLayout:objectTypes cachePolicy:dataPolicy refreshCacheIfOlderThan:kSFMetadataRefreshInterval completion:^(NSArray *result, BOOL isDataFromCache) {

            // Caches the data.
            if ([self shouldCacheData:cachePolicy]) {
                [self cacheObject:objectTypes cacheType:cacheType cacheKey:cacheKey];
            }
            if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
                completionBlock(objectTypes, NO);
            }
        } error:^(NSError *error) {
            invokeErrorBlock(error);
        }];
    };

    // Processes the smart scopes.
    void(^processSmartScopes)(NSArray *recentItems, NSArray *searchableObjects) = ^ (NSArray *recentItems, NSArray *searchableObjects) {
        if (recentItems) {
            NSMutableArray *returnList = [NSMutableArray arrayWithArray:recentItems];
            for (NSString *objectType in recentItems) {
                SFObjectType *typeModel = [self objectTypeInArray:searchableObjects name:objectType];
                if (nil == typeModel) {

                    // If the user does not have acccess to the type model, removes it.
                    [returnList removeObject:objectType];
                }
            }
            recentItems = returnList;
        }
        if (nil != recentItems && recentItems.count > 0) {
            NSMutableArray *returnList = [NSMutableArray arrayWithCapacity:recentItems.count];
            for (NSString *objectType in recentItems) {
                SFObjectType *typeModel = [self objectTypeInArray:searchableObjects name:objectType];
                if (typeModel) {
                    [returnList addObject:typeModel];
                }
            }
            recentItems = returnList;
        }

        // Loads the layout, which will call the completion block.
        if (recentItems && recentItems.count > 0) {
            loadObjectLayouts(recentItems, searchableObjects);
        } else {
            completionBlock(recentItems, NO);
        }
    };

    // Loads the smart scopes.
    void (^loadSearchScope)(NSArray *searchableObjects) = ^ (NSArray *searchableObjects){
        NSString *path =[NSString stringWithFormat:@"%@/%@/search/scopeOrder", kSFMetadataRestApiPath, self.apiVersion];
        [self.networkManager remoteJSONGetRequest:path params:nil requestHeaders:[self requestHeader:cachedTime] completion:^(id responseAsJson, NSInteger statusCode) {
            NSArray *recentItems = nil;
            if (nil != responseAsJson) {
                NSArray *returnedItems = (NSArray *)responseAsJson;
                if (returnedItems && [returnedItems isKindOfClass:[NSArray class]]) {
                    NSMutableArray *returnList = [NSMutableArray arrayWithCapacity:returnedItems.count];
                    for (NSDictionary *item in returnedItems) {
                        if (item[@"type"]) {
                            [returnList addObject:item[@"type"]];
                        }
                    }
                    recentItems = returnList;
                }
            }
            processSmartScopes(recentItems, searchableObjects);
        } error:^(NSError *error) {
            if ([self.networkManager isNetworkError:error]) {
                invokeErrorBlock(error);
            } else {
                [self log:SFLogLevelError format:@"Unable to load smart scopes, %@", error];
                processSmartScopes(nil, searchableObjects);
            }
        }];
        
    };

    // Loads all searchable objects.
    dispatch_block_t loadAllSearchableObjects = ^ {
        [self loadAllObjectTypes:dataPolicy refreshCacheIfOlderThan:kSFMetadataRefreshInterval completion:^(NSArray *results, BOOL isDataFromCache) {
            loadSearchScope(results);
        } error:^(NSError *error) {
            invokeErrorBlock(error);
        }];
    };
    loadAllSearchableObjects();
}

#pragma mark - Private Methods

- (BOOL)shouldCallCompletionBlock:(id)completionBlock completionBlockInvoked:(BOOL)completionBlockInvoked cachePolicy:(SFDataCachePolicy)cachePolicy {
    BOOL shouldCallCompletionBlock = NO;
    if (completionBlock) {
        if (!completionBlockInvoked) {
            shouldCallCompletionBlock = YES;
        }
    }
    return shouldCallCompletionBlock;
}

- (NSError *)errorWithDescription:(NSString *)errorMessage {
    return [NSError errorWithDomain:SFMetadataManagerErrorDomain
                               code:SFMetadataManagerErrorCode
                           userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
}

- (BOOL)shouldCacheData:(SFDataCachePolicy)cachePolicy {
    return self.cacheEnabled && (cachePolicy != SFDataCachePolicyIgnoreCacheData) && (cachePolicy != SFDataCachePolicyReturnCacheDataDontReload) && (cachePolicy != SFDataCachePolicyInvalidateCacheDontReload);
}

- (BOOL)shouldIgnoreCache:(SFDataCachePolicy)cachePolicy {
    BOOL ignoreCache = NO;
    switch (cachePolicy) {
        case SFDataCachePolicyIgnoreCacheData:
        case SFDataCachePolicyInvalidateCacheAndReload:
        case SFDataCachePolicyInvalidateCacheDontReload:
        case SFDataCachePolicyReloadAndReturnCacheOnFailure:
            ignoreCache = YES;
            break;
        default:
            ignoreCache = NO;
            break;
    }
    return ignoreCache;
}

- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes name:(NSString *)name {
    if (nil == objectTypes || name == nil) {
        return nil;
    }
    for (SFObjectType *typeModel in objectTypes) {
        if (![typeModel.name isEqual:[NSNull null]] && [typeModel.name isEqualToString:name]) {
            return typeModel;
        }
    }
    return nil;
}

- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes keyPrefix:(NSString *)keyPrefix {
    if (nil == objectTypes || keyPrefix == nil) {
        return nil;
    }
    
    for (SFObjectType *typeModel in objectTypes) {
        if (![typeModel.keyPrefix isEqual:[NSNull null]] && [typeModel.keyPrefix isEqualToString:keyPrefix]) {
            return typeModel;
        }
    }
    return nil;
}

- (NSDictionary *)requestHeader:(NSDate *)cacheTime {
    NSDictionary *headers = nil;
    if (cacheTime) {
        NSString *cacheDateStr = [ObjectUtils formatLocalDateToGMTString:cacheTime];
        if (![ObjectUtils isEmpty:cacheDateStr]) {
            headers = @{@"If-Modified-Since" : cacheDateStr};
        }
    }
    return headers;
}

@end