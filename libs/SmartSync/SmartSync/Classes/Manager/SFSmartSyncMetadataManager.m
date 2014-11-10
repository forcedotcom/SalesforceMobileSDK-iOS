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
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncConstants.h"
#import "SFObjectType+Internal.h"
#import "SFObject+Internal.h"
#import "SFObjectTypeLayout+Internal.h"

// Default API version.
static NSString * kDefaultApiVersion = @"v31.0";

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

@interface SFSmartSyncMetadataManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, assign) BOOL cacheEnabled;
@property (nonatomic, assign) BOOL encryptCache;

- (BOOL)shouldCallCompletionBlock:(id)completionBlock completionBlockInvoked:(BOOL)completionBlockInvoked
                      cachePolicy:(SFDataCachePolicy)cachePolicy;
- (NSError *)errorWithDescription:(NSString *)errorMessage;
- (BOOL)shouldCacheData:(SFDataCachePolicy)cachePolicy;
- (BOOL)shouldIgnoreCache:(SFDataCachePolicy)cachePolicy;
- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes name:(NSString *)name;
- (SFObjectType *)objectTypeInArray:(NSArray *)objectTypes keyPrefix:(NSString *)keyPrefix;
- (NSDictionary *)requestHeader:(NSDate *)cacheTime;
- (SFObjectType *)cachedObjectType:(NSString *)objectTypeName cachedTime:(out NSDate **)cachedTime;
- (void)removeObjectTypesLayout:(NSArray *)objectTypesToLoad;
- (BOOL)canLoadLayoutForObjectType:(SFObjectType *)objectType;
- (void)cacheObject:(id)object cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey;
- (id)cachedObject:(SFDataCachePolicy)cachePolicy cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey
                objectClass:(Class)objectClass containedObjectClass:(Class)objectClass cachedTime:(out NSDate **)cachedTime;
- (NSString *)returnFieldsForObjectType:(SFObjectType *)objectType;

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
                metadataMgr = [[SFSmartSyncMetadataManager alloc] initWithUser:user];
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

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        self.networkManager = [SFSmartSyncNetworkManager sharedInstance:user];
        self.cacheManager = [SFSmartSyncCacheManager sharedInstance:user];
        self.apiVersion = kDefaultApiVersion;
        self.cacheEnabled = YES;
        self.encryptCache = YES;
        [[SFAuthenticationManager sharedManager] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
}

