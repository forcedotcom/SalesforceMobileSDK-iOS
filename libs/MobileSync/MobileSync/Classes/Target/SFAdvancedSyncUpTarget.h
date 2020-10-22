/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import <MobileSync/SFSyncUpTarget.h>
#import <MobileSync/SFSyncState.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for advanced sync up target where records are not simply created, updated, or deleted.
 With advanced sync up target, sync manager simply calls the `syncUpRecords` method.
 */
NS_SWIFT_NAME(AdvancedSyncUpTarget)
@protocol SFAdvancedSyncUpTarget

/**
 Maximum number of records that can be passed to `syncUpRecords` at once.
 */
@property (nonatomic,readonly) NSUInteger maxBatchSize;

/**
 Sync up locally created, updated, or deleted records to the server.
 @param syncManager Sync manager doing the sync
 @param records Records being synced
 @param fieldlist List of fields to send to server
 @param mergeMode Merge mode--either "OVERWRITE" or "LEAVE_IF_CHANGED".
 @param syncSoupName Soup being synced.
 @param completionBlock Block to execute after the server call completes.
 @param failBlock Block to execute if the server call fails.
 */
- (void)syncUpRecords:(SFMobileSyncSyncManager *)syncManager
              records:(NSArray<NSMutableDictionary*>*)records
            fieldlist:(NSArray*)fieldlist
            mergeMode:(SFSyncStateMergeMode)mergeMode
         syncSoupName:(NSString*)syncSoupName
      completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
            failBlock:(SFSyncUpTargetErrorBlock)failBlock;

@end

NS_ASSUME_NONNULL_END
