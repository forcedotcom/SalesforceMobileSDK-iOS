#import "SalesforceSDKManager.h"
#import "SFSecurityLockout+Internal.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFSDKAppConfig.h"
#import "SFAuthenticationManager.h"
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
- (void)handleIDPInitiatedAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleUserDidLogout:(nonnull NSNotification *)notification;
- (void)handleUserWillSwitch:(nullable SFUserAccount *)fromUser toUser:(nullable SFUserAccount *)toUser;
- (void)handleUserDidSwitch:(nullable SFUserAccount *)fromUser toUser:(nullable SFUserAccount *)toUser;

@end

@interface SnapshotViewController : UIViewController

@end

SFSDK_USE_DEPRECATED_BEGIN
@interface SalesforceSDKManager () <SalesforceSDKManagerFlow, SFUserAccountManagerDelegate, SFSecurityLockoutDelegate,SFAuthenticationManagerDelegate>
{
    BOOL _isLaunching;
    UIViewController* _snapshotViewController;
}
SFSDK_USE_DEPRECATED_END

@property (nonatomic, assign) SFAppType appType;
@property (nonatomic, weak, nullable) id<SalesforceSDKManagerFlow> sdkManagerFlow;
@property (nonatomic, assign) BOOL hasVerifiedPasscodeAtStartup;
@property (nonatomic, assign) SFSDKLaunchAction launchActions;
@property (nonatomic, strong, nonnull) NSHashTable<id<SalesforceSDKManagerDelegate>> *delegates;
@property (nonatomic, assign, getter=isPasscodeDisplayed) BOOL passcodeDisplayed;
@property (nonatomic, assign, getter=isInManagerForegroundProcess) BOOL inManagerForegroundProcess;

- (void)passcodeValidatedToAuthValidation;
- (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction;
- (void)presentSnapshot;
- (BOOL)isSnapshotPresented;
- (void)dismissSnapshot;

@end
