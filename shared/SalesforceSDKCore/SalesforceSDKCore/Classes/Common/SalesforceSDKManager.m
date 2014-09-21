/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SalesforceSDKManager+Internal.h"
#import "SFUserAccountManager.h"
#import "SFAuthenticationManager+Internal.h"
#import "SFSecurityLockout+Internal.h"
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

//
// Helper class to manage the default (non-test) SDK Manager flows.  Implementation at the end.
//
@interface SFSDKManagerDefaultFlowHandler : NSObject <SalesforceSDKManagerFlow>

@end

static id<SalesforceSDKManagerFlow> sSdkManagerFlow;
static SFSDKPostLaunchCallbackBlock sPostLaunchAction;
static SFSDKLaunchErrorCallbackBlock sLaunchErrorAction;
static SFSDKLogoutCallbackBlock sPostLogoutAction;
static SFSDKSwitchUserCallbackBlock sSwitchUserAction;
static SFSDKAppForegroundCallbackBlock sPostAppForegroundAction;
static SFSDKLaunchAction sLaunchActions;
static BOOL sIsLaunching = NO;
static BOOL sHasVerifiedPasscodeAtStartup = NO;
static BOOL sUseSnapshotView = YES;
static BOOL sAuthenticateAtLaunch = YES;
static UIViewController *sSnapshotViewController;
static UIView *sSnapshotView;
static SFSDKManagerEventHandler *sDelegateHandler;

@implementation SalesforceSDKManager

+ (void)initialize
{
    id<SalesforceSDKManagerFlow> defaultManagerFlow = [[SFSDKManagerDefaultFlowHandler alloc] init];
    [self setSdkManagerFlow:defaultManagerFlow];
    sDelegateHandler = [[SFSDKManagerEventHandler alloc] init];
    [[SFUserAccountManager sharedInstance] addDelegate:sDelegateHandler];
    [[SFAuthenticationManager sharedManager] addDelegate:sDelegateHandler];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:sDelegateHandler selector:@selector(authCompleted:) name:kSFAuthenticationManagerFinishedNotification object:nil];
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

#pragma mark - Public methods / properties

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

+ (BOOL)authenticateAtLaunch
{
    return sAuthenticateAtLaunch;
}

+ (void)setAuthenticateAtLaunch:(BOOL)authenticateAtLaunch
{
    sAuthenticateAtLaunch = authenticateAtLaunch;
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

+ (BOOL)launch
{
    if (sIsLaunching) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Launch already in progress."];
        return NO;
    }
    
    [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Launching the Salesforce SDK."];
    sIsLaunching = YES;
    sLaunchActions = SFSDKLaunchActionNone;
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Please correct errors and try again."];
        [self sendLaunchError:launchStateError];
    } else {
        // If there's a passcode configured, and we haven't validated before (through a previous call to
        // launch), we validate that first.
        if (!sHasVerifiedPasscodeAtStartup) {
            [sSdkManagerFlow passcodeValidationAtLaunch];
        } else {
            // Otherwise, passcode validation is subject to activity timeout.  Skip to auth check.
            [sSdkManagerFlow authValidationAtLaunch];
        }
    }
    return YES;
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
    if (launchActions & SFSDKLaunchActionAuthBypassed) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionAuthBypassed"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionPasscodeVerified) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionPasscodeVerified"];
        joinString = @"|";
    }
    
    return launchActionString;
}

#pragma mark - Private methods

+ (id<SalesforceSDKManagerFlow>)sdkManagerFlow
{
    return sSdkManagerFlow;
}

+ (void)setSdkManagerFlow:(id<SalesforceSDKManagerFlow>)sdkManagerFlow
{
    sSdkManagerFlow = sdkManagerFlow;
}

+ (SFSDKLaunchAction)launchActions
{
    return sLaunchActions;
}

+ (void)setLaunchActions:(SFSDKLaunchAction)launchActions
{
    sLaunchActions = launchActions;
}

+ (BOOL)hasVerifiedPasscodeAtStartup
{
    return sHasVerifiedPasscodeAtStartup;
}

+ (void)setHasVerifiedPasscodeAtStartup:(BOOL)hasVerifiedPasscodeAtStartup
{
    sHasVerifiedPasscodeAtStartup = hasVerifiedPasscodeAtStartup;
}

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

