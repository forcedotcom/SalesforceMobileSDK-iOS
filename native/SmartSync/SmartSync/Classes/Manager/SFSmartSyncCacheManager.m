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
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSecurity/SFKeyStoreManager.h>
#import <SalesforceCommonUtils/SFCrypto.h>
#import <SalesforceCommonUtils/SFPathUtil.h>

static NSString * const kRootCachePath = @"smart_sync_cache";
static NSString * const kCacheTimeKey = @"CacheTime";
static NSString * const kCacheEncryptedKey = @"CacheEncrypted";
static NSString * const kCacheDataKey = @"CacheData";
static NSString * const kPlainCacheKey = @"%@_plain";
static NSString * const kEncryptedCacheKey = @"%@_encrypted";

@interface SFSmartSyncCacheManager ()

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, strong) NSCache *inMemCache;
@property (nonatomic, assign) BOOL enableInMemoryCache;
@property (nonatomic, strong) NSString *rootCachePath;
@property (nonatomic, assign) BOOL cacheShouldPersistWithAppUpgrade;

- (void)ensurePathExists:(NSString *)path;
- (NSString *)compositeCacheKeyFor:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted;
- (NSString *)filePathFor:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted;
- (NSData *)dataAtPath:(NSString *)filePath encrypted:(BOOL)encrypted cachedTime:(out NSDate **)cachedTime;
- (BOOL)shouldInvalidateCache:(SFDataCachePolicy)cachePolicy;
- (BOOL)shouldBypassCache:(SFDataCachePolicy)cachePolicy;
- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted;

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
                cacheMgr = [[SFSmartSyncCacheManager alloc] init:user];
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

- (id)init:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.inMemCache = [[NSCache alloc] init];
        self.enableInMemoryCache = YES;
        self.cacheShouldPersistWithAppUpgrade = YES;
        self.user = user;
    }
    return self;
}

- (void)setCacheShouldPersistWithAppUpgrade:(BOOL)shouldPersistAppUpgrade {
    if (_cacheShouldPersistWithAppUpgrade == shouldPersistAppUpgrade  ) {
        return;
    }

    // Remove old file caches.
    if (_rootCachePath) {

        // Remove root cache path.
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:_rootCachePath]) {
            NSError *error = nil;
            BOOL success = [fileManager removeItemAtPath:_rootCachePath error:&error];
            if (!success) {
                [self log:SFLogLevelError format:@"Failed to clean root cache path: [%@]", [error localizedDescription]];
            }
        }
        _rootCachePath = nil;
    }
    _cacheShouldPersistWithAppUpgrade = shouldPersistAppUpgrade;
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
    BOOL byPassCache = NO;
    switch (cachePolicy) {
        case SFDataCachePolicyIgnoreCacheData:
        case SFDataCachePolicyReloadAndReturnCacheOnFailure:
        case SFDataCachePolicyInvalidateCacheDontReload:
        case SFDataCachePolicyInvalidateCacheAndReload:
            byPassCache = YES;
            break;
        case SFDataCachePolicyReturnCacheDataAndReload:
        case SFDataCachePolicyReturnCacheDataAndReloadIfExpired:
        case SFDataCachePolicyReturnCacheDataDontReload:
        default:
            byPassCache = NO;
            break;
    }
    return byPassCache;
}

- (NSString *)rootCachePath {
    if (_rootCachePath) {
        return _rootCachePath;
    }
    if (nil == self.user) {
        return nil;
    }
    
    // Calculate root path for cache.
    NSSearchPathDirectory type;
    if (self.cacheShouldPersistWithAppUpgrade) {
        type = NSLibraryDirectory;
    } else {
        type = NSCachesDirectory;
    }
    _rootCachePath = [[SFDirectoryManager sharedManager] directoryForUser:self.user type:type components:@[kRootCachePath]];

    // This will create the root path and with proper do not backup flag applied.
    [SFPathUtil createFileItemIfNotExist:_rootCachePath skipBackup:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:_rootCachePath]) {
        _rootCachePath = nil;
    }
    return _rootCachePath;
}

