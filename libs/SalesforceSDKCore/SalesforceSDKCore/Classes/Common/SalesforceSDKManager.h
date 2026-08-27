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
#import <SalesforceSDKCore/SalesforceSDKCoreDefines.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
@class SFUserAccount, SFSDKAppConfig, SFScreenLockManager, SFBiometricAuthenticationManager, SFDomainDiscoveryResult;
@protocol SFScreenLockManager, SFBiometricAuthenticationManager, SFNativeLoginManager;

/**
 Block typedef for creating a custom snapshot view controller.
 */
typedef UIViewController * __nullable (^SFSnapshotViewControllerCreationBlock)(void)  NS_SWIFT_NAME(SnapshotViewCreationBlock);

typedef NS_ENUM(NSUInteger, SFAppType) {
    kSFAppTypeNative,
    kSFAppTypeHybrid,
    kSFAppTypeReactNative,
    kSFAppTypeNativeSwift
} NS_SWIFT_NAME(SalesforceManager.AppType);

typedef NS_ENUM(NSUInteger, SFURLCacheType) {
    // Cache data will be encrypted.
    kSFURLCacheTypeEncrypted = 1,
    // Cache won't store responses.
    kSFURLCacheTypeNull,
    // Standard URL cache.
    kSFURLCacheTypeStandard
} NS_SWIFT_NAME(SalesforceManager.URLCacheType);

NS_ASSUME_NONNULL_BEGIN

NSString *SFAppTypeGetDescription(SFAppType appType) NS_SWIFT_NAME(getter:SFAppType.description(self:));

/**
 Block typedef for presenting the snapshot view controller.
 */
typedef void (^SFSnapshotViewControllerPresentationBlock)(UIViewController* snapshotViewController) NS_SWIFT_NAME(SalesforceManager.SnapshotViewDisplayBlock) API_UNAVAILABLE(visionos);

/**
 Block typedef for dismissing the snapshot view controller.
 */
typedef void (^SFSnapshotViewControllerDismissalBlock)(UIViewController* snapshotViewController) NS_SWIFT_NAME(SalesforceManager.SnapshotViewDismissBlock) API_UNAVAILABLE(visionos);

NS_SWIFT_NAME(DevAction)
@interface SFSDKDevAction : NSObject

/**
 * Gets the  name being used by the action. Is used to display the option
 * @return name.
 */
@property(nonatomic, readonly) NSString *name;

/**
 * Gets the  handler associated with the action. Is used to display the option
 * @return name.
 */
@property(nonatomic, copy, nonnull) void (^handler)(void);

/**
 * Initialize with a name and a handler.
 * @param name The name use  display an option in the dev options display action sheet.
 * @param handler The handler that should be invoked when the option is selected.
 */
- (instancetype)initWith:(NSString *)name handler:(void (^)(void))handler;

@end

/** Notification sent when the screen lock will be displayed.
 */
extern NSString * const kSFScreenLockFlowWillBegin;

/** Notification sent when the screen lock flow has completed.
 */
extern NSString * const kSFScreenLockFlowCompleted;

/** Notification sent when the screen lock will be displayed.
 */
extern NSString * const kSFBiometricAuthenticationFlowWillBegin;

/** Notification sent when the screen lock flow has completed.
 */
extern NSString * const kSFBiometricAuthenticationFlowCompleted;

/**
 This class will manage the basic infrastructure of the Mobile SDK elements of the app,
 including the orchestration of authentication, screen lock displaying, and management of app
 backgrounding and foregrounding state.
 */
NS_SWIFT_NAME(SalesforceManager)
@interface SalesforceSDKManager : NSObject

/**
 Class instance to be used to instantiate the singleton.
 @param className Name of instantiator class.
 */
+ (void)setInstanceClass:(Class)className;

/**
 * Sets & Gets the app name being used by the analytics framework.
 *
 * @return App name.
 */
@property (class, nonatomic, strong) NSString *ailtnAppName NS_SWIFT_NAME(analyticsAppName);

/**
 * Gets & sets the app name being used by the SDK for user agent and other parts within the SDK.
 *
 * @return App name.
 */
@property (class, nonatomic, strong) NSString *appName NS_SWIFT_NAME(appName);

/**
 @return The singleton instance of the SDK Manager.
 */
@property (class, nonatomic, readonly) SalesforceSDKManager *sharedManager NS_SWIFT_NAME(shared);