- (void)loadSmartScopeObjectTypes:(SFDataCachePolicy)cachePolicy
          refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                  completionBlock:(void(^)(NSArray *results, BOOL isDataFromCache))completionBlock
                            error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (!self.networkManager) {
        errorMessage = @"Unable to load recently searched object types [NetworkManager not specified]";
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

- (void)loadMRUObjects:(NSString *)objectTypeName limit:(NSInteger)limit cachePolicy:(SFDataCachePolicy)cachePolicy
            refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                networkFieldName:(NSString *)networkFieldName inRetry:(BOOL)inRetry
                    completion:(void(^)(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache))completionBlock
                        error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (!self.networkManager) {
        errorMessage = @"Unable to load recently accessed objects by type [NetworkManager not specified]";
        [self log:SFLogLevelError msg:errorMessage];
        if (errorBlock) {
            NSError *error = [self errorWithDescription:errorMessage];
            if (errorBlock) {
                errorBlock(error);
            }
        }
        return;
    }
    if (limit > kSFMetadataMaximumLimit || limit < 0) {
        limit = kSFMetadataMaximumLimit;
    }
    NSString *cacheType = kSFMRUCacheType;
    NSString *cacheKey = nil;
    BOOL globalMRU = NO;
    if ([SFSmartSyncObjectUtils isEmpty:objectTypeName]) {

        // Gets global MRU objects.
        globalMRU = YES;
        cacheKey = [NSString stringWithFormat:kSFMRUObjectsByObjectType, @"global"];
    } else {
        cacheKey = [NSString stringWithFormat:kSFMRUObjectsByObjectType, objectTypeName];
    }

    // Checks the cache first.
    NSDate *cachedTime = nil;
    NSArray *cachedData = (NSArray *)[self cachedObject:cachePolicy cacheType:cacheType cacheKey:cacheKey objectClass:[NSArray class] containedObjectClass:[SFObject class] cachedTime:&cachedTime];
    __block BOOL completionBlockInvoked = NO;
    if (cachedData && limit > 0 && limit < cachedData.count) {

        // Removes items based on the limit passed in.
        NSMutableArray *updatedItems = [NSMutableArray arrayWithArray:cachedData];
        [updatedItems removeObjectsInRange:NSMakeRange(limit, cachedData.count - limit)];
        cachedData = updatedItems;
    }
    BOOL needToReloadCache = YES;

    // Checks to see if we need to refresh the cache.
    if (![self.cacheManager needToReloadCache:(nil != cachedData) cachePolicy:cachePolicy lastCachedTime:cachedTime refreshIfOlderThan:refreshCacheIfOlderThan]) {
        needToReloadCache = NO;
    }
    if (cachedData && cachedData.count > 0 && cachePolicy!= SFDataCachePolicyReloadAndReturnCacheOnFailure) {
        completionBlockInvoked = YES;
        if (completionBlock) {
            completionBlock(cachedData, YES, needToReloadCache);
        }
    }

    // Checks to see if need to refresh the cache.
    if (!needToReloadCache) {

        // No need to refresh the cache, hence returns directly.
        if (!completionBlockInvoked && completionBlock) {
            completionBlock(cachedData, YES, needToReloadCache);
        }
        return;
    }
    __block NSArray *recentItems = nil;
    void(^callErrorBlock)(NSError *error) = ^(NSError *error) {
        if (error.code != kSFNetworkRequestFailedDueToNoModification) {
            [self log:SFLogLevelError format:@"Failed to get recently accessed objects by type [%@], %@", objectTypeName, [error localizedDescription]];
        }
        if (!completionBlockInvoked && error.code == kSFNetworkRequestFailedDueToNoModification) {
            completionBlock(cachedData, YES, needToReloadCache);
        } else if (!completionBlockInvoked && cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
            if (completionBlock) {
                completionBlock(cachedData, YES, needToReloadCache);
            }
        } else if (errorBlock && !completionBlockInvoked) {
            errorBlock(error);
        }
    };

    // Loads the MRU objects.
    void (^loadRecentsBlock)(SFObjectType *objectType) = ^(SFObjectType *objectType){
        NSString *path = nil;
        NSDictionary *queryParams = nil;
        SFSmartSyncSoqlBuilder *queryBuilder = nil;
        if (globalMRU) {
            queryBuilder = [SFSmartSyncSoqlBuilder withFields:@"Id, Name, Type"];
            [queryBuilder from:kRecentlyViewed];
            NSString *whereClause = @"LastViewedDate != NULL";
            if (![SFSmartSyncObjectUtils isEmpty:self.communityId]) {
                whereClause = [NSString stringWithFormat:@"%@ AND NetworkId = '%@'", whereClause, self.communityId];
            }
            [queryBuilder where:whereClause];
            [queryBuilder limit:limit];
        } else {
            BOOL objectContainedLastViewedDate = NO;
            NSPredicate *viewPredicate = [NSPredicate predicateWithFormat:@"name = %@", @"LastViewedDate"];
            NSArray *fields = [objectType.fields filteredArrayUsingPredicate:viewPredicate];
            if (fields && fields.count > 0) {
                objectContainedLastViewedDate = YES;
            }
            NSString *queryFields = nil;
            queryFields = [self returnFieldsForObjectType:objectType];
            if (![SFSmartSyncObjectUtils isEmpty:queryFields]) {
                queryBuilder = [SFSmartSyncSoqlBuilder withFields:queryFields];
            } else {
                queryBuilder = [SFSmartSyncSoqlBuilder withFields:@"Id, Name, Type"];
            }
            NSString *whereClause = nil;
            if (objectContainedLastViewedDate) {
                [queryBuilder from:[NSString stringWithFormat:@"%@ using MRU", objectTypeName]];
                whereClause = @"LastViewedDate != NULL";
                [queryBuilder orderBy:@"LastViewedDate DESC"];
                [queryBuilder limit:limit];
            } else {
                [queryBuilder from:kRecentlyViewed];
                whereClause = [NSString stringWithFormat:@"LastViewedDate != NULL and Type = '%@'", objectTypeName];
                [queryBuilder limit:limit];
            }
            if (![SFSmartSyncObjectUtils isEmpty:self.communityId]) {
                if (![SFSmartSyncObjectUtils isEmpty:networkFieldName]) {
                    whereClause = [NSString stringWithFormat:@"%@ AND %@ = '%@'", whereClause, networkFieldName, self.communityId];
                }
            }
            [queryBuilder where:whereClause];
        }
        NSString * queryString = [queryBuilder build];
        queryParams = @{@"q": queryString};
        path =[NSString stringWithFormat:@"%@/%@/query/", kSFMetadataRestApiPath, self.apiVersion];

        // Executes the query.
        [self.networkManager remoteJSONGetRequest:path params:queryParams requestHeaders:[self requestHeader:cachedTime] completion:^(id responseAsJson, NSInteger statusCode) {
            if (nil != responseAsJson) {
                if ([responseAsJson isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *returnDict = (NSDictionary *)responseAsJson;
                    NSArray *returnedItems = returnDict[@"records"];
                    if (!returnedItems && [objectTypeName isEqualToString:kContent]) {
                        returnedItems = returnDict[@"recentItems"];
                    }
                    if (returnedItems && [returnedItems isKindOfClass:[NSArray class]]) {
                        recentItems = returnedItems;
                    }
                }
                NSMutableArray *returnList = [NSMutableArray arrayWithCapacity:recentItems.count];
                for (NSDictionary *item in recentItems) {
                    SFObject *object = [[SFObject alloc] initWithDictionary:item];
                    if (globalMRU) {
                        if ([object.objectType isEqualToString:kContent]) {
                            object.objectType = kContentVersion;
                        }
                        SFObjectType *objectDef = [self cachedObjectType:object.objectType cachedTime:nil];
                        if ([self isObjectTypeSearchable:objectDef]) {
                            [returnList addObject:object];
                        }
                    } else {
                        [returnList addObject:object];
                    }
                }
                recentItems = returnList;
                if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
                    completionBlock(recentItems, NO, needToReloadCache);
                }

                // Save data to the cache.
                if ([self shouldCacheData:cachePolicy]) {
                    [self cacheObject:returnList cacheType:cacheType cacheKey:cacheKey];
                }
            }
        } error:^(NSError *error) {
            if (error.code == 400) {

                // 400 error could be due to cached search layout, so retry it at least once.
                [self log:SFLogLevelError format:@"Load MRU failed with %@, retry with updated search layout ", [error localizedDescription]];
                [self removeObjectTypesLayout:@[objectType]];
                [self loadMRUObjects:objectTypeName limit:limit cachePolicy:cachePolicy refreshCacheIfOlderThan:refreshCacheIfOlderThan networkFieldName:nil inRetry:NO completion:completionBlock error:errorBlock];
            } else {
                callErrorBlock(error);
            }
        }];
    };

    // Loads the object layouts.
    void(^loadObjectLayoutBlock)(SFObjectType *objectType)=^(SFObjectType *objectType) {
        SFDataCachePolicy layoutCachePolicy = SFDataCachePolicyReloadAndReturnCacheOnFailure;
        [self loadObjectTypesLayout:@[objectType] cachePolicy:layoutCachePolicy refreshCacheIfOlderThan:kSFMetadataRefreshInterval completion:^(NSArray *result, BOOL isDataFromCache) {
            loadRecentsBlock(objectType);
        } error:^(NSError *error) {
            callErrorBlock(error);
        }];
    };

    // Loads the object definition.
    void(^loadCompleteObjectDefBlock)(NSString *objectType)=^(NSString *objectType) {
        [self loadObjectType:objectType cachePolicy:SFDataCachePolicyReturnCacheDataAndReloadIfExpired refreshCacheIfOlderThan:kSFMetadataRefreshInterval completion:^(SFObjectType *result, BOOL isDataFromCache) {
            if ([self canLoadLayoutForObjectType:result]) {
                loadObjectLayoutBlock(result);
            } else {
                loadRecentsBlock(result);
            }
        } error:^(NSError *error) {
            callErrorBlock(error);
        }];
    };
    if (objectTypeName) {
        loadCompleteObjectDefBlock(objectTypeName);
    } else {
        loadRecentsBlock(nil);
    }
}

