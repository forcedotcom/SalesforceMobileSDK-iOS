/*
 SFSDKRootController.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/24/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKRootController.h"
#import "SFSDKWindowManager.h"
@interface SFSDKRootController ()

@end

@implementation SFSDKRootController

-(BOOL)prefersStatusBarHidden {
    
    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    if (topViewController && topViewController!=self) {
        return [topViewController prefersStatusBarHidden];
    }
    return NO;
}

-(UIStatusBarStyle)preferredStatusBarStyle
{

    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleDefault;
    if (topViewController && topViewController!=self) {
        statusBarStyle = [topViewController preferredStatusBarStyle];
    }
    return statusBarStyle;
}

-(UIViewController *)childViewControllerForStatusBarStyle
{
    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    if (topViewController && topViewController!=self) {
        return [topViewController childViewControllerForStatusBarStyle];
    }
    return nil;
}

-(UIViewController *)childViewControllerForStatusBarHidden {
    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    if (topViewController && topViewController!=self) {
        return [topViewController childViewControllerForStatusBarHidden];
    }
    return nil;
}

-(BOOL)shouldAutorotate
{
    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    if (topViewController!=nil && topViewController!=self)
        return [topViewController shouldAutorotate];
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    UIViewController *topViewController = [SFSDKRootController topViewController:self];
    if (topViewController!=nil && topViewController!=self)
        return [topViewController supportedInterfaceOrientations];
    
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Helper class methods
+ (UIViewController *)topViewController:(SFSDKRootController *) controller
{
    return [SFSDKWindowContainer topViewControllerWithRootViewController:controller];
}

@end
