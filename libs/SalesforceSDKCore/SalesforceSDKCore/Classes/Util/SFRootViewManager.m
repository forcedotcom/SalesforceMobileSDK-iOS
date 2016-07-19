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

#import "SFRootViewManager.h"
#import "SFApplicationHelper.h"

@interface SFRootViewManager()

@property (nonatomic, weak) UIWindow* previousKeyWindow;
@property (nonatomic, strong) NSMutableOrderedSet *delegates;

@end

@implementation SFRootViewManager

@synthesize mainWindow = _mainWindow;

+ (SFRootViewManager *)sharedManager
{
    static SFRootViewManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SFRootViewManager alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _delegates = [NSMutableOrderedSet orderedSet];
    }
    
    return self;
}

- (UIWindow *)mainWindow
{
    if (_mainWindow == nil) {
        // Try to set a sane value for mainWindow, if it hasn't been set already.
        _mainWindow = [SFApplicationHelper sharedApplication].windows[0];
        if (_mainWindow == nil) {
            [self log:SFLogLevelError format:@"UIApplication has no defined windows."];
        }
    }
    return _mainWindow;
}

- (void)addDelegate:(id<SFRootViewManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFRootViewManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];        
    }
}

- (void)enumerateDelegates:(void (^)(id<SFRootViewManagerDelegate> delegate))block
{
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFRootViewManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
    }
}

//
// NB: There are a number of edge cases that don't play nicely with this approach, all of them having
// to do one way or another with the presentation of modal views (UIAlertView, UIActionSheet, popover
// views) in the old view at the time of showing the new view.  This approach covers a lot of standard
// ground, but implementing an approach with an alternate UIWindow may yield more comprehensive results.
// Whatever the implementation, it promises to be complex.  As of iOS 6.1, Apple simply does not make
// the presentation of an "uber" view easy to implement on the edges.
//

- (void)pushViewController:(UIViewController *)viewController
{
    __weak SFRootViewManager *weakSelf = self;
    void (^pushControllerBlock)(void) = ^{
        UIViewController *currentViewController = weakSelf.mainWindow.rootViewController;
        while (currentViewController.presentedViewController != nil && !currentViewController.presentedViewController.isBeingDismissed) {
            currentViewController = currentViewController.presentedViewController;
        }
        
        if (currentViewController != nil) {
            if (currentViewController != viewController
                && viewController.presentedViewController != currentViewController) {
                [weakSelf log:SFLogLevelDebug format:@"pushViewController: Presenting view controller (%@).", viewController];
                
                [weakSelf enumerateDelegates:^(id<SFRootViewManagerDelegate> delegate) {
                    if ([delegate respondsToSelector:@selector(rootViewManager:willPushViewControler:)]) {
                        [delegate rootViewManager:weakSelf willPushViewControler:viewController];
                    }
                }];
                
                [currentViewController presentViewController:viewController animated:NO completion:NULL];
            } else {
                [weakSelf log:SFLogLevelDebug format:@"pushViewController: View controller (%@) is already presented.", viewController];
            }
        } else {
            [weakSelf log:SFLogLevelDebug format:@"pushViewController: Making view controller (%@) the root view controller.", viewController];
            weakSelf.mainWindow.rootViewController = viewController;
            [self saveCurrentKeyWindow];
            [weakSelf.mainWindow makeKeyAndVisible];
        }
    };
    
    dispatch_async(dispatch_get_main_queue(), pushControllerBlock);
}

- (void)popViewController:(UIViewController *)viewController
{
    __weak SFRootViewManager *weakSelf = self;
    void (^popControllerBlock)(void) = ^{
        UIViewController *currentViewController = weakSelf.mainWindow.rootViewController;
        if (currentViewController == viewController) {
            [weakSelf log:SFLogLevelDebug format:@"popViewController: Removing rootViewController (%@).", viewController];
            weakSelf.mainWindow.rootViewController = nil;
            [self restorePreviousKeyWindow];
        } else {
            while ((currentViewController != nil) && (currentViewController != viewController)) {
                currentViewController = [currentViewController presentedViewController];
            }
            
            if (currentViewController == nil) {
                [weakSelf log:SFLogLevelDebug format:@"popViewController: View controller (%@) not found in the view controller stack.  No action taken.", viewController];
            } else {
                [weakSelf log:SFLogLevelDebug format:@"popViewController: View controller (%@) is now being dismissed from presentation.", viewController];
                [[currentViewController presentingViewController] dismissViewControllerAnimated:NO completion:^{
                    [weakSelf enumerateDelegates:^(id<SFRootViewManagerDelegate> delegate) {
                        if ([delegate respondsToSelector:@selector(rootViewManager:didPopViewControler:)]) {
                            [delegate rootViewManager:weakSelf didPopViewControler:viewController];                            
                        }
                    }];
                }];
            }
        }
    };
    
    dispatch_async(dispatch_get_main_queue(), popControllerBlock);
}

#pragma mark - Private

- (void)saveCurrentKeyWindow
{
    for (UIWindow* w in [SFApplicationHelper sharedApplication].windows) {
        if ([w isKeyWindow]) {
            self.previousKeyWindow = w;
            break;
        }
    }
}

- (void)restorePreviousKeyWindow
{
    [self.previousKeyWindow makeKeyAndVisible];
    self.previousKeyWindow = nil;
}

@end
