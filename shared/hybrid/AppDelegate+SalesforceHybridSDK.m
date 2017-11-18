/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import <objc/runtime.h>
#import "AppDelegate+SalesforceHybridSDK.h"
#import "UIApplication+SalesforceHybridSDK.h"
#import "InitialViewController.h"
#import <SalesforceHybridSDK/SFLocalhostSubstitutionCache.h>
#import <SalesforceHybridSDK/SFHybridViewConfig.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceAnalytics/SFSDKLogger.h>
#import <SalesforceHybridSDK/SalesforceHybridSDKManager.h>

@implementation AppDelegate (SalesforceHybridSDK)

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(init)), class_getInstanceMethod(self, @selector(sfsdk_swizzled_init)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:)), class_getInstanceMethod(self, @selector(sfsdk_swizzled_application:didFinishLaunchingWithOptions:)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)), class_getInstanceMethod(self, @selector(sfsdk_swizzled_application:didRegisterForRemoteNotificationsWithDeviceToken:)));
}

- (AppDelegate *)sfsdk_swizzled_init
{
    // Need to use SalesforceHybridSDKManager in hybrid apps
    [SalesforceSDKManager setInstanceClass:[SalesforceHybridSDKManager class]];
    
    //Uncomment the following line inorder to enable/force the use of advanced authentication flow.
    //[SFUserAcountManager sharedInstance].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    // OR
    // To  retrieve advanced auth configuration from the org, to determine whether to initiate advanced authentication.
    //[SFUserAcountManager sharedInstance].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationAllow;
    
    // NOTE: If advanced authentication is configured or forced,  it will launch Safari to handle authentication
    // instead of a webview. You must implement application:openURL:options: to handle the callback.
    
    
    //Or uncomment following block to enable IDP Login flow.
    /*
     //scheme of idpAppp
     [SalesforceSDKManager sharedManager].idpAppURIScheme = @"sampleidpapp";
     //user friendly display name
     [SalesforceSDKManager sharedManager].appDisplayName = @"SampleAppOne";
     
     //Use the following code block to replace the login flow selection dialog
     [SalesforceSDKManager sharedManager].idpLoginFlowSelectionBlock = ^UIViewController<SFSDKLoginFlowSelectionView> * _Nonnull{
     IDPLoginNavViewController *controller = [[IDPLoginNavViewController alloc] init];
     return controller;
     };
     */
    __weak __typeof(self) weakSelf = self;
    [SalesforceSDKManager sharedManager].postLaunchAction = ^(SFSDKLaunchAction launchActionList) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [SFSDKLogger log:[self class] level:DDLogLevelInfo format:@"Post-launch: launch actions taken: %@", [SalesforceSDKManager launchActionsStringRepresentation:launchActionList]];
        [strongSelf setupRootViewController];
    };
    [SalesforceSDKManager sharedManager].launchErrorAction = ^(NSError *error, SFSDKLaunchAction launchActionList) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [SFSDKLogger log:[self class] level:DDLogLevelError format:@"Error during SDK launch: %@", [error localizedDescription]];
        [strongSelf initializeAppViewState];
        [[SalesforceSDKManager sharedManager] launch];
    };
    [SalesforceSDKManager sharedManager].postLogoutAction = ^{
        [weakSelf handleSdkManagerLogout];
    };
    [SalesforceSDKManager sharedManager].switchUserAction = ^(SFUserAccount *fromUser, SFUserAccount *toUser) {
        [weakSelf handleUserSwitch:fromUser toUser:toUser];
    };
    
    return [self sfsdk_swizzled_init];
}

#pragma mark - App event lifecycle

- (BOOL)sfsdk_swizzled_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    int cacheSizeMemory = 8 * 1024 * 1024; // 8MB
    int cacheSizeDisk = 32 * 1024 * 1024; // 32MB
    NSURLCache* sharedCache = [[SFLocalhostSubstitutionCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:sharedCache];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.autoresizesSubviews = YES;
    
    [self initializeAppViewState];
    [[SalesforceSDKManager sharedManager] launch];
    return YES; // we don't want to run's Cordova didFinishLaunchingWithOptions - it creates another window with a webview
                // if devs want to customize their AppDelegate.m, then they should get rid of AppDelegate+SalesforceHybrid.m
                // and bring all of its code in their AppDelegate.m
}

- (void)sfsdk_swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken != nil) {
        [[SFPushNotificationManager sharedInstance] registerForSalesforceNotifications];
    }
    
    [self sfsdk_swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    
    //Uncomment following block to enable IDP Login flow or If you're using advanced authentication:
    // --Configure your app to handle incoming requests to your
    //   OAuth Redirect URI custom URL scheme.
    // --Uncomment the following line and delete the original return statement:
    /*
     return [[SFUserAccountManager sharedInstance] handleAdvancedAuthenticationResponse:url options:options];
     */
    return NO;
    
}

- (void)handleSdkManagerLogout
{
    [self resetViewState:^{
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Logout notification received. Resetting app."];
        ((SFHybridViewController*)self.viewController).appHomeUrl = nil;
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
                [SFUserAccountManager sharedInstance].currentUser = allAccounts[0];
            }
            [[SalesforceSDKManager sharedManager] launch];
        }
    }];
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser
                  toUser:(SFUserAccount *)toUser
{
    [self resetViewState:^{
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@. Resetting app.",
         fromUser.userName, toUser.userName];
        [self initializeAppViewState];
        [[SalesforceSDKManager sharedManager] launch];
    }];
}

#pragma mark - Private methods

- (void)initializeAppViewState
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeAppViewState];
        });
        return;
    }
    
    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
}

- (void)setupRootViewController
{
    self.viewController = [[SFHybridViewController alloc] initWithConfig:(SFHybridViewConfig*)[SalesforceSDKManager sharedManager].appConfig];
    self.window.rootViewController = self.viewController;
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

@end