+ (void)handleAuthCompleted
{
    // Will set up the passcode timer for auth that occurs out of band from SDK Manager launch.
    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
}

+ (void)handlePostLogout
{
    // Close the passcode screen and reset passcode monitoring.
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
    [self sendPostLogout];
}

+ (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    // Close the passcode screen and reset passcode monitoring.
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
    [self sendUserAccountSwitch:fromUser toUser:toUser];
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
        [self passcodeValidatedToAuthValidation];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        // Note: Failed passcode verification automatically logs out users, which the logout
        // delegate handler will catch and pass on.  We just log the error and reset launch
        // state here.
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
    }];
    [SFSecurityLockout lock];
}

+ (void)passcodeValidatedToAuthValidation
{
    sLaunchActions |= SFSDKLaunchActionPasscodeVerified;
    sHasVerifiedPasscodeAtStartup = YES;
    [sSdkManagerFlow authValidationAtLaunch];
}

+ (void)authValidationAtLaunch
{
    if (![SFUserAccountManager sharedInstance].currentUser.credentials.accessToken && sAuthenticateAtLaunch) {
        // Access token check works equally well for any of the members being nil, which are all conditions to
        // (re-)authenticate.
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"No valid credentials found.  Proceeding with authentication."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"Authentication (%@) succeeded.  Launch completed.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh")];
            [SFSecurityLockout setupTimer];
            [SFSecurityLockout startActivityMonitoring];
            [self authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
        } failure:^(SFOAuthInfo *authInfo, NSError *authError) {
            [SFLogger log:[self class] level:SFLogLevelError format:@"Authentication (%@) failed: %@.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh"), [authError localizedDescription]];
            [self sendLaunchError:authError];
        }];
    } else {
        // If credentials already exist, or launch shouldn't attempt authentication, we won't try authenticate.
        SFSDKLaunchAction noAuthLaunchAction;
        if (!sAuthenticateAtLaunch) {
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"SDK Manager is configured not to attempt authentication at launch.  Skipping auth."];
            noAuthLaunchAction = SFSDKLaunchActionAuthBypassed;
        } else {
            [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Credentials already present.  Will not attempt to authenticate."];
            noAuthLaunchAction = SFSDKLaunchActionAlreadyAuthenticated;
        }
        [SFSecurityLockout setupTimer];
        [SFSecurityLockout startActivityMonitoring];
        [self authValidatedToPostAuth:noAuthLaunchAction];
    }
}

+ (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction
{
    sLaunchActions |= launchAction;
    [self sendPostLaunch];
}

@end

#pragma mark - SFSDKManagerEventHandler implementation

@implementation SFSDKManagerEventHandler

- (void)appWillEnterForeground:(NSNotification *)notification
{
    [[SalesforceSDKManager sdkManagerFlow] handleAppForeground];
}

- (void)appDidEnterBackground:(NSNotification *)notification
{
    [[SalesforceSDKManager sdkManagerFlow] handleAppBackground];
}

- (void)appWillTerminate:(NSNotification *)notification
{
    [[SalesforceSDKManager sdkManagerFlow] handleAppTerminate];
}

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [[SalesforceSDKManager sdkManagerFlow] handlePostLogout];
}

- (void)authCompleted:(NSNotification *)notification
{
    [[SalesforceSDKManager sdkManagerFlow] handleAuthCompleted];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [[SalesforceSDKManager sdkManagerFlow] handleUserSwitch:fromUser toUser:toUser];
}

@end

#pragma mark - SFSDKManagerDefaultFlowHandler implementation

@implementation SFSDKManagerDefaultFlowHandler

- (void)passcodeValidationAtLaunch
{
    [SalesforceSDKManager passcodeValidationAtLaunch];
}

- (void)authValidationAtLaunch
{
    [SalesforceSDKManager authValidationAtLaunch];
}

- (void)handleAppForeground
{
    [SalesforceSDKManager handleAppForeground];
}

- (void)handleAppBackground
{
    [SalesforceSDKManager handleAppBackground];
}

- (void)handleAppTerminate
{
    [SalesforceSDKManager handleAppTerminate];
}

- (void)handlePostLogout
{
    [SalesforceSDKManager handlePostLogout];
}

- (void)handleAuthCompleted
{
    [SalesforceSDKManager handleAuthCompleted];
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    [SalesforceSDKManager handleUserSwitch:fromUser toUser:toUser];
}

@end
