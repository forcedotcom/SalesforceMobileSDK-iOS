/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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
#import "RootViewController.h"
#import <SalesforceSDKCore/SFAccountManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceOAuth/SFOAuthInfo.h>

// Fill these in when creating a new Connected Application on Force.com
static NSString * const RemoteAccessConsumerKey = @"3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";
static NSString * const OAuthRedirectURI        = @"testsfdc:///mobilesdk/detect/oauth/done";

@interface AppDelegate ()

/**
 * Success block to call when authentication completes.
 */
@property (nonatomic, copy) SFOAuthFlowSuccessCallbackBlock initialLoginSuccessBlock;

/**
 * Failure block to calls if authentication fails.
 */
@property (nonatomic, copy) SFOAuthFlowFailureCallbackBlock initialLoginFailureBlock;

/**
 * Handles the notification from SFAuthenticationManager that a logout has been initiated.
 * @param notification The notification containing the details of the logout.
 */
- (void)logoutInitiated:(NSNotification *)notification;

/**
 * Handles the notification from SFAuthenticationManager that the login host has changed in
 * the Settings application for this app.
 * @param The notification whose userInfo dictionary contains:
 *        - kSFLoginHostChangedNotificationOriginalHostKey: The original host, prior to host change.
 *        - kSFLoginHostChangedNotificationUpdatedHostKey: The updated (new) login host.
 */
- (void)loginHostChanged:(NSNotification *)notification;

/**
 * Convenience method for setting up the main UIViewController and setting self.window's rootViewController
 * property accordingly.
 */
- (void)setupRootViewController;

/**
 * (Re-)sets the view state when the app first loads (or post-logout).
 */
- (void)initializeAppViewState;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize initialLoginSuccessBlock = _initialLoginSuccessBlock;
@synthesize initialLoginFailureBlock = _initialLoginFailureBlock;

- (id)init
{
    self = [super init];
    if (self) {
        [SFLogger setLogLevel:SFLogLevelDebug];
        
        // These SFAccountManager settings are the minimum required to identify the Connected App.
        [SFAccountManager setClientId:RemoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:OAuthRedirectURI];
        [SFAccountManager setScopes:[NSSet setWithObjects:@"api", nil]];
        
        // Logout and login host change handlers.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutInitiated:) name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginHostChanged:) name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
        
        // Blocks to execute once authentication has completed.  You could define these at the different boundaries where
        // authentication is initiated, if you have specific logic for each case.
        __weak AppDelegate *weakSelf = self;
        self.initialLoginSuccessBlock = ^(SFOAuthInfo *info) {
            [weakSelf setupRootViewController];
        };
        self.initialLoginFailureBlock = ^(SFOAuthInfo *info, NSError *error) {
            [[SFAuthenticationManager sharedManager] logout];
        };
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
}

#pragma mark - App delegate lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self initializeAppViewState];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
    
    return YES;
}

#pragma mark - Private methods

- (void)initializeAppViewState
{
    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
}

- (void)setupRootViewController
{
    RootViewController *rootVC = [[RootViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navVC;
}

- (void)logoutInitiated:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    [self initializeAppViewState];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
}

- (void)loginHostChanged:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Login host changed notification received.  Resetting app."];
    [self initializeAppViewState];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
}

@end
