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

#import "SFSmartSyncCacheManager.h"
#import "SFObject.h"
#import "SFObjectType.h"
#import "SFSmartSyncPersistableObject.h"
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFJsonUtils.h>


static NSString * const kCacheTimeKey      = @"CacheTime";
static NSString * const kCacheDataKey      = @"CacheData";

// SmartStore constants
static NSString * const kSmartStoreSoupMappingSoupName = @"master_soup";
static NSString * const kSmartStoreSoupNamesPath       = @"soup_names";
static NSString * const kSmartStoreCacheKeyPath        = @"cache_key";
static NSString * const kSmartStoreCacheDataPath       = @"cache_data";

// Store data keys
static NSString * const kRawDataKey = @"rawData";
static NSString * const kTypeKey    = @"type";

@interface SFSmartSyncCacheManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, readonly) SFSmartStore *store;
@property (nonatomic, strong) NSCache *inMemCache;
@property (nonatomic, assign) BOOL enableInMemoryCache;

- (NSString *)compositeCacheKeyForCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey;
- (BOOL)shouldInvalidateCache:(SFDataCachePolicy)cachePolicy;
- (BOOL)shouldBypassCache:(SFDataCachePolicy)cachePolicy;
- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey;

@end

@implementation SFSmartSyncCacheManager

static NSMutableDictionary *cacheMgrList = nil;

+ (id)sharedInstance:(SFUserAccount *)user {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        cacheMgrList = [[NSMutableDictionary alloc] init];
	});
    @synchronized([SFSmartSyncCacheManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            id cacheMgr = [cacheMgrList objectForKey:key];
            if (!cacheMgr) {
                cacheMgr = [[SFSmartSyncCacheManager alloc] initWithUser:user];
                [cacheMgrList setObject:cacheMgr forKey:key];
            }
            return cacheMgr;
        } else {
            return nil;
        }
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
    @synchronized([SFSmartSyncCacheManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            [cacheMgrList removeObjectForKey:key];
        }
    }
}

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.inMemCache = [[NSCache alloc] init];
        self.enableInMemoryCache = YES;
        self.user = user;
        [[SFAuthenticationManager sharedManager] addDelegate:self];
    }
    return self;
}

- (SFSmartStore *)store {
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:self.user];
}

- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
}

#pragma mark - Private Methods

- (BOOL)shouldInvalidateCache:(SFDataCachePolicy)cachePolicy {
    BOOL invalidateCache = NO;
    switch (cachePolicy) {
        case SFDataCachePolicyInvalidateCacheDontReload:
        case SFDataCachePolicyInvalidateCacheAndReload:
            invalidateCache = YES;
            break;
        default:
            invalidateCache = NO;
            break;
    }
    return invalidateCache;
}

- (BOOL)shouldBypassCache:(SFDataCachePolicy)cachePolicy {
    BOOL bypassCache = NO;
    switch (cachePolicy) {
        case SFDataCachePolicyIgnoreCacheData:
        case SFDataCachePolicyReloadAndReturnCacheOnFailure:
        case SFDataCachePolicyInvalidateCacheDontReload:
        case SFDataCachePolicyInvalidateCacheAndReload:
            bypassCache = YES;
            break;
        case SFDataCachePolicyReturnCacheDataAndReload:
        case SFDataCachePolicyReturnCacheDataAndReloadIfExpired:
        case SFDataCachePolicyReturnCacheDataDontReload:
        default:
            bypassCache = NO;
            break;
    }
    return bypassCache;
}

- (NSString *)compositeCacheKeyForCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    if ([cacheKey length] == 0 || [cacheType length] == 0) {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@%@", cacheType, cacheKey];
}

- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    NSString *compositeCacheKey = [self compositeCacheKeyForCacheType:cacheType cacheKey:cacheKey];
    if (compositeCacheKey == nil) {
        // Invalid cacheType and/or cacheKey
        return;
    }

    // Clean out in-memory cache.
    [self.inMemCache removeObjectForKey:compositeCacheKey];
    
    // Clean out SmartStore.
    [self removeDataFromStoreWithCacheType:cacheType cacheKey:cacheKey];
}