- (void)loadAllObjectTypes:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                completion:(void(^)(NSArray * results, BOOL isDataFromCache))completionBlock
                     error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (!self.networkManager) {
        errorMessage = @"Unable to load all objects [NetworkManager not specified]";
        [self log:SFLogLevelError msg:errorMessage];
        if (errorBlock) {
            NSError *error = [self errorWithDescription:errorMessage];
            if (errorBlock) {
                errorBlock(error);
            }
        }
        return;
    }
    NSString *cacheType = kSFMetadataCacheType;
    NSString *cacheKey = kSFAllObjects;

    // Checks the cache first.
    NSDate *cachedTime = nil;
    NSArray *cachedData = (NSArray *)[self cachedObject:SFDataCachePolicyReturnCacheDataDontReload cacheType:cacheType cacheKey:cacheKey objectClass:[NSArray class] containedObjectClass:[SFObjectType class] cachedTime:&cachedTime];
    BOOL completionBlockInvoked = NO;
    if (cachedData && cachedData.count > 0 && cachePolicy != SFDataCachePolicyReloadAndReturnCacheOnFailure) {
        completionBlockInvoked = YES;
        if (completionBlock) {
            completionBlock(cachedData, YES);
        }
    }

    // Checks to see if we need to refresh the cache.
    if (![self.cacheManager needToReloadCache:(nil != cachedData) cachePolicy:cachePolicy lastCachedTime:cachedTime refreshIfOlderThan:refreshCacheIfOlderThan]) {

        // No need to refresh, hence returns directly.
        if (!completionBlockInvoked && completionBlock) {
            completionBlock(cachedData, YES);
        }
        return;
    }
    NSString *path =[NSString stringWithFormat:@"%@/%@/sobjects", kSFMetadataRestApiPath, self.apiVersion];
    [self.networkManager remoteJSONGetRequest:path params:nil requestHeaders:[self requestHeader:cachedTime] completion:^(id responseAsJson, NSInteger statusCode) {
        NSMutableArray *returnList = nil;
        if (nil != responseAsJson) {
            if ([responseAsJson isKindOfClass:[NSDictionary class]]) {
                NSDictionary *data = (NSDictionary *)responseAsJson;
                NSArray *objectTypes = data[@"sobjects"];
                returnList = [NSMutableArray arrayWithCapacity:objectTypes.count];
                for (NSDictionary *item in objectTypes) {
                    if (![item[kHiddenField] boolValue]) {
                        SFObjectType *objectType = [[SFObjectType alloc] initWithDictionary:item];
                        [returnList addObject:objectType];
                    }
                }
            }
        }
        if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
            completionBlock(returnList, NO);
        }

        // Save data to the cache.
        if ([self shouldCacheData:cachePolicy]) {
            [self cacheObject:returnList cacheType:cacheType cacheKey:cacheKey];
        }
    } error:^(NSError *error) {
        if (error.code != kSFNetworkRequestFailedDueToNoModification) {
            [self log:SFLogLevelError format:@"failed to get get all searchable objects, [%@]", [error localizedDescription]];
        }
        if (error.code == kSFNetworkRequestFailedDueToNoModification) {
            if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
                completionBlock(cachedData, YES);
            }
        } else if (!completionBlockInvoked && cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
            if (completionBlock) {
                completionBlock(cachedData, YES);
            }
        } else if (errorBlock && !completionBlockInvoked) {
            errorBlock(error);
        }
    }];
}

