/*
 SalesforceAnalyticsManager.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/16/16.
 
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

#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import "SFSDKSalesforceAnalyticsManager+Internal.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import "SFDirectoryManager.h"
#import "SFSDKCryptoUtils.h"
#import "SFSDKAILTNPublisher.h"
#import "UIDevice+SFHardware.h"
#import "SFIdentityData.h"
#import "SFApplicationHelper.h"
#import <SalesforceAnalytics/SFSDKAILTNTransform.h>
#import <SalesforceAnalytics/SFSDKDeviceAppAttributes.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKAppConfig.h"

static NSString * const kAnalyticsUnauthenticatedManagerKey = @"-unauthenticated-";
static NSString * const kEventStoresDirectory = @"event_stores";
static NSString * const kEventStoreEncryptionKeyLabel = @"com.salesforce.eventStore.encryptionKey";
static NSString * const kAnalyticsOnOffKey = @"ailtn_enabled";
static NSString * const kSFAppFeatureAiltnEnabled = @"AI";
static NSString * const kEventStoreGCMEncryptedKey = @"com.salesforce.eventStore.encryption.GCM";

static NSMutableDictionary *analyticsManagerList = nil;

static SInt32 kBatchProcessCount = 100;

@implementation SFSDKSalesforceAnalyticsManager

+ (void)initialize {
    if (self == [SFSDKSalesforceAnalyticsManager class] && analyticsManagerList == nil) {
        analyticsManagerList = [[NSMutableDictionary alloc] init];
    }
}


+ (instancetype) sharedInstanceWithUser:(SFUserAccount *) userAccount {
    @synchronized ([SFSDKSalesforceAnalyticsManager class]) {
        if (!userAccount) {
            userAccount = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!userAccount) {
            return nil;
        }
        NSString *key = SFKeyForUserAndScope(userAccount, SFUserAccountScopeCommunity);
        if (!key) {
            return nil;
        }
        id analyticsMgr = analyticsManagerList[key];
        if (!analyticsMgr) {
            if (userAccount.loginState != SFUserAccountLoginStateLoggedIn) {
                [SFSDKCoreLogger w:[self class] format:@"%@ A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a SFSDKSalesforceAnalyticsManager instance for a user.", NSStringFromSelector(_cmd)];
                return nil;
            }
            analyticsMgr = [[self alloc] initWithUser:userAccount];
            if (analyticsMgr) {
                analyticsManagerList[key] = analyticsMgr;
            } else {
                [SFSDKCoreLogger w:[self class] format:@"%@ Unable to create a SFSDKSalesforceAnalyticsManager instance for a user.", NSStringFromSelector(_cmd)];
                return nil;
            }
        }
        return analyticsMgr;
    }
}

+ (instancetype)sharedUnauthenticatedInstance {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        if (analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] == nil) {
            analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] = [[self alloc] init];
        }
    });
    return analyticsManagerList[kAnalyticsUnauthenticatedManagerKey];
}

+ (void) removeSharedInstanceWithUser:(SFUserAccount *) userAccount {
    @synchronized ([SFSDKSalesforceAnalyticsManager class]) {
        if (!userAccount) {
            userAccount = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!userAccount) {
            return;
        }
        
        NSString *userKey = SFKeyForUserAndScope(userAccount, SFUserAccountScopeUser);
        // Remove all sub-instances (community users) for this user as well
        NSArray *keys = analyticsManagerList.allKeys;
        if(userKey) {
            for( NSString *key in keys) {
                if([key hasPrefix:userKey]) {
                    [analyticsManagerList removeObjectForKey:key];
                }
            }
        }
    }
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    return [self initWithUser:nil];
}

- (instancetype) initWithUser:(SFUserAccount *) userAccount {
    self = [super init];
    if (self) {
        _userAccount = userAccount;
        SFSDKDeviceAppAttributes *deviceAttributes = [[self class] getDeviceAppAttributes];
        
        NSString *rootStoreDir;
        if (_userAccount != nil) {
            rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:userAccount type:NSDocumentDirectory components:@[ kEventStoresDirectory ]];
        } else {
            rootStoreDir = [[SFDirectoryManager sharedManager] globalDirectoryOfType:NSDocumentDirectory components:@[ kEventStoresDirectory ]];
        }
        
        if (!rootStoreDir) {
            [SFSDKCoreLogger e:[self class] format:@"Root directory path is nil"];
            return nil;
        }

        NSError *error = nil;
        NSData *encryptionKey = [SFSDKKeyGenerator encryptionKeyFor:kEventStoreEncryptionKeyLabel error:&error];
        if (error) {
            [SFSDKCoreLogger e:[self class] format:@"Error getting encryption key: %@", error.localizedDescription];
        }

        DataEncryptorBlock dataEncryptorBlock = ^NSData*(NSData *data) {
            NSError *error = nil;
            NSData *encryptedData = [SFSDKEncryptor encryptData:data key:encryptionKey error:&error];
            if (error) {
                [SFSDKCoreLogger e:[self class] format:@"Error encrypting data: %@", error.localizedDescription];
            }
            return encryptedData;
        };
        DataDecryptorBlock dataDecryptorBlock = ^NSData*(NSData *data) {
            NSError *error = nil;
            NSData *decryptedData = [SFSDKEncryptor decryptData:data key:encryptionKey error:&error];
            if (error) {
                [SFSDKCoreLogger e:[self class] format:@"Error decrypting data: %@", error.localizedDescription];
            }
            return decryptedData;
        };
        _analyticsManager = [[SFSDKAnalyticsManager alloc] initWithStoreDirectory:rootStoreDir dataEncryptorBlock:dataEncryptorBlock dataDecryptorBlock:dataDecryptorBlock deviceAttributes:deviceAttributes];
        _eventStoreManager = self.analyticsManager.storeManager;
        _remotes = [[NSMutableArray alloc] init];
        _task = UIBackgroundTaskInvalid;
        // There's no standard for unauthenticated instrumentation publishing, currently.  Consumers
        // should explicitly specify their own.
        if (_userAccount != nil) {
            SFSDKAnalyticsTransformPublisherPair *tpp = [[SFSDKAnalyticsTransformPublisherPair alloc] initWithTransform:[[SFSDKAILTNTransform alloc] init] publisher:[[SFSDKAILTNPublisher alloc] init]];
            [_remotes addObject:tpp];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publishOnAppBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        // Only work with auth-based notifications for an authenticated context.
        if (userAccount != nil) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserWillLogout:)  name:kSFNotificationUserWillLogout object:nil];
        }
    }
    return self;
}

- (void) setLoggingEnabled:(BOOL) loggingEnabled {
    if (loggingEnabled) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAiltnEnabled];
    } else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAiltnEnabled];
    }
    [self storeAnalyticsPolicy:loggingEnabled];
    self.eventStoreManager.loggingEnabled = loggingEnabled;
}

- (BOOL)isLoggingEnabled {
    return [self readAnalyticsPolicy];
}

- (void) updateLoggingPrefs {
    NSDictionary *customAttributes = self.userAccount.idData.customAttributes;
    if (customAttributes) {
        NSString *enabled = customAttributes[kAnalyticsOnOffKey];
        if (enabled == nil) {
            self.loggingEnabled = YES;
        } else {
            self.loggingEnabled = [enabled boolValue];
        }
    }
}

- (void) publishAllEvents {
    @synchronized (self) {
        dispatch_group_t publishEventsGroup = dispatch_group_create();

        if (self.batchingEnabled == NO) {
            NSArray<SFSDKInstrumentationEvent *> *events = [self.eventStoreManager fetchAllEvents];
            [self publishEvents:events dispatchGroup:publishEventsGroup];
        } else {
            NSArray *eventFiles = [self.eventStoreManager eventFiles];
            SInt32 i = 0;
            NSUInteger remainingEvents = eventFiles.count;
            
            while (i < eventFiles.count) {
                NSArray *subEvents = [eventFiles subarrayWithRange:NSMakeRange(i, MIN(kBatchProcessCount, remainingEvents))];
                //MIN() used because array must be larger than or equal to range size, else exception will be thrown
                
                // batch process and use autorelease pool to best manage memory usage in processsing events
                @autoreleasepool {
                    NSMutableArray * eventsArray = [NSMutableArray arrayWithCapacity:kBatchProcessCount];
                    for (SInt32 subCount = 0; subCount < subEvents.count; subCount++) {
                        
                        NSString *eventFile = subEvents[subCount];
                        [eventsArray addObject:[self.eventStoreManager fetchEvent:eventFile]];
                    }
                    [self publishEvents:eventsArray dispatchGroup:publishEventsGroup];
                    i += subEvents.count;
                    remainingEvents = remainingEvents - subEvents.count;
                }
                
            }
        }
        
        dispatch_group_notify(publishEventsGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [self cleanupBackgroundTask];
        });
    }
}

- (void) publishEvents:(NSArray<SFSDKInstrumentationEvent *> *) events {
    [self publishEvents:events dispatchGroup:nil];
}

- (void) publishEvents:(NSArray<SFSDKInstrumentationEvent *> *) events dispatchGroup:(nullable dispatch_group_t) dispatchGroup {
    if (events.count == 0 || self.remotes.count == 0) {
        return;
    }
    @synchronized (self) {
        
        if (dispatchGroup != nil) {
            dispatch_group_enter(dispatchGroup);
        }
        
        NSMutableArray<NSString *> *eventIds = [[NSMutableArray alloc] init];
        for (SFSDKInstrumentationEvent *event in events) {
            [eventIds addObject:event.eventId];
        }
        __block BOOL overallSuccess = YES;
        __block BOOL overallCompletionStatus = NO;
        NSMutableArray<SFSDKAnalyticsTransformPublisherPair *> *remoteKeySet = [self.remotes mutableCopy];
        __block SFSDKAnalyticsTransformPublisherPair *currentTpp = remoteKeySet[0];
        PublishCompleteBlock __block publishCompleteBlock = ^void(BOOL success, NSError *error) {

            /*
             * Updates the success flag only if all previous requests have been
             * successful. This ensures that the operation is marked success only
             * if all publishers are successful.
             */
            if (overallSuccess) {
                overallSuccess = success;
            }

            // Removes current transform from the list since it's done.
            if (remoteKeySet) {
                [remoteKeySet removeObject:currentTpp];
            }

            // If there are no transforms left, we're done here.
            if (remoteKeySet.count == 0) {
                overallCompletionStatus = YES;
            }
            if (!overallCompletionStatus) {
                currentTpp = remoteKeySet[0];
                [self applyTransformAndPublish:currentTpp events:events publishCompleteBlock:publishCompleteBlock];
            } else {

                /*
                 * Deletes events from the event store if the network publishing was successful.
                 */
                if (overallSuccess) {
                    [self.eventStoreManager deleteEvents:eventIds];
                }
                publishCompleteBlock = nil;
            }
            
            if (dispatchGroup != nil) {
                dispatch_group_leave(dispatchGroup);
            }
        };
        [self applyTransformAndPublish:currentTpp events:events publishCompleteBlock:publishCompleteBlock];
    }
}