- (BOOL)needToReloadCache:(BOOL)cacheExists cachePolicy:(SFDataCachePolicy)cachePolicy lastCachedTime:(NSDate *)cacheTime refreshIfOlderThan:(NSTimeInterval)refreshIfOlderThan {
    if (cachePolicy == SFDataCachePolicyInvalidateCacheDontReload) {
        return NO;
    }
    if (cachePolicy == SFDataCachePolicyReloadAndReturnCacheOnFailure) {
        return YES;
    }

    // Cache exists.
    if (cachePolicy == SFDataCachePolicyReturnCacheDataAndReload) {
        return YES;
    } else if (cachePolicy == SFDataCachePolicyReturnCacheDataDontReload) {
        return NO;
    }
    if (!cacheExists) {

        // If cache does not exist, always reload.
        return YES;
    }
    if (refreshIfOlderThan <= 0) {
        return YES;
    }
    if (nil == cacheTime) {
        return YES;
    }
    NSTimeInterval timeDiff = [[NSDate date] timeIntervalSinceDate:cacheTime];
    if (timeDiff > refreshIfOlderThan) {
        return YES;
    } else {
        return NO;
    }
}

- (void)cleanCache {
    // Clean out in-memory cache.
    [self.inMemCache removeAllObjects];
    
    // Clean out SmartStore
    for (NSString *soupName in [self allCacheSoupNames]) {
        [self.store removeSoup:soupName];
    }
}

- (NSArray *)readDataWithCacheType:(NSString *)cacheType
                          cacheKey:(NSString *)cacheKey
                       cachePolicy:(SFDataCachePolicy)cachePolicy
                        objectClass:(Class)objectClass
                        cachedTime:(out NSDate **)lastCachedTime {
    BOOL bypassCache = [self shouldBypassCache:cachePolicy];
    if (bypassCache) {
        return nil;
    }
    
    NSString *compositeCacheKey = [self compositeCacheKeyForCacheType:cacheType cacheKey:cacheKey];
    if (compositeCacheKey == nil) {
        return nil;
    }
    
    // Check in-memory cache first.
    NSArray *cachedData = nil;
    if (self.enableInMemoryCache) {
        NSDictionary *inMemoryCacheInfo = [self.inMemCache objectForKey:compositeCacheKey];
        if (inMemoryCacheInfo) {
            cachedData = inMemoryCacheInfo[kCacheDataKey];
            if (lastCachedTime) {
                *lastCachedTime = inMemoryCacheInfo[kCacheTimeKey];
            }
            return cachedData;
        }
    }
    
    // Check SmartStore if in-memory cache not found.
    if (![objectClass isSubclassOfClass:[SFSmartSyncPersistableObject class]]) {
        [self log:SFLogLevelError format:@"%@: Object type class '%@' should be an instance of SmartSyncPersistableObject.", NSStringFromSelector(_cmd), objectClass];
        return nil;
    }
    
    NSDictionary *soupEntry = [self retrieveDataFromStoreWithCacheType:cacheType cacheKey:cacheKey];
    cachedData = [self convertFromPersistable:soupEntry[kSmartStoreCacheDataPath] objectType:objectClass];
    
    // Save to in-memory cache, if there's data to save.
    if ([cachedData count] > 0 && self.enableInMemoryCache) {
        NSDate *dbLastCachedTime = [SFSmartStore dateFromLastModifiedValue:soupEntry[SOUP_LAST_MODIFIED_DATE]];
        [self.inMemCache setObject:@{ kCacheDataKey : cachedData, kCacheTimeKey : dbLastCachedTime } forKey:compositeCacheKey];
        if (lastCachedTime) {
            *lastCachedTime = dbLastCachedTime;
            
        }
    }
    
    return cachedData;
}

- (void)writeDataToCache:(NSArray *)data cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    NSString *compositeCacheKey = [self compositeCacheKeyForCacheType:cacheType cacheKey:cacheKey];
    if (compositeCacheKey == nil) {
        // Invalid/empty cache key or cache type.
        [self log:SFLogLevelError msg:@"Cache type and cache key must both have a value. No action taken."];
        return;
    }
    
    // Delete data case.
    if (data == nil) {
        // Set cache to nil = remove cache by key.
        [self removeCache:cacheType cacheKey:cacheKey];
        return;
    }
    
    // Otherwise, we have data to write to the cache.
    
    if (![self isValidStoreCacheData:data]) {
        [self log:SFLogLevelError msg:@"Data array is not valid for storage."];
        return;
    }

    // Save to in-memory cache first.
    if (self.enableInMemoryCache) {
        [self.inMemCache setObject:@{kCacheDataKey : data, kCacheTimeKey : [NSDate date]} forKey:compositeCacheKey];
    }
    
    // Build SmartStore data entry.
    NSArray *persistableData = [self convertToPersistable:data];
    NSDictionary *cacheSoupEntry = @{ kSmartStoreCacheKeyPath: cacheKey, kSmartStoreCacheDataPath: persistableData };

    // Write to SmartStore.
    NSString *cacheSoupName = cacheType;
    [self upsertData:cacheSoupEntry toSoup:cacheSoupName];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}

