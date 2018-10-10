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

NS_ASSUME_NONNULL_BEGIN

@class SFSyncTarget;
@class SFSyncDownTarget;
@class SFSyncUpTarget;
@class SFSyncOptions;
@class SFSmartStore;

// soups and soup fields
extern NSString * const kSFSyncStateSyncsSoupName;
extern NSString * const kSFSyncStateSyncsSoupSyncType;

// Fields in dict representation
extern NSString * const kSFSyncStateId;
extern NSString * const kSFSyncStateName;
extern NSString * const kSFSyncStateType;
extern NSString * const kSFSyncStateTarget;
extern NSString * const kSFSyncStateSoupName;
extern NSString * const kSFSyncStateOptions;
extern NSString * const kSFSyncStateStatus;
extern NSString * const kSFSyncStateProgress;
extern NSString * const kSFSyncStateTotalSize;
extern NSString * const kSFSyncStateMaxTimeStamp;
extern NSString * const kSFSyncStateStartTime;
extern NSString * const kSFSyncStateEndTime;

// Possible values for sync type
typedef NS_ENUM(NSInteger, SFSyncStateSyncType) {
    SFSyncStateSyncTypeDown,
    SFSyncStateSyncTypeUp,
} NS_SWIFT_NAME(SyncType);

extern NSString * const kSFSyncStateTypeDown;
extern NSString * const kSFSyncStateTypeUp;

// Possible value for sync status
typedef NS_ENUM(NSInteger, SFSyncStateStatus) {
    SFSyncStateStatusNew,
    SFSyncStateStatusRunning,
    SFSyncStateStatusDone,
    SFSyncStateStatusFailed
} NS_SWIFT_NAME(SyncStatus);

extern NSString * const kSFSyncStateStatusNew;
extern NSString * const kSFSyncStateStatusRunning;
extern NSString * const kSFSyncStateStatusDone;
extern NSString * const kSFSyncStateStatusFailed;

// Possible value for merge mode
typedef NS_ENUM(NSInteger, SFSyncStateMergeMode) {
    SFSyncStateMergeModeOverwrite,
    SFSyncStateMergeModeLeaveIfChanged
    
} NS_SWIFT_NAME(SyncMergeMode);

extern NSString * const kSFSyncStateMergeModeOverwrite;
extern NSString * const kSFSyncStateMergeModeLeaveIfChanged;

NS_SWIFT_NAME(SyncState)
@interface SFSyncState : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger syncId;
@property (nonatomic, strong, readonly) NSString* syncName;
@property (nonatomic, readonly) SFSyncStateSyncType type;
@property (nonatomic, strong, readonly) NSString* soupName;
@property (nonatomic, strong, readonly) SFSyncTarget* target;
@property (nonatomic, strong, readonly) SFSyncOptions* options;
@property (nonatomic) SFSyncStateStatus status;
@property (nonatomic) NSInteger progress;
@property (nonatomic) NSInteger totalSize;
@property (nonatomic) SFSyncStateMergeMode mergeMode;
@property (nonatomic) long long maxTimeStamp;

// Start and end time in milliseconds since 1970
@property (nonatomic, readonly) NSInteger startTime;
@property (nonatomic, readonly) NSInteger endTime;

/** Setup soup that keeps track of sync operations
 */
+ (void) setupSyncsSoupIfNeeded:(SFSmartStore*)store;

/** Factory methods
 */
+ (nullable SFSyncState *)newSyncDownWithOptions:(SFSyncOptions *)options target:(SFSyncDownTarget *)target soupName:(NSString *)soupName name:(nullable NSString *) name store:(SFSmartStore*)store NS_SWIFT_NAME(buildSyncDown(options:target:soupName:name:store:));
+ (nullable SFSyncState *)newSyncUpWithOptions:(SFSyncOptions *)options target:(SFSyncUpTarget *)target soupName:(NSString *)soupName name:(nullable NSString *)name store:(SFSmartStore *)store NS_SWIFT_NAME(buildSyncUp(options:target:soupName:name:store:));
+ (nullable SFSyncState*) newSyncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName store:(SFSmartStore*)store NS_SWIFT_NAME(buildSyncUp(options:soupName:store:));;

/** Methods to save/retrieve/delete from smartstore
 */
+ (nullable SFSyncState*)byId:(NSNumber *)syncId store:(SFSmartStore*)store;
+ (nullable SFSyncState*)byName:(NSString *)name store:(SFSmartStore*)store;
- (void) save:(SFSmartStore*)store;
+ (void) deleteById:(NSNumber*)syncId store:(SFSmartStore*)store NS_SWIFT_NAME(delete(syncId:store:));
+ (void) deleteByName:(NSString*)name store:(SFSmartStore*)store NS_SWIFT_NAME(delete(syncName:store:));

/** Methods to translate to/from dictionary
 */
+ (nullable SFSyncState*) newFromDict:(NSDictionary *)dict NS_SWIFT_NAME(build(dict:));
- (NSDictionary*) asDict;

/** Method for easy status check
 */
- (BOOL) isDone;
- (BOOL) hasFailed;
- (BOOL) isRunning;

/** Enum to/from string helper methods
 */
+ (SFSyncStateSyncType) syncTypeFromString:(NSString*)syncType;
+ (NSString*) syncTypeToString:(SFSyncStateSyncType)syncType;
+ (SFSyncStateStatus) syncStatusFromString:(nullable NSString*)syncStatus;
+ (NSString*) syncStatusToString:(SFSyncStateStatus)syncStatus;
+ (SFSyncStateMergeMode) mergeModeFromString:(NSString*)mergeMode;
+ (NSString*) mergeModeToString:(SFSyncStateMergeMode)mergeMode;

@end

NS_ASSUME_NONNULL_END