- (void)loadObjectType:(NSString *)objectTypeName cachePolicy:(SFDataCachePolicy)cachePolicy
            refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                completion:(void(^)(SFObjectType *result, BOOL isDataFromCache))completionBlock
                    error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (objectTypeName == nil) {
        errorMessage = @"Object type name is nil";
    } else if (!self.networkManager) {
        errorMessage = @"NetworkManager not specified";
    }
    if (nil != errorMessage) {
        errorMessage = [NSString stringWithFormat:@"Unable to load objectTypeInfo, [%@]", errorMessage];
        [self log:SFLogLevelError msg:errorMessage];
        if (errorBlock) {
            NSError *error = [self errorWithDescription:errorMessage];
            if (errorBlock) {
                errorBlock(error);
            }
        }
        return;
    }
    NSString *cacheType = kSFMetadataCacheType;
    NSString *cacheKey = [NSString stringWithFormat:kSFObjectByType, objectTypeName];

    // Checks the cache first.
    NSDate *cachedTime = nil;
    SFObjectType *cachedData = (SFObjectType *) [self cachedObject:SFDataCachePolicyReturnCacheDataDontReload cacheType:cacheType cacheKey:cacheKey objectClass:[SFObjectType class] containedObjectClass:[SFObjectType class] cachedTime:&cachedTime];
    BOOL completionBlockInvoked = NO;
    if (cachedData && cachePolicy != SFDataCachePolicyReloadAndReturnCacheOnFailure) {
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
    NSString *path =[NSString stringWithFormat:@"%@/%@/sobjects/%@/describe", kSFMetadataRestApiPath, self.apiVersion, objectTypeName];
    [self.networkManager remoteJSONGetRequest:path params:nil requestHeaders:[self requestHeader:cachedTime] completion:^(id responseAsJson, NSInteger statusCode) {
        SFObjectType *objectType = nil;
        if (nil != responseAsJson) {
            if ([responseAsJson isKindOfClass:[NSDictionary class]]) {
                NSDictionary *data = (NSDictionary *)responseAsJson;
                objectType = [[SFObjectType alloc] initWithDictionary:data];
            }
        }
        if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
            completionBlock(objectType, NO);
        }

        // Saves data to the cache.
        if ([self shouldCacheData:cachePolicy]) {
            [self cacheObject:objectType cacheType:cacheType cacheKey:cacheKey];
        }
    } error:^(NSError *error) {
        if (error.code != kSFNetworkRequestFailedDueToNoModification) {
            [self log:SFLogLevelError format:@"Failed to get get object information for %@, [%@]", objectTypeName, [error localizedDescription]];
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
    }];
}