/**
 * Returns a unique device ID.
 *
 * @return Device ID.
 */
- (NSString *) deviceId;

/** The OAuth configuration parameters defined in the developer's Salesforce connected app.
 */
@property (nonatomic, strong, nullable) SFSDKAppConfig *appConfig NS_SWIFT_NAME(bootConfig);

/**
 App type (native, hybrid or react native)
 */
@property (nonatomic, readonly) SFAppType appType;

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, nullable, copy) NSString *brandLoginPath NS_SWIFT_NAME(brandLoginIdentifier);

/**
 Whether or not to use a security snapshot view when the app is backgrounded, to prevent
 sensitive data from being displayed outside of the app context.  Default is YES on iOS. Disabled when running on Mac.
 */
@property (nonatomic, assign) BOOL useSnapshotView NS_SWIFT_NAME(usesSnapshotView) API_UNAVAILABLE(macCatalyst);

/**
 The block to provide custom view to use for IDP selection flow.
 */
@property (nonatomic, copy, nullable) SFIDPLoginFlowSelectionBlock idpLoginFlowSelectionBlock  NS_SWIFT_NAME(loginFlowSelectionViewProvider);

/**
 The block to provide custom view to use for IDP user selection flow.
 */
@property (nonatomic, copy, nullable) SFIDPUserSelectionBlock idpUserSelectionBlock NS_SWIFT_NAME(idpUserSelectionViewProvider);
/**
 The block to provide custom view to use as the "image" that represents the app display when it is backgrounded.
 @discussion
 This action is called when `useSnapshotView` is YES. If this action is not set or if nil is returned,
 a default opaque white view will be used.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerCreationBlock snapshotViewControllerCreationAction NS_SWIFT_NAME(snapshotViewCreationHandler);

/**
 The block to execute to present the snapshot viewcontroller.
 If this property is not set, SFSDKWindowManager will be used to present the snapshot in the snapshot window.
 @discussion
 This block is only invoked if the dismissal action is also set.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerPresentationBlock snapshotPresentationAction NS_SWIFT_NAME(snapshotViewPresentationHandler) API_UNAVAILABLE(visionos);

/**
 The block to execute to dismiss the snapshot viewcontroller.
 @discussion
 This block is only invoked if the presentation action is also set.
 */
@property (nonatomic, copy, nullable) SFSnapshotViewControllerDismissalBlock snapshotDismissalAction NS_SWIFT_NAME(snapshotViewDismissalHandler) API_UNAVAILABLE(visionos);

/**
 Gets or sets a block that will return a user agent string, created with an optional qualifier.
 Default implementation, when executed, will return a user agent of the form:
 SalesforceMobileSDK/3.0.0 iPhone OS/8.1 (iPad) AppName/AppVersion *Native or Hybrid with optional qualifier* *Web-based user agent string*
 */
@property (nonatomic, copy) SFSDKUserAgentCreationBlock userAgentString NS_SWIFT_NAME(userAgentGenerator);

/**
 Returns a user agent string that includes both global and per-user feature flags.
 @param qualifier Optional string appended to the app type (e.g., "Local" for hybrid).
 @param user The user account whose per-user flags to include, or nil to use the current user.
 @return The user agent string for the given user.
 */
- (nonnull NSString *)userAgentString:(nonnull NSString *)qualifier forUser:(nullable SFUserAccount *)user NS_SWIFT_NAME(userAgent(qualifier:for:));

/**
 Block to dynamically select the app config at runtime based on login host.
 
 NB: SFUserAccountManager stores the consumer key, callback URL, etc. in its shared
 instance, backed by shared prefs and initialized from the static boot config.
 Previously, the app always used these shared instance values for login.
 Now, the app can inject alternate values instead — in that case, the shared
 instance and prefs are left untouched (not read or overwritten).
 The consumer key and related values used for login are saved in the user
 account credentials (as before) and therefore used later for token refresh.
 */
 @property (nonatomic, copy, nullable) SFSDKAppConfigRuntimeSelectorBlock appConfigRuntimeSelectorBlock NS_SWIFT_NAME(bootConfigRuntimeSelector);

/** Use this flag to indicate if the APP will be an identity provider. When enabled this flag allows this application to perform authentication on behalf of another app.
 */
@property (nonatomic,assign) BOOL isIdentityProvider NS_SWIFT_NAME(isIdentityProvider);

/** Use this flag to indicate if the scheme for the identity provider app
 */
