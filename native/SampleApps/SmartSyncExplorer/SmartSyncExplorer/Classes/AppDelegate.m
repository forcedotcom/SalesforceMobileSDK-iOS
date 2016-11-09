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
#import <SmartStore/SalesforceSDKManagerWithSmartStore.h>
#import <SalesforceSDKCore/SFSDKDatasharingHelper.h>
#import <SalesforceSDKCore/NSUserDefaults+SFAdditions.h>
#import <SmartSyncExplorerCommon/SmartSyncExplorerConfig.h>

@interface AppDelegate ()

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
        #if defined(DEBUG)
            [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
        #else
            [SFLogger sharedLogger].logLevel = SFLogLevelInfo;
        #endif
        SmartSyncExplorerConfig *config = [SmartSyncExplorerConfig sharedInstance];
        [SFSDKDatasharingHelper sharedInstance].appGroupName = config.appGroupName;
        [SFSDKDatasharingHelper sharedInstance].appGroupEnabled = config.appGroupsEnabled;
        [SalesforceSDKManager setInstanceClass:[SalesforceSDKManagerWithSmartStore class]];
        
        // Need to use SalesforceSDKManagerWithSmartStore when using smartstore
        [SalesforceSDKManager setInstanceClass:[SalesforceSDKManagerWithSmartStore class]];
        [SalesforceSDKManager sharedManager].connectedAppId = config.remoteAccessConsumerKey;
        [SalesforceSDKManager sharedManager].connectedAppCallbackUri = config.oauthRedirectURI;
        [SalesforceSDKManager sharedManager].authScopes = config.oauthScopes;
        __weak typeof(self) weakSelf = self;
        [SalesforceSDKManager sharedManager].postLaunchAction = ^(SFSDKLaunchAction launchActionList) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            //
            // If you wish to register for push notifications, uncomment the line below.  Note that,
            // if you want to receive push notifications from Salesforce, you will also need to
            // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
            //
            //[[SFPushNotificationManager sharedInstance] registerForRemoteNotifications];
            //
            [strongSelf setUserLoginStatus:YES];
            
            [strongSelf log:SFLogLevelInfo format:@"Post-launch: launch actions taken: %@", [SalesforceSDKManager launchActionsStringRepresentation:launchActionList]];
            [strongSelf setupRootViewController];

        };
        [SalesforceSDKManager sharedManager].launchErrorAction = ^(NSError *error, SFSDKLaunchAction launchActionList) {
            __strong typeof(weakSelf) strongSelf = weakSelf;

            [strongSelf log:SFLogLevelError format:@"Error during SDK launch: %@", [error localizedDescription]];
            [strongSelf initializeAppViewState];
            [[SalesforceSDKManager sharedManager] launch];
        };
        [SalesforceSDKManager sharedManager].postLogoutAction = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf setUserLoginStatus:NO];
            [strongSelf handleSdkManagerLogout];
        };
        [SalesforceSDKManager sharedManager].switchUserAction = ^(SFUserAccount *fromUser, SFUserAccount *toUser) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf setUserLoginStatus:NO];
            [strongSelf handleUserSwitch:fromUser toUser:toUser];
        };
    }
    return self;
}

- (void)setUserLoginStatus :(BOOL) loggedIn {
    [[NSUserDefaults msdkUserDefaults] setBool:loggedIn forKey:@"userLoggedIn"];
    [[NSUserDefaults msdkUserDefaults] synchronize];
    [self log:SFLogLevelDebug format:@"%d userLoggedIn", [[NSUserDefaults msdkUserDefaults] boolForKey:@"userLoggedIn"] ];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self initializeAppViewState];
    [[SalesforceSDKManager sharedManager] launch];
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

#pragma mark - Private methods

- (void)initializeAppViewState
{
    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
}

- (void)setupRootViewController
{
    ContactListViewController *rootVC = [[ContactListViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navVC;
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
    [self log:SFLogLevelDebug msg:@"SFAuthenticationManager logged out.  Resetting app."];
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
            }
            
            [[SalesforceSDKManager sharedManager] launch];
        }
    }];
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser
                  toUser:(SFUserAccount *)toUser
{
    [self log:SFLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@.  Resetting app.",
     fromUser.userName, toUser.userName];
    [self resetViewState:^{
        [self initializeAppViewState];
        [[SalesforceSDKManager sharedManager] launch];
    }];
}

@end