#pragma mark - SmartStore management

- (BOOL)isValidStoreCacheData:(NSArray *)inputData
{
    if ([inputData count] == 0) {
        [self log:SFLogLevelError format:@"%@: No entries to cache.", NSStringFromSelector(_cmd)];
        return NO;
    }
    
    Class inputDataClass = [inputData[0] class];
    for (id arrayItem in inputData) {
        if (![arrayItem isKindOfClass:[SFSmartSyncPersistableObject class]]) {
            [self log:SFLogLevelError format:@"%@: Data with class '%@' should be an instance of SmartSyncPersistableObject.", NSStringFromSelector(_cmd), NSStringFromClass([arrayItem class])];
            return NO;
        }
        if ([arrayItem class] != inputDataClass) {
            [self log:SFLogLevelError format:@"%@: Input data items should all be the same class.  Current mixture of '%@' and '%@'.", NSStringFromSelector(_cmd), NSStringFromClass(inputDataClass), NSStringFromClass([arrayItem class])];
            return NO;
        }
        if (((SFSmartSyncPersistableObject *)arrayItem).rawData == nil) {
            [self log:SFLogLevelError format:@"%@: Raw data of '%@' item should not be nil.", NSStringFromSelector(_cmd), NSStringFromClass([arrayItem class])];
            return NO;
        }
    }
    
    return YES;
}

- (NSArray *)convertToPersistable:(NSArray *)dataObjectsToPersist {
    // NB: Assumes isValidStoreCacheData: has already validated this data.
    NSMutableArray *returnData = [NSMutableArray array];
    for (SFSmartSyncPersistableObject *objectToPersist in dataObjectsToPersist) {
        NSMutableDictionary *persistDict = [NSMutableDictionary dictionary];
        persistDict[kRawDataKey] = objectToPersist.rawData;
        if (objectToPersist.objectType != nil) {
            persistDict[kTypeKey] = objectToPersist.objectType;
        }
        [returnData addObject:persistDict];
    }
    
    return returnData;
}

- (NSArray *)convertFromPersistable:(NSArray *)persistableDataObjects objectType:(Class)objectTypeClass {
    if (persistableDataObjects == nil) {
        return nil;
    }
    
    NSMutableArray *convertedDataObjects = [NSMutableArray array];
    for (NSDictionary *persistedObjectDict in persistableDataObjects) {
        NSDictionary *rawDataDict = persistedObjectDict[kRawDataKey];
        if (rawDataDict == nil) {
            [self log:SFLogLevelError format:@"Cache data for '%@' class has no raw data.", NSStringFromClass(objectTypeClass)];
            continue;
        }
        NSString *objectType = persistedObjectDict[kTypeKey];
        
        SFSmartSyncPersistableObject *convertedObject;
        if (objectType == nil) {
            convertedObject = [(SFSmartSyncPersistableObject *)[objectTypeClass alloc] initWithDictionary:rawDataDict];
        } else {
            convertedObject = [(SFSmartSyncPersistableObject *)[objectTypeClass alloc] initWithDictionary:rawDataDict forObjectType:objectType];
        }
        [convertedDataObjects addObject:convertedObject];
    }
    return convertedDataObjects;
}

- (void)upsertData:(NSDictionary *)data toSoup:(NSString *)soupName {
    [self createCacheSoup:soupName];
    NSError *upsertError = nil;
    [self.store upsertEntries:@[ data ] toSoup:soupName withExternalIdPath:kSmartStoreCacheKeyPath error:&upsertError];
    if (upsertError) {
        [self log:SFLogLevelError format:@"Error upserting cache data to SmartStore: %@", [upsertError localizedDescription]];
    }
}