- (void) publishEvent:(SFSDKInstrumentationEvent *) event {
    if (!event) {
        return;
    }
    @synchronized (self) {
        NSMutableArray<SFSDKInstrumentationEvent *> *events = [[NSMutableArray alloc] init];
        [events addObject:event];
        [self publishEvents:events];
    }
}

- (void) addRemotePublisher:(id<SFSDKTransform>) transformer publisher:(id<SFSDKAnalyticsPublisher>) publisher {
    if (!transformer || !publisher) {
        [SFSDKCoreLogger w:[self class] format:@"Invalid transformer and/or publisher"];
        return;
    }
    SFSDKAnalyticsTransformPublisherPair *tpp = [[SFSDKAnalyticsTransformPublisherPair alloc] initWithTransform:transformer publisher:publisher];
    [self.remotes addObject:tpp];
}

+ (SFSDKDeviceAppAttributes *) getDeviceAppAttributes {
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    NSString *prodAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
    NSString *appVersion = [NSString stringWithFormat:@"%@(%@)", prodAppVersion, buildNumber];
    NSString *appName = [SalesforceSDKManager ailtnAppName];
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *osVersion = [curDevice systemVersion];
    NSString *osName = [curDevice systemName];
    NSString *appTypeStr = [sdkManager getAppTypeAsString];
    NSString *mobileSdkVersion = SALESFORCE_SDK_VERSION;
    NSString *deviceModel = [curDevice sfsdk_platform];
    NSString *deviceId = [sdkManager deviceId];
    NSString *clientId = sdkManager.appConfig.remoteAccessConsumerKey;
    return [[SFSDKDeviceAppAttributes alloc] initWithAppVersion:appVersion appName:appName osVersion:osVersion osName:osName nativeAppType:appTypeStr mobileSdkVersion:mobileSdkVersion deviceModel:deviceModel deviceId:deviceId clientId:clientId];
}

