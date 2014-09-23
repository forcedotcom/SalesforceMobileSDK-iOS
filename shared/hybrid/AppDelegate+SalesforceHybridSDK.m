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

#import <objc/runtime.h>

#import "AppDelegate+SalesforceHybridSDK.h"
#import "UIApplication+SalesforceHybridSDK.h"
#import <SalesforceHybridSDK/SFLocalhostSubstitutionCache.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceCommonUtils/SFLogger.h>

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
#if defined(DEBUG)
    [SFLogger setLogLevel:SFLogLevelDebug];
#else
    [SFLogger setLogLevel:SFLogLevelInfo];
#endif
    
    // Auth manager delegate, for receiving logout and login host change events.
    [[SFAuthenticationManager sharedManager] addDelegate:self];
    [[SFUserAccountManager sharedInstance] addDelegate:self];
    
    return [self sfsdk_swizzled_init];
}

- (void)dealloc
{
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
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
    return YES;
}

- (void)sfsdk_swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([SFUserAccountManager sharedInstance].currentUser != nil) {
        [[SFPushNotificationManager sharedInstance] registerForSalesforceNotifications];
    }
    
    [self sfsdk_swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}


#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    
    [self resetViewState:^{
        ((SFHybridViewController*)self.viewController).appHomeUrl = nil;
        
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
                [self.viewController dismissViewControllerAnimated:YES completion:NULL];
            }];
            [self.viewController presentViewController:userSwitchVc animated:YES completion:NULL];
        } else {
            if ([allAccounts count] == 1) {
                [SFUserAccountManager sharedInstance].currentUser = allAccounts[0];
            }
            [self initializeAppViewState];
        }
    }];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self log:SFLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@.  Resetting app.",
     fromUser.userName, toUser.userName];
    [self resetViewState:^{
        [self initializeAppViewState];
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
    
    self.viewController = [[SFHybridViewController alloc] init];
    self.window.rootViewController = self.viewController;
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

@end

