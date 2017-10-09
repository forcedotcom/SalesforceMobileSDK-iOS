/*
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

#import <Foundation/Foundation.h>

@class SFUserAccount;
@class UIViewController;
@protocol SFSDKLoginFlowSelectionView;
@protocol SFSDKUserSelectionView;
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

/**
 Block typedef for creating a custom login flow selection dialog.
 */
typedef UIViewController<SFSDKLoginFlowSelectionView>*_Nonnull (^SFIDPLoginFlowSelectionBlock)(void);


/**
 Block typedef for creating a custom user selection flow for idp provider app.
 */
typedef UIViewController<SFSDKUserSelectionView>*_Nonnull (^SFIDPUserSelectionBlock)(void);
NS_ASSUME_NONNULL_END
