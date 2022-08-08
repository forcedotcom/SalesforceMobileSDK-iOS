/*
 SFSDKAuthHelper.m
 SalesforceSDKCore
 
 Created by Raj Rao on 07/19/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import "SalesforceSDKManager.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFSDKAppConfig.h"
#import "SFSDKAuthHelper.h"
#import "SFUserAccountManager.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKWindowManager.h"
#import "SFSDKWindowManager+Internal.h"
#import "SFDefaultUserManagementViewController.h"
#import "SFApplicationHelper.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

@implementation SFSDKAuthHelper

+ (void)loginIfRequired:(void (^)(void))completionBlock {
    UIScene *scene = [[SFSDKWindowManager sharedManager] defaultScene];
    [SFSDKAuthHelper loginIfRequired:scene completion:completionBlock];
}

+ (void)loginIfRequired:(UIScene *)scene completion:(void (^)(void))completionBlock {
    [SFSDKAuthHelper registerBlockForLoginNotification:^{
        if (completionBlock) {
            completionBlock();
        }
    }];

    if (![SFUserAccountManager sharedInstance].currentUser && [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate) {
        SFUserAccountManagerFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *authError) {
            [SFSDKCoreLogger e:[self class] format:@"Authentication failed: %@.", [authError localizedDescription]];
        };
        BOOL result = [[SFUserAccountManager sharedInstance] loginWithCompletion:nil failure:failureBlock scene:scene];
        if (!result) {
            [[SFUserAccountManager sharedInstance] stopCurrentAuthentication:^(BOOL result) {
                [[SFUserAccountManager sharedInstance] loginWithCompletion:nil failure:failureBlock scene:scene];
            }];
        }
    } else {
        [self screenLockValidation:completionBlock];
    }
}

+(void)screenLockValidation:(void (^)(void))completionBlock  {
    [[SFScreenLockManager shared] setCallbackBlockWithScreenLockCallbackBlock:^{
            [SFSDKCoreLogger i:[self class] format:@"Screen unlocked or not configured.  Proceeding with authentication validation."];
            if (completionBlock) {
                completionBlock();
            }
    }];
    [[SFScreenLockManager shared] handleAppForeground];
}

+ (void)handleLogout:(void (^)(void))completionBlock {
    UIScene *scene = [[SFSDKWindowManager sharedManager] defaultScene];
    [SFSDKAuthHelper handleLogout:scene completion:completionBlock];
}

+ (void)handleLogout:(UIScene *)scene completion:(void (^)(void))completionBlock {
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
            [[[SFSDKWindowManager sharedManager] mainWindow:scene].window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
        }];
        [[[SFSDKWindowManager sharedManager] mainWindow:scene].window.rootViewController presentViewController:userSwitchVc animated:YES completion:NULL];
    } else {
        if ([allAccounts count] == 1) {
            [[SFUserAccountManager sharedInstance] switchToUser:([SFUserAccountManager sharedInstance].allUserAccounts)[0]];
            if (completionBlock) {
                completionBlock();
            }
        } else {
            [self loginIfRequired:scene completion:completionBlock];
        }
    }
}

+ (void)registerBlockForLoginNotification:(void (^)(void))completionBlock {
    [[NSNotificationCenter defaultCenter] addObserverForName:kSFNotificationUserDidLogIn object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
           if (completionBlock) {
               completionBlock();
           }
       }];
}

+ (void)registerBlockForCurrentUserChangeNotifications:(void (^)(void))completionBlock {
    UIScene *scene = [[SFSDKWindowManager sharedManager] defaultScene];
    [SFSDKAuthHelper registerBlockForCurrentUserChangeNotifications:scene completion:completionBlock];
}

+ (void)registerBlockForCurrentUserChangeNotifications:(UIScene *)scene completion:(void (^)(void))completionBlock {
    [self registerBlockForLogoutNotifications:scene completion:completionBlock];
    [self registerBlockForSwitchUserNotifications:completionBlock];
}

+ (void)registerBlockForLogoutNotifications:(void (^)(void))completionBlock {
    UIScene *scene = [[SFSDKWindowManager sharedManager] defaultScene];
    [SFSDKAuthHelper registerBlockForLogoutNotifications:scene completion:completionBlock];
}

+ (void)registerBlockForLogoutNotifications:(UIScene *)scene completion:(void (^)(void))completionBlock {
    __weak typeof (self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:kSFNotificationUserDidLogout object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf handleLogout:scene completion:completionBlock];
    }];
}

+ (void)registerBlockForSwitchUserNotifications:(void (^)(void))completionBlock {
    [[NSNotificationCenter defaultCenter] addObserverForName:kSFNotificationUserDidSwitch object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        if (completionBlock) {
            completionBlock();
        }
    }];
}

@end