- (void)ensurePathExists:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSString *)compositeCacheKeyFor:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted {
    NSString *compositeCacheKey = nil;
    if (encrypted) {
        compositeCacheKey = [NSString stringWithFormat:kEncryptedCacheKey, cacheKey];
    } else {
        compositeCacheKey = [NSString stringWithFormat:kPlainCacheKey, cacheKey];
    }
    return compositeCacheKey;
}

- (NSString *)filePathFor:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted {
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encrypted];
    NSString *filePath = [[self rootCachePath] stringByAppendingPathComponent:cacheType];

    // Ensure path exists.
    [self ensurePathExists:filePath];
    filePath = [filePath stringByAppendingPathComponent:compositeCacheKey];
    return filePath;
}

- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey encrypted:(BOOL)encrypted {
    if (nil == cacheType || nil == cacheKey) {
        return;
    }
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encrypted];

    // Clean out in memory cache.
    [self.inMemCache removeObjectForKey:compositeCacheKey];
    
    // Clean out disk cache.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self filePathFor:cacheType cacheKey:cacheKey encrypted:encrypted];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
        if (!success) {
            [self log:SFLogLevelError format:@"Failed to clean cache [%@]: [%@]", compositeCacheKey, [error localizedDescription]];
        }
    }
}

- (NSData *)dataAtPath:(NSString *)filePath encrypted:(BOOL)encrypted cachedTime:(out NSDate **)cachedTime {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSData *cachedData = [NSData dataWithContentsOfFile:filePath];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
        if (attributes) {
            if (cachedTime) {
                *cachedTime =  [attributes fileModificationDate];
            }
        }
        NSData *returnData = nil;
        if (encrypted) {

            // Decrypt data.
            SFEncryptionKey *encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"CHSalesforceOneEncryptionKey" keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
            SFCrypto *cipher = [[SFCrypto alloc] initWithOperation:kCCDecrypt
                                                               key:encryptionKey.key
                                                              mode:SFCryptoModeInMemory];
            @try {
                returnData = [cipher decryptDataInMemory:cachedData];
            } @catch (NSException *exception) {
                [self log:SFLogLevelError format:@"Error decrypting file at path [%@]: [%@]", filePath, exception.debugDescription];
                returnData = nil;
                NSError *error = nil;
                if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                    [self log:SFLogLevelError format:@"Error deleting malformed encrypted file at path %@: %@", filePath, error];
                }
            }
        } else {

            // Data not encrypted.
            returnData = cachedData;
        }
        return cachedData;
    } else {
        if (cachedTime) {
            *cachedTime = nil;
        }
        return nil;
    }
}

#pragma mark - Implement Delegate Methods

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

    if(!cacheExists) {

        // If cache does not exist, always reload.
        return YES;
    }
    if (refreshIfOlderThan <= 0) {
        return YES;
    }
    if (nil == cacheTime) {
        return YES;
    }
    NSTimeInterval timeDiff= [[NSDate date] timeIntervalSinceDate:cacheTime];
    if (timeDiff > refreshIfOlderThan) {
        return YES;
    } else {
        return NO;
    }
}

- (void)cleanCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Remove root cache path.
    if (self.rootCachePath && [fileManager fileExistsAtPath:self.rootCachePath]) {
        NSError *error = nil;
        BOOL success = [fileManager removeItemAtPath:self.rootCachePath error:&error];
        if (!success) {
            [self log:SFLogLevelError format:@"Failed to clean root cache path: [%@]", [error localizedDescription]];
        }
    }

    // Clean out in memory cache.
    [self.inMemCache removeAllObjects];
}

- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey {

    // Remove both encrypted and non-encrypted cache.
    [self removeCache:cacheType cacheKey:cacheKey encrypted:YES];
    [self removeCache:cacheType cacheKey:cacheKey encrypted:NO];
}

