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
#import <SalesforceAnalytics/DeviceAppAttributes.h>

static NSMutableDictionary *analyticsManagerList = nil;

@interface SalesforceAnalyticsManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, readwrite, strong) AnalyticsManager *analyticsManager;

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
        NSString *rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:userAccount type:NSDocumentDirectory components:nil];
        
    }
    return self;
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
    [[self class] removeSharedInstanceWithUser:user];
}

@end
