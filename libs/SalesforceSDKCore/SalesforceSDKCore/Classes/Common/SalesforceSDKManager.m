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
#import "SFAuthenticationManager+Internal.h"
#import "SFSecurityLockout+Internal.h"
#import "SFRootViewManager.h"
#import "SFSDKWebUtils.h"
#import "SFManagedPreferences.h"
#import "SFOAuthInfo.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFInactivityTimerCenter.h"
#import "SFApplicationHelper.h"

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

// User agent constants
static NSString * const kSFMobileSDKNativeDesignator = @"Native";
static NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";
static NSString * const kSFMobileSDKReactNativeDesignator = @"ReactNative";

// Device id
static NSString* uid = nil;

// Instance class
static Class InstanceClass = nil;

@implementation SnapshotViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (BOOL)shouldAutorotate {
    return !(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

@end

@implementation SalesforceSDKManager

+ (void)setInstanceClass:(Class)className {
    InstanceClass = className;
}

+ (instancetype)sharedManager
{
    static dispatch_once_t pred;
    static SalesforceSDKManager *sdkManager = nil;
    dispatch_once(&pred , ^{
        uid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        if (InstanceClass) {
            sdkManager = [[InstanceClass alloc] init];
        } else {
            sdkManager = [[self alloc] init];
        }
    });
    return sdkManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.sdkManagerFlow = self;
        self.delegates = [NSHashTable weakObjectsHashTable];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAuthCompleted:) name:kSFAuthenticationManagerFinishedNotification object:nil];
        
        [SFPasscodeManager sharedManager].preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
        if (NSClassFromString(@"SFHybridViewController") != nil) {
            self.appType = kSFAppTypeHybrid;
        }
        else {
            if (NSClassFromString(@"SFNetReactBridge") != nil) {
                self.appType = kSFAppTypeReactNative;
            }
            else {
                self.appType = kSFAppTypeNative;
            }            
        }
        self.useSnapshotView = YES;
        self.authenticateAtLaunch = YES;
        self.userAgentString = [self defaultUserAgentString];
    }
    
    return self;
}

#pragma mark - Public methods / properties

- (BOOL)isLaunching
{
    return _isLaunching;
}

- (NSString *)connectedAppId
{
    return [SFUserAccountManager sharedInstance].oauthClientId;
}

- (void)setConnectedAppId:(NSString *)connectedAppId
{
    [SFUserAccountManager sharedInstance].oauthClientId = connectedAppId;
}

- (NSString *)connectedAppCallbackUri
{
    return [SFUserAccountManager sharedInstance].oauthCompletionUrl;
}

- (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri
{
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = connectedAppCallbackUri;
}

- (NSArray *)authScopes
{
    return [[SFUserAccountManager sharedInstance].scopes allObjects];
}

- (void)setAuthScopes:(NSArray *)authScopes
{
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithArray:authScopes];
}

- (NSString *)preferredPasscodeProvider
{
    return [SFPasscodeManager sharedManager].preferredPasscodeProvider;
}

- (void)setPreferredPasscodeProvider:(NSString *)preferredPasscodeProvider
{
    [SFPasscodeManager sharedManager].preferredPasscodeProvider = preferredPasscodeProvider;
}

