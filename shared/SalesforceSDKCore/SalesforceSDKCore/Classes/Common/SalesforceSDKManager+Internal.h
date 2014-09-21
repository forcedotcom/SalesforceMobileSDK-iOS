#import "SalesforceSDKManager.h"

@protocol SalesforceSDKManagerFlow <NSObject>

- (void)passcodeValidationAtLaunch;
- (void)authValidationAtLaunch;
- (void)handleAppForeground;
- (void)handleAppBackground;
- (void)handleAppTerminate;
- (void)handlePostLogout;
- (void)handleAuthCompleted;
- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser;

@end

@interface SalesforceSDKManager ()

+ (id<SalesforceSDKManagerFlow>)sdkManagerFlow;
+ (void)setSdkManagerFlow:(id<SalesforceSDKManagerFlow>)sdkManagerFlow;
+ (void)passcodeValidatedToAuthValidation;
+ (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction;
+ (BOOL)hasVerifiedPasscodeAtStartup;
+ (void)setHasVerifiedPasscodeAtStartup:(BOOL)hasVerifiedPasscodeAtStartup;
+ (SFSDKLaunchAction)launchActions;
+ (void)setLaunchActions:(SFSDKLaunchAction)launchActions;

@end