- (NSDictionary *)retrieveDataFromStoreWithCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    if (![self.store soupExists:cacheType]) {
        return nil;
    }
    
    SFQuerySpec *querySpec = [SFQuerySpec newExactQuerySpec:cacheType withPath:kSmartStoreCacheKeyPath withMatchKey:cacheKey withOrderPath:kSmartStoreCacheKeyPath withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    NSError *queryError = nil;
    
    NSArray *results = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:&queryError];
    if (queryError) {
        [self log:SFLogLevelError format:@"Error querying SmartStore for cached data: %@", [queryError localizedDescription]];
        return nil;
    }
    
    if ([results count] == 0) {
        return nil;
    } else {
        NSDictionary *retData = results[0];
        return retData;
    }
}

- (void)createCacheSoup:(NSString *)cacheSoupName {
    [self createCacheSoupMappingSoup];
    if (![self.store soupExists:cacheSoupName]) {
        NSArray *cacheIndexSpecs = @[ [[SFSoupIndex alloc] initWithPath:kSmartStoreCacheKeyPath indexType:kSoupIndexTypeString columnName:nil] ];
        [self.store registerSoup:cacheSoupName withIndexSpecs:cacheIndexSpecs error:nil];
        [self addCacheSoupToSoupMappingSoup:cacheSoupName];
    }
}

- (void)removeDataFromStoreWithCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey {
    if (![self.store soupExists:cacheType]) {
        return;
    }
    
    SFQuerySpec * querySpec = [SFQuerySpec newExactQuerySpec:cacheType withPath:kSmartStoreCacheKeyPath withMatchKey:cacheKey withOrderPath:kSmartStoreCacheKeyPath withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    [self.store removeEntriesByQuery:querySpec fromSoup:cacheType];
}

- (void)createCacheSoupMappingSoup {
    if ([self.store soupExists:kSmartStoreSoupMappingSoupName]) {
        return;
    }
    
    SFSoupIndex *indexSpec = [[SFSoupIndex alloc] initWithPath:kSmartStoreSoupNamesPath indexType:kSoupIndexTypeString columnName:nil];
    [self.store registerSoup:kSmartStoreSoupMappingSoupName withIndexSpecs:@[ indexSpec ] error:nil];
}

- (void)addCacheSoupToSoupMappingSoup:(NSString *)soupName {
    if ([self cacheSoupInSoupMappingSoup:soupName]) {
        return;
    }
    
    NSDictionary *soupNameEntry = @{ kSmartStoreSoupNamesPath: soupName };
    NSError *upsertError = nil;
    [self.store upsertEntries:@[ soupNameEntry ] toSoup:kSmartStoreSoupMappingSoupName withExternalIdPath:kSmartStoreSoupNamesPath error:&upsertError];
    if (upsertError) {
        [self log:SFLogLevelError format:@"Error adding cache soup '%@' to mapping soup: %@", soupName, [upsertError localizedDescription]];
    }
}

- (BOOL)cacheSoupInSoupMappingSoup:(NSString *)soupName {
    NSArray *allSoupNames = [self allCacheSoupNames];
    for (NSString *existingSoupName in allSoupNames) {
        if ([existingSoupName isEqualToString:soupName]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSArray *)allCacheSoupNames {
    if (![self.store soupExists:kSmartStoreSoupMappingSoupName]) {
        // No master soup table, so no soups.
        return nil;
    }
    
    NSString *allCacheSoupsSql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@}", kSmartStoreSoupMappingSoupName, kSmartStoreSoupNamesPath, kSmartStoreSoupMappingSoupName];
    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:allCacheSoupsSql withPageSize:25];
    NSError *queryError = nil;
    NSMutableArray *soupNamesArray = [NSMutableArray array];
    NSUInteger pageIndex = 0;
    NSUInteger numResults = 0;
    do {
        NSArray *results = [self.store queryWithQuerySpec:querySpec pageIndex:pageIndex error:&queryError];
        if (queryError) {
            [self log:SFLogLevelError format:@"Error querying SmartStore for cache soup names: %@", [queryError localizedDescription]];
            return nil;
        }
        
        numResults = [results count];
        for (NSUInteger i = 0; i < numResults; i++) {
            [soupNamesArray addObject:results[i][0]];
        }
        pageIndex++;
    } while (numResults > 0);
    
    return soupNamesArray;
}

@end