- (void) storeAnalyticsPolicy:(BOOL) enabled {
    @synchronized (self) {
        NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
        [defs setBool:enabled forKey:kAnalyticsOnOffKey];
        [defs synchronize];
    }
}

- (BOOL) readAnalyticsPolicy {
    BOOL analyticsEnabled;
    NSNumber *analyticsEnabledNum = [[NSUserDefaults msdkUserDefaults] objectForKey:kAnalyticsOnOffKey];
    if (analyticsEnabledNum == nil) {
        // Default is Enabled.
        analyticsEnabled = YES;
        [self storeAnalyticsPolicy:analyticsEnabled];
    } else {
        analyticsEnabled = [analyticsEnabledNum boolValue];
    }
    return analyticsEnabled;
}

- (void) publishOnAppBackground {

    // Publishing should only happen for the current user, not for all users signed in.
    if (![self.userAccount.accountIdentity isEqual:[SFUserAccountManager sharedInstance].currentUser.accountIdentity]) {
        return;
    }
    // Avoid re-entrance if task is active
    if (self.task == UIBackgroundTaskInvalid) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __block typeof(self) weakSelf = self;
            weakSelf.task = [[SFApplicationHelper sharedApplication] beginBackgroundTaskWithName:NSStringFromClass([self class]) expirationHandler:^{
                [weakSelf cleanupBackgroundTask];
            }];
            [self publishAllEvents];
        });
    }
}

