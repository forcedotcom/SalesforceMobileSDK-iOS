//
//  SalesforceSDKManager.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"
#import "SFAuthenticationManager+Internal.h"
#import "SFSecurityLockout.h"
#import "SFRootViewManager.h"
#import <SalesforceOAuth/SFOAuthInfo.h>
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFPasscodeProviderManager.h>
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
static NSString * const kAppSettingsAccountLogout = @"account_logout_pref";

//
// Helper class to handle user account and auth delegate calls.  Implementation at the end.
//
@interface SFSDKManagerEventHandler : NSObject <SFUserAccountManagerDelegate, SFAuthenticationManagerDelegate>

@end

static SFSDKPostLaunchCallbackBlock sPostLaunchAction;
static SFSDKLaunchErrorCallbackBlock sLaunchErrorAction;
static SFSDKLogoutCallbackBlock sPostLogoutAction;
static SFSDKSwitchUserCallbackBlock sSwitchUserAction;
static SFSDKAppForegroundCallbackBlock sPostAppForegroundAction;
static SFSDKLaunchAction sLaunchActions;
static BOOL sIsLaunching = NO;
static BOOL sHasVerifiedPasscodeAtStartup = NO;
static BOOL sUseSnapshotView = YES;
static UIViewController *sSnapshotViewController;
static UIView *sSnapshotView;
static SFSDKManagerEventHandler *sDelegateHandler;

@implementation SalesforceSDKManager

+ (void)initialize
{
    sDelegateHandler = [[SFSDKManagerEventHandler alloc] init];
    [[SFUserAccountManager sharedInstance] addDelegate:sDelegateHandler];
    [[SFAuthenticationManager sharedManager] addDelegate:sDelegateHandler];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [SFPasscodeManager sharedManager].preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
    
    // Make sure the login host settings and dependent data are synced at pre-auth app startup.
    // Note: No event generation necessary here.  This will happen before the first authentication
    // in the app's lifetime, and is merely meant to rationalize the App Settings data with the in-memory
    // app state as an initialization step.
    BOOL logoutAppSettingEnabled = [self logoutSettingEnabled];
    SFLoginHostUpdateResult *result = [[SFUserAccountManager sharedInstance] updateLoginHost];
    if (logoutAppSettingEnabled) {
        [[SFAuthenticationManager sharedManager] clearAccountState:YES];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAppSettingsAccountLogout];
        [defs synchronize];
    } else if (result.loginHostChanged) {
        // Authentication hasn't started yet.  Just reset the current user.
        [SFUserAccountManager sharedInstance].currentUser = nil;
    }
}

+ (BOOL)isLaunching
{
    return sIsLaunching;
}

+ (NSString *)connectedAppId
{
    return [SFUserAccountManager sharedInstance].oauthClientId;
}

+ (void)setConnectedAppId:(NSString *)connectedAppId
{
    [SFUserAccountManager sharedInstance].oauthClientId = connectedAppId;
}

+ (NSString *)connectedAppCallbackUri
{
    return [SFUserAccountManager sharedInstance].oauthCompletionUrl;
}

+ (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri
{
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = connectedAppCallbackUri;
}

+ (NSArray *)authScopes
{
    return [[SFUserAccountManager sharedInstance].scopes allObjects];
}

+ (void)setAuthScopes:(NSArray *)authScopes
{
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithArray:authScopes];
}

+ (SFSDKPostLaunchCallbackBlock)postLaunchAction
{
    return sPostLaunchAction;
}

+ (void)setPostLaunchAction:(SFSDKPostLaunchCallbackBlock)postLaunchAction
{
    sPostLaunchAction = postLaunchAction;
}

+ (SFSDKLaunchErrorCallbackBlock)launchErrorAction
{
    return sLaunchErrorAction;
}

+ (void)setLaunchErrorAction:(SFSDKLaunchErrorCallbackBlock)launchErrorAction
{
    sLaunchErrorAction = launchErrorAction;
}

