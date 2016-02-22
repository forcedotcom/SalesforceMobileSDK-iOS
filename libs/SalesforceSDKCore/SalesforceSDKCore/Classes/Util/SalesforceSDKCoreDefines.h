//
//  SalesforceSDKCoreDefines.h
//  SalesforceSDKCore
//
//  Created by Michael Nachbaur on 2/26/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SFUserAccount;
NS_ASSUME_NONNULL_BEGIN
// Errors
extern NSString * const kSalesforceSDKManagerErrorDomain;
extern NSString * const kSalesforceSDKManagerErrorDetailsKey;
enum {
    kSalesforceSDKManagerErrorUnknown = 766,
    kSalesforceSDKManagerErrorInvalidLaunchParameters
};

// Launch actions taken
typedef NS_OPTIONS(NSInteger, SFSDKLaunchAction) {
    SFSDKLaunchActionNone                 = 0,
    SFSDKLaunchActionAuthenticated        = 1 << 0,
    SFSDKLaunchActionAlreadyAuthenticated = 1 << 1,
    SFSDKLaunchActionAuthBypassed         = 1 << 2,
    SFSDKLaunchActionPasscodeVerified     = 1 << 3
};

/**
 Callback block to implement for post launch actions.
 */
typedef void (^SFSDKPostLaunchCallbackBlock)(SFSDKLaunchAction);

/**
 Callback block to implement for handling launch errors.
 */
typedef void (^SFSDKLaunchErrorCallbackBlock)(NSError*, SFSDKLaunchAction);

/**
 Callback block to implement for post logout actions.
 */
typedef void (^SFSDKLogoutCallbackBlock)(void);

/**
 Callback block to implement for user switching.
 */
typedef void (^SFSDKSwitchUserCallbackBlock)(SFUserAccount*, SFUserAccount*);

/**
 Callback block to implement for post app foregrounding actions.
 */
typedef void (^SFSDKAppForegroundCallbackBlock)(void);

/**
 Block to return a user agent string, with an optional qualifier.
 */
typedef NSString*_Nonnull (^SFSDKUserAgentCreationBlock)(NSString *qualifier);

NS_ASSUME_NONNULL_END
