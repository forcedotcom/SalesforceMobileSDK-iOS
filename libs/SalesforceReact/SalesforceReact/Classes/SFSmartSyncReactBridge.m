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

#import "SFSmartSyncReactBridge.h"

#import <ReactKit/RCTAssert.h>
#import <ReactKit/RCTLog.h>
#import <ReactKit/RCTUtils.h>
#import <SalesforceCommonUtils/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SmartSync/SFSmartSyncSyncManager.h>
#import <SmartSync/SFSyncState.h>

// Private constants
NSString * const kSyncSoupNameArg = @"soupName";
NSString * const kSyncTargetArg = @"target";
NSString * const kSyncOptionsArg = @"options";
NSString * const kSyncIdArg = @"syncId";
NSString * const kSyncEventType = @"sync";
NSString * const kSyncDetail = @"detail";

@implementation SFSmartSyncReactBridge

#pragma mark - Bridged methods

- (void) getSyncStatus:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSNumber* syncId = (NSNumber*) [args nonNullObjectForKey:kSyncIdArg];
    
    [self log:SFLogLevelDebug format:@"getSyncStatus with sync id: %@", syncId];
    
    SFSyncState* sync = [self.syncManager getSyncStatus:syncId];
    callback( @[ [sync asDict] ]);
}

- (void) syncDown:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSyncSoupNameArg];
    SFSyncOptions *options = [SFSyncOptions newFromDict:[args nonNullObjectForKey:kSyncOptionsArg]];
    SFSyncTarget *target = [SFSyncTarget newFromDict:[args nonNullObjectForKey:kSyncTargetArg]];
    
    __weak SFSmartSyncReactBridge *weakSelf = self;
    SFSyncState* sync = [self.syncManager syncDownWithTarget:target options:options soupName:soupName updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync callback:callback callbackErr:callbackErr];
    }];

    [self log:SFLogLevelDebug format:@"syncDown # %d from soup: %@", sync.syncId, soupName];
}

- (void) reSync:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSNumber* syncId = (NSNumber*) [args nonNullObjectForKey:kSyncIdArg];
    
    __weak SFSmartSyncReactBridge *weakSelf = self;
    SFSyncState* sync = [self.syncManager reSync:syncId updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync callback:callback callbackErr:callbackErr];
    }];

    [self log:SFLogLevelDebug format:@"reSync # %d from soup: %@", sync.syncId, sync.soupName];
}

- (void) syncUp:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSyncSoupNameArg];
    SFSyncOptions *options = [SFSyncOptions newFromDict:[args nonNullObjectForKey:kSyncOptionsArg]];
    
    __weak SFSmartSyncReactBridge *weakSelf = self;
    SFSyncState* sync = [self.syncManager syncUpWithOptions:options soupName:soupName updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync callback:callback callbackErr:callbackErr];
    }];
    
    [self log:SFLogLevelDebug format:@"syncUp # %d from soup: %@", sync.syncId, soupName];
}


#pragma mark - Helper methods

- (SFSmartSyncSyncManager*) syncManager
{
    RCT_EXPORT();
    SFUserAccount* user = [SFUserAccountManager sharedInstance].currentUser;
    [SFSmartSyncSyncManager removeSharedInstance:user];
    return [SFSmartSyncSyncManager sharedInstance:user];
}

- (void)handleSyncUpdate:(SFSyncState*)sync callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    if (sync.status == SFSyncStateStatusDone) {
        callback( @[ [sync asDict] ]);
    }
    else if (sync.status == SFSyncStateStatusFailed) {
        callbackErr( @ [[ sync asDict] ]);
    }
}


@end