+ (SFSDKLogoutCallbackBlock)postLogoutAction
{
    return sPostLogoutAction;
}

+ (void)setPostLogoutAction:(SFSDKLogoutCallbackBlock)postLogoutAction
{
    sPostLogoutAction = postLogoutAction;
}

+ (SFSDKSwitchUserCallbackBlock)switchUserAction
{
    return sSwitchUserAction;
}

+ (void)setSwitchUserAction:(SFSDKSwitchUserCallbackBlock)switchUserAction
{
    sSwitchUserAction = switchUserAction;
}

+ (SFSDKAppForegroundCallbackBlock)postAppForegroundAction
{
    return sPostAppForegroundAction;
}

+ (void)setPostAppForegroundAction:(SFSDKAppForegroundCallbackBlock)postAppForegroundAction
{
    sPostAppForegroundAction = postAppForegroundAction;
}

+ (NSString *)preferredPasscodeProvider
{
    return [SFPasscodeManager sharedManager].preferredPasscodeProvider;
}

+ (void)setPreferredPasscodeProvider:(NSString *)preferredPasscodeProvider
{
    [SFPasscodeManager sharedManager].preferredPasscodeProvider = preferredPasscodeProvider;
}

+ (void)launch
{
    [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Launching the Salesforce SDK."];
    sLaunchActions = SFSDKLaunchActionNone;
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Please correct errors and try again."];
        [self sendLaunchError:launchStateError];
        return;
    }
    
    if (sIsLaunching) {
        NSString * alreadyLaunchingMessage = @"Launch already in progress.";
        [SFLogger log:[self class] level:SFLogLevelError msg:alreadyLaunchingMessage];
        NSError *alreadyLaunchingError = [[NSError alloc] initWithDomain:kSalesforceSDKManagerErrorDomain
                                                                    code:kSalesforceSDKManagerErrorLaunchAlreadyInProgress
                                                                userInfo:@{ NSLocalizedDescriptionKey : alreadyLaunchingMessage }];
        [self sendLaunchError:alreadyLaunchingError];
        return;
    }
    
    // If there's a passcode configured, and we haven't validated before (through a previous call to
    // launch), we validate that first.
    if (!sHasVerifiedPasscodeAtStartup) {
        [self passcodeValidationAtLaunch];
    } else {
        // Otherwise, passcode validation is subject to activity timeout.  Skip to auth check.
        [self authValidationAtLaunch];
    }
}

+ (NSString *)launchActionsStringRepresentation:(SFSDKLaunchAction)launchActions
{
    if (launchActions == SFSDKLaunchActionNone)
        return @"SFSDKLaunchActionNone";
    
    NSMutableString *launchActionString = [NSMutableString string];
    NSString *joinString = @"";
    if (launchActions & SFSDKLaunchActionAlreadyAuthenticated) {
        [launchActionString appendString:@"SFSDKLaunchActionAlreadyAuthenticated"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionAuthenticated) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionAuthenticated"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionPasscodeVerified) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionPasscodeVerified"];
        joinString = @"|";
    }
    
    return launchActionString;
}

#pragma mark - Private methods

