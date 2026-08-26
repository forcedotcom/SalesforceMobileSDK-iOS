#import <SalesforceSDKCommon/SFSDKSafeMutableDictionary.h>
#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFSDKAppConfig.h"

static NSString * _Nonnull const kSFDefaultNativeLoginViewControllerKey = @"defaultKey";

@protocol SalesforceSDKManagerFlow <NSObject>

- (void)handleAppForeground:(nonnull NSNotification *)notification;
- (void)handleAppBackground:(nonnull NSNotification *)notification;
- (void)handleAppTerminate:(nonnull NSNotification *)notification;
- (void)handlePostLogout;
- (void)handleAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleIDPInitiatedAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleUserDidLogout:(nonnull NSNotification *)notification;

@end

API_UNAVAILABLE(visionos)
@interface SnapshotViewController : UIViewController

@end

@interface SalesforceSDKManager () <SalesforceSDKManagerFlow>

@property (nonatomic, assign) SFAppType appType;
@property (nonatomic, weak, nullable) id<SalesforceSDKManagerFlow> sdkManagerFlow;

/** Non-deprecated internal accessor for the same backing storage as the public
 `forceAdvancedAuthentication` property (deprecated in 14.0, removed in 15.0). Internal SDK code
 reads and writes the flag through this accessor so that its own use does not trip
 -Wdeprecated-declarations. Delete this alongside the public property in 15.0.
 */
@property (nonatomic, assign) BOOL sdk_forceAdvancedAuthentication;

/** Non-deprecated internal accessor for the same backing storage as the public
 `useWebServerAuthentication` property (deprecated in 14.0, removed in 15.0). Internal SDK code
 reads and writes the flag through this accessor so that its own use does not trip
 -Wdeprecated-declarations. Delete this alongside the public property in 15.0.
 */
@property (nonatomic, assign) BOOL sdk_useWebServerAuthentication;
@property (nonatomic, strong, nonnull) SFSDKSafeMutableDictionary<NSString *, UIViewController *> *snapshotViewControllers;
@property (nonatomic, strong, nullable) SFSDKSafeMutableDictionary<NSString *, UIViewController *> *nativeLoginViewControllers;

- (void)presentSnapshot:(nonnull UIScene *)scene API_UNAVAILABLE(visionos);
- (BOOL)isSnapshotPresented:(nonnull UIScene *)scene API_UNAVAILABLE(visionos);
- (void)dismissSnapshot:(nonnull UIScene *)scene completion:(void (^ __nullable)(void))completion API_UNAVAILABLE(visionos);

- (nonnull NSArray<SFSDKDevAction *> *)getDevActions:(nonnull UIViewController *)presentedViewController;
- (void)hydratePerUserFeatureFlags;

/** The SDK's own user agent string (SDK version, device/app info, app type, ftr_ markers),
 without the WebView user agent that -userAgentString:forUser: appends as a trailing component.
 */
- (nonnull NSString *)sdkUserAgentString:(nonnull NSString *)qualifier forUser:(nullable SFUserAccount *)user;

@end
