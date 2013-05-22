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

@interface SFRootViewManager ()
{
    
}

/**
 The view controller representing the "uber" view state to display.
 */
@property (nonatomic, strong) UIViewController *viewController;

/**
 The original root view controller of the key window.
 */
@property (nonatomic, strong) UIViewController *origViewController;

/**
 Whether or not the new view state is being displayed.
 */
@property (nonatomic, assign, readwrite) BOOL newViewIsDisplayed;

/**
 Whether or not the original view controller is a controller presented by the rootViewController
 hierarchy of the key window.  How the new view state will be presented is dependent on this
 paradigm.
 */
@property (nonatomic, assign) BOOL origViewControllerIsAPresentedController;

@end

@implementation SFRootViewManager

@synthesize viewController = _viewController;
@synthesize origViewController = _origViewController;
@synthesize newViewIsDisplayed = _newViewIsDisplayed;
@synthesize origViewControllerIsAPresentedController = _origViewControllerIsAPresentedController;

- (id)initWithViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        NSAssert(viewController != nil, @"viewController argument cannot be nil.");
        self.viewController = viewController;
        self.newViewIsDisplayed = NO;
    }
    
    return self;
}

- (void)dealloc
{
    self.viewController = nil;
    self.origViewController = nil;
}

//
// NB: There are a number of edge cases that don't play nicely with this approach, all of them having
// to do one way or another with the presentation of modal views (UIAlertView, UIActionSheet, popover
// views) in the old view at the time of showing the new view.  This approach covers a lot of standard
// ground, but implementing an approach with an alternate UIWindow may yield more comprehensive results.
// Whatever the implementation, it promises to be complex.  As of iOS 6.1, Apple simply does not make
// the presentation of an "uber" view easy to implement on the edges.
//

- (void)showNewView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showNewView];
        });
        return;
    }
    
    if (self.newViewIsDisplayed) {
        [self log:SFLogLevelWarning msg:@"Alternate view is already being displayed.  No action taken."];
        return;
    }
    
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    self.origViewController = keyWindow.rootViewController;
    while (self.origViewController.presentedViewController != nil) {
        self.origViewControllerIsAPresentedController = YES;
        self.origViewController = self.origViewController.presentedViewController;
    }
    
    if (self.origViewControllerIsAPresentedController) {
        [self log:SFLogLevelDebug format:@"Root view controller is presenting another controller (%@).  Will present the new controller (%@) from the currently presented controller.", NSStringFromClass([self.origViewController class]), NSStringFromClass([self.viewController class])];
        [self.origViewController presentViewController:self.viewController animated:YES completion:^ {
            [self log:SFLogLevelDebug msg:@"showNewView: new view controller modal presentation complete."];
        }];
    } else {
        NSString *origRvcClassName = (self.origViewController == nil ? @"NONE" : NSStringFromClass([self.origViewController class]));
        [self log:SFLogLevelDebug format:@"Replacing root view controller (%@) with alternate (%@).", origRvcClassName, NSStringFromClass([self.viewController class])];
        // Leaving animations out for now.  We can revisit if and how we might want to animate view transitions in the future.
        //[UIView transitionWithView:keyWindow
        //                  duration:0.5
        //                   options:UIViewAnimationOptionTransitionFlipFromBottom
        //                animations:^ {
                            keyWindow.rootViewController = self.viewController;
        //                }
        //                completion:^(BOOL finished) {
        //                    [self log:SFLogLevelDebug msg:@"showNewView: root view controller replacement complete."];
        //                }];
    }
    
    self.newViewIsDisplayed = YES;
}

- (void)restorePreviousView
{
    if (!self.newViewIsDisplayed) {
        [self log:SFLogLevelWarning msg:@"No alternate view was established in the first place.  No action taken."];
        return;
    }
    
    if (self.origViewControllerIsAPresentedController) {
        [self log:SFLogLevelDebug format:@"Dismissing presented view controller (%@).", NSStringFromClass([self.viewController class])];
        [self.origViewController dismissViewControllerAnimated:YES completion:^ {
            [self log:SFLogLevelDebug msg:@"restorePreviousView: dismissal of modal view controller presentation complete."];
        }];
    } else {
        NSString *origRvcClassName = (self.origViewController == nil ? @"NONE" : NSStringFromClass([self.origViewController class]));
        [self log:SFLogLevelDebug format:@"Restoring original root view controller (%@).", origRvcClassName];
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        // Leaving animations out for now.  We can revisit if and how we might want to animate view transitions in the future.
        //[UIView transitionWithView:keyWindow
        //                  duration:0.5
        //                   options:UIViewAnimationOptionTransitionFlipFromBottom
        //                animations:^ {
                            keyWindow.rootViewController = self.origViewController;
        //                }
        //                completion:^(BOOL finished) {
        //                    [self log:SFLogLevelDebug msg:@"restorePreviousView: reverting of root view controller complete."];
        //                }];
    }
    
    self.origViewController = nil;
    self.origViewControllerIsAPresentedController = NO;
    self.newViewIsDisplayed = NO;
}

@end