- (BOOL)launch
{
    if (_isLaunching) {
        [self log:SFLogLevelError msg:@"Launch already in progress."];
        return NO;
    }
    
    [self log:SFLogLevelInfo msg:@"Launching the Salesforce SDK."];
    _isLaunching = YES;
    self.launchActions = SFSDKLaunchActionNone;
    if ([SFRootViewManager sharedManager].mainWindow == nil) {
        [SFRootViewManager sharedManager].mainWindow = [SFApplicationHelper sharedApplication].windows[0];
    }
    
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [self log:SFLogLevelError msg:@"Please correct errors and try again."];
        [self sendLaunchError:launchStateError];
    } else {
        // If there's a passcode configured, and we haven't validated before (through a previous call to
        // launch), we validate that first.
        if (!self.hasVerifiedPasscodeAtStartup) {
            [self.sdkManagerFlow passcodeValidationAtLaunch];
        } else {
            // Otherwise, passcode validation is subject to activity timeout.  Skip to auth check.
            [self authValidationAtLaunch];
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
    if (launchActions & SFSDKLaunchActionPasscodeVerified) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionPasscodeVerified"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionAuthBypassed) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionAuthBypassed"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionAuthenticated) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionAuthenticated"];
        joinString = @"|";
    }
    if (launchActions & SFSDKLaunchActionAlreadyAuthenticated) {
        [launchActionString appendFormat:@"%@%@", joinString, @"SFSDKLaunchActionAlreadyAuthenticated"];
        joinString = @"|";
    }
    
    return launchActionString;
}

+ (void)setDesiredAccount:(SFUserAccount*)account
{
    [SFUserAccountManager setActiveUserIdentity:account.accountIdentity];
}

#pragma mark - Private methods

- (BOOL)validateLaunchState:(NSError **)launchStateError
{
    BOOL validInputs = YES;
    NSMutableArray *launchStateErrorMessages = [NSMutableArray array];
    
    // If an app config has been specified, set values from that first.
    if (self.appConfig != nil) {
        [self configureWithAppConfig];
    }
    
    // Managed settings should override any equivalent local app settings.
    [self configureManagedSettings];
    
    if ([SFRootViewManager sharedManager].mainWindow == nil) {
        NSString *noWindowError = [NSString stringWithFormat:@"%@ cannot perform launch before the UIApplication main window property has been initialized.  Cannot continue.", [self class]];
        [self log:SFLogLevelError msg:noWindowError];
        [launchStateErrorMessages addObject:noWindowError];
        validInputs = NO;
    }
    if ([self.connectedAppId length] == 0) {
        NSString *noConnectedAppIdError = @"No value for Connected App ID.  Cannot continue.";
        [self log:SFLogLevelError msg:noConnectedAppIdError];
        [launchStateErrorMessages addObject:noConnectedAppIdError];
        validInputs = NO;
    }
    if ([self.connectedAppCallbackUri length] == 0) {
        NSString *noCallbackUriError = @"No value for Connected App Callback URI.  Cannot continue.";
        [self log:SFLogLevelError msg:noCallbackUriError];
        [launchStateErrorMessages addObject:noCallbackUriError];
        validInputs = NO;
    }
    if ([self.authScopes count] == 0) {
        NSString *noAuthScopesError = @"No auth scopes set.  Cannot continue.";
        [self log:SFLogLevelError msg:noAuthScopesError];
        [launchStateErrorMessages addObject:noAuthScopesError];
        validInputs = NO;
    }
    if (!self.postLaunchAction) {
        [self log:SFLogLevelWarning msg:@"No post-launch action set.  Nowhere to go after launch completes."];
    }
    if (!self.launchErrorAction) {
        [self log:SFLogLevelWarning msg:@"No launch error action set.  Nowhere to go if an error occurs during launch."];
    }
    if (!self.postLogoutAction) {
        [self log:SFLogLevelWarning msg:@"No post-logout action set.  Nowhere to go when the user is logged out."];
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

- (void)configureWithAppConfig
{
    self.connectedAppId = self.appConfig.remoteAccessConsumerKey;
    self.connectedAppCallbackUri = self.appConfig.oauthRedirectURI;
    self.authScopes = [self.appConfig.oauthScopes allObjects];
    self.authenticateAtLaunch = self.appConfig.shouldAuthenticate;
}

- (void)configureManagedSettings
{
    if ([SFManagedPreferences sharedPreferences].requireCertificateAuthentication) {
        [SFAuthenticationManager sharedManager].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }
    
    if ([[SFManagedPreferences sharedPreferences].connectedAppId length] > 0) {
        self.connectedAppId = [SFManagedPreferences sharedPreferences].connectedAppId;
    }
    
    if ([[SFManagedPreferences sharedPreferences].connectedAppCallbackUri length] > 0) {
        self.connectedAppCallbackUri = [SFManagedPreferences sharedPreferences].connectedAppCallbackUri;
    }
}

- (void)sendLaunchError:(NSError *)theLaunchError
{
    _isLaunching = NO;
    if (self.launchErrorAction) {
        self.launchErrorAction(theLaunchError, self.launchActions);
    }
}

- (void)sendPostLogout
{
    _isLaunching = NO;
    if (self.postLogoutAction) {
        self.postLogoutAction();
    }
}

- (void)sendPostLaunch
{
    _isLaunching = NO;
    if (self.postLaunchAction) {
        self.postLaunchAction(self.launchActions);
    }
}

- (void)sendUserAccountSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    _isLaunching = NO;
    if (self.switchUserAction) {
        self.switchUserAction(fromUser, toUser);
    }
}

- (void)sendPostAppForeground
{
    if (self.postAppForegroundAction) {
        self.postAppForegroundAction();
    }
}

- (void)handleAppForeground:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is entering the foreground."];
    
    [self enumerateDelegates:^(NSObject<SalesforceSDKManagerDelegate> *delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerWillEnterForeground)]) {
            [delegate sdkManagerWillEnterForeground];
        }
    }];
    
    @try {
        [self dismissSnapshot];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelWarning format:@"Exception thrown while removing security snapshot view: '%@'. Will continue to resume app.", [exception reason]];
    }
    
    if (_isLaunching) {
        [self log:SFLogLevelDebug format:@"SDK is still launching.  No foreground action taken."];
    } else {
        
        // Check to display pin code screen.
        
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            // Note: Failed passcode verification automatically logs out users, which the logout
            // delegate handler will catch and pass on.  We just log the error and reset launch
            // state here.
            [self log:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
        }];
        
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction lockoutAction) {
            [self log:SFLogLevelInfo msg:@"Passcode validation succeeded, or was not required, on app foreground.  Triggering postAppForeground handler."];
            [self sendPostAppForeground];
        }];
        
        [SFSecurityLockout validateTimer];
    }
}

