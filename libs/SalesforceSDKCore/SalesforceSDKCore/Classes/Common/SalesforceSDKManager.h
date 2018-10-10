/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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
#import "SalesforceSDKCoreDefines.h"
#import "SalesforceSDKConstants.h"
@class SFUserAccount, SFSDKAppConfig;

/**
 Block typedef for creating a custom snapshot view controller.
 */
typedef UIViewController * __nullable (^SFSnapshotViewControllerCreationBlock)(void)  NS_SWIFT_NAME(SnapshotViewCreationBlock);

typedef NS_ENUM(NSUInteger, SFAppType) {
    kSFAppTypeNative,
    kSFAppTypeHybrid,
    kSFAppTypeReactNative,
    kSFAppTypeNativeSwift
} NS_SWIFT_NAME(AppType);

NS_ASSUME_NONNULL_BEGIN

// User agent constants
static NSString * const kSFMobileSDKNativeDesignator = @"Native";
static NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";
static NSString * const kSFMobileSDKReactNativeDesignator = @"ReactNative";
static NSString * const kSFMobileSDKNativeSwiftDesignator = @"NativeSwift";

/**
 Block typedef for presenting the snapshot view controller.
 */
typedef void (^SFSnapshotViewControllerPresentationBlock)(UIViewController* snapshotViewController) NS_SWIFT_NAME(SnapshotViewDisplayBlock);

/**
 Block typedef for dismissing the snapshot view controller.
 */
typedef void (^SFSnapshotViewControllerDismissalBlock)(UIViewController* snapshotViewController) NS_SWIFT_NAME(SnapshotViewDismissBlock);


/** Delegate protocol for handling foregrounding and backgrounding in Mobile SDK apps.
 */
NS_SWIFT_NAME(SalesforceSDKDelegate)
@protocol SalesforceSDKManagerDelegate <NSObject>

@optional

/**
 Called after UIApplicationWillResignActiveNotification is received
 */
- (void)sdkManagerWillResignActive NS_SWIFT_NAME(willResignActive());

/**
 Called after UIApplicationDidBecomeActiveNotification is received.
 */
- (void)sdkManagerDidBecomeActive NS_SWIFT_NAME(didBecomeActive());

/**
 Called after UIApplicationWillEnterForegroundNotification is received.
 */
- (void)sdkManagerWillEnterForeground NS_SWIFT_NAME(willEnterForeground());

/**
 Called after UIApplicationDidEnterBackgroundNotification is received
 */
- (void)sdkManagerDidEnterBackground NS_SWIFT_NAME(didEnterBackground());

@end

/**
 This class will manage the basic infrastructure of the Mobile SDK elements of the app,
 including the orchestration of authentication, passcode displaying, and management of app
 backgrounding and foregrounding state.
 */
NS_SWIFT_NAME(SalesforceSDK)
@interface SalesforceSDKManager : NSObject

/**
 Class instance to be used to instantiate the singleton.
 @param className Name of instantiator class.
 */
+ (void)setInstanceClass:(Class)className;

/**
 * Sets the app name to be used by the analytics framework.
 *
 * @param appName App name.
 */
+ (void)setAiltnAppName:(nonnull NSString *)appName;

/**
 * Returns the app name being used by the analytics framework.
 *
 * @return App name.
 */
+ (nonnull NSString *)ailtnAppName;

/**
 @return The singleton instance of the SDK Manager.
 */
+ (nonnull instancetype)sharedManager;

/**
 * Returns a unique device ID.
 *
 * @return Device ID.
 */
- (NSString *) deviceId;

/** The OAuth configuration parameters defined in the developer's Salesforce connected app.
 */
@property (nonatomic, strong, nullable) SFSDKAppConfig *appConfig;

/**
 Whether or not the SDK is currently in the middle of a launch process.
 */
@property (nonatomic, readonly) BOOL isLaunching;

/**
 App type (native, hybrid or react native)
 */
@property (nonatomic, readonly) SFAppType appType;

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, nullable, copy) NSString *brandLoginPath;


/**
 The configured post launch action block to execute when launch completes.
 */
@property (nonatomic, copy, nullable) SFSDKPostLaunchCallbackBlock postLaunchAction;

/**
 The configured launch error action block to execute in the event of an error during launch.
 */
@property (nonatomic, copy, nullable) SFSDKLaunchErrorCallbackBlock launchErrorAction;

/**
 The post logout action block to execute after the current user has been logged out.
 */
@property (nonatomic, copy, nullable) SFSDKLogoutCallbackBlock postLogoutAction;

/**
 The switch user action block to execute when switching from one user to another.
 */
@property (nonatomic, copy, nullable) SFSDKSwitchUserCallbackBlock switchUserAction;

/**
 The block to execute after the app has entered the foreground.
 */
@property (nonatomic, copy, nullable) SFSDKAppForegroundCallbackBlock postAppForegroundAction;

