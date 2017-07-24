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

@interface SFSDKWindowContainer() {
    UIViewController *_modalViewController;
}
@property (nonatomic, strong) NSMutableOrderedSet *delegates;
@end

@implementation SFSDKWindowContainer
@synthesize window = _window;
@synthesize windowLevel = _windowLevel;

- (instancetype)initWithWindow:(UIWindow *)window andName:(NSString *) windowName {
    
    self = [super init];
    if (self) {
        _delegates = [NSMutableOrderedSet orderedSet];
        _window = window;
        _windowName = windowName;
    }
    return self;
}

- (void) setWindowLevel:(UIWindowLevel)windowLevel {
    if (windowLevel !=_windowLevel){
        _windowLevel = windowLevel;
        self.window.windowLevel = _windowLevel;
    }
}

- (void)pushViewController:(UIViewController *)controller {
    [self pushViewController:controller animated:NO completion:nil];
}

- (void)popViewController:(UIViewController *)controller {
    [self popViewController:controller animated:NO completion:nil];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)flag completion:(void (^)(void))completion {
    
    if (!viewController)
        return;
    
    __weak typeof(self) weakSelf = self;
    
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf pushViewController:viewController animated:flag completion:completion];
        });
        return;
    }
    
    
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowWillPushViewController:controller:)]) {
            [delegate windowWillPushViewController:weakSelf controller:viewController];
        }
    }];
    
    if (!self.window.rootViewController) {
        
        if ([viewController isKindOfClass:UIAlertController.class]) {
            UIViewController *blankViewController = [[UIViewController alloc] init];
            [[blankViewController view] setBackgroundColor:[UIColor clearColor]];
            self.window.rootViewController = blankViewController;
            [blankViewController presentViewController:viewController animated:NO completion:^{
                
            }];
        } else {
            self.window.rootViewController = viewController;
        }
        
        if (completion)
            completion();
        
        return;
    }
    
    UIViewController *currentViewController = self.window.rootViewController;
    while (currentViewController.presentedViewController != nil
           && !currentViewController.presentedViewController.isBeingDismissed) {
        //stop if we find that an alert has been presented
        if ([self alertIsPresented:currentViewController]) {
            [self saveAlert:currentViewController.presentedViewController];
            break;
        }
        currentViewController = currentViewController.presentedViewController;
    }
    if (currentViewController) {
        //invoke delegates and then present
        if (currentViewController!=viewController)
            [currentViewController presentViewController:viewController animated:NO completion:completion];
    }
    else {
        self.window.rootViewController = viewController;
        if (completion)
            completion();
    }
    
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowDidPushViewController:controller:)]) {
            [delegate windowDidPushViewController:weakSelf controller:viewController];
        }
    }];
    
}

- (void)popViewController:(UIViewController *)viewController animated:(BOOL)flag completion:(void (^)(void))completion {
    
    __weak typeof(self) weakSelf = self;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf popViewController:viewController animated:flag completion:completion];
        });
        return;
    }
    
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowWillPopViewController:controller:)]) {
            [delegate windowWillPushViewController:weakSelf controller:viewController];
        }
    }];
    
    UIViewController *currentViewController = self.window.rootViewController;
    if (viewController && currentViewController != viewController) {
        // look for controller
        while (currentViewController && currentViewController.presentedViewController!=viewController) {
            currentViewController = currentViewController.presentedViewController;
        }
        // if controller is found dismiss the view, invoke delegates && restore Alerts if required.
        if (viewController == currentViewController.presentedViewController) {
            [self dismissPresentedViewController:currentViewController dismissViewControllerAnimated:flag completion:completion];
        }
    } else {
        self.window.rootViewController = nil;
        if (completion)
            completion();
    }
    
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowDidPopViewController:controller:)]) {
            [delegate windowWillPushViewController:weakSelf controller:viewController];
        }
    }];
    
}

- (void)makeKeyVisible {
    __weak typeof(self) weakSelf = self;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf makeKeyVisible];
        });
        return;
    }
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowWillMakeKeyVisible:)]) {
            [delegate windowWillMakeKeyVisible:weakSelf];
        }
    }];
    
    [self.window setWindowLevel:_windowLevel];
    [self.window setHidden:NO];
    [self.window makeKeyWindow];
    [self enumerateDelegates:^(id<SFSDKWindowContainerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowDidMakeKeyVisible:)]) {
            [delegate windowDidMakeKeyVisible:weakSelf];
        }
    }];
    
}

- (void)sendToBack {
    self.window.windowLevel = -self.windowLevel;
    [self.window setHidden:YES];
}

// private members

- (BOOL)alertWasPresent{
    return self->_modalViewController?YES:NO;
}

- (BOOL)alertIsPresented:(UIViewController *) current {
    return [current.presentedViewController isKindOfClass:[UIAlertController class]];
}

- (void)saveAlert:(UIViewController *) alert {
    self ->_modalViewController = alert;
    [alert dismissViewControllerAnimated:NO completion:nil];
}

- (void)restoreAlert:(UIViewController *) presentingViewController {
    [presentingViewController presentViewController:self->_modalViewController  animated:NO completion:^{
        self ->_modalViewController = nil;
    }];
}

- (void)presentViewController:(UIViewController *)toBePresented using:(UIViewController *)presentingViewController {
    [presentingViewController presentViewController:toBePresented animated:NO completion:nil];
}

- (void)dismissPresentedViewController :(UIViewController *)presentingViewController dismissViewControllerAnimated:(BOOL) animate completion:(void(^)(void)) completion {
    __weak typeof (self) weakSelf = self;
    [presentingViewController.presentedViewController dismissViewControllerAnimated:NO completion:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if ([strongSelf alertWasPresent]) {
            [strongSelf restoreAlert:presentingViewController];
        }
        if (completion)
            completion();
    }];
}

- (void)addDelegate:(id<SFSDKWindowContainerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFSDKWindowContainerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)enumerateDelegates:(void (^)(id<SFSDKWindowContainerDelegate> delegate))block
{
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFSDKWindowContainerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
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

@end