- (void)handleAppBackground:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is entering the background."];
    
    [self enumerateDelegates:^(id<SalesforceSDKManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerDidEnterBackground)]) {
            [delegate sdkManagerDidEnterBackground];
        }
    }];
    
    [self savePasscodeActivityInfo];
    [self clearClipboard];
}

- (void)handleAppTerminate:(NSNotification *)notification
{
    [self savePasscodeActivityInfo];
}

- (void)handleAppDidBecomeActive:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is resuming active state."];
    
    [self enumerateDelegates:^(id<SalesforceSDKManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerDidBecomeActive)]) {
            [delegate sdkManagerDidBecomeActive];
        }
    }];
    
    @try {
        [self dismissSnapshot];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelWarning format:@"Exception thrown while removing security snapshot view: '%@'. Will continue to resume app.", [exception reason]];
    }
}

- (void)handleAppWillResignActive:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is resigning active state."];
    
    [self enumerateDelegates:^(id<SalesforceSDKManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerWillResignActive)]) {
            [delegate sdkManagerWillResignActive];
        }
    }];
    
    // Set up snapshot security view, if it's configured.
    @try {
        [self presentSnapshot];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelWarning format:@"Exception thrown while setting up security snapshot view: '%@'. Continuing resign active.", [exception reason]];
    }
}

- (void)handleAuthCompleted:(NSNotification *)notification
{
    // Will set up the passcode timer for auth that occurs out of band from SDK Manager launch.
    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
}

- (void)handlePostLogout
{
    // Close the passcode screen and reset passcode monitoring.
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
    [self sendPostLogout];
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    // Close the passcode screen and reset passcode monitoring.
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
    [self sendUserAccountSwitch:fromUser toUser:toUser];
}

- (void)savePasscodeActivityInfo
{
    [SFSecurityLockout removeTimer];
    [SFInactivityTimerCenter saveActivityTimestamp];
}
    