- (void)loadObjectTypesLayout:(NSArray *)objectTypesToLoad cachePolicy:(SFDataCachePolicy)cachePolicy
            refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                   completion:(void(^)(NSArray *result, BOOL isDataFromCache))completionBlock
                        error:(void(^)(NSError *error))errorBlock {
    NSString *errorMessage = nil;
    if (objectTypesToLoad == nil || objectTypesToLoad.count == 0) {
        errorMessage = @"Object types to load is empty";
    } else if (!self.networkManager) {
        errorMessage = @"NetworkManager not specified";
    }
    if (nil != errorMessage) {
        errorMessage = [NSString stringWithFormat:@"Unable to load object layout, [%@]", errorMessage];
        [self log:SFLogLevelError msg:errorMessage];
        if (errorBlock) {
            NSError *error = [self errorWithDescription:errorMessage];
            if (errorBlock) {
                errorBlock(error);
            }
        }
        return;
    }
    NSString *cacheType = kSFMetadataCacheType;
    NSMutableArray *layouts = [NSMutableArray arrayWithCapacity:objectTypesToLoad.count];
    NSDate *oldestCacheTime = nil;
    BOOL needToLoadDataFromServer = NO;
    NSMutableArray *layoutObjectsToLoad = [NSMutableArray arrayWithCapacity:objectTypesToLoad.count];
    BOOL cacheDataExistsForAllObjectTypes = YES;
    for (NSUInteger idx = 0; idx < objectTypesToLoad.count; idx++) {
        SFObjectType *objectType = objectTypesToLoad[idx];
        if (![self canLoadLayoutForObjectType:objectType]) {

            // Layout does not exist.
            continue;
        }
        NSString *cacheKey = [NSString stringWithFormat:kSFObjectLayoutByType, objectType.name];

        // Checks the cache first.
        NSDate *cachedTime = nil;
        SFObjectTypeLayout *cachedData = (SFObjectTypeLayout *) [self cachedObject:SFDataCachePolicyReturnCacheDataDontReload cacheType:cacheType cacheKey:cacheKey objectClass:[SFObjectTypeLayout class] containedObjectClass:[SFObjectType class] cachedTime:&cachedTime];
        if (cachedTime) {
            if (nil == oldestCacheTime) {
                oldestCacheTime = cachedTime;
            } else if ([cachedTime compare:oldestCacheTime] == NSOrderedAscending) {
                oldestCacheTime = cachedTime;
            }
        }
        if (nil != cachedData) {
            [layouts addObject:cachedData];

            // Checks to see if we need to refresh the cache for the specified object type.
            if ([self.cacheManager needToReloadCache:(nil != cachedData) cachePolicy:cachePolicy lastCachedTime:cachedTime refreshIfOlderThan:refreshCacheIfOlderThan]) {
                if (cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
                    if (!needToLoadDataFromServer) {
                        needToLoadDataFromServer = YES;
                    }
                }

                // Cache needs to be refreshed.
                [layoutObjectsToLoad addObject:objectType];
            }
        } else {
            if (cacheDataExistsForAllObjectTypes) {
                cacheDataExistsForAllObjectTypes = NO;
            }
            if (!needToLoadDataFromServer) {
                needToLoadDataFromServer = YES;
            }
            [layoutObjectsToLoad addObject:objectType];
        }
    }
    if (!cacheDataExistsForAllObjectTypes) {
        oldestCacheTime = nil;
    }
    BOOL completionBlockInvoked = NO;
    if ((!needToLoadDataFromServer || layoutObjectsToLoad.count == 0) && cachePolicy != SFDataCachePolicyReloadAndReturnCacheOnFailure) {
        completionBlockInvoked = YES;

        // No need to refresh anything, since we have data in the cache.
        if (completionBlock) {
            completionBlock(layouts, YES);
        }
        if (layoutObjectsToLoad.count == 0) {

            // No need to refresh anything, since we have data in the cache.
            return;
        }
    }
    NSMutableString *objectsString = [NSMutableString string];
    for (SFObjectType *objectType in layoutObjectsToLoad) {
        if (objectsString.length > 0) {
            [objectsString appendString:@","];
        }
        [objectsString appendString:objectType.name];
    }
    if ([SFSmartSyncObjectUtils isEmpty:objectsString]) {
        completionBlock(nil, NO);
        return;
    }
    NSString *path =[NSString stringWithFormat:@"%@/%@/search/layout/", kSFMetadataRestApiPath, self.apiVersion];
    NSDictionary *params = @{@"q": objectsString};
    [self.networkManager remoteJSONGetRequest:path params:params requestHeaders:[self requestHeader:oldestCacheTime] completion:^(id responseAsJson, NSInteger statusCode) {
        if (nil != responseAsJson) {
            if ([responseAsJson isKindOfClass:[NSArray class]]) {
                NSArray *data = (NSArray *)responseAsJson;
                for (NSUInteger idx = 0; idx < data.count; idx++) {
                    NSDictionary *layoutDict = data[idx];
                    SFObjectType *typeModel = layoutObjectsToLoad[idx];
                    NSString *cacheKey = [NSString stringWithFormat:kSFObjectLayoutByType, typeModel.name];
                    SFObjectTypeLayout *layoutObj = [[SFObjectTypeLayout alloc] initWithDictionary:layoutDict forObjectType:typeModel.name];
                    [layouts addObject:layoutObj];

                    // Saves data to the cache.
                    if ([self shouldCacheData:cachePolicy]) {
                        [self cacheObject:layoutObj cacheType:cacheType cacheKey:cacheKey];
                    }
                }
            }
        }
        if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
            completionBlock(layouts, NO);
        }
    } error:^(NSError *error) {
        if (error.code != kSFNetworkRequestFailedDueToNoModification) {
            [self log:SFLogLevelError format:@"failed to get get objects layout, [%@]", [error localizedDescription]];
        }
        if (error.code == kSFNetworkRequestFailedDueToNoModification) {
            if ([self shouldCallCompletionBlock:completionBlock completionBlockInvoked:completionBlockInvoked cachePolicy:cachePolicy]) {
                completionBlock(layouts, YES);
            }
        } else if (!completionBlockInvoked && cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
            if (completionBlock) {
                completionBlock(layouts, YES);
            }
        } else  if (errorBlock && !completionBlockInvoked) {
            errorBlock(error);
        }
    }];
}