+ (BOOL)validateLaunchState:(NSError **)launchStateError
{
    BOOL validInputs = YES;
    NSMutableArray *launchStateErrorMessages = [NSMutableArray array];
    
    if ([[UIApplication sharedApplication] delegate].window == nil) {
        NSString *noWindowError = [NSString stringWithFormat:@"%@ cannot perform launch before the UIApplication delegate's window property has been initialized.  Cannot continue.", [self class]];
        [SFLogger log:[self class] level:SFLogLevelError msg:noWindowError];
        [launchStateErrorMessages addObject:noWindowError];
        validInputs = NO;
    }
    if ([[self connectedAppId] length] == 0) {
        NSString *noConnectedAppIdError = @"No value for Connected App ID.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noConnectedAppIdError];
        [launchStateErrorMessages addObject:noConnectedAppIdError];
        validInputs = NO;
    }
    if ([[self connectedAppCallbackUri] length] == 0) {
        NSString *noCallbackUriError = @"No value for Connected App Callback URI.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noCallbackUriError];
        [launchStateErrorMessages addObject:noCallbackUriError];
        validInputs = NO;
    }
    if ([[self authScopes] count] == 0) {
        NSString *noAuthScopesError = @"No auth scopes set.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noAuthScopesError];
        [launchStateErrorMessages addObject:noAuthScopesError];
        validInputs = NO;
    }
    if (![self postLaunchAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No post-launch action set.  Nowhere to go after launch completes."];
    }
    if (![self launchErrorAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No launch error action set.  Nowhere to go if an error occurs during launch."];
    }
    if (![self postLogoutAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No post-logout action set.  Nowhere to go when the user is logged out."];
    }
    
    if (!validInputs && launchStateError) {
        *launchStateError = [[NSError alloc] initWithDomain:kSalesforceSDKManagerErrorDomain
                                                       code:kSalesforceSDKManagerErrorInvalidLaunchParameters
                                                   userInfo:@{
                                                              NSLocalizedDescriptionKey : @"Invalid launch parameters",
                                                              kSalesforceSDKManagerErrorDetailsKey : launchStateErrorMessages
                                                              }];
    }
    
    return validInputs;
}

+ (void)sendLaunchError:(NSError *)theLaunchError
{
    sIsLaunching = NO;
    if ([self launchErrorAction]) {
        [self launchErrorAction](theLaunchError, sLaunchActions);
    }
}

+ (void)sendPostLogout
{
    sIsLaunching = NO;
    if ([self postLogoutAction]) {
        [self postLogoutAction]();
    }
}

+ (void)sendPostLaunch
{
    sIsLaunching = NO;
    if ([self postLaunchAction]) {
        [self postLaunchAction](sLaunchActions);
    }
}

+ (void)sendUserAccountSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    sIsLaunching = NO;
    if ([self switchUserAction]) {
        [self switchUserAction](fromUser, toUser);
    }
}

+ (void)sendPostAppForeground
{
    if ([self postAppForegroundAction]) {
        [self postAppForegroundAction]();
    }
}

+ (void)handleAppForeground
{
    [SFLogger log:[self class] level:SFLogLevelDebug msg:@"App entering foreground."];
    [self removeSnapshotView];
    
    BOOL shouldLogout = [self logoutSettingEnabled];
    SFLoginHostUpdateResult *result = [[SFUserAccountManager sharedInstance] updateLoginHost];
    if (shouldLogout) {
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Logout setting triggered.  Logging out of the application."];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAppSettingsAccountLogout];
        [defs synchronize];
        [[SFAuthenticationManager sharedManager] logout];
    } else if (result.loginHostChanged) {
        [SFLogger log:[self class] level:SFLogLevelInfo format:@"Login host changed ('%@' to '%@').  Switching to new login host.", result.originalLoginHost, result.updatedLoginHost];
        [[SFAuthenticationManager sharedManager] cancelAuthentication];
        [[SFUserAccountManager sharedInstance] switchToNewUser];
    } else if (sIsLaunching) {
        [SFLogger log:[self class] level:SFLogLevelDebug format:@"SDK is still launching.  No foreground action taken."];
    } else {
        
        // Check to display pin code screen.
        
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            // Note: Failed passcode verification automatically logs out users, which the logout
            // delegate handler will catch and pass on.  We just log the error and reset launch
            // state here.
            [SFLogger log:[self class] level:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
        }];
        
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction lockoutAction) {
            [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Passcode validation succeeded, or was not required, on app foreground.  Triggering postAppForeground handler."];
            [self sendPostAppForeground];
        }];
        
        [SFSecurityLockout validateTimer];
    }
}

+ (void)handleAppBackground
{
    [SFLogger log:[self class] level:SFLogLevelDebug msg:@"App is entering the background."];
    
    [self savePasscodeActivityInfo];
    
    // Set up snapshot security view, if it's configured.
    [self setupSnapshotView];
}

