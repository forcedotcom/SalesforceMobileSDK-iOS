/*
 SFSDKWindowContainer.h
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

typedef NS_ENUM(NSInteger, SFSDKWindowType) {
    SFSDKWindowTypeMain,
    SFSDKWindowTypeAuth,
    SFSDKWindowTypePasscode,
    SFSDKWindowTypeSnapshot,
    SFSDKWindowTypeOther
};
@class SFSDKWindowContainer;

@protocol SFSDKWindowContainerDelegate<NSObject>

@optional

/**
 Called when the window is going to be made key & visible
 @param window The window that is going to be made key & visible
 */
- (void)windowWillMakeKeyVisible:(SFSDKWindowContainer *)window;

/**
 Called when the window was made key & visible
 @param window The window that was made key & visible
 */
- (void)windowDidMakeKeyVisible:(SFSDKWindowContainer *)window;

/**
 Called when the controller will be pushed
 @param window The window that will be used
 @param controller The controller that will be presented by the window
 */
- (void)windowWillPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called when the controller was pushed
 @param window The window that will be used
 @param controller The controller that was presented by the window
 */
- (void)windowDidPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called prior to the controller being dimissed
 @param window The window that will be used
 @param controller The controller that will be dismissed from the window
 */
- (void)windowWillPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;

/**
 Called after the controller was dimissed
 @param window The window that will be used
 @param controller The controller that was dismissed from the window
 */
- (void)windowDidPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller;
@end

@interface SFSDKWindowContainer : NSObject
/** Underlying Window that is wrapped by this container
 */
@property (nonatomic, strong) UIWindow *window;

/** UIWindowLevel for the window
 */
@property (nonatomic, assign) UIWindowLevel windowLevel;

/** SFSDKWindowType for the window
 */
@property (nonatomic, assign) SFSDKWindowType windowType;

/** SFSDKWindowType windowName
 */
@property (nonatomic, copy, readonly) NSString *windowName;

/**
 Create an instance of a Window
 @param window An instance of UIWindow
 @param windowName key for the UIWindow
 @return SFSDKWindowComtainer
 */
- (instancetype)initWithWindow:(UIWindow *) window andName:(NSString *) windowName;

/** Add a Window Container delegate
 * @param delegate to add
 */
- (void)addDelegate:(id<SFSDKWindowContainerDelegate>)delegate;

/** Remove a Window Container delegate
 * @param delegate to remove
 */
- (void)removeDelegate:(id<SFSDKWindowContainerDelegate>)delegate;

/** Push(present) a View Controller
 * @param controller to push
 */
- (void)pushViewController:(UIViewController *)controller;

/** Pop(dismiss) a View Controller
 * @param controller to pop
 */
- (void)popViewController:(UIViewController *)controller;

/** Push(present) a View Controller and invoke completion block when done
 @param controller to push
 @param animated animate or not
 @param completion to invoke when done
 */
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;

/** Pop(dismiss) a View Controller and invoke completion block when done
 * @param controller to pop
 * @param animated animate or not
 * @param completion to invoke when done
 */
- (void)popViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;

/**
 * Bring this window to the front (set its Z-Order value) and make key visible
 */
- (void)makeKeyVisible;

/**
 * Bring this window to the front (unset its Z-Order value)
 */
- (void)sendToBack;

/** Convenience API returns true if the SFSDKWindowType is main
 * @return YES if this is the main Window
 */
- (BOOL)isMainWindow;

/** Convenience API returns true if the SFSDKWindowType is auth
 * @return YES if this is the auth Window
 */
- (BOOL)isAuthWindow;

/** Convenience API returns true if the SFSDKWindowType is snapshot
 * @return YES if this is the snapshot Window
 */
- (BOOL)isSnapshotWindow;

/** Convenience API returns true if the SFSDKWindowType is passcode
 * @return YES if this is the passcode Window
 */
- (BOOL)isPasscodeWindow;


@end