- (UIColor *)colorForObjectType:(NSString *)objectTypeName {
    if (nil == objectTypeName) {
        return nil;
    }
    if ([objectTypeName isEqualToString:kAccount]) {
        return [UIColor colorWithRed:0.243 green:0.502 blue:0.765 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kContact]) {
        return [UIColor colorWithRed:0.506 green:0.447 blue:0.678 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kTask]) {
        return [UIColor colorWithRed:0.106 green:0.714 blue:0.549 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kCase]) {
        return [UIColor colorWithRed:0.769 green:0.698 blue:0.314 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kOpportunity]) {
        return [UIColor colorWithRed:0.976 green:0.796 blue:0.173 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kLead]) {
        return [UIColor colorWithRed:1.0 green:0.647 blue:0.145 alpha:1.0];
    } else if ([objectTypeName isEqualToString:kCampaign]) {
        return [UIColor colorWithRed:0.929 green:0.725 blue:0.231 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.733 green:0.733 blue:0.733 alpha:1.0];
    }
}

- (BOOL)isObjectTypeSearchable:(SFObjectType *)objectType {
    if (objectType == nil) {
        return false;
    }
    NSString *objectName = [objectType name];
    if (![SFSmartSyncObjectUtils isEmpty:objectName]) {
        return [objectType isSearchable];
    }
    return NO;
}

