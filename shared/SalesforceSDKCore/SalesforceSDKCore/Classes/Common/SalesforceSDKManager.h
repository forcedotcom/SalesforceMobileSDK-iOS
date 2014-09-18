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
    SFSDKLaunchActionPasscodeVerified     = 1 << 2
} SFSDKLaunchAction;

typedef void (^SFSDKPostLaunchCallbackBlock)(SFSDKLaunchAction);
typedef void (^SFSDKLaunchErrorCallbackBlock)(NSError*, SFSDKLaunchAction);
typedef void (^SFSDKLogoutCallbackBlock)(void);
typedef void (^SFSDKSwitchUserCallbackBlock)(SFUserAccount*, SFUserAccount*);
typedef void (^SFSDKAppForegroundCallbackBlock)(void);

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
+ (SFSDKSwitchUserCallbackBlock)switchUserAction;
+ (void)setSwitchUserAction:(SFSDKSwitchUserCallbackBlock)switchUserAction;
+ (SFSDKAppForegroundCallbackBlock)postAppForegroundAction;
+ (void)setPostAppForegroundAction:(SFSDKAppForegroundCallbackBlock)postAppForegroundAction;
+ (BOOL)useSnapshotView;
+ (void)setUseSnapshotView:(BOOL)useSnapshotView;
+ (UIView *)snapshotView;
+ (void)setSnapshotView:(UIView *)snapshotView;
+ (void)launch;
+ (NSString *)launchActionsStringRepresentation:(SFSDKLaunchAction)launchActions;

/**
 @return The preferred passcode provider for the app.  Defaults to kSFPasscodeProviderPBKDF2.
 */
+ (NSString *)preferredPasscodeProvider;

/**
 Set the preferred passcode provider to use.  Defaults to kSFPasscodeProviderPBKDF2.  See SFPasscodeProviderManager.
 NOTE: If you wanted to set your own provider, you could do the following:
         id<SFPasscodeProvider> *myProvider = [[MyProvider alloc] initWithProviderName:myProviderName];
         [SFPasscodeProviderManager addPasscodeProvider:myProvider];
         [SalesforceSDKManager setPreferredPasscodeProvider:myProviderName];
 */
+ (void)setPreferredPasscodeProvider:(NSString *)preferredPasscodeProvider;

@end
