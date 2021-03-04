/*
 SFPicklistSyncManager.m
 MobileSync
 
 Created by Keith Siilats on 4/28/2020.
 
 Copyright (c) 2018-present, bytelogics.com, inc. All rights reserved.
 
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

#import "SFPicklistSyncManager.h"
#import "SFPicklistSyncDownTarget.h"
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>

static NSString * const kSoupName = @"sfdcPicklists";
static NSString * const kSFAppFeaturePicklistSync = @"PL";
static NSString * const kQuery = @"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@-%@-%@-%@-%@'";

@interface SFPicklistSyncManager ()

@property (nonatomic, strong, readwrite) SFSmartStore *smartStore;
@property (nonatomic, strong, readwrite) SFMobileSyncSyncManager *syncManager;

@end

@implementation SFPicklistSyncManager

static NSMutableDictionary *syncMgrList = nil;
static NSArray<SFSoupIndex *> *indexSpecs = nil;

+ (instancetype)sharedInstance {
    return [SFPicklistSyncManager sharedInstance:nil];
}

+ (instancetype)sharedInstance:(SFUserAccount *)user {
    return [SFPicklistSyncManager sharedInstance:user smartStore:nil];
}

+ (instancetype)sharedInstance:(SFUserAccount *)user smartStore:(NSString *)smartStore {
    if (!user) {
        user = [SFUserAccountManager sharedInstance].currentUser;
    }
    SFMobileSyncSyncManager *syncManager = [SFMobileSyncSyncManager sharedInstanceForUser:user storeName:smartStore];
    @synchronized ([SFPicklistSyncManager class]) {
        NSString *keyPrefix = user == nil ? SFKeyForUserAndScope(nil, SFUserAccountScopeGlobal) : SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
        NSString *key = [NSString stringWithFormat:@"%@-%@", keyPrefix, syncManager.store.storeName];
        id syncMgr = [syncMgrList objectForKey:key];
        if (syncMgr == nil) {
            syncMgr = [[self alloc] init:syncManager];
            syncMgrList[key] = syncMgr;
        }
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeaturePicklistSync];
        return syncMgr;
    }
}

+ (void)reset {
    @synchronized (([SFPicklistSyncManager class])) {
        [syncMgrList removeAllObjects];
    }
}

+ (void)reset:(SFUserAccount *)user {
    @synchronized([SFPicklistSyncManager class]) {
        if (user) {
            NSString *matchingKey = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            NSArray<NSString *> *keys = syncMgrList.allKeys;
            for (NSString *key in keys) {
                if ([key hasPrefix:matchingKey]) {
                    [syncMgrList removeObjectForKey:key];
                }
            }
        }
    }
}

+ (void)initialize {
    if (self == [SFPicklistSyncManager class]) {
        syncMgrList = [NSMutableDictionary new];
        indexSpecs = [NSArray arrayWithObjects:[[SFSoupIndex alloc] initWithPath:@"Id" indexType:kSoupIndexTypeJSON1 columnName:@"Id"], nil];
    }
}

- (void)fetchPicklistForObject:(NSString *)objectType
                  layoutType:(NSString *)layoutType
                        mode:(SFSDKFetchMode)mode
             completionBlock:(SFPicklistSyncCompletionBlock)completionBlock {
    [self fetchPicklistForObjectAPIName:objectType formFactor:nil layoutType:layoutType mode:nil recordTypeId:nil syncMode:mode completionBlock:completionBlock];
}

- (void)fetchPicklistForObjectAPIName:(NSString *)objectAPIName
                         formFactor:(NSString *)formFactor
                         layoutType:(NSString *)layoutType
                               mode:(NSString *)mode
                       recordTypeId:(NSString *)recordTypeId
                           syncMode:(SFSDKFetchMode)syncMode
                    completionBlock:(SFPicklistSyncCompletionBlock)completionBlock {
    switch (syncMode) {
        case SFSDKFetchModeCacheOnly:
            [self fetchFromCache:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId completionBlock:completionBlock fallbackOnServer:NO];
            break;
        case SFSDKFetchModeCacheFirst:
            [self fetchFromCache:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId completionBlock:completionBlock fallbackOnServer:YES];
            break;
        case SFSDKFetchModeServerFirst:
            [self fetchFromServer:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId completionBlock:completionBlock];
            break;
    }
}

- (instancetype)init:(SFMobileSyncSyncManager *)syncManager {
    self = [super init];
    if (self) {
        self.syncManager = syncManager;
        self.smartStore = syncManager.store;
        [self initializeSoup];
    }
    return self;
}

- (void)fetchFromServer:(NSString *)objectAPIName
             formFactor:(NSString *)formFactor
             layoutType:(NSString *)layoutType
                   mode:(NSString *)mode
           recordTypeId:(NSString *)recordTypeId
        completionBlock:(SFPicklistSyncCompletionBlock)completionBlock {
    SFPicklistSyncDownTarget *target = [SFPicklistSyncDownTarget newSyncTarget:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId];
    __weak typeof (self) weakSelf = self;
    [self.syncManager syncDownWithTarget:target soupName:kSoupName updateBlock:^(SFSyncState *sync) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if (sync.status == SFSyncStateStatusDone) {
            [strongSelf fetchFromCache:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId completionBlock:completionBlock fallbackOnServer:NO];
        }
    }];
}

- (void)fetchFromCache:(NSString *)objectAPIName
            formFactor:(NSString *)formFactor
            layoutType:(NSString *)layoutType
                  mode:(NSString *)mode
          recordTypeId:(NSString *)recordTypeId
       completionBlock:(SFPicklistSyncCompletionBlock)completionBlock
      fallbackOnServer:(BOOL)fallbackOnServer {
    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:[NSString stringWithFormat:kQuery, kSoupName, kSoupName, kSoupName, objectAPIName, formFactor, layoutType, mode, recordTypeId] withPageSize:1];
    NSArray *results = [self.smartStore queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    if (!results || results.count == 0) {
        if (fallbackOnServer) {
            [self fetchFromServer:objectAPIName formFactor:formFactor layoutType:layoutType mode:mode recordTypeId:recordTypeId completionBlock:completionBlock];
        } else {
            completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil);
        }
    } else {
        completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, [SFPicklist fromJSON:results[0][0]]);
    }
}

- (void)initializeSoup {
    if (![self.smartStore soupExists:kSoupName]) {
        [self.smartStore registerSoup:kSoupName withIndexSpecs:indexSpecs error:nil];
    }
}

@end
