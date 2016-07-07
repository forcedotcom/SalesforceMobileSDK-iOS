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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SFRootViewManager;

/**
 Delegate of the root view manager
 */
@protocol SFRootViewManagerDelegate <NSObject>

@optional

/**
 Called when the root view manager is going to push a view controller
 @param manager The root view manager performing the action
 @param viewController The view controller that is going to be pushed
 */
- (void)rootViewManager:(SFRootViewManager*)manager willPushViewControler:(UIViewController*)viewController;

/**
 Called when the root view manager is did pop a view controller
 @param manager The root view manager performing the action
 @param viewController The view controller that got dismissed
 */
- (void)rootViewManager:(SFRootViewManager*)manager didPopViewControler:(UIViewController*)viewController;

@end
/**
 Class to control the presentation of temporary modal views in an existing view stack.  Used
 internally for things like the authentication view and the passcode screen.
 */
@interface SFRootViewManager : NSObject

/**
 @return The singleton SFRootViewManager object.
 */
+ (SFRootViewManager *)sharedManager;

/**
 The main window of the application.  If not explicitly set, defaults to `[UIApplication sharedApplication].windows[0]`.
 */
@property (nonatomic, strong) UIWindow *mainWindow;

/**
 Add a delegate
 @param delegate The delegate to add
 */
- (void)addDelegate:(id<SFRootViewManagerDelegate>)delegate;

/**
 Remove a delegate
 @param delegate The delegate to remove
 */
- (void)removeDelegate:(id<SFRootViewManagerDelegate>)delegate;

/**
 Push a view controller onto the top of the presentation stack.
 @param viewController The view controller to display.
 */
- (void)pushViewController:(UIViewController *)viewController;

/**
 Take a view controller off of the presentation stack.
 @param viewController The view to remove.  Does nothing if the view controller is not found in the presented stack.
 */
- (void)popViewController:(UIViewController *)viewController;

@end
