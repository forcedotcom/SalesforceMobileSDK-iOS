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
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKCore/SFSDKAuthHelper.h>
#import <SalesforceHybridSDK/SalesforceHybridSDKManager.h>
#import <SalesforceHybridSDK/SFSDKHybridLogger.h>

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
    [SalesforceHybridSDKManager initializeSDK];
    
    //App Setup for any changes to the current authenticated user
    __weak typeof (self) weakSelf = self;
    [SFSDKAuthHelper registerBlockForCurrentUserChangeNotifications:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        [strongSelf resetViewState:^{
            [strongSelf setupRootViewController];
        }];
    }];
    
    //Uncomment following block to enable IDP Login flow.
    /*
     //scheme of idpAppp
     [SalesforceHybridSDKManager sharedManager].idpAppURIScheme = @"sampleidpapp";
     //user friendly display name
     [SalesforceHybridSDKManager sharedManager].appDisplayName = @"SampleAppOne";
     
     //Use the following code block to replace the login flow selection dialog
     [SalesforceHybridSDKManager sharedManager].idpLoginFlowSelectionBlock = ^UIViewController<SFSDKLoginFlowSelectionView> * _Nonnull{
     IDPLoginNavViewController *controller = [[IDPLoginNavViewController alloc] init];
     return controller;
     };
     */
    
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
     __weak typeof (self) weakSelf = self;
    [SFSDKAuthHelper loginIfRequired:^{
        [weakSelf setupRootViewController];
    }];
    return YES; // we don't want to run's Cordova didFinishLaunchingWithOptions - it creates another window with a webview
                // if devs want to customize their AppDelegate.m, then they should get rid of AppDelegate+SalesforceHybrid.m
                // and bring all of its code in their AppDelegate.m
}

- (void)sfsdk_swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken != nil) {
        [[SFPushNotificationManager sharedInstance] registerSalesforceNotificationsWithCompletionBlock:nil failBlock:nil];
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
    self.viewController = [[SFHybridViewController alloc] initWithConfig:(SFHybridViewConfig*)[SalesforceHybridSDKManager sharedManager].appConfig];
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