+ (void)handleAppTerminate
{
    [self savePasscodeActivityInfo];
}

+ (BOOL)logoutSettingEnabled
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
	BOOL logoutSettingEnabled =  [userDefaults boolForKey:kAppSettingsAccountLogout];
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"userLogoutSettingEnabled: %d", logoutSettingEnabled];
    return logoutSettingEnabled;
}

+ (void)savePasscodeActivityInfo
{
    [SFSecurityLockout removeTimer];
    [SFInactivityTimerCenter saveActivityTimestamp];
}
    
+ (void)removeSnapshotView
{
    if ([self useSnapshotView]) {
        [[SFRootViewManager sharedManager] popViewController:sSnapshotViewController];
    }
}

+ (void)setupSnapshotView
{
    if ([self useSnapshotView]) {
        if ([self snapshotView] == nil) {
            [self setSnapshotView:[self createDefaultSnapshotView]];
        }
        
        if (sSnapshotViewController == nil) {
            sSnapshotViewController = [[UIViewController alloc] initWithNibName:nil bundle:nil];
            [sSnapshotViewController.view addSubview:[self snapshotView]];
        }
        
        [[SFRootViewManager sharedManager] pushViewController:sSnapshotViewController];
    }
}

+ (UIView *)createDefaultSnapshotView
{
    UIView *opaqueView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    opaqueView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    opaqueView.backgroundColor = [UIColor whiteColor];
    return opaqueView;
}

+ (BOOL)useSnapshotView
{
    return sUseSnapshotView;
}

+ (void)setUseSnapshotView:(BOOL)useSnapshotView
{
    sUseSnapshotView = useSnapshotView;
}

+ (UIView *)snapshotView
{
    return sSnapshotView;
}

+ (void)setSnapshotView:(UIView *)snapshotView
{
    sSnapshotView = snapshotView;
}

+ (void)passcodeValidationAtLaunch
{
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Passcode verified, or not configured.  Proceeding with authentication validation."];
        sLaunchActions |= SFSDKLaunchActionPasscodeVerified;
        sHasVerifiedPasscodeAtStartup = YES;
        [self authValidationAtLaunch];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        // Note: Failed passcode verification automatically logs out users, which the logout
        // delegate handler will catch and pass on.  We just log the error and reset launch
        // state here.
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
    }];
    [SFSecurityLockout lock];
}

+ (void)authValidationAtLaunch
{
    if (![SFUserAccountManager sharedInstance].currentUser.credentials.accessToken) {
        // Works equally well for any of the above being nil, which are all conditions to
        // (re-)authenticate.
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"No valid credentials found.  Proceeding with authentication."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"Authentication (%@) succeeded.  Launch completed.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh")];
            sLaunchActions |= SFSDKLaunchActionAuthenticated;
            [self sendPostLaunch];
        } failure:^(SFOAuthInfo *authInfo, NSError *authError) {
            [SFLogger log:[self class] level:SFLogLevelError format:@"Authentication (%@) failed: %@.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh"), [authError localizedDescription]];
            [self sendLaunchError:authError];
        }];
    } else {
        // If credentials already exist, we won't try to refresh them.
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Credentials already present.  Will not attempt to authenticate."];
        sLaunchActions |= SFSDKLaunchActionAlreadyAuthenticated;
        [self sendPostLaunch];
    }
}

@end

@implementation SFSDKManagerEventHandler

#pragma mark - App lifecycle notifications

- (void)appWillEnterForeground:(NSNotification *)notification
{
    [SalesforceSDKManager handleAppForeground];
}

- (void)appDidEnterBackground:(NSNotification *)notification
{
    [SalesforceSDKManager handleAppBackground];
}

- (void)appWillTerminate:(NSNotification *)notification
{
    [SalesforceSDKManager handleAppTerminate];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [SalesforceSDKManager sendPostLogout];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [SalesforceSDKManager sendUserAccountSwitch:fromUser toUser:toUser];
}

@end