- (BOOL)isSnapshotPresented
{
    return (_snapshotViewController.presentingViewController || _snapshotViewController.view.superview);
}

- (void)presentSnapshot
{
    if (!self.useSnapshotView) {
        return;
    }
    
    // Dismiss it first if it is currently presented
    if ([self isSnapshotPresented]) {
        [self dismissSnapshot];
    }
    
    // Try to retrieve a custom snapshot view controller
    UIViewController* customSnapshotViewController = nil;
    if (self.snapshotViewControllerCreationAction) {
        customSnapshotViewController = self.snapshotViewControllerCreationAction();
    }
    
    // Custom snapshot view controller provided
    if (customSnapshotViewController) {
        _snapshotViewController = customSnapshotViewController;
        _defaultSnapshotViewController = nil; //no need to keep the default in memory
    }
    // No custom snapshot view controller provided
    else {
        if (!_defaultSnapshotViewController) {
            _defaultSnapshotViewController = [[SnapshotViewController alloc] initWithNibName:nil bundle:nil];
        }
        _snapshotViewController = _defaultSnapshotViewController;
    }
    
    // Presentation
    if (self.snapshotPresentationAction && self.snapshotDismissalAction) {
        self.snapshotPresentationAction(_snapshotViewController);
    } else {
        [[SFRootViewManager sharedManager] pushViewController:_snapshotViewController];
    }
}

- (void)dismissSnapshot
{
    if (![self isSnapshotPresented]) {
        return;
    }
    
    if (self.snapshotPresentationAction && self.snapshotDismissalAction) {
        self.snapshotDismissalAction(_snapshotViewController);
    } else {
        [[SFRootViewManager sharedManager] popViewController:_snapshotViewController];
    }
}

- (void)clearClipboard
{
    if ([SFManagedPreferences sharedPreferences].clearClipboardOnBackground) {
        [self log:SFLogLevelInfo format:@"%@: Clearing clipboard on app background.", NSStringFromSelector(_cmd)];
        [UIPasteboard generalPasteboard].strings = @[ ];
        [UIPasteboard generalPasteboard].URLs = @[ ];
        [UIPasteboard generalPasteboard].images = @[ ];
        [UIPasteboard generalPasteboard].colors = @[ ];
    }
}

- (void)passcodeValidationAtLaunch
{
    if ([SFUserAccountManager sharedInstance].isCurrentUserAnonymous) {

        // Anonymous user doesn't have any passcode associated with it
        // so bypass this step and go to the next one directly.
        [self authValidationAtLaunch];
    } else {
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
            [self log:SFLogLevelInfo msg:@"Passcode verified, or not configured.  Proceeding with authentication validation."];
            [self passcodeValidatedToAuthValidation];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{

            // Note: Failed passcode verification automatically logs out users, which the logout
            // delegate handler will catch and pass on.  We just log the error and reset launch
            // state here.
            [self log:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
        }];
        [SFSecurityLockout lock];
    }
}

- (void)passcodeValidatedToAuthValidation
{
    self.launchActions |= SFSDKLaunchActionPasscodeVerified;
    self.hasVerifiedPasscodeAtStartup = YES;
    [self authValidationAtLaunch];
}

- (void)authValidationAtLaunch
{
    if (![SFUserAccountManager sharedInstance].isCurrentUserAnonymous && ![SFUserAccountManager sharedInstance].currentUser.credentials.accessToken && self.authenticateAtLaunch) {
        // Access token check works equally well for any of the members being nil, which are all conditions to
        // (re-)authenticate.
        [self.sdkManagerFlow authAtLaunch];
    } else {
        // If credentials already exist, or launch shouldn't attempt authentication, we won't try
        // to authenticate.
        [self.sdkManagerFlow authBypassAtLaunch];
    }
}

