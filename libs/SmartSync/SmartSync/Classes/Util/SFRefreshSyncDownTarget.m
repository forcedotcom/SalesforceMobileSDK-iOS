/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFRefreshSyncDownTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"

NSString * const kSFSyncTargetRefreshSoupName = @"soupName";
NSString * const kSFSyncTargetRefreshObjectType = @"objectType";
NSString * const kSFSyncTargetRefreshFieldlist = @"fieldlist";


@interface SFRefreshSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* soupName;
@property (nonatomic, strong, readwrite) NSString* objectType;
@property (nonatomic, strong, readwrite) NSArray*  fieldlist;

@end

@implementation SFRefreshSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeRefresh;
        self.soupName = dict[kSFSyncTargetRefreshSoupName];
        self.objectType = dict[kSFSyncTargetRefreshObjectType];
        self.fieldlist = dict[kSFSyncTargetRefreshFieldlist];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeRefresh;
    }
    return self;
}

#pragma mark - Factory methods

+ (SFRefreshSyncDownTarget*) newSyncTarget:(NSString*)soupName objectType:(NSString*)objectType fieldlist:(NSArray*)fieldlist {
    SFRefreshSyncDownTarget* syncTarget = [[SFRefreshSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeRefresh;
    syncTarget.soupName = soupName;
    syncTarget.objectType = objectType;
    syncTarget.fieldlist = fieldlist;
    return syncTarget;
}

#pragma mark - To dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetRefreshSoupName] = self.soupName;
    dict[kSFSyncTargetRefreshObjectType] = self.objectType;
    dict[kSFSyncTargetRefreshFieldlist] = self.fieldlist;
    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    // TBD
}

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
           queryRun:(NSString*)queryRun
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    // TBD
}

- (void) getListOfRemoteIds:(SFSmartSyncSyncManager*)syncManager
                   localIds:(NSArray*)localIds
                 errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
              completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (localIds == nil) {
        completeBlock(nil);
    }
    // TBD
}

@end
