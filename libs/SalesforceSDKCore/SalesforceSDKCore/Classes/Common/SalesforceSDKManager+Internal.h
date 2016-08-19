#import "SalesforceSDKManager.h"

#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFSDKAppConfig.h"

@protocol SalesforceSDKManagerFlow <NSObject>

- (void)passcodeValidationAtLaunch;
- (void)authAtLaunch;
- (void)authBypassAtLaunch;
- (void)handleAppForeground:(nonnull NSNotification *)notification;
- (void)handleAppBackground:(nonnull NSNotification *)notification;
- (void)handleAppTerminate:(nonnull NSNotification *)notification;
- (void)handleAppDidBecomeActive:(nonnull NSNotification *)notification;
- (void)handleAppWillResignActive:(nonnull NSNotification *)notification;
- (void)handlePostLogout;
- (void)handleAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleUserSwitch:(nullable SFUserAccount *)fromUser toUser:(nullable SFUserAccount *)toUser;

@end

@interface SnapshotViewController : UIViewController

@end

@interface SalesforceSDKManager () <SalesforceSDKManagerFlow, SFUserAccountManagerDelegate>
{
    BOOL _isLaunching;
    UIViewController* _defaultSnapshotViewController;
    UIViewController* _snapshotViewController;
}

@property (nonatomic, assign) SFAppType appType;
@property (nonatomic, weak, nullable) id<SalesforceSDKManagerFlow> sdkManagerFlow;
@property (nonatomic, assign) BOOL hasVerifiedPasscodeAtStartup;
@property (nonatomic, assign) SFSDKLaunchAction launchActions;
@property (nonatomic, strong, nonnull) NSHashTable<id<SalesforceSDKManagerDelegate>> *delegates;

- (void)passcodeValidatedToAuthValidation;
- (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction;

@end