- (NSData *)readDataWithCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey cachePolicy:(SFDataCachePolicy)cachePolicy encrypted:(BOOL)encrypted cachedTime:(out NSDate **)lastCachedTime {
    BOOL byPassCache = [self shouldBypassCache:cachePolicy];
    if (byPassCache) {
        return nil;
    }
    NSDate *cachedTime = nil;
    NSData *cachedData = nil;
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encrypted];

    // Calculate local file cache path.
    NSString *filePath = [self filePathFor:cacheType cacheKey:cacheKey encrypted:encrypted];
    NSData *returnData = nil;

    // Check in-memory cache first.
    if (self.enableInMemoryCache) {
        NSDictionary *inMemoryCacheInfo = [self.inMemCache objectForKey:compositeCacheKey];
        if (inMemoryCacheInfo) {
            cachedData = inMemoryCacheInfo[kCacheDataKey];
            cachedTime = inMemoryCacheInfo[kCacheTimeKey];
        }
    }

    // Check on disk cache if in-memory cache not found.
    if (!cachedData) {
        returnData = [self dataAtPath:filePath encrypted:encrypted cachedTime:lastCachedTime];

        // Save to in memory cache.
        if (returnData && self.enableInMemoryCache) {
            if (lastCachedTime) {
                if (nil == *lastCachedTime) {
                    *lastCachedTime = [NSDate date];
                }
                [self.inMemCache setObject:@{kCacheDataKey : returnData, kCacheTimeKey : *lastCachedTime} forKey:compositeCacheKey];
            } else {
                [self.inMemCache setObject:@{kCacheDataKey : returnData} forKey:compositeCacheKey];
            }
        }
    } else {
        if (lastCachedTime) {
            *lastCachedTime = cachedTime;
        }
    }
    return returnData;
}

- (void)writeDataToCache:(NSData *)data cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey encryptCache:(BOOL)encryptCache {
    if (!cacheKey) {

        // Cache key is nil, directly return.
        return;
    }
    if (!data) {

        // Set cache to nil = remove cache by key.
        [self removeCache:cacheType cacheKey:cacheKey encrypted:encryptCache];
    }
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encryptCache];

    // Save to in-memory cache.
    if (data && self.enableInMemoryCache) {
        [self.inMemCache setObject:@{kCacheDataKey : data, kCacheTimeKey : [NSDate date]} forKey:compositeCacheKey];
    }

    // Write to disk.
    NSString *filePath = [self filePathFor:cacheType cacheKey:cacheKey encrypted:encryptCache];
    @try {

        // Encrypt data.
        SFEncryptionKey *encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"CHSalesforceOneEncryptionKey" keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
        SFCrypto *cipher = [[SFCrypto alloc] initWithOperation:kCCEncrypt
                                                           key:encryptionKey.key
                                                          mode:SFCryptoModeInMemory];
        NSData *dataToWrite = nil;
        @try {
            dataToWrite = [cipher encryptDataInMemory:data];
            [dataToWrite writeToFile:filePath atomically:YES];
        } @catch (NSException *exception) {
            [self log:SFLogLevelError format:@"Error decrypting file at path [%@]: [%@]", filePath, exception.debugDescription];
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                [self log:SFLogLevelError format:@"Error deleting malformed encrypted file at path %@: %@", filePath, error];
            }
        }
    } @catch (NSException *exception) {
        [self log:SFLogLevelError format:@"Failed to save to disk cache: [%@]", exception.debugDescription];
    }
}