- (void)authAtLaunch
{
    [self log:SFLogLevelInfo msg:@"No valid credentials found.  Proceeding with authentication."];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
        [self log:SFLogLevelInfo format:@"Authentication (%@) succeeded.  Launch completed.", authInfo.authTypeDescription];
        [SFSecurityLockout setupTimer];
        [SFSecurityLockout startActivityMonitoring];
        [self authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
    } failure:^(SFOAuthInfo *authInfo, NSError *authError) {
        [self log:SFLogLevelError format:@"Authentication (%@) failed: %@.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh"), [authError localizedDescription]];
        [self sendLaunchError:authError];
    }];
}

- (void)authBypassAtLaunch
{
    // If there is a current user (from a previous authentication), we still need to set up the
    // in-memory auth state of that user.
    if ([SFUserAccountManager sharedInstance].currentUser != nil) {
        [[SFAuthenticationManager sharedManager] setupWithUser:[SFUserAccountManager sharedInstance].currentUser];
    }
    
    SFSDKLaunchAction noAuthLaunchAction;
    if (!self.authenticateAtLaunch) {
        [self log:SFLogLevelInfo format:@"SDK Manager is configured not to attempt authentication at launch.  Skipping auth."];
        noAuthLaunchAction = SFSDKLaunchActionAuthBypassed;
    } else {
        [self log:SFLogLevelInfo msg:@"Credentials already present.  Will not attempt to authenticate."];
        noAuthLaunchAction = SFSDKLaunchActionAlreadyAuthenticated;
    }
    
    // Dismiss the auth view controller if present. This step is necessary,
    // especially if the user is anonymous, to ensure the auth view controller
    // is dismissed otherwise it stays visible - because by default it is dismissed
    // only after a successfully authentication.
    // A typical scenario when this happen is when the user switches to a new user
    // but decides to "go back" to the existing user and that existing user is
    // the anonymous user - the auth flow never happens and the auth view controller
    // stays on the screen, masking the main UI.
    [[SFAuthenticationManager sharedManager] dismissAuthViewControllerIfPresent];

    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
    [self authValidatedToPostAuth:noAuthLaunchAction];
}

- (void)authValidatedToPostAuth:(SFSDKLaunchAction)launchAction
{
    self.launchActions |= launchAction;
    [self sendPostLaunch];
}

- (SFSDKUserAgentCreationBlock)defaultUserAgentString {
    return ^NSString *(NSString *qualifier) {
        UIDevice *curDevice = [UIDevice currentDevice];
        NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleNameKey];
        NSString *prodAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
        NSString *appVersion = [NSString stringWithFormat:@"%@(%@)", prodAppVersion, buildNumber];

        // App type.
        NSString* appTypeStr;
        switch (self.appType) {
            case kSFAppTypeNative: appTypeStr = kSFMobileSDKNativeDesignator; break;
            case kSFAppTypeHybrid: appTypeStr = kSFMobileSDKHybridDesignator; break;
            case kSFAppTypeReactNative: appTypeStr = kSFMobileSDKReactNativeDesignator; break;
        }
        NSString *myUserAgent = [NSString stringWithFormat:
                                 @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@%@ uid_%@",
                                 SALESFORCE_SDK_VERSION,
                                 [curDevice systemName],
                                 [curDevice systemVersion],
                                 [curDevice model],
                                 appName,
                                 appVersion,
                                 appTypeStr,
                                 (qualifier != nil ? qualifier : @""),
                                 uid
                                 ];
        return myUserAgent;
    };
}

- (void)addDelegate:(id<SalesforceSDKManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            [self.delegates addObject:delegate];
        }
    }
}

- (void)removeDelegate:(id<SalesforceSDKManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            [self.delegates removeObject:delegate];
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SalesforceSDKManagerDelegate>))block
{
    @synchronized(self) {
        for (id<SalesforceSDKManagerDelegate> delegate in self.delegates) {
            if (block) block(delegate);
        }
    }
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self.sdkManagerFlow handlePostLogout];
}

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user
{

}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self.sdkManagerFlow handleUserSwitch:fromUser toUser:toUser];
}

@end
