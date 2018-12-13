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

#import "SFSDKSalesforceAnalyticsManager+Internal.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import "SFDirectoryManager.h"
#import "SFKeyStoreManager.h"
#import "SFSDKCryptoUtils.h"
#import "SFSDKAILTNPublisher.h"
#import "UIDevice+SFHardware.h"
#import "SFIdentityData.h"
#import "SFApplicationHelper.h"
#import <SalesforceAnalytics/SFSDKAILTNTransform.h>
#import <SalesforceAnalytics/SFSDKDeviceAppAttributes.h>
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKAppConfig.h"

static NSString * const kAnalyticsUnauthenticatedManagerKey = @"-unauthenticated-";
static NSString * const kEventStoresDirectory = @"event_stores";
static NSString * const kEventStoreEncryptionKeyLabel = @"com.salesforce.eventStore.encryptionKey";
static NSString * const kAnalyticsOnOffKey = @"ailtn_enabled";
static NSString * const kSFAppFeatureAiltnEnabled = @"AI";

static NSMutableDictionary *analyticsManagerList = nil;

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
                [SFSDKCoreLogger w:[self class] format:@"%@ A user account must be in the  SFUserAccountLoginStateLoggedIn state in order to create a SFSDKSalesforceAnalyticsManager instance for a user.", NSStringFromSelector(_cmd)];
                return nil;
            }
            analyticsMgr = [[self alloc] initWithUser:userAccount];
            analyticsManagerList[key] = analyticsMgr;
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
        NSString *key = SFKeyForUserAndScope(userAccount, SFUserAccountScopeCommunity);
        [analyticsManagerList removeObjectForKey:key];
    }
}

- (void) dealloc {
    // Only work with auth-based notifications for an authenticated context.
    if (_userAccount != nil) {
        SFSDK_USE_DEPRECATED_BEGIN
        [[SFAuthenticationManager sharedManager] removeDelegate:self];
        SFSDK_USE_DEPRECATED_END
    }
    
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
        
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kEventStoreEncryptionKeyLabel autoCreate:YES];
        DataEncryptorBlock dataEncryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256EncryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        DataDecryptorBlock dataDecryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256DecryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        _analyticsManager = [[SFSDKAnalyticsManager alloc] initWithStoreDirectory:rootStoreDir dataEncryptorBlock:dataEncryptorBlock dataDecryptorBlock:dataDecryptorBlock deviceAttributes:deviceAttributes];
        _eventStoreManager = self.analyticsManager.storeManager;
        _remotes = [[NSMutableArray alloc] init];
        
        // There's no standard for unauthenticated instrumentation publishing, currently.  Consumers
        // should explicitly specify their own.
        if (_userAccount != nil) {
            SFSDKAnalyticsTransformPublisherPair *tpp = [[SFSDKAnalyticsTransformPublisherPair alloc] initWithTransform:[[SFSDKAILTNTransform alloc] init] publisher:[[SFSDKAILTNPublisher alloc] init]];
            [_remotes addObject:tpp];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publishOnAppBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        // Only work with auth-based notifications for an authenticated context.
        if (userAccount != nil) {
            SFSDK_USE_DEPRECATED_BEGIN
            [[SFAuthenticationManager sharedManager] addDelegate:self];
            SFSDK_USE_DEPRECATED_END
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
        NSArray<SFSDKInstrumentationEvent *> *events = [self.eventStoreManager fetchAllEvents];
        [self publishEvents:events];
    }
}

- (void) publishEvents:(NSArray<SFSDKInstrumentationEvent *> *) events {
    if (events.count == 0 || self.remotes.count == 0) {
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
    NSString *deviceModel = [curDevice platform];
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block UIBackgroundTaskIdentifier task;
        task = [[SFApplicationHelper sharedApplication] beginBackgroundTaskWithName:NSStringFromClass([self class]) expirationHandler:^{
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

SFSDK_USE_DEPRECATED_BEGIN

- (void) authManager:(SFAuthenticationManager *) manager willLogoutUser:(SFUserAccount *) user {
    [self handleLogoutForUser:user];
}

@end

SFSDK_USE_DEPRECATED_END

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

