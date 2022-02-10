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
#import <SalesforceSDKCore/SFSDKWindowContainer.h>
@class SFSDKWindowManager;
/**
 Delegate of the SFSDKWindowManager
 */
@protocol SFSDKWindowManagerDelegate <NSObject>

@optional
/**
 Called when the window will be made opaque
 @param windowManager The window manager making this call
 @param window The window that will be made opaque
 */
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
    willPresentWindow:(SFSDKWindowContainer *_Nonnull)window;

/**
 Called when the window has been made opaque
 @param windowManager The window manager making this call
 @param window The window that has been made opaque
 */
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
     didPresentWindow:(SFSDKWindowContainer *_Nonnull)window;

/**
 Called when the window will be made transparent
 @param windowManager The window manager making this call
 @param window The window will be made transparent
 */
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
    willDismissWindow:(SFSDKWindowContainer *_Nonnull)window;

/**
 Called when the window is made transparent
 @param windowManager The window manager making this call
 @param window The window that has been made transparent
 */
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
     didDismissWindow:(SFSDKWindowContainer *_Nonnull)window;
@end

@interface SFSDKUIWindow : UIWindow
- (instancetype _Nonnull)initWithFrame:(CGRect)frame;
- (instancetype _Nonnull)initWithFrame:(CGRect)frame andName:(NSString *_Nonnull)windowName;
@property (nonatomic,strong) UIViewController * _Nullable stashedController;
@property (nonatomic,readonly) NSString * _Nullable windowName;
@end

@interface SFSDKWindowManager : NSObject

/** Sets overrideUserInterfaceStyle on managed windows. Default is UIUserInterfaceStyleUnspecified.
 */
@property (nonatomic, assign) UIUserInterfaceStyle userInterfaceStyle;

/** SDK uses this window to present the screen lock view.
 */
- (nonnull SFSDKWindowContainer *)screenLockWindow;

/** SDK uses this window to present the login flow for the given scene. Defaults a connected scene if one isn't provided.
 */
- (nonnull SFSDKWindowContainer *)authWindow:(nullable UIScene *)scene;

/** SDK uses this window to present the snapshot view for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (nonnull SFSDKWindowContainer *)snapshotWindow:(nullable UIScene *)scene;

/** Returns the SFSDKWindowContainer window representing the mainWindow that has been set for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (nonnull SFSDKWindowContainer *)mainWindow:(nullable UIScene *)scene;

/** Returns the SFSDKWindowContainer window representing the active presented window that has been set for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (nullable SFSDKWindowContainer *)activeWindow:(nullable UIScene *)scene;

/** Used to setup the main application window.
 */
- (void)setMainUIWindow:(UIWindow *_Nonnull)window;

/** Used to setup the main window for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (void)setMainUIWindow:(nonnull UIWindow *)window scene:(nullable UIScene *)scene;

/** Used to create a new Window keyed by a specified name
 */
- (SFSDKWindowContainer *_Nullable)createNewNamedWindow:(NSString *_Nonnull)windowName;

/** Used to create a new window keyed by a specified name for a given scene. Defaults to a  connected scene if one isn't provided.
 */
- (nullable SFSDKWindowContainer *)createNewNamedWindow:(nonnull NSString *)windowName scene:(nullable UIScene *)scene;

/** Used to remove a Window by a specified name
 */
- (BOOL)removeNamedWindow:(NSString *_Nonnull)windowName;

/** Used to remove a window by a specified name for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (BOOL)removeNamedWindow:(nonnull NSString *)windowName scene:(nullable UIScene *)scene;

/** Used to retrieve a Window by a specified name
 */
- (SFSDKWindowContainer *_Nullable)windowWithName:(NSString *_Nonnull)name;

/** Used to retrieve a window by a specified name for a given scene. Defaults to a connected scene if one isn't provided.
 */
- (nullable SFSDKWindowContainer *)windowWithName:(nonnull NSString *)name scene:(nullable UIScene *)scene;

/** Add a Window Manager Delegate
 */
- (void)addDelegate:(id<SFSDKWindowManagerDelegate>_Nonnull)delegate;

/** Remove a Window Manager Delegate
 */
- (void)removeDelegate:(id<SFSDKWindowManagerDelegate>_Nonnull)delegate;

+ (instancetype _Nonnull)sharedManager;

@end
