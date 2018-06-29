/*
 SFSDKWindowContainer.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/4/17.
 
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
#import "SFSDKWindowContainer.h"
#import "SFSDKWindowManager.h"
#import "SFSDKRootController.h"
@interface SFSDKWindowContainer()

@end

@implementation SFSDKWindowContainer
@synthesize window = _window;

- (instancetype)initWithName:(NSString *)windowName {
    self = [super init];
    if (self) {
        _windowName = windowName;
    }
    return self;
}

- (instancetype)initWithWindow:(UIWindow *)window name:(NSString *) windowName {
    self = [super init];
    if (self) {
        _window = window;
        _windowName = windowName;
        _viewController = window.rootViewController;
    }
    return self;
}

- (UIWindow *)window {
    if (_window == nil) {
        _window = [[SFSDKUIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds  andName:_windowName];
        _window.windowLevel = self.windowLevel;
        UIViewController *controller = _viewController;
        if (!controller) {
            controller = [[SFSDKRootController alloc] init];
        }
        self.viewController = controller;
    }
    return _window;
}

- (void)setViewController:(UIViewController *) viewController {
    if (_viewController != viewController) {
        _viewController = viewController;
        if (_window) {
            _window.rootViewController = viewController;
        }
    }
}

- (void)presentWindow {
    [self presentWindowAnimated:NO withCompletion:nil];
}

- (BOOL)isEnabled {
    return _window && _window.isKeyWindow;
}

- (void)presentWindowAnimated:(BOOL)animated withCompletion:(void (^ _Nullable)(void))completion {
    if ([self.windowDelegate respondsToSelector:@selector(presentWindow:animated:withCompletion:)]) {
        [self.windowDelegate presentWindow:self animated:animated withCompletion:completion];
    }
}

- (void)dismissWindow {
    [self dismissWindowAnimated:NO withCompletion:nil];
}

- (void)dismissWindowAnimated:(BOOL)animated withCompletion:(void (^ _Nullable)(void))completion {
    if ([self isEnabled]) {
        if ([self.windowDelegate respondsToSelector:@selector(dismissWindow:animated:withCompletion:)]) {
            [self.windowDelegate dismissWindow:self animated:animated withCompletion:completion];
        }
    }
}

- (BOOL)isMainWindow {
    return _windowType == SFSDKWindowTypeMain;
}

- (BOOL)isAuthWindow {
    return _windowType == SFSDKWindowTypeAuth;
}


- (BOOL)isSnapshotWindow {
    return _windowType == SFSDKWindowTypeSnapshot;
}

- (BOOL)isPasscodeWindow {
    return _windowType == SFSDKWindowTypePasscode;
}

- (UIViewController*)topViewController {
    return [SFSDKWindowContainer topViewControllerWithRootViewController:_window.rootViewController];
}

+ (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)viewController {
    if ([viewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*)viewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    } else if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navContObj = (UINavigationController*)viewController;
        return [self topViewControllerWithRootViewController:navContObj.visibleViewController];
    } else if (viewController.presentedViewController && !viewController.presentedViewController.isBeingDismissed) {
        UIViewController* presentedViewController = viewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    else {
        for (UIView *view in [viewController.view subviews])
        {
            id subViewController = [view nextResponder];
            if ( subViewController && [subViewController isKindOfClass:[UIViewController class]])
            {
                if ([(UIViewController *)subViewController presentedViewController]  && ![subViewController presentedViewController].isBeingDismissed) {
                    return [self topViewControllerWithRootViewController:[(UIViewController *)subViewController presentedViewController]];
                }
            }
        }
        return viewController;
    }
}

@end
