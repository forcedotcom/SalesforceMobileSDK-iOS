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
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKcore/SFSDKWindowManager.h>
#import <SalesforceSDKCore/SFSDKAuthHelper.h>
#import <MobileSync/MobileSyncSDKManager.h>
#import <SalesforceSDKCommon/SFSDKDatasharingHelper.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <MobileSyncExplorerCommon/MobileSyncExplorerConfig.h>
#import <SalesforceSDKcore/SFSDKNavigationController.h>

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
        MobileSyncExplorerConfig *config = [MobileSyncExplorerConfig sharedInstance];
        [SFSDKDatasharingHelper sharedInstance].appGroupName = config.appGroupName;
        [SFSDKDatasharingHelper sharedInstance].appGroupEnabled = config.appGroupsEnabled;

        [MobileSyncSDKManager initializeSDK];
        
        //App Setup for any changes to the current authenticated user
        __weak typeof (self) weakSelf = self;
        [SFSDKAuthHelper registerBlockForCurrentUserChangeNotifications:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf setUserLoginStatus:YES];
            [strongSelf resetViewState:^{
                [strongSelf setupRootViewController];
            }];
        }];
        
        //Uncomment following lines to enable IDP Login flow. Set scheme of idpAppp & display name (optional)
        //[MobileSyncSDKManager sharedManager].idpAppURIScheme = @"sampleidpapp";
        //[MobileSyncSDKManager sharedManager].appDisplayName = @"SampleAppOne";
        
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
    __weak typeof (self) weakSelf = self;
    [SFSDKAuthHelper loginIfRequired:^{
        [weakSelf setupRootViewController];
    }];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //
    // Uncomment the code below to register your device token with the push notification manager
    //
    // [[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    // if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken != nil) {
    //     [[SFPushNotificationManager sharedInstance] registerSalesforceNotificationsWithCompletionBlock:nil failBlock:nil];
    // }
    //
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    // Respond to any push notification registration errors here.
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    
    // Uncomment following block to enable IDP Login flow
    // return [[SFUserAccountManager sharedInstance] handleIDPAuthenticationResponse:url options:options];
    return NO;

}

#pragma mark - Private methods
- (void)setUserLoginStatus:(BOOL) loggedIn {
    [[NSUserDefaults msdkUserDefaults] setBool:loggedIn forKey:@"userLoggedIn"];
    [[NSUserDefaults msdkUserDefaults] synchronize];
    [SFSDKMobileSyncLogger log:[self class] level:SFLogLevelDebug format:@"%d userLoggedIn", [[NSUserDefaults msdkUserDefaults] boolForKey:@"userLoggedIn"] ];
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

- (void)sdkManagerWillResignActive {
    if ([MobileSyncSDKManager sharedManager].useSnapshotView) {
        // Remove the keyboard if it is showing..
        [[SFSDKWindowManager sharedManager].activeWindow.window endEditing:YES];
    }
}
@end
