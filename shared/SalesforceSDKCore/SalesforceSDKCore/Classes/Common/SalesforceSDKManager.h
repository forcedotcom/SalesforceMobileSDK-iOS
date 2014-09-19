/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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
#import "SFUserAccount.h"

// Errors
extern NSString * const kSalesforceSDKManagerErrorDomain;
extern NSString * const kSalesforceSDKManagerErrorDetailsKey;
enum {
    kSalesforceSDKManagerErrorUnknown = 766,
    kSalesforceSDKManagerErrorLaunchAlreadyInProgress,
    kSalesforceSDKManagerErrorInvalidLaunchParameters
};

// Launch actions taken
typedef enum {
    SFSDKLaunchActionNone                 = 0,
    SFSDKLaunchActionAuthenticated        = 1 << 0,
    SFSDKLaunchActionAlreadyAuthenticated = 1 << 1,
    SFSDKLaunchActionAuthBypassed         = 1 << 2,
    SFSDKLaunchActionPasscodeVerified     = 1 << 3
} SFSDKLaunchAction;

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
 This class will manage the basic infrastructure of the Mobile SDK elements of the app,
 including the orchestration of authentication, passcode displaying, and management of app
 backgrounding and foregrounding state.
 */
@interface SalesforceSDKManager : NSObject

/**
 @return Whether or not the SDK is currently in the middle of a launch process.
 */
+ (BOOL)isLaunching;

/**
 @return The Connected App ID configured for this application.
 */
+ (NSString *)connectedAppId;

/**
 Sets the Connected App ID for this application.
 @param connectedAppId The Connected App ID to associate with this app.
 */
+ (void)setConnectedAppId:(NSString *)connectedAppId;

/**
 @return The Connected App Callback URI configured for this application.
 */
+ (NSString *)connectedAppCallbackUri;

/**
 Sets the Connected App Callback URI for this application.
 @param connectedAppCallbackUri The Connected App Callback URI to associate with this app.
 */
+ (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri;

/**
 @return The OAuth scopes configured for this application.
 */
+ (NSArray *)authScopes;

/**
 Sets the OAuth scopes for this application.
 @param authScopes The array of OAuth scopes to associate with this app.
 */
+ (void)setAuthScopes:(NSArray *)authScopes;

/**
 @return Whether or not to attempt authentication as part of the launch process.  Default
 value is YES.
 */
+ (BOOL)authenticateAtLaunch;

/**
 Sets a flag to determine whether or not to attempt authentication as part of the launch
 process.  Default value is YES.
 @param authenticateAtLaunch Whether or not to attempt authentication during the launch process.
 */
+ (void)setAuthenticateAtLaunch:(BOOL)authenticateAtLaunch;

/**
 @return The configured post launch action block to execute when launch completes.
 */
+ (SFSDKPostLaunchCallbackBlock)postLaunchAction;

/**
 Sets the post launch action block to execute when launch completes.
 @param postLaunchAction The post launch action block to execute.
 */
+ (void)setPostLaunchAction:(SFSDKPostLaunchCallbackBlock)postLaunchAction;

/**
 @return The configured launch error action block to execute in the event of an error during launch.
 */
+ (SFSDKLaunchErrorCallbackBlock)launchErrorAction;

/**
 Sets the launch error action block to execute in the event of a launch error.
 @param launchErrorAction The block to execute in the event of a launch error.
 */
+ (void)setLaunchErrorAction:(SFSDKLaunchErrorCallbackBlock)launchErrorAction;

/**
 @return The post logout action block to execute after the current user has been logged out.
 */
+ (SFSDKLogoutCallbackBlock)postLogoutAction;

/**
 Sets the post logout action block to execute after the current user has been logged out.
 @param postLogoutAction The action block to execute after logout.
 */
+ (void)setPostLogoutAction:(SFSDKLogoutCallbackBlock)postLogoutAction;

/**
 @return The switch user action block to execute when switching from one user to another.
 */
+ (SFSDKSwitchUserCallbackBlock)switchUserAction;

/**
 Sets the switch user action block to execute when the user switches from one user to another.
 @param switchUserAction The block to execute when the user switches.
 */
+ (void)setSwitchUserAction:(SFSDKSwitchUserCallbackBlock)switchUserAction;

/**
 @return The block to execute after the app has entered the foreground.
 */
+ (SFSDKAppForegroundCallbackBlock)postAppForegroundAction;

/**
 Sets the block to execute after the app has entered the foreground.  Only required if your
 app needs to take specific actions when it enters the foreground.
 @param postAppForegroundAction The block to execute after the app enters the foreground.
 */
+ (void)setPostAppForegroundAction:(SFSDKAppForegroundCallbackBlock)postAppForegroundAction;

/**
 @return Whether or not to use a security snapshot view when the app is backgrounded, to prevent
 sensitive data from being displayed outside of the app context.  Default is YES.
 */
+ (BOOL)useSnapshotView;

/**
 Sets the flag to denote whether or not to use a security snapshot view to prevent sensitive data
 from being displayed when the app is backgrounded.  Default is YES.
 @param useSnapshotView Whether or not to use the security feature.
 */
+ (void)setUseSnapshotView:(BOOL)useSnapshotView;

/**
 @return A custom view to use as the "image" that represents the app display when it is backgrounded.
 Default will be an opaque white view.
 */
+ (UIView *)snapshotView;

/**
 Sets a custom view to use as the "image" that represents the app display when it is backgrounded.  Default
 is an opaque white view.
 @param snapshotView The custom view to display.
 */
+ (void)setSnapshotView:(UIView *)snapshotView;

/**
 Launches the SDK.  This will verify an existing passcode the first time it runs, and attempt to
 authenticate if the current user is not already authenticated.  @see postLaunchAction, launchErrorAction,
 postLogoutAction, and switchUserAction for callbacks that can be set for handling post launch
 actions.
 */
+ (void)launch;

/**
 @return A log-friendly string of the launch actions that were taken, given in postLaunchAction.
 */
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
