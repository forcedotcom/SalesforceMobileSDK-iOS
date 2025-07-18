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
@property (nonatomic, strong, nonnull) SFSDKSafeMutableDictionary<NSString *, UIViewController *> *snapshotViewControllers;
@property (nonatomic, strong, nullable) SFSDKSafeMutableDictionary<NSString *, UIViewController *> *nativeLoginViewControllers;

- (void)presentSnapshot:(nonnull UIScene *)scene API_UNAVAILABLE(visionos);
- (BOOL)isSnapshotPresented:(nonnull UIScene *)scene API_UNAVAILABLE(visionos);
- (void)dismissSnapshot:(nonnull UIScene *)scene completion:(void (^ __nullable)(void))completion API_UNAVAILABLE(visionos);

@end
