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

#import <SmartStore/SFSmartStore.h>
#import "SmartSyncSDKManager.h"
#import "SFSDKSyncsConfig.h"

@implementation SmartSyncSDKManager

- (void) setupGlobalSyncsFromDefaultConfig {
    NSString *configPath = [self pathForGlobalSyncsConfig];
    [SFSDKSmartSyncLogger d:[self class] format:@"Setting up global syncs using config found in %@", configPath];
    SFSDKSyncsConfig* syncsConfig = [[SFSDKSyncsConfig alloc] initWithResourceAtPath:configPath];
    if ([syncsConfig hasSyncs]) {
        [syncsConfig createSyncs:[SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName]];
    }
}

- (void) setupUserSyncsFromDefaultConfig {
    NSString *configPath = [self pathForUserSyncsConfig];
    [SFSDKSmartSyncLogger d:[self class] format:@"Setting up user syncs using config found in %@", configPath];
    SFSDKSyncsConfig* syncsConfig = [[SFSDKSyncsConfig alloc] initWithResourceAtPath:configPath];
    if ([syncsConfig hasSyncs]) {
        [syncsConfig createSyncs:[SFSmartStore sharedStoreWithName:kDefaultSmartStoreName]];
    }
}

- (NSString*) pathForGlobalSyncsConfig {
    return @"globalsyncs.json";
}

- (NSString*) pathForUserSyncsConfig {
    return @"usersyncs.json";
}



@end

