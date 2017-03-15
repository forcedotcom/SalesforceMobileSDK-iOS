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

#import "SFSDKSalesforceAnalyticsManager.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import "SFDirectoryManager.h"
#import "SFKeyStoreManager.h"
#import "SFSDKCryptoUtils.h"
#import "SFSDKAILTNPublisher.h"
#import "UIDevice+SFHardware.h"
#import "SFIdentityData.h"
#import "NSUserDefaults+SFAdditions.h"
#import "SFApplicationHelper.h"
#import <SalesforceAnalytics/SFSDKAILTNTransform.h>
#import <SalesforceAnalytics/SFSDKDeviceAppAttributes.h>

static NSString * const kEventStoresDirectory = @"event_stores";
static NSString * const kEventStoreEncryptionKeyLabel = @"com.salesforce.eventStore.encryptionKey";
static NSString * const kAnalyticsOnOffKey = @"ailtn_enabled";
static NSString * const kSFAppFeatureAiltnEnabled = @"AI";

static NSMutableDictionary *analyticsManagerList = nil;

@interface SFSDKAnalyticsTransformPublisherPair : NSObject

@property (nonnull, nonatomic, readonly, strong) id<SFSDKTransform> transform;
@property (nonnull, nonatomic, readonly, strong) id<SFSDKAnalyticsPublisher> publisher;

- (instancetype)initWithTransform:(id<SFSDKTransform>)transform publisher:(id<SFSDKAnalyticsPublisher>)publisher;

@end

@interface SFSDKSalesforceAnalyticsManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, readwrite, strong) SFSDKAnalyticsManager *analyticsManager;
@property (nonatomic, readwrite, strong) SFSDKEventStoreManager *eventStoreManager;
@property (nonatomic, readwrite, strong) SFUserAccount *userAccount;
@property (nonatomic, readwrite, strong) NSMutableArray<SFSDKAnalyticsTransformPublisherPair *> *remotes;

@end

@implementation SFSDKSalesforceAnalyticsManager

+ (instancetype) sharedInstanceWithUser:(SFUserAccount *) userAccount {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        analyticsManagerList = [[NSMutableDictionary alloc] init];
    });
    @synchronized ([SFSDKSalesforceAnalyticsManager class]) {
        if (!userAccount) {
            userAccount = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!userAccount) {
            return nil;
        }
        NSString *key = SFKeyForUserAndScope(userAccount, SFUserAccountScopeCommunity);
        id analyticsMgr = analyticsManagerList[key];
        if (!analyticsMgr) {
            analyticsMgr = [[SFSDKSalesforceAnalyticsManager alloc] initWithUser:userAccount];
            analyticsManagerList[key] = analyticsMgr;
        }
        return analyticsMgr;
    }
}

+ (void) removeSharedInstanceWithUser:(SFUserAccount *) userAccount {
    @synchronized ([SFSDKSalesforceAnalyticsManager class]) {
        if (!userAccount) {
            userAccount = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!userAccount) {
            return;
        }
        NSString *key = SFKeyForUserAndScope(userAccount, SFUserAccountScopeCommunity);
        [analyticsManagerList removeObjectForKey:key];
    }
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (instancetype) initWithUser:(SFUserAccount *) userAccount {
    self = [super init];
    if (self) {
        self.userAccount = userAccount;
        SFSDKDeviceAppAttributes *deviceAttributes = [self buildDeviceAppAttributes];
        NSString *rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:userAccount type:NSDocumentDirectory components:@[ kEventStoresDirectory ]];
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kEventStoreEncryptionKeyLabel keyType:SFKeyStoreKeyTypePasscode autoCreate:YES];
        DataEncryptorBlock dataEncryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256EncryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        DataDecryptorBlock dataDecryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256DecryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        self.analyticsManager = [[SFSDKAnalyticsManager alloc] initWithStoreDirectory:rootStoreDir dataEncryptorBlock:dataEncryptorBlock dataDecryptorBlock:dataDecryptorBlock deviceAttributes:deviceAttributes];
        self.eventStoreManager = self.analyticsManager.storeManager;
        self.remotes = [[NSMutableArray alloc] init];
        SFSDKAnalyticsTransformPublisherPair *tpp = [[SFSDKAnalyticsTransformPublisherPair alloc] initWithTransform:[[SFSDKAILTNTransform alloc] init] publisher:[[SFSDKAILTNPublisher alloc] init]];
        [self.remotes addObject:tpp];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publishOnAppBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void) setLoggingEnabled:(BOOL) loggingEnabled {
    if (loggingEnabled) {
        [[SalesforceSDKManager sharedManager] registerAppFeature:kSFAppFeatureAiltnEnabled];
    } else {
        [[SalesforceSDKManager sharedManager] unregisterAppFeature:kSFAppFeatureAiltnEnabled];
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
        NSArray<SFSDKInstrumentationEvent *> *events = [self.eventStoreManager fetchAllEvents];
        [self publishEvents:events];
    }
}