- (id)readArchivableObjectWithCacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey cachePolicy:(SFDataCachePolicy)cachePolicy encrypted:(BOOL)encrypted cachedTime:(out NSDate **)lastCachedTime {
    BOOL shouldInvalidateCache = [self shouldInvalidateCache:cachePolicy];
    if (shouldInvalidateCache) {
        [self removeCache:cacheType cacheKey:cacheKey encrypted:encrypted];
        return nil;
    }
    BOOL byPassCache = [self shouldBypassCache:cachePolicy];
    if (byPassCache) {
        return nil;
    }
    NSData *cachedData = nil;
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encrypted];
    NSString *filePath = [self filePathFor:cacheType cacheKey:cacheKey encrypted:encrypted];

    // Check in memory cache first.
    if (self.enableInMemoryCache) {
        NSDictionary *inMemoryCacheInfo = [self.inMemCache objectForKey:compositeCacheKey];
        if (inMemoryCacheInfo) {
            cachedData = inMemoryCacheInfo[kCacheDataKey];
            if (lastCachedTime) {
                *lastCachedTime = inMemoryCacheInfo[kCacheTimeKey];
            }
        }
    }
    if (cachedData) {
        return cachedData;
    }

    // Check on disk cache instead.
    cachedData = [self dataAtPath:filePath encrypted:encrypted cachedTime:lastCachedTime];
    if (nil == cachedData) {
        return nil;
    }
    id <NSCoding> unarchivedData = nil;
    @try {

        // Decrypt the data.
        if (encrypted) {
            SFEncryptionKey *encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"CHSalesforceOneEncryptionKey" keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
            SFCrypto *cipher = [[SFCrypto alloc] initWithOperation:kCCDecrypt
                                                               key:encryptionKey.key
                                                              mode:SFCryptoModeInMemory];
            cachedData = [cipher decryptDataInMemory:cachedData];
        }
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithData:cachedData];

        // Save to in-memory cache.
        if (unarchivedData && self.enableInMemoryCache) {
            if (lastCachedTime) {
                if (nil == *lastCachedTime) {
                    *lastCachedTime = [NSDate date];
                }
                [self.inMemCache setObject:@{kCacheDataKey : unarchivedData, kCacheTimeKey : *lastCachedTime} forKey:compositeCacheKey];
            } else {
                [self.inMemCache setObject:@{kCacheDataKey : unarchivedData} forKey:compositeCacheKey];
            }
        }
    } @catch (NSException *exception) {

        // If we received an exception when unarchiving this object, remove
        // it from disk and return a nil object.
        unarchivedData = nil;
        if (lastCachedTime) {
            *lastCachedTime = nil;
        }
        [self log:SFLogLevelError format:@"Error unarchiving %@: %@", filePath, exception.description];
        if (filePath) {
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                [self log:SFLogLevelError format:@"Error delete corrupted archive file %@: %@", filePath, exception.description];
            }
        }
    } @finally {
        return unarchivedData;
    }
}

- (void)writeArchivableObjectToCache:(id)object cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey encryptCache:(BOOL)encryptCache {
    if (nil == object || nil == cacheType || nil == cacheKey) {
        return;
    }
    BOOL validObjectTypes = NO;
    if ([object conformsToProtocol:@protocol(NSCoding)]) {
        validObjectTypes = YES;
    } else if ([object isKindOfClass:[NSArray class]]) {
        NSArray *objects = (NSArray *)object;
        if (objects.count == 0) {
            // return
            return;
        } else if ([objects[0] conformsToProtocol:@protocol(NSCoding)]) {
            validObjectTypes = YES;
        }
    }
    if (!validObjectTypes) {
        [self log:SFLogLevelError format:@"Object to be persisted using %@ has to be either implement NSCoding or an NSArray of objects that implement NSCoding", [[self class] description]];
        return;
    }
    NSString *compositeCacheKey = [self compositeCacheKeyFor:cacheType cacheKey:cacheKey encrypted:encryptCache];
    NSString *filePath = [self filePathFor:cacheType cacheKey:cacheKey encrypted:encryptCache];

    // Save to in-memory cache.
    if (object && self.enableInMemoryCache) {
        [self.inMemCache setObject:@{kCacheDataKey : object, kCacheTimeKey : [NSDate date]} forKey:compositeCacheKey];
    }

    // Write to disk.
    if (object) {
        @try {
            NSData *objectData = [NSKeyedArchiver archivedDataWithRootObject:object];
            if (encryptCache) {

                // Encrypt cache if necessary.
                SFEncryptionKey *encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:@"CHSalesforceOneEncryptionKey" keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
                SFCrypto *cipher = [[SFCrypto alloc] initWithOperation:kCCEncrypt key:encryptionKey.key mode:SFCryptoModeInMemory];
                objectData = [cipher encryptDataInMemory:objectData];
            }
            [objectData writeToFile:filePath atomically:YES];
        } @catch (NSException *exception) {

            // If we received an exception when unarchiving this object, remove
            // it from disk and return a nil object.
            [self log:SFLogLevelError format:@"Error archiving %@: %@", filePath, exception.description];
        }
    }
}

@end
