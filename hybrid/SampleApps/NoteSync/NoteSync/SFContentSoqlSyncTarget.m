/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFContentSoqlSyncTarget.h"
#import <SmartSync/SFSmartSyncSyncManager.h>

@implementation SFContentSoqlSyncTarget

#pragma mark - Factory methods

+ (SFContentSoqlSyncTarget*) newSyncTarget:(NSString*)query {
    SFContentSoqlSyncTarget* syncTarget = [[SFContentSoqlSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeCustom;
    syncTarget.query = query;
    return syncTarget;
}


#pragma mark - From/to dictionary

+ (SFContentSoqlSyncTarget*) newFromDict:(NSDictionary*)dict {
    SFContentSoqlSyncTarget* syncTarget = nil;
    if (dict != nil && [dict count] != 0) {
        syncTarget = [[SFContentSoqlSyncTarget alloc] init];
        syncTarget.queryType = SFSyncTargetQueryTypeCustom;
        syncTarget.query = dict[kSFSoqlSyncTargetQuery];
    }
    return syncTarget;
}

- (NSDictionary*) asDict {
    return @{
             kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
             kSFSoqlSyncTargetQuery: self.query,
             kSFSyncTargetiOSImpl: NSStringFromClass([self class])
             };
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    
    // FIXME
    
    completeBlock(nil);
}

- (void) continueFetch:(SFSmartSyncSyncManager *)syncManager
            errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    // FIXME
    
    completeBlock(nil);
}

@end
