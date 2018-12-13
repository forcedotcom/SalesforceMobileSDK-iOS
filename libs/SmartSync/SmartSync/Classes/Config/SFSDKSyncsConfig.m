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


#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SmartStore/SmartStore.h>
#import "SFSDKSyncsConfig.h"
#import "SFSmartSyncSyncManager.h"

static NSString *const kSyncsConfigSyncs = @"syncs";
static NSString *const kSyncsConfigSyncName = @"syncName";
static NSString *const kSyncsConfigSyncType = @"syncType";
static NSString *const kSyncsConfigOptions = @"options";
static NSString *const kSyncsConfigSoupName = @"soupName";
static NSString *const kSyncsConfigTarget = @"target";

@interface SFSDKSyncsConfig ()

@property (nonatomic, nullable) NSArray* syncConfigs;

@end

@implementation SFSDKSyncsConfig

- (nullable id)initWithResourceAtPath:(NSString *)path {
    self = [super init];
    if (self) {
        NSDictionary *config = [SFSDKResourceUtils loadConfigFromFile:path];
        self.syncConfigs = config == nil ? nil : config[kSyncsConfigSyncs];
    }
    return self;
}

- (void)createSyncs:(SFSmartStore *)store {
    if (self.syncConfigs == nil) {
        [SFSDKSmartSyncLogger d:[self class] format:@"No store config available"];
        return;
    }

    SFSmartSyncSyncManager * syncManager = [SFSmartSyncSyncManager sharedInstanceForStore:store];

    for (NSDictionary * syncConfig in self.syncConfigs) {
        NSString *syncName = [syncConfig nonNullObjectForKey:kSyncsConfigSyncName];

        // Leaving sync alone if it already exists
        if ([syncManager hasSyncWithName:syncName]) {
            [SFSDKSmartSyncLogger d:[self class] format:@"Sync already exists:%@ - skipping", syncName];
            continue;
        }

        SFSyncStateSyncType syncType = [SFSyncState syncTypeFromString:syncConfig[kSyncsConfigSyncType]];
        SFSyncOptions * syncOptions = [SFSyncOptions newFromDict:syncConfig[kSyncsConfigOptions]];
        NSString* soupName = syncConfig[kSyncsConfigSoupName];
        [SFSDKSmartSyncLogger d:[self class] format:@"Creating sync: %@", syncName];

        switch (syncType) {
            case SFSyncStateSyncTypeDown:
                [syncManager createSyncDown:[SFSyncDownTarget newFromDict:syncConfig[kSyncsConfigTarget]] options:syncOptions soupName:soupName syncName:syncName];
                break;
            case SFSyncStateSyncTypeUp:
                [syncManager createSyncUp:[SFSyncUpTarget newFromDict:syncConfig[kSyncsConfigTarget]] options:syncOptions soupName:soupName syncName:syncName];
                break;
        }
    }
}

- (BOOL)hasSyncs {
    return self.syncConfigs != nil && self.syncConfigs.count > 0;
}

@end
