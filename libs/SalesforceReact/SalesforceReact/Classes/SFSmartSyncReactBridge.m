/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "RCTUtils.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SmartStore/SFSmartStore.h>
#import <SmartSync/SFSmartSyncSyncManager.h>
#import <SmartSync/SFSyncState.h>

// Private constants
NSString * const kSyncSoupNameArg = @"soupName";
NSString * const kSyncTargetArg = @"target";
NSString * const kSyncOptionsArg = @"options";
NSString * const kSyncIdArg = @"syncId";
NSString * const kSyncEventType = @"sync";
NSString * const kSyncDetail = @"detail";
NSString * const kSyncIsGlobalStoreArg = @"isGlobalStore";

@interface SFSmartSyncReactBridge ()

@property (nonatomic, strong) SFSmartSyncSyncManager *syncManager;
@property (nonatomic, strong) SFSmartSyncSyncManager *globalSyncManager;

@end

@implementation SFSmartSyncReactBridge

RCT_EXPORT_MODULE();

#pragma mark - Bridged methods

RCT_EXPORT_METHOD(getSyncStatus:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    NSNumber* syncId = (NSNumber*) [args nonNullObjectForKey:kSyncIdArg];
    BOOL isGlobal = [self isGlobal:args];
    [self log:SFLogLevelDebug format:@"getSyncStatus with sync id: %@", syncId];
    SFSyncState* sync = [[self getSyncManagerInst:isGlobal] getSyncStatus:syncId];
    callback(@[[NSNull null], [sync asDict]]);
}

RCT_EXPORT_METHOD(syncDown:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [args nonNullObjectForKey:kSyncSoupNameArg];
    SFSyncOptions *options = [SFSyncOptions newFromDict:[args nonNullObjectForKey:kSyncOptionsArg]];
    SFSyncDownTarget *target = [SFSyncDownTarget newFromDict:[args nonNullObjectForKey:kSyncTargetArg]];
    BOOL isGlobal = [self isGlobal:args];
    __weak SFSmartSyncReactBridge *weakSelf = self;
    SFSyncState* sync = [[self getSyncManagerInst:isGlobal]  syncDownWithTarget:target options:options soupName:soupName updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync isGlobal:isGlobal callback:callback];
    }];
    [self log:SFLogLevelDebug format:@"syncDown # %d to soup: %@", sync.syncId, soupName];
}

RCT_EXPORT_METHOD(reSync:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    NSNumber* syncId = (NSNumber*) [args nonNullObjectForKey:kSyncIdArg];
    BOOL isGlobal = [self isGlobal:args];
    [self log:SFLogLevelDebug format:@"reSync with sync id: %@", syncId];
    __weak SFSmartSyncReactBridge *weakSelf = self;
    [[self getSyncManagerInst:isGlobal] reSync:syncId updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync isGlobal:isGlobal callback:callback];
    }];
}

RCT_EXPORT_METHOD(cleanResyncGhosts:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    NSNumber* syncId = (NSNumber*) [args nonNullObjectForKey:kSyncIdArg];
    BOOL isGlobal = [self isGlobal:args];
    [self log:SFLogLevelDebug format:@"cleanResyncGhosts with sync id: %@", syncId];
    [[self getSyncManagerInst:isGlobal] cleanResyncGhosts:syncId completionStatusBlock:nil];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(syncUp:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [args nonNullObjectForKey:kSyncSoupNameArg];
    SFSyncOptions *options = [SFSyncOptions newFromDict:[args nonNullObjectForKey:kSyncOptionsArg]];
    SFSyncUpTarget *target = [SFSyncUpTarget newFromDict:[args nonNullObjectForKey:kSyncTargetArg]];
    BOOL isGlobal = [self isGlobal:args];
    __weak SFSmartSyncReactBridge *weakSelf = self;
    SFSyncState* sync = [[self getSyncManagerInst:isGlobal] syncUpWithTarget:target options:options soupName:soupName updateBlock:^(SFSyncState* sync) {
        [weakSelf handleSyncUpdate:sync isGlobal:isGlobal callback:callback];
    }];
    [self log:SFLogLevelDebug format:@"syncUp # %d from soup: %@", sync.syncId, soupName];
}

#pragma mark - Helper methods

- (SFSmartSyncSyncManager *)syncManager
{
    return [SFSmartSyncSyncManager sharedInstanceForStore:[SFSmartStore sharedStoreWithName:kDefaultSmartStoreName]];
}

- (SFSmartSyncSyncManager *)globalSyncManager
{
    return [SFSmartSyncSyncManager sharedInstanceForStore:[SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName]];
}

- (SFSmartSyncSyncManager *)getSyncManagerInst:(BOOL)isGlobal
{
    return isGlobal ? self.globalSyncManager : self.syncManager;
}

- (BOOL)isGlobal:(NSDictionary *)args
{
    return args[kSyncIsGlobalStoreArg] != nil && [args[kSyncIsGlobalStoreArg] boolValue];
}

- (void)handleSyncUpdate:(SFSyncState*)sync isGlobal:(BOOL)isGlobal callback:(RCTResponseSenderBlock)callback
{
    NSMutableDictionary* syncDict = [NSMutableDictionary dictionaryWithDictionary:[sync asDict]];
    syncDict[kSyncIsGlobalStoreArg] = isGlobal ? @YES : @NO;
    if (sync.status == SFSyncStateStatusDone) {
        callback(@[[NSNull null], syncDict]);
    } else if (sync.status == SFSyncStateStatusFailed) {
        callback(@[RCTMakeError(@"Sync failed", nil, nil), syncDict]);
    }
}

@end
