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

#import <UIKit/UIColor.h>
#import "SFSmartSyncCacheManager.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFObjectType.h"

// Constants for creating NSError object
extern NSString * const SFMetadataManagerErrorDomain;
extern NSInteger  const SFMetadataManagerErrorCode;

// Cache constants
extern NSString * const kSFMRUCacheType;
extern NSString * const kSFMetadataCacheType;
extern NSString * const kSFAllObjectsCacheKey;

@class SFUserAccount;

/** This class defines APIs required to interact with metadata.
 */
@interface SFSmartSyncMetadataManager : NSObject

/** Community ID to use.
 Specify nil for the internal community (aka org)
 or when no communities are configured for the current org.
 This property is used internally to scope all the search
 queries toward the server.
 */
@property (nonatomic, copy) NSString *communityId;

/** API version being used.
 */
@property (nonatomic, copy) NSString *apiVersion;

/** Cache manager being used.
 */
@property (nonatomic, strong) SFSmartSyncCacheManager *cacheManager;

/** Singleton method for accessing metadata manager instance.
 @param user A user that will scope this manager instance data
 */
+ (id)sharedInstance:(SFUserAccount *)user;

/** Removes the shared instance associated with the specified user
 @param user The user
 */
+ (void)removeSharedInstance:(SFUserAccount*)user;

+ (NSString *)globalMruCacheKey;

/** Get a list of smart scope object types
 
 @param cachePolicy `SFDataCachePolicy` used to decide whether to read data from cache first and if data reload from server is needed when data is found in cache
 @param refreshCacheIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass any value that is <=0 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy`
 @param completionBlock Block to invoke after list of object types is returned
 @param errorBlock Block to invoke if failed to load object types
 
 */
- (void)loadSmartScopeObjectTypes:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                  completionBlock:(void(^)(NSArray *results, BOOL isDataFromCache))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Get a list of recently accessed objects by object type
 
 @param objectTypeName Object type name to get recently accessed objects. If nil, this method will return a list of recently accessed objecs across all object types
 @param limit Fetch limit of objects. Set to <=0 to specify no limit
 @param cachePolicy `SFDataCachePolicy` used to decide whether to read data from cache first and if data reload from server is needed when data is found in cache
 @param refreshCacheIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass -1 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy`
 @param networkFieldName Network field name
 @param inRetry Is retrying
 @param completionBlock Block to invoke after recently access objects are loaded
 @param errorBlock Block to invoke if failed to load objects
 
 */
- (void)loadMRUObjects:(NSString *)objectTypeName limit:(NSInteger)limit cachePolicy:(SFDataCachePolicy)cachePolicy
            refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan networkFieldName:(NSString *)networkFieldName
                inRetry:(BOOL)inRetry completion:(void(^)(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache))completionBlock
                    error:(void(^)(NSError *error))errorBlock;

/** Load all object types
 
 @param cachePolicy `SFDataCachePolicy` used to decide whether to read data from cache first and if data reload from server is needed when data is found in cache
 @param refreshCacheIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass -1 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy`
 @param completionBlock Block to invoke after all objects are returned. Input parameter for this completionBlock will include a list of `SFMetadataModel` objects
 @param errorBlock Block to invoke if failed to load objects list
 
 */
- (void)loadAllObjectTypes:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                completion:(void(^)(NSArray * results, BOOL isDataFromCache))completionBlock
                     error:(void(^)(NSError *error))errorBlock;

/** Load a specific object type information
 
 Object type information returned by this method is what /sobjects/xxxx/describe returns, include object describe and object detailed information
 @param objectTypeName Object type name
 @param cachePolicy `SFDataCachePolicy` used to decide whether to read data from cache first and if data reload from server is needed when data is found in cache
 @param refreshCacheIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass -1 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy`
 @param completionBlock Block to invoke after object type info is loaded
 @param errorBlock Block to invoke if loading metadata failed
 
 */
- (void)loadObjectType:(NSString *)objectTypeName cachePolicy:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
            completion:(void(^)(SFObjectType *result, BOOL isDataFromCache))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Load object layout information
 
 @param objectTypesToLoad Array of `SFObjectTypeModel` objects to load layout for
 @param cachePolicy `SFDataCachePolicy` used to decide whether to read data from cache first and if data reload from server is needed when data is found in cache
 @param refreshCacheIfOlderThan Number of secconds that has to pass in order to refresh cache. Pass -1 if you don't want cache to be refrefreshed. This value is used together with `cachePolicy`
 @param completionBlock Block to invoke after object type info is loaded
 @param errorBlock Block to invoke if loading metadata failed
 
 */
- (void)loadObjectTypesLayout:(NSArray *)objectTypesToLoad cachePolicy:(SFDataCachePolicy)cachePolicy refreshCacheIfOlderThan:(NSTimeInterval)refreshCacheIfOlderThan
                   completion:(void(^)(NSArray *result, BOOL isDataFromCache))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Color for the specific object type
 
 @param objectTypeName Object type name
 */
- (UIColor *)colorForObjectType:(NSString *)objectTypeName;

/** Return YES if object type is searchable
 
 @param objectType Object type
 */
- (BOOL)isObjectTypeSearchable:(SFObjectType *)objectType;

/** Mark an object as viewed
 
 @param objectId Object ID
 @param objectType Object type
 @param networkFieldName Network field name
 @param completionBlock Block to invoke after object is marked viewed
 @param errorBlock Block to invoke if marking viewed failed
 
 */
- (void)markObjectAsViewed:(NSString *)objectId objectType:(NSString *)objectType networkFieldName:(NSString *)networkFieldName
           completionBlock:(void(^)())completionBlock error:(void(^)(NSError *error))errorBlock;

@end
