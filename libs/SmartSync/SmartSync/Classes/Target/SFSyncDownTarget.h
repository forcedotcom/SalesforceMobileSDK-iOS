/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>
#import "SFSyncTarget.h"

NS_ASSUME_NONNULL_BEGIN

@class SFSmartSyncSyncManager;

typedef void (^SFSyncDownTargetFetchCompleteBlock) (NSArray* _Nullable records);
typedef void (^SFSyncDownTargetFetchErrorBlock) (NSError * _Nullable e);

typedef NS_ENUM(NSInteger, SFSyncDownTargetQueryType) {
  SFSyncDownTargetQueryTypeMru,
  SFSyncDownTargetQueryTypeSosl,
  SFSyncDownTargetQueryTypeSoql,
  SFSyncDownTargetQueryTypeRefresh,
  SFSyncDownTargetQueryTypeParentChildren,
  SFSyncDownTargetQueryTypeCustom,
  SFSyncDownTargetQueryTypeMetadata,
  SFSyncDownTargetQueryTypeLayout
};

@interface SFSyncDownTarget : SFSyncTarget

@property (nonatomic,assign) SFSyncDownTargetQueryType queryType;

// Set during a fetch
@property (nonatomic) NSUInteger totalSize;

/**
 * Methods to translate to/from dictionary
 */
+ (nullable SFSyncDownTarget*) newFromDict:(NSDictionary *)dict;

/**
 * Start fetching records conforming to target
 */
- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Continue fetching records conforming to target if any
 */
- (void) continueFetch:(SFSmartSyncSyncManager*)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Gets the latest modification timestamp from the array of records. Note: inheriting classes can
 * override this method to determine the timestamp in a customized way. The default implementation
 * looks at the LastModifiedDate field of each record.
 *
 * @param records The array of records to query.
 * @return The timestamp of the record with the most recent modification date.
 */
- (long long) getLatestModificationTimeStamp:(NSArray*)records;


/**
 * Delete from local store records that a full sync down would no longer download
  *
  * @param syncManager The sync manager
  * @param soupName The soup to clean
  * @param syncId The sync id
  * @param errorBlock Block to execute in case of error
  * @param completeBlock Block to execute upon completion
  */
- (void)cleanGhosts:(SFSmartSyncSyncManager *)syncManager
           soupName:(NSString *)soupName
             syncId:(NSNumber *)syncId
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Get ids of records that should not be written over
 * during a sync down with merge mode leave-if-changed
 * @param syncManager The sync manager
 * @param soupName The soup
 * @return set of ids
 */
- (NSOrderedSet *)getIdsToSkip:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName;

/**
 * Enum to/from string helper methods
 */
+ (SFSyncDownTargetQueryType) queryTypeFromString:(NSString*)queryType;
+ (NSString*) queryTypeToString:(SFSyncDownTargetQueryType)queryType;

@end

NS_ASSUME_NONNULL_END
