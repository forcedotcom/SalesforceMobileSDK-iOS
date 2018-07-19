/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

#import "AppDelegate.h"
#import "InitialViewController.h"
#import "ContactListViewController.h"
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKcore/SFSDKWindowManager.h>
#import <SmartSync/SmartSyncSDKManager.h>
#import <SalesforceAnalytics/SFSDKDatasharingHelper.h>
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>
#import <SmartSyncExplorerCommon/SmartSyncExplorerConfig.h>
#import <SalesforceSDKcore/SFSDKNavigationController.h>
#import "IDPLoginNavViewController.h"

@interface AppDelegate () <SalesforceSDKManagerDelegate>

/**
 * Convenience method for setting up the main UIViewController and setting self.window's rootViewController
 * property accordingly.
 */
- (void)setupRootViewController;

/**
 * (Re-)sets the view state when the app first loads (or post-logout).
 */
- (void)initializeAppViewState;

- (void)setUserLoginStatus :(BOOL) loggedIn;
@end

@implementation AppDelegate

@synthesize window = _window;

- (id)init
{
    self = [super init];
    if (self) {
        SmartSyncExplorerConfig *config = [SmartSyncExplorerConfig sharedInstance];
        [SFSDKDatasharingHelper sharedInstance].appGroupName = config.appGroupName;
        [SFSDKDatasharingHelper sharedInstance].appGroupEnabled = config.appGroupsEnabled;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserDidLogout:) name:kSFNotificationUserDidLogout object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserDidSwitch:) name:kSFNotificationUserDidSwitch  object:nil];
        [SmartSyncSDKManager initializeSDK];
        [[SmartSyncSDKManager sharedManager] addDelegate:self];
       
        //Uncomment following block to enable IDP Login flow.
        /*
        //scheme of idpAppp
        [SmartSyncSDKManager sharedManager].idpAppURIScheme = @"sampleidpapp";
         //user friendly display name
        [SmartSyncSDKManager sharedManager].appDisplayName = @"SampleAppOne";
         
        //Use the following code block to replace the login flow selection dialog
        [SmartSyncSDKManager sharedManager].idpLoginFlowSelectionBlock = ^UIViewController<SFSDKLoginFlowSelectionView> * _Nonnull{
            IDPLoginNavViewController *controller = [[IDPLoginNavViewController alloc] init];
            return controller;
        };
        */
    }
    return self;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // The Mobile SDK uses multiple UIWindow's inorder to present views. Having
    // Multiple windows with different controllers varying rotational behaviors
    // lead to weird UIWindow behaviors. To avoid such rotation and other issues
    // between visible and hidden windows use the SFSDKUIWindow instead of  
    // UIWindow.
    self.window = [[SFSDKUIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self initializeAppViewState];
    [self loginIfRequired];
     return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //
    // Uncomment the code below to register your device token with the push notification manager
    //
    //[[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    //if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken != nil) {
    //    [[SFPushNotificationManager sharedInstance] registerForSalesforceNotifications];
    //}
    //
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    // Respond to any push notification registration errors here.
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    
    //Uncomment following block to enable IDP Login flow
    /*
    return [[SFUserAccountManager sharedInstance] handleAdvancedAuthenticationResponse:url options:options];
    */
    return NO;

}

#pragma mark - Private methods

- (void)handleUserDidSwitch:(NSNotification *)notification {
    [self setUserLoginStatus:NO];
    SFUserAccount *fromUser = notification.userInfo[kSFNotificationFromUserKey];
    SFUserAccount *toUser = notification.userInfo[kSFNotificationToUserKey];
    [self handleUserSwitch:fromUser toUser:toUser];
}
- (void)handleUserDidLogout:(NSNotification *)notification {
    [self handleSdkManagerLogout];
}

- (void)setUserLoginStatus :(BOOL) loggedIn {
    [[NSUserDefaults msdkUserDefaults] setBool:loggedIn forKey:@"userLoggedIn"];
    [[NSUserDefaults msdkUserDefaults] synchronize];
    [SFSDKSmartSyncLogger log:[self class] level:DDLogLevelDebug format:@"%d userLoggedIn", [[NSUserDefaults msdkUserDefaults] boolForKey:@"userLoggedIn"] ];
}

- (void)loginIfRequired {
    __weak typeof(self) weakSelf = self;
    if (![SFUserAccountManager sharedInstance].currentUser) {
        SFUserAccountManagerSuccessCallbackBlock successBlock = ^(SFOAuthInfo *authInfo,SFUserAccount *userAccount) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [SFUserAccountManager sharedInstance].currentUser = userAccount;
            [strongSelf setupRootViewController];
        };
        
        SFUserAccountManagerFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *authError) {
            [SFSDKSmartSyncLogger e:[self class] format:@"Authentication failed: %@.",[authError localizedDescription]];
            
        };
        [[SFUserAccountManager sharedInstance] loginWithCompletion:successBlock failure:failureBlock];
    } else {
        [self setupRootViewController];
    }
}

- (void)initializeAppViewState
{
    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
}

- (void)setupRootViewController
{
    ContactListViewController *rootVC = [[ContactListViewController alloc] initWithStyle:UITableViewStylePlain];
    SFSDKNavigationController *navVC = [[SFSDKNavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navVC;
    [self.window makeKeyAndVisible];
}

- (void)resetViewState:(void (^)(void))postResetBlock
{
    if ([self.window.rootViewController presentedViewController]) {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
            postResetBlock();
        }];
    } else {
        postResetBlock();
    }
}

- (void)handleSdkManagerLogout
{
    [SFSDKSmartSyncLogger log:[self class] level:DDLogLevelDebug format:@"SFUserAccountManager logged out. Resetting app."];
    [self resetViewState:^{
        [self initializeAppViewState];
        
        // Multi-user pattern:
        // - If there are two or more existing accounts after logout, let the user choose the account
        //   to switch to.
        // - If there is one existing account, automatically switch to that account.
        // - If there are no further authenticated accounts, present the login screen.
        //
        // Alternatively, you could just go straight to re-initializing your app state, if you know
        // your app does not support multiple accounts.  The logic below will work either way.
        NSArray *allAccounts = [SFUserAccountManager sharedInstance].allUserAccounts;
        if ([allAccounts count] > 1) {
            SFDefaultUserManagementViewController *userSwitchVc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
                [self.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
            }];
            [self.window.rootViewController presentViewController:userSwitchVc animated:YES completion:NULL];
        } else {
            if ([allAccounts count] == 1) {
                [SFUserAccountManager sharedInstance].currentUser = ([SFUserAccountManager sharedInstance].allUserAccounts)[0];
                [self setupRootViewController];
            } else {
                [self loginIfRequired];
            }
        }
    }];
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser
                  toUser:(SFUserAccount *)toUser
{
    [SFSDKSmartSyncLogger log:[self class] level:DDLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@.  Resetting app.",
     fromUser.userName, toUser.userName];
    [self resetViewState:^{
        [self initializeAppViewState];
        [self setupRootViewController];
    }];
}

- (void)sdkManagerWillResignActive {
    if ([SmartSyncSDKManager sharedManager].useSnapshotView) {
        // Remove the keyboard if it is showing..
        [[SFSDKWindowManager sharedManager].activeWindow.window endEditing:YES];
    }
}
@end
