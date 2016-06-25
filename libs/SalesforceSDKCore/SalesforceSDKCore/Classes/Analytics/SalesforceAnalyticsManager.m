/*
 SalesforceAnalyticsManager.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/16/16.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SalesforceAnalyticsManager.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import "SFDirectoryManager.h"
#import "SFKeyStoreManager.h"
#import "SFSDKCryptoUtils.h"
#import "AILTNPublisher.h"
#import <SalesforceAnalytics/AILTNTransform.h>
#import <SalesforceAnalytics/DeviceAppAttributes.h>

static NSString * const kEventStoresDirectory = @"event_stores";
static NSString * const kEventStoreEncryptionKeyLabel = @"com.salesforce.eventStore.encryptionKey";

static NSMutableDictionary *analyticsManagerList = nil;

@interface SalesforceAnalyticsManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, readwrite, strong) AnalyticsManager *analyticsManager;
@property (nonatomic, readwrite, strong) EventStoreManager *eventStoreManager;
@property (nonatomic, readwrite, strong) NSMutableDictionary *remotes;

@end

@implementation SalesforceAnalyticsManager

+ (id) sharedInstanceWithUser:(SFUserAccount *) userAccount {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        analyticsManagerList = [[NSMutableDictionary alloc] init];
    });
    @synchronized ([SalesforceAnalyticsManager class]) {
        if (!userAccount) {
            userAccount = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!userAccount) {
            return nil;
        }
        id analyticsMgr = [analyticsManagerList objectForKey:userAccount];
        if (!analyticsMgr) {
            analyticsMgr = [[SalesforceAnalyticsManager alloc] init:userAccount];
            NSString *key = SFKeyForUserAndScope(userAccount, SFUserAccountScopeCommunity);
            [analyticsManagerList setObject:analyticsMgr forKey:key];
        }
        return analyticsMgr;
    }
}

+ (void) removeSharedInstanceWithUser:(SFUserAccount *) userAccount {
    @synchronized ([SalesforceAnalyticsManager class]) {
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

- (id) init:(SFUserAccount *) userAccount {
    self = [super init];
    if (self) {
        DeviceAppAttributes *deviceAttributes = [self buildDeviceAppAttributes];
        NSString *rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:userAccount type:NSDocumentDirectory components:@[ kEventStoresDirectory ]];
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kEventStoreEncryptionKeyLabel keyType:SFKeyStoreKeyTypePasscode autoCreate:YES];
        DataEncryptorBlock dataEncryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256EncryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        DataDecryptorBlock dataDecryptorBlock = ^NSData*(NSData *data) {
            return [SFSDKCryptoUtils aes256DecryptData:data withKey:encKey.key iv:encKey.initializationVector];
        };
        self.analyticsManager = [[AnalyticsManager alloc] init:rootStoreDir dataEncryptorBlock:dataEncryptorBlock dataDecryptorBlock:dataDecryptorBlock deviceAttributes:deviceAttributes];
        self.eventStoreManager = self.analyticsManager.storeManager;
        self.remotes = [[NSMutableDictionary alloc] init];
        [self.remotes setObject:[AILTNPublisher class] forKey:(id<NSCopying>) [AILTNTransform class]];
    }
    return self;
}

- (void) disableOrEnableLogging:(BOOL) enabled {
    [self.eventStoreManager disableOrEnableLogging:enabled];
}

- (BOOL) isLoggingEnabled {
    return self.eventStoreManager.isLoggingEnabled;
}

- (void) publishAllEvents {
    NSArray<InstrumentationEvent *> *events = [self.eventStoreManager fetchAllEvents];
    [self publishEvents:events];
}

- (void) publishEvents:(NSArray<InstrumentationEvent *> *) events {
    if (!events || events.count == 0) {
        return;
    }
    NSMutableArray<NSString *> *eventIds = [[NSMutableArray alloc] init];
    BOOL success = YES;
    NSArray<Class<Transform>> *remoteKeySet = [self.remotes allKeys];
    for (Class<Transform> transformClass in remoteKeySet) {
        if (transformClass) {
            NSMutableArray<NSDictionary *> *eventsJSONArray = [[NSMutableArray alloc] init];
            for (InstrumentationEvent *event in events) {
                [eventIds addObject:event.eventId];
                NSDictionary *eventJSON = [transformClass transform:event];
                if (eventJSON) {
                    [eventsJSONArray addObject:eventJSON];
                }
            }
            Class<AnalyticsPublisher> networkPublisher = [self.remotes objectForKey:transformClass];
            if (networkPublisher) {
                BOOL networkSuccess = [networkPublisher publish:eventsJSONArray];

                /*
                 * Updates the success flag only if all previous requests have been
                 * successful. This ensures that the operation is marked success only
                 * if all publishers are successful.
                 */
                if (success) {
                    success = networkSuccess;
                }
            }
        }
    }

    /*
     * Deletes events from the event store if the network publishing was successful.
     */
    if (success) {
        [self.eventStoreManager deleteEvents:eventIds];
    }
}

- (void) publishEvent:(InstrumentationEvent *) event {
    if (!event) {
        return;
    }
    NSMutableArray<InstrumentationEvent *> *events = [[NSMutableArray alloc] init];
    [events addObject:event];
    [self publishEvents:events];
}

- (void) addRemotePublisher:(Class<Transform>) transformer publisher:(Class<AnalyticsPublisher>) publisher {
    if (!transformer || !publisher) {
        [self log:SFLogLevelWarning msg:@"Invalid transformer and/or publisher"];
        return;
    }
    [self.remotes setObject:publisher forKey:(id<NSCopying>) transformer];
}

- (DeviceAppAttributes *) buildDeviceAppAttributes {
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleVersionKey];
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
    NSString *deviceModel = [curDevice model];
    NSString *deviceId = [sdkManager deviceId];
    return [[DeviceAppAttributes alloc] init:appVersion appName:appName osVersion:osVersion osName:osName nativeAppType:appTypeStr mobileSdkVersion:mobileSdkVersion deviceModel:deviceModel deviceId:deviceId];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void) authManager:(SFAuthenticationManager *) manager willLogoutUser:(SFUserAccount *) user {
    [self.analyticsManager reset];
    [[self class] removeSharedInstanceWithUser:user];
}

@end
