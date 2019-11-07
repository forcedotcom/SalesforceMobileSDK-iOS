/*
 SFMobileSyncSyncManager+Instrumentation.m
 SalesforceSDKCore
 Created by Raj Rao on 3/21/19.
 
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFMobileSyncSyncManager+Instrumentation.h"
#import <objc/runtime.h>
#import <os/log.h>
#import <os/signpost.h>
#import <SalesforceSDKCore/SFSDKInstrumentationHelper.h>

@implementation SFMobileSyncSyncManager (Instrumentation)

+ (os_log_t)oslog {
    static os_log_t _logger;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        _logger = os_log_create([appName  cStringUsingEncoding:NSUTF8StringEncoding], [@"SFMobileSync" cStringUsingEncoding:NSUTF8StringEncoding]);
    });
    return _logger;
}


+ (void)load{
    if ([SFSDKInstrumentationHelper isEnabled]  && (self == SFMobileSyncSyncManager.self)) {
        [self enableInstrumentation];
    }
}

+ (void)enableInstrumentation {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(getSyncStatus:);
        SEL swizzledSelector = @selector(instr_getSyncStatus:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(getSyncStatusByName:);
        swizzledSelector = @selector(instr_getSyncStatusByName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(hasSyncWithName:);
        swizzledSelector = @selector(instr_hasSyncWithName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(deleteSyncById:);
        swizzledSelector = @selector(instr_deleteSyncById:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(deleteSyncByName:);
        swizzledSelector = @selector(instr_deleteSyncByName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(createSyncDown:options:soupName:syncName:);
        swizzledSelector = @selector(instr_createSyncDown:options:soupName:syncName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(syncDownWithTarget:soupName:updateBlock:);
        swizzledSelector = @selector(instr_syncDownWithTarget:soupName:updateBlock:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(syncDownWithTarget:options:soupName:syncName:updateBlock:error:);
        swizzledSelector = @selector(instr_syncDownWithTarget:options:soupName:syncName:updateBlock:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(reSync:updateBlock:error:);
        swizzledSelector = @selector(instr_reSync:updateBlock:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(reSyncByName:updateBlock:error:);
        swizzledSelector = @selector(instr_reSyncByName:updateBlock:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(createSyncUp:options:soupName:syncName:);
        swizzledSelector = @selector(instr_createSyncUp:options:soupName:syncName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(createSyncDown:options:soupName:syncName:);
        swizzledSelector = @selector(instr_createSyncDown:options:soupName:syncName:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(syncUpWithOptions:soupName:updateBlock:);
        swizzledSelector = @selector(instr_syncUpWithOptions:soupName:updateBlock:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(syncUpWithTarget:options:soupName:updateBlock:);
        swizzledSelector = @selector(instr_syncUpWithTarget:options:soupName:updateBlock:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(syncUpWithTarget:options:soupName:syncName:updateBlock:error:);
        swizzledSelector = @selector(instr_syncUpWithTarget:options:soupName:syncName:updateBlock:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(cleanResyncGhosts:completionStatusBlock:error:);
        swizzledSelector = @selector(instr_cleanResyncGhosts:completionStatusBlock:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
    });
}
                      
- (SFSyncState*)instr_getSyncStatus:(NSNumber*)syncId {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "getSyncStatus", "storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
    SFSyncState *result = [self instr_getSyncStatus:syncId];
    sf_os_signpost_interval_end(logger, sid, "getSyncStatus", "storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
    return  result;
}

- (SFSyncState*)instr_getSyncStatusByName:(NSString*)syncName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "getSyncStatusByName", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
    SFSyncState *result = [self instr_getSyncStatusByName:syncName];
    sf_os_signpost_interval_end(logger, sid, "getSyncStatusByName", "storeName:%{public}@  syncName:%{public}@", self.store.storeName, syncName);
    return  result;
}

- (BOOL)instr_hasSyncWithName:(NSString*)syncName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "hasSyncWithName", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
    BOOL result = [self instr_hasSyncWithName:syncName];
    sf_os_signpost_interval_end(logger, sid, "hasSyncWithName", "storeName:%{public}@  syncName:%{public}@", self.store.storeName, syncName);
    return  result;
}

- (void)instr_deleteSyncById:(NSNumber*)syncId {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "deleteSyncById", "storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
    [self instr_deleteSyncById:syncId];
    sf_os_signpost_interval_end(logger, sid, "deleteSyncById", "storeName:%{public}@  syncId:%@", self.store.storeName, syncId);
}

- (void)instr_deleteSyncByName:(NSString*)syncName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "deleteSyncByName", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
   [self instr_deleteSyncByName:syncName];
    sf_os_signpost_interval_end(logger, sid, "deleteSyncByName", "storeName:%{public}@  syncName:%{public}@", self.store.storeName, syncName);
}

- (SFSyncState *)instr_createSyncDown:(SFSyncDownTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "deleteSyncByName", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
    SFSyncState *result = [self instr_createSyncDown:target options:options soupName:soupName syncName:syncName];
    sf_os_signpost_interval_end(logger, sid, "deleteSyncByName", "storeName:%{public}@  syncName:%{public}@", self.store.storeName, syncName);
    return  result;
}

- (SFSyncState*)instr_syncDownWithTarget:(SFSyncDownTarget*)target soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncDownWithTarget:soupName:updateBlock", "storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    
    SFSyncState *result = [self instr_syncDownWithTarget:target soupName:soupName updateBlock:^(SFSyncState * _Nonnull sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:soupName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:soupName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    }];
    return  result;
}

- (SFSyncState*)instr_syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncDownWithTarget:options:soupName:soupName:updateBlock", "storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    SFSyncState *result = [self instr_syncDownWithTarget:target options:options soupName:soupName updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:options:soupName:soupName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:options:soupName:soupName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        }
        if (updateBlock) {
          updateBlock(sync);
        }
    } error:error];
    return  result;
}

- (SFSyncState*)instr_syncDownWithTarget:(SFSyncDownTarget*)target options:(SFSyncOptions*)options soupName:(NSString*)soupName syncName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncDownWithTarget:options:soupName:soupName:syncName:updateBlock", "storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    SFSyncState *result = [self instr_syncDownWithTarget:target options:options soupName:soupName syncName:syncName updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:options:soupName:syncName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncDownWithTarget:options:soupName:syncName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    } error:error];
    return  result;
}

- (SFSyncState*)instr_reSync:(NSNumber*)syncId updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "reSync:updateBlock", "storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
    SFSyncState *result = [self instr_reSync:syncId updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "reSync:updateBlock", "success storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "reSync:updateBlock", "failed storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    } error:error];
    return  result;
}

- (SFSyncState*)instr_reSyncByName:(NSString*)syncName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "reSyncByName:updateBlock", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
    SFSyncState *result = [self instr_reSyncByName:syncName updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "reSyncByName:updateBlock", "success storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "reSyncByName:updateBlock", "failed storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    } error:error];
    return  result;
}

- (SFSyncState *)instr_createSyncUp:(SFSyncUpTarget *)target options:(SFSyncOptions *)options soupName:(NSString *)soupName syncName:(NSString *)syncName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "createSyncUp:options:soupName:syncName:updateBlock", "storeName:%{public}@ syncName:%{public}@", self.store.storeName, syncName);
    SFSyncState *result = [self instr_createSyncUp:target options:options soupName:soupName syncName:syncName];
     sf_os_signpost_interval_end(logger, sid, "createSyncUp:options:soupName:syncName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    return  result;
}

- (SFSyncState*)instr_syncUpWithOptions:(SFSyncOptions*)options soupName:(NSString*)soupName updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncUpWithOptions:soupName:updateBlock", "storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    SFSyncState *result = [self instr_syncUpWithOptions:options soupName:soupName  updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithOptions:soupName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithOptions:soupName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    }];
    return  result;
}

- (SFSyncState*)instr_syncUpWithTarget:(SFSyncUpTarget*)target options:(SFSyncOptions*)options
                      soupName:(NSString*)soupName
                      updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncUpWithTarget:options:soupName:updateBlock", "storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
    SFSyncState *result = [self instr_syncUpWithTarget:target options:options soupName:soupName  updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithTarget:options:soupName:updateBlock", "success storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithTarget:options:soupName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@", self.store.storeName, soupName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    }];
    return  result;
    
}

- (SFSyncState*)instr_syncUpWithTarget:(SFSyncUpTarget*)target
                               options:(SFSyncOptions*)options
                              soupName:(NSString*)soupName
                              syncName:(NSString*)syncName
                           updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                 error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "syncUpWithTarget:options:soupName:syncName:updateBlock", "storeName:%{public}@ soupName:%{public}@ syncName:%{public}@", self.store.storeName, soupName,syncName);
    SFSyncState *result = [self instr_syncUpWithTarget:target options:options soupName:soupName  syncName:syncName updateBlock:^(SFSyncState *sync) {
        if ([sync isDone]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithTarget:options:soupName:syncName:updateBlock", "success storeName:%{public}@ soupName:%{public}@ syncName:%{public}@", self.store.storeName, soupName, syncName);
        } else if ([sync hasFailed]) {
            sf_os_signpost_interval_end(logger, sid, "syncUpWithTarget:options:soupName:syncName:updateBlock", "failed storeName:%{public}@ soupName:%{public}@ syncName:%{public}@", self.store.storeName, soupName, syncName);
        }
        if (updateBlock) {
            updateBlock(sync);
        }
    } error:error];
    return  result;
}

- (BOOL)instr_cleanResyncGhosts:(NSNumber*)syncId completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock
                          error:(NSError**)error {
    
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "cleanResyncGhosts:completionStatusBlock", "storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
    BOOL result = [self instr_cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus, NSUInteger numRecords) {
        if (syncStatus==SFSyncStateStatusDone) {
            sf_os_signpost_interval_end(logger, sid, "cleanResyncGhosts:completionStatusBlock", "success storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
        } else if (syncStatus==SFSyncStateStatusFailed) {
            sf_os_signpost_interval_end(logger, sid, "cleanResyncGhosts:completionStatusBlock", "failed storeName:%{public}@ syncId:%@", self.store.storeName, syncId);
        }
        if (completionStatusBlock) {
            completionStatusBlock(syncStatus,numRecords);
        }
    } error:error];
    return result;
}

@end