- (void)markObjectAsViewed:(NSString *)objectId objectType:(NSString *)objectType
          networkFieldName:(NSString *)networkFieldName completionBlock:(void(^)())completionBlock
                     error:(void(^)(NSError *error))errorBlock {
    if (nil == objectType || nil == objectId || [objectType isEqualToString:kContentVersion] || [objectType isEqualToString:kContent]) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    void(^callErrorBlock)(NSError *error) = ^(NSError * error) {
        if (errorBlock) {
            errorBlock(error);
        }
    };
    [self loadObjectType:objectType cachePolicy:SFDataCachePolicyReturnCacheDataAndReloadIfExpired refreshCacheIfOlderThan:kSFMetadataRefreshInterval completion:^(SFObjectType *result, BOOL isDataFromCache) {
        SFSmartSyncSoqlBuilder *queryBuilder = [[SFSmartSyncSoqlBuilder withFields:@"Id"] from:objectType];
        NSString *whereClause = nil;
        if (result && [self isObjectTypeSearchable:result]) {
            whereClause = [NSString stringWithFormat:@"Id = '%@' FOR VIEW", objectId];
        } else {
            whereClause = [NSString stringWithFormat:@"Id = '%@'", objectId];
        }
        if (![SFSmartSyncObjectUtils isEmpty:self.communityId] && ![SFSmartSyncObjectUtils isEmpty:networkFieldName]) {
            whereClause = [NSString stringWithFormat:@"%@ AND %@ = '%@'", whereClause, networkFieldName, self.communityId];
        }
        queryBuilder = [queryBuilder where:whereClause];
        NSString *queryString = [[queryBuilder where:whereClause] build];
        NSString *path =[NSString stringWithFormat:@"%@/%@/query/", kSFMetadataRestApiPath, self.apiVersion];
        [self.networkManager remoteJSONGetRequest:path params:@{@"q": queryString} autoRetryOnNetworkError:YES requestHeaders:nil completion:^(id responseAsJson, NSInteger statusCode) {
            NSArray *records = responseAsJson[@"records"];
            if (records && [records isKindOfClass:[NSArray class]]) {
                if (records.count == 0) {

                    // Object no longer exists.
                    NSError *error = [self errorWithDescription:@"Object no longer exists"];
                    [self log:SFLogLevelError format:@"Failed to mark %@ as being viewed, error %@", objectId, error];
                    callErrorBlock(error);
                } else {
                    if (completionBlock) {
                        completionBlock();
                    }
                }
            }
        } error:^(NSError *error) {
            [self log:SFLogLevelError format:@"Failed to mark %@ as being viewed, error %@", objectId, [error localizedDescription]];
            callErrorBlock(error);
        }];
    } error:^(NSError *error) {
        [self log:SFLogLevelError format:@"Failed to mark %@ as being viewed, error %@", objectId, [error localizedDescription]];
        callErrorBlock(error);
    }];
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
        NSString *cacheDateStr = [SFSmartSyncObjectUtils formatLocalDateToGMTString:cacheTime];
        if (![SFSmartSyncObjectUtils isEmpty:cacheDateStr]) {
            headers = @{@"If-Modified-Since" : cacheDateStr};
        }
    }
    return headers;
}