- (void) publishEvents:(NSArray<SFSDKInstrumentationEvent *> *) events {
    if (!events || events.count == 0) {
        return;
    }
    @synchronized (self) {
        NSMutableArray<NSString *> *eventIds = [[NSMutableArray alloc] init];
        for (SFSDKInstrumentationEvent *event in events) {
            [eventIds addObject:event.eventId];
        }
        __block BOOL overallSuccess = YES;
        __block BOOL overallCompletionStatus = NO;
        NSMutableArray<SFSDKAnalyticsTransformPublisherPair *> *remoteKeySet = [self.remotes mutableCopy];
        __block SFSDKAnalyticsTransformPublisherPair *currentTpp = remoteKeySet[0];
        PublishCompleteBlock publishCompleteBlock = ^void(BOOL success, NSError *error) {

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
            if (!remoteKeySet || remoteKeySet.count == 0) {
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
        [self log:SFLogLevelWarning msg:@"Invalid transformer and/or publisher"];
        return;
    }
    SFSDKAnalyticsTransformPublisherPair *tpp = [[SFSDKAnalyticsTransformPublisherPair alloc] initWithTransform:transformer publisher:publisher];
    [self.remotes addObject:tpp];
}

- (SFSDKDeviceAppAttributes *) buildDeviceAppAttributes {
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    NSString *prodAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
    NSString *appVersion = [NSString stringWithFormat:@"%@(%@)", prodAppVersion, buildNumber];
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *osVersion = [curDevice systemVersion];
    NSString *osName = [curDevice systemName];
    NSString *appTypeStr = @"";
    switch ([sdkManager appType]) {
        case kSFAppTypeNative:
            appTypeStr = kSFMobileSDKNativeDesignator;
            break;
        case kSFAppTypeHybrid:
            appTypeStr = kSFMobileSDKHybridDesignator;
            break;
        case kSFAppTypeReactNative:
            appTypeStr = kSFMobileSDKReactNativeDesignator;
            break;
    }
    NSString *mobileSdkVersion = SALESFORCE_SDK_VERSION;
    NSString *deviceModel = [curDevice platform];
    NSString *deviceId = [sdkManager deviceId];
    NSString *clientId = sdkManager.connectedAppId;
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block UIBackgroundTaskIdentifier task;
        task = [[SFApplicationHelper sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[SFApplicationHelper sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }];
        [self publishAllEvents];
        [[SFApplicationHelper sharedApplication] endBackgroundTask:task];
        task = UIBackgroundTaskInvalid;
    });
}

- (void) applyTransformAndPublish:(SFSDKAnalyticsTransformPublisherPair *)tpp events:(NSArray<SFSDKInstrumentationEvent *> *) events publishCompleteBlock:(PublishCompleteBlock) publishCompleteBlock {
    if (tpp) {
        NSMutableArray *eventsArray = [[NSMutableArray alloc] init];
        for (SFSDKInstrumentationEvent *event in events) {
            id transformedEvent = [tpp.transform transform:event];
            if (transformedEvent != nil) {
                [eventsArray addObject:transformedEvent];
            }
        }
        id<SFSDKAnalyticsPublisher> networkPublisher = tpp.publisher;
        if (networkPublisher) {
            [networkPublisher publish:eventsArray publishCompleteBlock:publishCompleteBlock];
        }
    }
}

#pragma mark - SFAuthenticationManagerDelegate

- (void) authManager:(SFAuthenticationManager *) manager willLogoutUser:(SFUserAccount *) user {
    [self.analyticsManager reset];
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs removeObjectForKey:kAnalyticsOnOffKey];
    [[self class] removeSharedInstanceWithUser:user];
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
