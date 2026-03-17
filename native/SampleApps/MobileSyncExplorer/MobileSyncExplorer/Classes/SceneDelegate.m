/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

#import "SceneDelegate.h"
#import "InitialViewController.h"
#import "ContactListViewController.h"

@import SalesforceSDKCommon;
@import SalesforceSDKCore;
@import MobileSync;

@interface SceneDelegate ()

/**
 * Convenience method for setting up the main UIViewController and setting self.window's rootViewController
 * property accordingly.
 */
- (void)setupRootViewController;

/**
 * (Re-)sets the view state when the app first loads (or post-logout).
 */
- (void)initializeAppViewState;

/**
 * Resets the view state with a completion block.
 */
- (void)resetViewState:(void (^)(void))postResetBlock;

/**
 * Updates the user login status in user defaults.
 */
- (void)resetUserloginStatus;

@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[SFSDKUIWindow alloc] initWithWindowScene:windowScene];

    // App Setup for any changes to the current authenticated user
    __weak typeof(self) weakSelf = self;
    [SFSDKAuthHelper registerBlockForCurrentUserChangeNotifications:scene completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf resetUserloginStatus];
        [strongSelf resetViewState:^{
            [strongSelf setupRootViewController];
        }];
    }];

    [self initializeAppViewState];

    [SFSDKAuthHelper loginIfRequired:scene completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf resetUserloginStatus];
        [strongSelf setupRootViewController];
    }];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    // Uncomment following block to enable IDP Login flow
    // UIOpenURLContext *urlContext = URLContexts.anyObject;
    // if (urlContext) {
    //     [[SFUserAccountManager sharedInstance] handleIdentityProviderResponse:urlContext.URL
    //         withOptions:@{kSFUserAccountManagerSceneKey: scene.session.persistentIdentifier}];
    // }
}

#pragma mark - Private methods

- (void)resetUserloginStatus {
    BOOL loggedIn = [SFUserAccountManager.sharedInstance currentUser] != nil;
    [[NSUserDefaults msdkUserDefaults] setBool:loggedIn forKey:@"userLoggedIn"];
    [[NSUserDefaults msdkUserDefaults] synchronize];
    [SFSDKMobileSyncLogger log:[self class] level:SFLogLevelDebug format:@"%d userLoggedIn", [[NSUserDefaults msdkUserDefaults] boolForKey:@"userLoggedIn"]];
}

- (void)initializeAppViewState {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeAppViewState];
        });
        return;
    }

    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
}

- (void)setupRootViewController {
    ContactListViewController *rootVC = [[ContactListViewController alloc] initWithStyle:UITableViewStylePlain];
    SFSDKNavigationController *navVC = [[SFSDKNavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navVC;
}

- (void)resetViewState:(void (^)(void))postResetBlock {
    if ([self.window.rootViewController presentedViewController]) {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
            postResetBlock();
        }];
    } else {
        postResetBlock();
    }
}

@end
