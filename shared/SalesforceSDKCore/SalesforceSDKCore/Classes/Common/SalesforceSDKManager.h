//
//  SalesforceSDKManager.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFUserAccount.h"

typedef enum {
    SFSDKLaunchActionNone             = 0,
    SFSDKLaunchActionAuthenticated    = 1 << 0,
    SFSDKLaunchActionPasscodeVerified = 1 << 1,
    SFSDKLaunchActionPasscodeCreated  = 1 << 2,
    SFSDKLaunchActionPasscodeUpdated  = 1 << 3
} SFSDKLaunchAction;

typedef void (^SFSDKPostLaunchCallbackBlock)(SFSDKLaunchAction);
typedef void (^SFSDKLaunchErrorCallbackBlock)(NSError*, SFSDKLaunchAction);
typedef void (^SFSDKCurrentUserLogoutCallbackBlock)(void);
typedef void (^SFSDKSwitchUserCallbackBlock)(SFUserAccount*, SFUserAccount*);

@interface SalesforceSDKManager : NSObject

+ (NSString *)connectedAppId;
+ (void)setConnectedAppId:(NSString *)connectedAppId;
+ (NSString *)connectedAppCallbackUri;
+ (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri;
+ (NSArray *)authScopes;
+ (void)setAuthScopes:(NSArray *)authScopes;
+ (SFSDKPostLaunchCallbackBlock)postLaunchAction;
+ (void)setPostLaunchAction:(SFSDKPostLaunchCallbackBlock)postLaunchAction;
+ (SFSDKLaunchErrorCallbackBlock)launchErrorAction;
+ (void)setLaunchErrorAction:(SFSDKLaunchErrorCallbackBlock)launchErrorAction;
+ (SFSDKCurrentUserLogoutCallbackBlock)postCurrentUserLogoutAction;
+ (void)setPostCurrentUserLogoutAction:(SFSDKCurrentUserLogoutCallbackBlock)postCurrentUserLogoutAction;
+ (void)launch;

@end