@property (nonatomic, copy, nullable) NSString *idpAppURIScheme NS_SWIFT_NAME(identityProviderURLScheme);

/**
 A user friendly display name for use in UI by the SDK on behalf of the app.  This value will be used on various authentication screens
 such as biometric enrollment or IDP login. If left unset, this property will fallback to CFBundleDisplayName or CFBundleName depending on what is available.
 */
@property (nonatomic,copy) NSString *appDisplayName NS_SWIFT_NAME(appDisplayName);

/** Use this flag to indicate if the dev support dialog should be enabled in the APP
 */
@property (nonatomic, assign) BOOL isDevSupportEnabled;

/** Use this flag to indicate if the login webview should be inspectable
 */
@property (nonatomic, assign) BOOL isLoginWebviewInspectable;

/** When set (DEBUG builds only; setter is a no-op in Release), a callback URL is built from this result to trigger the domain discovery callback handler when welcome.salesforce.com is the login server. Used by tests to simulate domain discovery.
 */
@property (nonatomic, strong, nullable) SFDomainDiscoveryResult *simulatedDomainDiscoveryResult;

/** The type of cache used for the shared URL cache, defaults to kSFURLCacheTypeEncrypted.
*/
@property (nonatomic, assign) SFURLCacheType URLCacheType;

/** Use this flag to indicate if advanced authentication should use an ephemeral web session. Defaults to YES.
*/
@property (nonatomic, assign) BOOL useEphemeralSessionForAdvancedAuth;

/** Whether or not the app should use web server oauth flow in web view. If false, user-agent will be used.
 */
@property (nonatomic, assign) BOOL useWebServerAuthentication SFSDK_DEPRECATED(14.0, 15.0, "The OAuth user agent flow is being retired; the web server flow will be used going forward. This flag may be removed sooner than 15.0 if the server no longer supports the user agent flow.");

/** Whether hybrid authentication flow should be used. Defaults to YES.
 */
@property (nonatomic, assign) BOOL useHybridAuthentication;

/** Whether DPoP (RFC 9449) proof JWTs should be attached to token-endpoint requests.
 *  Defaults to `YES` as of Mobile SDK 14. When enabled, the SDK lazily generates a
 *  per-user P-256 keypair (Secure Enclave when available) and signs a proof JWT for
 *  every request to `/services/oauth2/token`. This flag governs new logins only:
 *  existing DPoP-bound credentials keep their binding and existing Bearer credentials
 *  are not upgraded to DPoP, regardless of this setting.
 */
@property (nonatomic, assign) BOOL useDPoP NS_SWIFT_NAME(usesDPoP);

/** Whether Advanced Authentication (browser-based OAuth) should always be used for interactive login, regardless of the target server's My Domain auth-configuration. When YES (the default), Advanced Auth is used even on standard login servers such as login.salesforce.com. When NO, Advanced Auth is used only when the server's My Domain auth-configuration opts into it (legacy behavior). Defaults to YES.

 @deprecated Advanced Authentication is becoming mandatory; this flag no longer serves a durable purpose and will be removed in Salesforce Mobile SDK 15.0.
 */
@property (nonatomic, assign) BOOL forceAdvancedAuthentication SFSDK_DEPRECATED(14.0, 15.0, "Advanced Authentication is becoming mandatory; this flag will be removed.");

/** Detect use of "Use Custom Domain" input from login web view using the given regex.
 *  Example for a specific org:
 *    "^https:\\/\\/mobilesdk\\.my\\.salesforce\\.com/\\?startURL=%2Fsetup%2Fsecur%2FRemoteAccessAuthorizationPage\\.apexp"
 *  For any my domain:
 *    "^https:\\/\\/[a-zA-Z0-9]+\\.my\\.salesforce\\.com/\\?startURL=%2Fsetup%2Fsecur%2FRemoteAccessAuthorizationPage\\.apexp"
 */
@property (nonatomic, copy, nullable) NSRegularExpression *customDomainInferencePattern;

/** Sets authentication ability for Salesforce integration users.  When true, Salesforce integration users will be prohibited from initial authentication and receive an error message.  Defaults to NO.
 */
@property (nonatomic, assign) BOOL blockSalesforceIntegrationUser;

/**
 Initializes the SDK.
 */
+ (void)initializeSDK;

/**
 Initializes the SDK.  Class instance to be used to instantiate the sdkManager.
 */
