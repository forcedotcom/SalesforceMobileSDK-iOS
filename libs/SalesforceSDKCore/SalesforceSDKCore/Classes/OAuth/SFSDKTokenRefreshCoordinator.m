/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKTokenRefreshCoordinator.h"
#import "SalesforceSDKConstants.h"
SFSDK_USE_DEPRECATED_BEGIN
#import "SFOAuthSessionRefresher.h"
SFSDK_USE_DEPRECATED_END
#import "SFOAuthCredentials.h"
#import "SFApplicationHelper.h"
#import "SFSDKCoreLogger.h"

/**
 * Private container for an in-flight refresh operation, holding the refresher
 * instance and all waiting callbacks.
 */
@interface SFSDKTokenRefreshEntry : NSObject
@property (nonatomic, strong) SFOAuthSessionRefresher *refresher;
@property (nonatomic, strong) NSMutableArray<void (^)(SFOAuthCredentials *)> *completionBlocks;
@property (nonatomic, strong) NSMutableArray<void (^)(NSError *)> *errorBlocks;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskId;
@end

@implementation SFSDKTokenRefreshEntry
- (instancetype)init {
    self = [super init];
    if (self) {
        _completionBlocks = [NSMutableArray new];
        _errorBlocks = [NSMutableArray new];
        _backgroundTaskId = UIBackgroundTaskInvalid;
    }
    return self;
}
@end

@interface SFSDKTokenRefreshCoordinator ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, SFSDKTokenRefreshEntry *> *activeRefreshes;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end

@implementation SFSDKTokenRefreshCoordinator

#pragma mark - Singleton

+ (SFSDKTokenRefreshCoordinator *)sharedInstance {
    static SFSDKTokenRefreshCoordinator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SFSDKTokenRefreshCoordinator alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeRefreshes = [NSMutableDictionary new];
        _serialQueue = dispatch_queue_create("com.salesforce.mobilesdk.tokenRefreshCoordinator", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public API

- (void)refreshSessionForCredentials:(SFOAuthCredentials *)credentials
                          completion:(void (^)(SFOAuthCredentials *))completionBlock
                               error:(void (^)(NSError *))errorBlock {
    NSString *key = credentials.identifier;
    if (!key) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot refresh credentials with nil identifier."];
        if (errorBlock) {
            NSError *err = [NSError errorWithDomain:@"SFSDKTokenRefreshCoordinator"
                                              code:-1
                                          userInfo:@{NSLocalizedDescriptionKey: @"Credentials identifier is nil"}];
            errorBlock(err);
        }
        return;
    }

    dispatch_async(self.serialQueue, ^{
        SFSDKTokenRefreshEntry *entry = self.activeRefreshes[key];
        BOOL alreadyInFlight = (entry != nil);

        if (!entry) {
            entry = [[SFSDKTokenRefreshEntry alloc] init];
        }

        // Append callbacks — same path whether coalescing or starting fresh
        if (completionBlock) {
            [entry.completionBlocks addObject:[completionBlock copy]];
        }
        if (errorBlock) {
            [entry.errorBlocks addObject:[errorBlock copy]];
        }

        if (alreadyInFlight) {
            [SFSDKCoreLogger d:[self class] format:@"Refresh already in-flight for credential %@. Coalescing request.", key];
            return;
        }

        // Background task protection
        UIApplication *app = [SFApplicationHelper sharedApplication];
        if (app) {
            entry.backgroundTaskId = [app beginBackgroundTaskWithName:@"SFSDKTokenRefresh"
                                                   expirationHandler:^{
                [self handleBackgroundExpirationForKey:key];
            }];
        }

        // TODO: Remove deprecated warning suppression when SFOAuthSessionRefresher is internal in Mobile SDK 15.0
        SFSDK_USE_DEPRECATED_BEGIN
        // Create refresher (via factory for testability, or standard instance)
        entry.refresher = self.refresherFactory
            ? self.refresherFactory(credentials)
            : [[SFOAuthSessionRefresher alloc] initWithCredentials:credentials];

        self.activeRefreshes[key] = entry;

        [SFSDKCoreLogger i:[self class] format:@"Starting token refresh for credential %@.", key];

        [entry.refresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
            dispatch_async(self.serialQueue, ^{
                [self completeRefreshForKey:key credentials:updatedCredentials error:nil];
            });
        } error:^(NSError *refreshError) {
            dispatch_async(self.serialQueue, ^{
                [self completeRefreshForKey:key credentials:nil error:refreshError];
            });
        }];
        SFSDK_USE_DEPRECATED_END
    });
}

#pragma mark - Private

- (void)completeRefreshForKey:(NSString *)key
                  credentials:(SFOAuthCredentials * _Nullable)credentials
                        error:(NSError * _Nullable)error {
    SFSDKTokenRefreshEntry *entry = self.activeRefreshes[key];
    if (!entry) return; // Already handled (e.g., by background expiration)

    [self.activeRefreshes removeObjectForKey:key];

    // End background task
    if (entry.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication *app = [SFApplicationHelper sharedApplication];
        if (app) {
            [app endBackgroundTask:entry.backgroundTaskId];
        }
        entry.backgroundTaskId = UIBackgroundTaskInvalid;
    }

    // Dispatch callbacks on the main queue as documented in the header.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            [SFSDKCoreLogger e:[self class] format:@"Token refresh failed for credential %@. Notifying %lu waiter(s). Error: %@",
             key, (unsigned long)entry.errorBlocks.count, error];
            for (void (^errorBlock)(NSError *) in entry.errorBlocks) {
                errorBlock(error);
            }
        } else {
            [SFSDKCoreLogger i:[self class] format:@"Token refresh succeeded for credential %@. Notifying %lu waiter(s).",
             key, (unsigned long)entry.completionBlocks.count];
            for (void (^completionBlock)(SFOAuthCredentials *) in entry.completionBlocks) {
                completionBlock(credentials);
            }
        }
    });
}

- (void)handleBackgroundExpirationForKey:(NSString *)key {
    dispatch_async(self.serialQueue, ^{
        SFSDKTokenRefreshEntry *entry = self.activeRefreshes[key];
        if (!entry) return;

        [SFSDKCoreLogger w:[self class] format:@"Background task expired during token refresh for credential %@. Delivering cancellation error.", key];

        NSError *bgError = [NSError errorWithDomain:@"SFSDKTokenRefreshCoordinator"
                                               code:-2
                                           userInfo:@{NSLocalizedDescriptionKey: @"Token refresh interrupted: app background time expired"}];
        [self completeRefreshForKey:key credentials:nil error:bgError];
    });
}

@end