- (SFObjectType *)cachedObjectType:(NSString *)objectTypeName cachedTime:(out NSDate **)cachedTime {
    NSString *cacheType = kSFMetadataCacheType;
    NSString *cacheKey = [NSString stringWithFormat:kSFObjectByType, objectTypeName];
    SFObjectType *typeModel = (SFObjectType *)[self cachedObject:SFDataCachePolicyReturnCacheDataDontReload cacheType:cacheType cacheKey:cacheKey objectClass:[SFObjectType class] containedObjectClass:[SFObjectType class] cachedTime:cachedTime];
    return typeModel;
}

- (void)removeObjectTypesLayout:(NSArray *)objectTypesToLoad {
    if (nil == objectTypesToLoad || objectTypesToLoad.count == 0) {
        return;
    }
    NSString *cacheType = kSFMetadataCacheType;
    for (NSUInteger idx = 0; idx < objectTypesToLoad.count; idx++) {
        SFObjectType *objectType = objectTypesToLoad[idx];
        NSString *cacheKey = [NSString stringWithFormat:kSFObjectLayoutByType, objectType.name];
        [self.cacheManager removeCache:cacheType cacheKey:cacheKey];
    }
}

- (BOOL)canLoadLayoutForObjectType:(SFObjectType *)objectType {
    if (objectType == nil) {
        return false;
    }
    return ([objectType isLayoutable] && [objectType isSearchable]);
}

- (void)cacheObject:(id)object cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    [self.cacheManager writeDataToCache:object cacheType:cacheType cacheKey:cacheKey];
}

- (id)cachedObject:(SFDataCachePolicy)cachePolicy
         cacheType:(NSString *)cacheType
          cacheKey:(NSString *)cacheKey
       objectClass:(Class)objectClass
containedObjectClass:(Class)containedObjectClass
        cachedTime:(out NSDate **)cachedTime {
    id cachedData = [self.cacheManager readDataWithCacheType:cacheType cacheKey:cacheKey cachePolicy:SFDataCachePolicyReturnCacheDataDontReload cachedTime:cachedTime];
    if (cachedData && ![cachedData isKindOfClass:objectClass]) {
        [self.cacheManager removeCache:cacheType cacheKey:cacheKey];
        cachedData = nil;
    }
    return cachedData;
}

- (NSString *)returnFieldsForObjectType:(SFObjectType *)objectType {
    if (nil == objectType) {
        return nil;
    }
    NSString *objectTypeName = objectType.name;
    if (nil == objectTypeName) {
        return nil;
    }
    NSMutableArray *returnFields = [NSMutableArray array];
    NSArray *extraValues = [self serverLayoutFieldsForObjectType:objectType];
    if (nil != extraValues) {
        [returnFields addObjectsFromArray:extraValues];
    }
    if (![returnFields containsObject:@"Id"]) {
        [returnFields addObject:@"Id"];
    }
    if (objectType.nameField && ![returnFields containsObject:objectType.nameField]) {
        [returnFields addObject:objectType.nameField];
    }
    return [returnFields componentsJoinedByString:@","];
}

- (NSArray *)serverLayoutFieldsForObjectType:(SFObjectType *)objectType {
    SFObjectTypeLayout *layout = [self cachedObjectTypeLayout:objectType cachedTime:nil];
    if (layout && layout.columns) {
        NSMutableArray *returnValues = [NSMutableArray arrayWithCapacity:layout.columns.count];
        for (NSDictionary *dictionary in layout.columns) {
            NSString *name = dictionary[kNameField];
            if (name) {
                [returnValues addObject:name];
            }
        }
        return returnValues;
    }
    return nil;
}

- (SFObjectTypeLayout *)cachedObjectTypeLayout:(SFObjectType *)objectType cachedTime:(out NSDate **)cachedTime {
    NSString *cacheType = kSFMetadataCacheType;
    NSString *cacheKey = [NSString stringWithFormat:kSFObjectLayoutByType, objectType.name];
    return (SFObjectTypeLayout *) [self cachedObject:SFDataCachePolicyReturnCacheDataDontReload cacheType:cacheType cacheKey:cacheKey objectClass:[SFObjectTypeLayout class] containedObjectClass:[SFObjectTypeLayout class] cachedTime:cachedTime];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}

@end