- (void) applyTransformAndPublish:(SFSDKAnalyticsTransformPublisherPair *)tpp events:(NSArray<SFSDKInstrumentationEvent *> *) events publishCompleteBlock:(PublishCompleteBlock) publishCompleteBlock {
    if (tpp) {
        NSMutableArray *eventsArray = [[NSMutableArray alloc] init];
        for (SFSDKInstrumentationEvent *event in events) {
            @autoreleasepool {
                id transformedEvent = [tpp.transform transform:event];
                if (transformedEvent != nil) {
                    [eventsArray addObject:transformedEvent];
                }
            }
        }

        id<SFSDKAnalyticsPublisher> networkPublisher = tpp.publisher;
        if (networkPublisher) {
            [networkPublisher publish:eventsArray user:self.userAccount publishCompleteBlock:publishCompleteBlock];
        }
    }
}

#pragma mark - SFUserAccountManagerDelegate
- (void)handleUserWillLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
    [self handleLogoutForUser:user];
}

- (void)handleLogoutForUser:(SFUserAccount *)user {
    [self.analyticsManager reset];
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs removeObjectForKey:kAnalyticsOnOffKey];
    [[self class] removeSharedInstanceWithUser:user];
}

- (void) cleanupBackgroundTask {
    [[SFApplicationHelper sharedApplication] endBackgroundTask:self.task];
    self.task = UIBackgroundTaskInvalid;
}
@end

@implementation SFSDKAnalyticsTransformPublisherPair

- (instancetype)initWithTransform:(id<SFSDKTransform>)transform publisher:(id<SFSDKAnalyticsPublisher>)publisher {
    self = [super init];
    if (self) {
        _transform = transform;
        _publisher = publisher;
    }
    return self;
}

@end

