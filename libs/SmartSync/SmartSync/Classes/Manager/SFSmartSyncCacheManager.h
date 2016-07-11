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

typedef  enum {
    SFDataCachePolicyIgnoreCacheData = 0, // ignore cache and always load from server
    SFDataCachePolicyReloadAndReturnCacheOnFailure, // Always reload and return cache on failure
    SFDataCachePolicyReturnCacheDataDontReload, // Use cache and don't reload cache if cache exists
    SFDataCachePolicyReturnCacheDataAndReload, // Return cache first and reload data in background to update cache
    SFDataCachePolicyReturnCacheDataAndReloadIfExpired, // Return cache first and reload data if based on refreshCache time internval in background to update cache and call completion block again if cache is updated
    SFDataCachePolicyInvalidateCacheDontReload, // Invalidate cache and don't reload
    SFDataCachePolicyInvalidateCacheAndReload, // Invalidate cache and reload data
} SFDataCachePolicy;

@class SFUserAccount;

/** This class acts as a simple cache to store and retrieve data.
 */
@interface SFSmartSyncCacheManager : NSObject

/** Singleton method for accessing cache manager instance.
 @param user A user that will scope this manager instance data
 */
+ (id)sharedInstance:(SFUserAccount *)user;

/** Removes the shared instance associated with the specified user
 @param user The user
 */
+ (void)removeSharedInstance:(SFUserAccount*)user;

/** Enable in memory cache. Default value is YES
 @enableInMemoryCache YES to enable in memory cache
 */
- (void)setEnableInMemoryCache:(BOOL)enableInMemoryCache;

/** Clean cache
 */
- (void)cleanCache;

/** Remove data from cache
 @param cacheType Cache type
 @param cacheKey Key to use to retrieve cached data
 */
- (void)removeCache:(NSString *)cacheType cacheKey:(NSString *)cacheKey;

/** Reurn YES if need to reload cache.
 Before calling this method, user should use `[SFSmartSyncCacheManager readDataWithCacheType:cacheKey:cachePolicy:encrypted:cachedTime]` to find out whether cache exists or not and what is the last time cache is updated
 @param cacheExists YES if cache already exists.
 @param cachePolicy `SFDataCachePolicy` used to decide
 @param cacheTime Last time cache is updated
 @param refreshIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass any value that is <=0 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy` to determine if cache needs reload or not
 */
- (BOOL)needToReloadCache:(BOOL)cacheExists cachePolicy:(SFDataCachePolicy)cachePolicy lastCachedTime:(NSDate *)cacheTime refreshIfOlderThan:(NSTimeInterval)refreshIfOlderThan;

/** Read data from cache.
 @param cacheType Cache type
 @param cacheKey Key to use to retrieve cached data
 @param cachePolicy See `SFDataCachePolicy`
 @param objectClass Object class to expect
 @param lastCachedTime Return time the data was last updated in cache
 */
- (NSArray *)readDataWithCacheType:(NSString *)cacheType
                          cacheKey:(NSString *)cacheKey
                       cachePolicy:(SFDataCachePolicy)cachePolicy
                        objectClass:(Class)objectClass
                        cachedTime:(out NSDate **)lastCachedTime;

/** Write data to cache.
 @param data Data to cache
 @param cacheType Cache type
 @param cacheKey Key to save cached data
 */
- (void)writeDataToCache:(id)data cacheType:(NSString *)cacheType cacheKey:(NSString *)cacheKey;

@end
