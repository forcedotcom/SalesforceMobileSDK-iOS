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

@class SFSmartSyncSyncManager;

typedef void (^SFSyncDownTargetFetchCompleteBlock) (NSArray* records);
typedef void (^SFSyncDownTargetFetchErrorBlock) (NSError *e);

typedef NS_ENUM(NSInteger, SFSyncDownTargetQueryType) {
  SFSyncDownTargetQueryTypeMru,
  SFSyncDownTargetQueryTypeSosl,
  SFSyncDownTargetQueryTypeSoql,
  SFSyncDownTargetQueryTypeCustom
};

@interface SFSyncDownTarget : SFSyncTarget

@property (nonatomic) SFSyncDownTargetQueryType queryType;

// Set during a fetch
@property (nonatomic) NSUInteger totalSize;

/**
 * Methods to translate to/from dictionary
 */
+ (SFSyncDownTarget*) newFromDict:(NSDictionary *)dict;

/**
 * Start fetching records conforming to target
 */
- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Start fetching records conforming to target with query
 */
- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
           queryRun:(NSString*)queryRun
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Continue fetching records conforming to target if any
 */
- (void) continueFetch:(SFSmartSyncSyncManager*)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

/**
 * Fetch list of IDs still present on the server from the list of local IDs
 */
- (void) getListOfRemoteIds:(SFSmartSyncSyncManager*)syncManager
                       localIds:(NSArray*)localIds
                     errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
                  completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

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
 * Enum to/from string helper methods
 */
+ (SFSyncDownTargetQueryType) queryTypeFromString:(NSString*)queryType;
+ (NSString*) queryTypeToString:(SFSyncDownTargetQueryType)queryType;

@end
