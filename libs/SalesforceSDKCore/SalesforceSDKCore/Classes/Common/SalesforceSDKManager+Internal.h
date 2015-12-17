#import "SalesforceSDKManager.h"

#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFSDKAppConfig.h"

@protocol SalesforceSDKManagerFlow <NSObject>

- (void)passcodeValidationAtLaunch;
- (void)authAtLaunch;
- (void)authBypassAtLaunch;
- (void)handleAppForeground:(NSNotification *)notification;
- (void)handleAppBackground:(NSNotification *)notification;
- (void)handleAppTerminate:(NSNotification *)notification;
- (void)handleAppDidBecomeActive:(NSNotification *)notification;
- (void)handleAppWillResignActive:(NSNotification *)notification;
- (void)handlePostLogout;
- (void)handleAuthCompleted:(NSNotification *)notification;
- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser;

@end

@interface SalesforceSDKManager () <SalesforceSDKManagerFlow, SFUserAccountManagerDelegate>
{
    BOOL _isLaunching;
    UIViewController *_snapshotViewController;
    NSMutableOrderedSet *_delegates;
}

@property (nonatomic, assign) SFAppType appType;
@property (nonatomic, weak) id<SalesforceSDKManagerFlow> sdkManagerFlow;
@property (nonatomic, assign) BOOL hasVerifiedPasscodeAtStartup;
@property (nonatomic, assign) SFSDKLaunchAction launchActions;

- (void)passcodeValidatedToAuthValidation;
- (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction;

@end