+ (void)initializeSDKWithClass:(Class)className NS_SWIFT_NAME(initializeSDK(manager:));

/**
 @return app type as a string
 */
- (NSString *)getAppTypeAsString;

/**
 * Show dev support dialog
 * @param presentingViewController The view controller currently presented.
 */
- (void)showDevSupportDialog:(UIViewController *)presentingViewController  NS_SWIFT_NAME(showDevSupportDialog(from:));

/**
 * @param presentedViewController The view controller currently presented.
 * @return Dev actions (list of DevAction objects) to show in dev support dialog
 */
- (NSArray<SFSDKDevAction *> *)getDevActions:(UIViewController *)presentedViewController NS_SWIFT_NAME(devActionsList(presentedViewController:));

/**
 * @return Dev info (list of name1, value1, name2, value2 etc) to show in SFSDKDevInfoController
 */
- (NSArray<NSString *>*)getDevSupportInfos NS_SWIFT_NAME(devSupportInfoList());

/**
 * Returns the title string of the dev support menu.
 *
 * @return Title string of the dev support menu.
 */
- (nonnull NSString *)devInfoTitleString;

/**
 * Returns The ScreenLockManager instance.
 *
 * @return The Screen Lock Manager.
 */
- (id <SFScreenLockManager>)screenLockManager;

/**
 * Returns The BiometricAuthenticationManager instance.
 *
 * @return The Biometric Authentication Manager.
 */
- (id <SFBiometricAuthenticationManager>)biometricAuthenticationManager;

/**
 * Asynchronously retrieves the app config (aka boot config) for the specified login host.
 *
 * If an appConfigRuntimeSelectorBlock is set, it will be invoked to select the appropriate config.
 * If the block is not set or returns nil, the default appConfig will be returned.
 *
 * @param loginHost The selected login host
 * @param callback The callback invoked with the selected app config
 */
- (void)appConfigForLoginHost:(nullable NSString *)loginHost callback:(nonnull void (^)(SFSDKAppConfig * _Nullable))callback NS_SWIFT_NAME(bootConfig(forLoginHost:callback:));

/**
 * Creates the NativeLoginManager instance.
 *
 * @param consumerKey The Connected App consumer key.
 * @param callbackUrl The Connected App redirect URI.
 * @param communityUrl The login url for native login
 * @param nativeLoginViewController The view presented to the user and responsible for using the
 * returned Native Login Manager to initiate either of the authorization code and credentials login flow or the
 * headless, password-less login flow.
 * @param scene Optional UIScene to enable multi-window support.
 *
 * @return The Native Login Manager.
 */
- (id <SFNativeLoginManager>)useNativeLoginWithConsumerKey:(nonnull NSString *)consumerKey
                                               callbackUrl:(nonnull NSString *)callbackUrl
                                              communityUrl:(nonnull NSString *)communityUrl
                                 nativeLoginViewController:(nonnull UIViewController *)nativeLoginViewController
                                                     scene:(nullable UIScene *)scene;

- (id <SFNativeLoginManager>)useNativeLoginWithConsumerKey:(nonnull NSString *)consumerKey
                                               callbackUrl:(nonnull NSString *)callbackUrl
                                              communityUrl:(nonnull NSString *)communityUrl
                                        reCaptchaSiteKeyId:(nullable NSString *)reCaptchaSiteKeyId
                                      googleCloudProjectId:(nullable NSString *)googleCloudProjectId
                                     isReCaptchaEnterprise:(BOOL)isReCaptchaEnterprise
                                 nativeLoginViewController:(nonnull UIViewController *)nativeLoginViewController
                                                     scene:(nullable UIScene *)scene;

/**
 * Returns The NativeLoginManager instance.
 *
 * @return The Native Login Manager.
 */
- (id <SFNativeLoginManager>)nativeLoginManager;

#if DEBUG
/**
 * Resets all local SDK auth state for UI testing.
 *
 * Logs out all users (including async server refresh-token revocation), resets the selected
 * login host to login.salesforce.com, removes persisted custom login servers, and restores
 * all SalesforceSDKManager auth flags to their post-init defaults.
 *
 * Call once at process startup when --resetSDKForUITesting is present in launch arguments,
 * after initializeSDK and before the SDK's login flow begins.
 *
 * NOT FOR PRODUCTION USE.
 */
+ (void)resetForUITesting NS_SWIFT_NAME(resetForUITesting());
#endif

@end

NS_ASSUME_NONNULL_END
