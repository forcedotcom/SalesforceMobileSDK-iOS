/*
 Copyright (c) 2011-2014, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceCommonUtils/SFLogger.h>

@interface AppDelegate () <SFAuthenticationManagerDelegate, SFUserAccountManagerDelegate>

- (void)initializeAppViewState;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (id)init
{
    self = [super init];
    if (self) {
#if defined(DEBUG)
        [SFLogger setLogLevel:SFLogLevelDebug];
#else
        [SFLogger setLogLevel:SFLogLevelInfo];
#endif
        
        // Auth manager delegate, for receiving logout and login host change events.
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    
    return self;
}

- (void)dealloc
{
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
}

#pragma mark - App event lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.autoresizesSubviews = YES;
    
    //
    // If you wish to register for push notifications, uncomment the line below.  Note that,
    // if you want to receive push notifications from Salesforce, you will also need to
    // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
    //
    //[[SFPushNotificationManager sharedInstance] registerForRemoteNotifications];
    //
    
    [self initializeAppViewState];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //
    // Uncomment the code below to register your device token with the push notification manager
    //
    //[[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    //if ([SFAccountManager sharedInstance].credentials.accessToken != nil) {
    //    [[SFPushNotificationManager sharedInstance] registerForSalesforceNotifications];
    //}
    //
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    // Respond to any push notification registration errors here.
}

- (BOOL)application:(UIApplication*)application handleOpenURL:(NSURL*)url
{
    if (url == nil) {
        return NO;
    }
    
    // calls into javascript global function 'handleOpenURL'
    NSString* jsString = [NSString stringWithFormat:@"handleOpenURL(\"%@\");", url];
    [self.viewController.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    return YES;
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    self.viewController.appHomeUrl = nil;
    
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
    } else if ([[SFUserAccountManager sharedInstance].allUserAccounts count] == 1) {
        [SFUserAccountManager sharedInstance].currentUser = [[SFUserAccountManager sharedInstance].allUserAccounts objectAtIndex:0];
        [self initializeAppViewState];
    } else {
        [self initializeAppViewState];
    }
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self log:SFLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@.  Resetting app.",
     fromUser.userName, toUser.userName];
    [self initializeAppViewState];
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
    self.viewController.useSplashScreen = YES;
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
}

@end
