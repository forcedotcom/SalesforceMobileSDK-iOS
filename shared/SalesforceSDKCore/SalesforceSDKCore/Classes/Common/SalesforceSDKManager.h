//
//  SalesforceSDKManager.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFUserAccount.h"

// Errors
extern NSString * const kSalesforceSDKManagerErrorDomain;
extern NSString * const kSalesforceSDKManagerErrorDetailsKey;
enum {
    kSalesforceSDKManagerErrorUnknown = 766,
    kSalesforceSDKManagerErrorLaunchAlreadyInProgress,
    kSalesforceSDKManagerErrorInvalidLaunchParameters
};

typedef enum {
    SFSDKLaunchActionNone                 = 0,
    SFSDKLaunchActionAuthenticated        = 1 << 0,
    SFSDKLaunchActionAlreadyAuthenticated = 1 << 1,
    SFSDKLaunchActionPasscodeVerified     = 1 << 2,
    SFSDKLaunchActionPasscodeCreated      = 1 << 3,
    SFSDKLaunchActionPasscodeUpdated      = 1 << 4
} SFSDKLaunchAction;

typedef void (^SFSDKPostLaunchCallbackBlock)(SFSDKLaunchAction);
typedef void (^SFSDKLaunchErrorCallbackBlock)(NSError*, SFSDKLaunchAction);
typedef void (^SFSDKLogoutCallbackBlock)(void);
typedef void (^SFSDKSwitchUserCallbackBlock)(SFUserAccount*, SFUserAccount*);

@interface SalesforceSDKManager : NSObject

+ (BOOL)isLaunching;
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
+ (SFSDKLogoutCallbackBlock)postLogoutAction;
+ (void)setPostLogoutAction:(SFSDKLogoutCallbackBlock)postLogoutAction;
+ (void)launch;

@end
