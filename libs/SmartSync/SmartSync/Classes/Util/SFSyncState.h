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

#import <Foundation/Foundation.h>

@class SFSmartStore;

// soups and soup fields
extern NSString * const kSFSyncStateSyncsSoupName;
extern NSString * const kSFSyncStateSyncsSoupSyncType;

// Fields in dict representation
extern NSString * const kSFSyncStateId;
extern NSString * const kSFSyncStateType;
extern NSString * const kSFSyncStateTarget;
extern NSString * const kSFSyncStateSoupName;
extern NSString * const kSFSyncStateOptions;
extern NSString * const kSFSyncStateStatus;
extern NSString * const kSFSyncStateProgress;
extern NSString * const kSFSyncStateTotalSize;

// Possible value for sync type
extern NSString * const kSFSyncStateTypeDown;
extern NSString * const kSFSyncStateTypeUp;

// Possible value for sync status
extern NSString * const kSFSyncStateStatusNew;
extern NSString * const kSFSyncStateStatusRunning;
extern NSString * const kSFSyncStateStatusDone;
extern NSString * const kSFSyncStateStatusFailed;

@interface SFSyncState : NSObject

@property (atomic, readonly) NSInteger syncId;
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSDictionary* target;
@property (nonatomic, strong) NSString* soupName;
@property (nonatomic, strong) NSDictionary* options;
@property (nonatomic, strong) NSString* status;
@property (atomic) NSInteger progress;
@property (atomic) NSInteger totalSize;

+ (void) setupSyncsSoupIfNeeded:(SFSmartStore*)store;
+ (SFSyncState*) newSyncDownWithTarget:(NSDictionary*)target soupName:(NSString*)soupName store:(SFSmartStore*)store;
+ (SFSyncState*) newSyncUpWithOptions:(NSDictionary*)options soupName:(NSString*)soupName store:(SFSmartStore*)store;
+ (SFSyncState*) byId:(NSNumber*)syncId store:(SFSmartStore*)store;
- (SFSyncState*) save:(SFSmartStore*)store;
- (SFSyncState*) fromDict:(NSDictionary *)dict;
- (NSDictionary*) asDict;
- (BOOL)isDone;
- (BOOL)hasFailed;

@end