/**
 Whether or not to use a security snapshot view when the app is backgrounded, to prevent
 sensitive data from being displayed outside of the app context.  Default is YES.
 */
@property (nonatomic, assign) BOOL useSnapshotView;

/**
 The block to provide custom view to use for IDP selection flow.
 */
@property (nonatomic, copy, nullable) SFIDPLoginFlowSelectionBlock idpLoginFlowSelectionBlock;


/**
 The block to provide custom view to use for IDP user selection flow.
 */
@property (nonatomic, copy, nullable) SFIDPUserSelectionBlock idpUserSelectionBlock;
/**
 The block to provide custom view to use as the "image" that represents the app display when it is backgrounded.
 @discussion
 This action is called when `useSnapshotView` is YES. If this action is not set or if nil is returned,
 a default opaque white view will be used.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerCreationBlock snapshotViewControllerCreationAction;

/**
 The block to execute to present the snapshot viewcontroller.
 If this property is not set, SFSDKWindowManager will be used to present the snapshot in the snapshot window.
 @discussion
 This block is only invoked if the dismissal action is also set.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerPresentationBlock snapshotPresentationAction;

/**
 The block to execute to dismiss the snapshot viewcontroller.
 @discussion
 This block is only invoked if the presentation action is also set.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerDismissalBlock snapshotDismissalAction;

/**
 The preferred passcode provider for the app.  Defaults to kSFPasscodeProviderPBKDF2.
 NOTE: If you wanted to set your own provider, you could do the following:
         id<SFPasscodeProvider> *myProvider = [[MyProvider alloc] initWithProviderName:myProviderName];
         [SFPasscodeProviderManager addPasscodeProvider:myProvider];
         [SalesforceSDKManager setPreferredPasscodeProvider:myProviderName];
 */
@property (nonatomic, nullable, copy) NSString *preferredPasscodeProvider;

/**
 Gets or sets a block that will return a user agent string, created with an optional qualifier.
 Default implementation, when executed, will return a user agent of the form:
 SalesforceMobileSDK/3.0.0 iPhone OS/8.1 (iPad) AppName/AppVersion *Native or Hybrid with optional qualifier* *Web-based user agent string*
 */
@property (nonatomic, copy) SFSDKUserAgentCreationBlock userAgentString;

/** Use this flag to indicate if the APP will be an identity provider
 */
@property (nonatomic,assign) BOOL isIdentityProvider;

/** Use this flag to indicate if the scheme for the identity provider app
 */
@property (nonatomic, copy) NSString *idpAppURIScheme;

/** Use this flag to setup a user friendly display name  for your current app. This value will be used by the identity
 *  provider app on the user selection view.
 */
@property (nonatomic,copy) NSString *appDisplayName;


/** Use this flag to indicate if the dev support dialog should be enabled in the APP
 */
@property (nonatomic, assign) BOOL isDevSupportEnabled;

/**
 Launches the SDK.  This will verify an existing passcode the first time it runs, and attempt to
 authenticate if the current user is not already authenticated.  @see postLaunchAction, launchErrorAction,
 postLogoutAction, and switchUserAction for callbacks that can be set for handling post launch
 actions.
 @return YES if the launch successfully kicks off, NO if launch is already running.
 */
- (BOOL)launch;

/**
 Initializes the SDK.
 */
+ (void)initializeSDK;

/**
 Initializes the SDK.  Class instance to be used to instantiate the sdkManager.
 */
+ (void)initializeSDKWithClass:(Class)className;

/**
 @return app type as a string
 */
- (NSString *)getAppTypeAsString;

/**
 Adds an SDK Manager delegate to the list of delegates.
 @param delegate The delegate to add.
 */
- (void)addDelegate:(id<SalesforceSDKManagerDelegate>)delegate;

/**
 Removes an SDK Manager delegate from the list of delegates.
 @param delegate The delegate to remove.
 */
- (void)removeDelegate:(id<SalesforceSDKManagerDelegate>)delegate;

/**
 @param launchActions Bit-coded descriptor of actions taken during launch.
 @return A log-friendly string of the launch actions that were taken, given in postLaunchAction.
 */
+ (NSString *)launchActionsStringRepresentation:(SFSDKLaunchAction)launchActions NS_SWIFT_NAME(asString(actions:));

/**
 * Show dev support dialog
 * @param presentedViewController The view controller currently presented.
 */
- (void)showDevSupportDialog:(UIViewController *)presentedViewController;

/**
 * @param presentedViewController The view controller currently presented.
 * @return Dev actions (list of title1, handler1, title2, handler2 etc) to show in dev support dialog
 */
- (NSArray *)getDevActions:(UIViewController *)presentedViewController;

/**
 * @return Dev info (list of name1, value1, name2, value2 etc) to show in SFSDKDevInfoController
 */
- (NSArray*) getDevSupportInfos;

@end

NS_ASSUME_NONNULL_END
