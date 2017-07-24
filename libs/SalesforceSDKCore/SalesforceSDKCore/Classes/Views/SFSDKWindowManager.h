/*
 SFUIWindowManager.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SFSDKWindowContainer.h"
@class SFSDKWindowManager;
/**
 Delegate of the SFSDKWindowManager
 */
@protocol SFWindowManagerDelegate <NSObject>

@optional
/**
 Called when the window is going to be brought to the front
 @param windowManager The window manager making this call
 @param window The window that is going to be brought to the front
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager willBringToFront:(SFSDKWindowContainer *)window;

/**
 Called when the window was brought to the front
 @param windowManager The window manager making this call
 @param window The window that was brought to the front
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager didBringToFront:(SFSDKWindowContainer *)window;

/**
 Called when the controller will be presented.
 @param windowManager The window manager making this call
 @param window The window that will be used to present a controller
 @param controller The controller that will be presented
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager willPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called when the controller is presented.
 @param windowManager The window manager making this call
 @param window The window that was used to present a controller
 @param controller The controller that was presented
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager didPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called when the controller will be be dismissed.
 @param windowManager The window manager making this call
 @param window The window that will be used to dismiss a controller
 @param controller The controller that was presented
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager willPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called when the controller is dismissed
 @param windowManager The window manager making this call
 @param window The window that was used to dismiss a controller
 @param controller The controller that was dismissed
 */
- (void)windowManager:(SFSDKWindowManager*)windowManager didPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;
@end

@interface SFSDKWindowManager : NSObject

/** SDK uses this window to present the login flow.
 */
@property(readonly,strong) SFSDKWindowContainer *authWindow;

/** SDK uses this window to present the snapshot View.
 */
@property(readonly,nonatomic,strong) SFSDKWindowContainer *snapshotWindow;

/** SDK uses this window to present the passocde View.
 */
@property(readonly,nonatomic,strong) SFSDKWindowContainer *passcodeWindow;

/** Use this to customize the snapshotview
 */
@property(nonatomic,strong) UIViewController *snapshotViewController;

@property (nonatomic, strong,readonly) NSMapTable<NSString *,SFSDKWindowContainer *> *namedWindows;

/** Api to push viewcontroller into a given window. BringtoFront the window & then push
 */
- (void)pushViewController:(UIViewController *)controller window:(SFSDKWindowContainer *)window withCompletion:(void (^)(void))completion;

/** Api to pop viewcontroller from a given window.
 */
- (void)popViewController:(UIViewController *)controller window:(SFSDKWindowContainer *)window withCompletion:(void (^)(void))completion;

/** Returns the SFSDKWindowContainer window representing the mainWindow that has been set
 */
- (SFSDKWindowContainer *)mainWindow;

/** Used to setup the main application window.
 */
- (void)setMainWindow:(UIWindow *)window;

/** Used to create a new Window keyed by a  specified name
 */
- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName;

/** Used to remove a  Window by a  specified name
 */
- (BOOL)removeNamedWindow:(NSString *)windowName;

/** Used to retrieve a Window by a  specified name
 */
- (SFSDKWindowContainer *)windowWithName:(NSString *)name;

///** Dictionary of all managed windows
// */
//- (NSDictionary<NSString *,SFSDKWindowContainer *> *)namedWindows;

/** Used to make a window Key and Visible.
 */
- (void)bringToFront:(SFSDKWindowContainer *)windowContainer;

/** Restore previously active window
 */
- (void) restorePreviousActiveWindow;

/** Add a Window Manager Delegate
 */
- (void)addDelegate:(id<SFWindowManagerDelegate>)delegate;

/** Remove a Window Manager Delegate
 */
- (void)removeDelegate:(id<SFWindowManagerDelegate>)delegate;

+ (instancetype)sharedManager;

@end
