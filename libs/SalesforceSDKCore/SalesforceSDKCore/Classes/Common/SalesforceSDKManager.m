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

#import <objc/runtime.h>
#import "SalesforceSDKManager+Internal.h"
#import "SFAuthenticationManager+Internal.h"
#import "SFSDKWindowManager.h"
#import "SFManagedPreferences.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFInactivityTimerCenter.h"
#import "SFApplicationHelper.h"
#import "SFSwiftDetectUtil.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKDevInfoViewController.h"
#import "SFDefaultUserManagementViewController.h"

static NSString * const kSFAppFeatureSwiftApp   = @"SW";
static NSString * const kSFAppFeatureMultiUser   = @"MU";

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

// Device id
static NSString* uid = nil;

// Instance class
static Class InstanceClass = nil;

// AILTN app name
static NSString* ailtnAppName = nil;

// Dev support
static NSString *const SFSDKShowDevDialogNotification = @"SFSDKShowDevDialogNotification";

@implementation UIWindow (SalesforceSDKManager)

- (void)sfsdk_motionEnded:(__unused UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.subtype == UIEventSubtypeMotionShake) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SFSDKShowDevDialogNotification object:nil];
    }
}

@end

@implementation SnapshotViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
   return UIInterfaceOrientationMaskAll;
}

@end

@interface SalesforceSDKManager ()

@property(nonatomic, strong) UIAlertController *actionSheet;

@end

@implementation SalesforceSDKManager

+ (void)setInstanceClass:(Class)className {
    InstanceClass = className;
}

+ (void)setAiltnAppName:(NSString *)appName {
    @synchronized (ailtnAppName) {
        if (appName) {
            ailtnAppName = appName;
        }
    }
}

+ (NSString *)ailtnAppName {
    return ailtnAppName;
}

+ (void)initialize {
    if (self == [SalesforceSDKManager class]) {

        // For dev support
        method_exchangeImplementations(class_getInstanceMethod([UIWindow class], @selector(motionEnded:withEvent:)), class_getInstanceMethod([UIWindow class], @selector(sfsdk_motionEnded:withEvent:)));

        /*
         * Checks if an analytics app name has already been set by the app.
         * If not, fetches the default app name to be used and sets it.
         */
        NSString *currentAiltnAppName = [SalesforceSDKManager ailtnAppName];
        if (!currentAiltnAppName) {
            NSString *ailtnAppName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
            if (ailtnAppName) {
                [SalesforceSDKManager setAiltnAppName:ailtnAppName];
            }
        }
    }
}

+ (instancetype)sharedManager {
    static dispatch_once_t pred;
    static SalesforceSDKManager *sdkManager = nil;
    dispatch_once(&pred , ^{
        uid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        if (InstanceClass) {
            sdkManager = [[InstanceClass alloc] init];
        } else {
            sdkManager = [[self alloc] init];
        }
        if([SFSwiftDetectUtil isSwiftApp]) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSwiftApp];
        }
        if([[[SFUserAccountManager sharedInstance] allUserIdentities] count]>1){
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMultiUser];
        }
        else{
            [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureMultiUser];
        }
    });
    return sdkManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
#ifdef DEBUG
        self.isDevSupportEnabled = YES;
#endif
        self.sdkManagerFlow = self;
        self.delegates = [NSHashTable weakObjectsHashTable];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        
        SFSDK_USE_DEPRECATED_BEGIN
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        SFSDK_USE_DEPRECATED_END

        [SFSecurityLockout addDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAuthCompleted:) name:kSFAuthenticationManagerFinishedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow
                                                selector:@selector(handleAuthCompleted:)
                                                     name:kSFNotificationUserDidLogIn object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow  selector:@selector(handleIDPInitiatedAuthCompleted:)
                                                     name:kSFNotificationUserIDPInitDidLogIn object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow  selector:@selector(handleIDPUserAddCompleted:)
                                                     name:kSFNotificationUserWillSendIDPResponse object:nil];
        
       [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleUserDidLogout:)  name:kSFNotificationUserDidLogout object:nil];
        
        [SFPasscodeManager sharedManager].preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
        self.useSnapshotView = YES;
        self.userAgentString = [self defaultUserAgentString];
    }
    return self;
}

- (NSString *) deviceId {
    return uid;
}

#pragma mark - Public methods / properties

- (SFAppType) appType {
    // The following if blocks are only there for hybrid or react native apps upgraded from SDK 5.x or older
    // that are not doing: [SalesforceSDKManager setInstanceClass:[{Correct-Sub-Class}SDKManager class]]
    // in their app delegate class.
    if (NSClassFromString(@"SFHybridViewController") != nil) {
        return kSFAppTypeHybrid;
    }
    if (NSClassFromString(@"SFNetReactBridge") != nil) {
        return kSFAppTypeReactNative;
    }

    return kSFAppTypeNative;
}

- (SFSDKAppConfig *)appConfig {
    if (_appConfig == nil) {
        SFSDKAppConfig *config = [SFSDKAppConfig fromDefaultConfigFile];
        _appConfig = config?:[[SFSDKAppConfig alloc] init];
    }
    return _appConfig;
}

- (SFIDPLoginFlowSelectionBlock)idpLoginFlowSelectionBlock {
    return [SFUserAccountManager sharedInstance].idpLoginFlowSelectionAction;
}

- (void)setIdpLoginFlowSelectionBlock:(SFIDPLoginFlowSelectionBlock)idpLoginFlowSelectionBlock {
    [SFUserAccountManager sharedInstance].idpLoginFlowSelectionAction = idpLoginFlowSelectionBlock;
}

- (SFIDPUserSelectionBlock)idpUserSelectionBlock {
    return [SFUserAccountManager sharedInstance].idpUserSelectionAction;
}

- (void)setIdpUserSelectionBlock:(SFIDPUserSelectionBlock)idpUserSelectionBlock {
    [SFUserAccountManager sharedInstance].idpUserSelectionAction = idpUserSelectionBlock;
}

- (BOOL)isIdentityProvider {
    return [SFUserAccountManager sharedInstance].isIdentityProvider;
}

- (void)setIsIdentityProvider:(BOOL)isIdentityProvider {
   [SFUserAccountManager sharedInstance].isIdentityProvider = isIdentityProvider;
}

- (BOOL)idpEnabled {
    return [SFUserAccountManager sharedInstance].idpAppURIScheme!=nil;
}

- (BOOL)useLegacyAuthenticationManager{
    return [SFUserAccountManager sharedInstance].useLegacyAuthenticationManager;
}

- (void)setUseLegacyAuthenticationManager:(BOOL)enabled {
    [SFUserAccountManager sharedInstance].useLegacyAuthenticationManager = enabled;
}

- (NSString *)appDisplayName {
    return [SFUserAccountManager sharedInstance].appDisplayName;
}

- (void)setAppDisplayName:(NSString *)appDisplayName {
    [SFUserAccountManager sharedInstance].appDisplayName = appDisplayName;
}

- (NSString *)idpAppURIScheme{
    return [SFUserAccountManager sharedInstance].idpAppURIScheme;
}

- (void)setIdpAppURIScheme:(NSString *)idpAppURIScheme {
    [SFUserAccountManager sharedInstance].idpAppURIScheme = idpAppURIScheme;
}

- (BOOL)isLaunching
{
    return _isLaunching;
}

- (NSString *)connectedAppId
{
    return self.appConfig.remoteAccessConsumerKey;
}

- (void)setConnectedAppId:(NSString *)connectedAppId
{
    self.appConfig.remoteAccessConsumerKey = connectedAppId;
}

- (NSString *)connectedAppCallbackUri
{
    return self.appConfig.oauthRedirectURI;
}

- (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri
{
    self.appConfig.oauthRedirectURI = connectedAppCallbackUri;
}

- (NSString *)brandLoginPath
{
    return [SFUserAccountManager sharedInstance].brandLoginPath;
}

- (void)setBrandLoginPath:(NSString *)brandLoginPath
{
    [SFUserAccountManager sharedInstance].brandLoginPath = brandLoginPath;
}

- (NSArray *)authScopes
{
    return [self.appConfig.oauthScopes allObjects];
}

- (void)setAuthScopes:(NSArray<NSString *> *)authScopes
{
    self.appConfig.oauthScopes = [NSSet setWithArray:authScopes];
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
        [SFSDKCoreLogger e:[self class] format:@"Launch already in progress."];
        return NO;
    }
    [SFSDKCoreLogger i:[self class] format:@"Launching the Salesforce SDK."];
    _isLaunching = YES;
    self.launchActions = SFSDKLaunchActionNone;
    if ([SFSDKWindowManager sharedManager].mainWindow == nil) {
        [[SFSDKWindowManager sharedManager] setMainUIWindow:[SFApplicationHelper sharedApplication].windows[0]];
    }
    
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [SFSDKCoreLogger e:[self class] format:@"Please correct errors and try again."];
        [self sendLaunchError:launchStateError];
    } else {
        // Set service configuration values, based on app config.
        [self setupServiceConfiguration];
        
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
    }
    
    return launchActionString;
}

#pragma mark - Dev support methods

- (void)setIsDevSupportEnabled:(BOOL)isDevSupportEnabled {
    _isDevSupportEnabled = isDevSupportEnabled;
    if (self.isDevSupportEnabled) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(showDevSupportDialog)
                                                     name:SFSDKShowDevDialogNotification
                                                   object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:SFSDKShowDevDialogNotification object:nil];
    }
}

- (void)showDevSupportDialog
{
    SFSDKWindowContainer * activeWindow = [SFSDKWindowManager sharedManager].activeWindow;
    if ([self isDevSupportEnabled] && activeWindow.isEnabled) {
        UIViewController * topViewController = activeWindow.topViewController;
        if (topViewController) {
            [self showDevSupportDialog:topViewController];
        }
    }
}


- (void) showDevSupportDialog:(UIViewController *)presentedViewController
{
    // Do nothing if dev support is not enabled or dialog is already being shown
    if (!self.isDevSupportEnabled || self.actionSheet) {
        return;
    }

    // On larger devices we don't have an anchor point for the action sheet
    UIAlertControllerStyle style = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? UIAlertControllerStyleActionSheet : UIAlertControllerStyleAlert;
    self.actionSheet = [UIAlertController alertControllerWithTitle:@"Mobile SDK Dev Support"
                                                       message:@""
                                                preferredStyle:style];

    NSArray* devActions = [self getDevActions:presentedViewController];
    for (int i=0; i<devActions.count; i+=2) {
        [self.actionSheet addAction:[UIAlertAction actionWithTitle:devActions[i]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(__unused UIAlertAction *action) {
                                                               ((dispatch_block_t) devActions[i+1])();
                                                               self.actionSheet = nil;
                                                           }]];
    }
    [self.actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(__unused UIAlertAction *action) {
                                                           self.actionSheet = nil;
                                                       }]];

    [presentedViewController presentViewController:self.actionSheet animated:YES completion:nil];
}

-(NSArray*) getDevActions:(UIViewController *)presentedViewController
{
    return @[
            @"Show dev info", ^{
                SFSDKDevInfoViewController *devInfo = [[SFSDKDevInfoViewController alloc] init];
                [presentedViewController presentViewController:devInfo animated:NO completion:nil];
            },
            @"Logout", ^{
                [[SFUserAccountManager  sharedInstance] logout];
            },
            @"Switch user", ^{
                SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
                    [presentedViewController dismissViewControllerAnimated:YES completion:nil];
                }];
                [presentedViewController presentViewController:umvc animated:YES completion:nil];
            }
    ];
}

- (NSArray*) getDevSupportInfos
{
    SFUserAccountManager* userAccountManager = [SFUserAccountManager sharedInstance];
    NSMutableArray * devInfos = [NSMutableArray arrayWithArray:@[
            @"SDK Version", SALESFORCE_SDK_VERSION,
            @"App Type", [self getAppTypeAsString],
            @"User Agent", self.userAgentString(@""),
            @"Browser Login Enabled", userAccountManager.advancedAuthConfiguration != SFOAuthAdvancedAuthConfigurationNone ? @"YES" : @"NO",
            @"IDP Enabled", [self idpEnabled] ? @"YES" : @"NO",
            @"Identity Provider", [self isIdentityProvider] ? @"YES" : @"NO",
            @"Current User", [self userToString:userAccountManager.currentUser],
            @"Authenticated Users", [self usersToString:userAccountManager.allUserAccounts]
    ]];

    [devInfos addObjectsFromArray:[self dictToDevInfos:self.appConfig.configDict keyPrefix:@"BootConfig"]];
    
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    [devInfos addObjectsFromArray:@[@"Managed", [managedPreferences hasManagedPreferences] ? @"YES" : @"NO"]];
    if ([managedPreferences hasManagedPreferences]) {
        [devInfos addObjectsFromArray:[self dictToDevInfos:managedPreferences.rawPreferences keyPrefix:@"Managed Pref"]];
    }

    return devInfos;
}

- (NSString*) userToString:(SFUserAccount*)user {
    return user ? user.email : @"";
}

- (NSString*) usersToString:(NSArray<SFUserAccount*>*)userAccounts {
    NSMutableArray* usernames = [NSMutableArray new];
    for (SFUserAccount *userAccount in userAccounts) {
        [usernames addObject:[self userToString:userAccount]];
    }
    return [usernames componentsJoinedByString:@", "];
}

- (NSArray*) dictToDevInfos:(NSDictionary*)dict keyPrefix:(NSString*)keyPrefix {
    NSMutableArray * devInfos = [NSMutableArray new];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [devInfos addObject:[NSString stringWithFormat:@"%@ - %@", keyPrefix, key]];
        [devInfos addObject:[[NSString stringWithFormat:@"%@", obj] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
    }];
    return devInfos;
}

#pragma mark - Private methods

- (BOOL)validateLaunchState:(NSError **)launchStateError
{
    BOOL validInputs = YES;
    NSMutableArray *launchStateErrorMessages = [NSMutableArray array];
    // Managed settings should override any equivalent local app settings.
    [self configureManagedSettings];
    
    if ([SFSDKWindowManager sharedManager].mainWindow == nil) {
        NSString *noWindowError = [NSString stringWithFormat:@"%@ cannot perform launch before the UIApplication main window property has been initialized.  Cannot continue.", [self class]];
        [SFSDKCoreLogger e:[self class] format:noWindowError];
        [launchStateErrorMessages addObject:noWindowError];
        validInputs = NO;
    }
    
    NSError *appConfigError = nil;
    BOOL appConfigValidated = [self.appConfig validate:&appConfigError];
    if (!appConfigValidated) {
        NSString *errorMessage = [NSString stringWithFormat:@"App config did not validate: %@. Cannot continue.", appConfigError.localizedDescription];
        [SFSDKCoreLogger e:[self class] message:errorMessage];
        [launchStateErrorMessages addObject:errorMessage];
        validInputs = NO;
    }
    if (!self.postLaunchAction) {
        [SFSDKCoreLogger w:[self class] format:@"No post-launch action set.  Nowhere to go after launch completes."];
    }
    if (!self.launchErrorAction) {
        [SFSDKCoreLogger w:[self class] format:@"No launch error action set.  Nowhere to go if an error occurs during launch."];
    }
    if (!self.postLogoutAction) {
        [SFSDKCoreLogger w:[self class] format:@"No post-logout action set.  Nowhere to go when the user is logged out."];
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

- (void)configureManagedSettings
{
    if ([SFManagedPreferences sharedPreferences].requireCertificateAuthentication) {
        [SFUserAccountManager sharedInstance].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }
    
    if ([SFManagedPreferences sharedPreferences].connectedAppId.length > 0) {
        self.appConfig.remoteAccessConsumerKey = [SFManagedPreferences sharedPreferences].connectedAppId;
    }
    
    if ([SFManagedPreferences sharedPreferences].connectedAppCallbackUri.length > 0) {
        self.appConfig.oauthRedirectURI = [SFManagedPreferences sharedPreferences].connectedAppCallbackUri;
    }
    
    if ([SFManagedPreferences sharedPreferences].idpAppURLScheme) {
        self.idpAppURIScheme = [SFManagedPreferences sharedPreferences].idpAppURLScheme;
    }
}

- (void)setupServiceConfiguration
{
    [SFUserAccountManager sharedInstance].oauthClientId = self.appConfig.remoteAccessConsumerKey;
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = self.appConfig.oauthRedirectURI;
    [SFUserAccountManager sharedInstance].scopes = self.appConfig.oauthScopes;
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
    [self logoutCleanup];
    if (self.postLogoutAction) {
        self.postLogoutAction();
    }
}

- (void)logoutCleanup
{
    _isLaunching = NO;
    self.inManagerForegroundProcess = NO;
    self.passcodeDisplayed = NO;
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

- (void)sendPostAppForegroundIfRequired
{
    if (self.isInManagerForegroundProcess) {
        self.inManagerForegroundProcess = NO;
        if (self.postAppForegroundAction) {
            self.postAppForegroundAction();
        }
    }
}

- (void)handleAppForeground:(NSNotification *)notification
{
    [SFSDKCoreLogger d:[self class] format:@"App is entering the foreground."];
    
    [self enumerateDelegates:^(NSObject<SalesforceSDKManagerDelegate> *delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerWillEnterForeground)]) {
            [delegate sdkManagerWillEnterForeground];
        }
    }];
    
    if (_isLaunching) {
        [SFSDKCoreLogger d:[self class] format:@"SDK is still launching.  No foreground action taken."];
    } else {
        self.inManagerForegroundProcess = YES;
        if (self.isPasscodeDisplayed) {
            // Passcode was already displayed prior to app foreground.  Leverage delegates to manage
            // post-foreground process.
            [SFSDKCoreLogger i:[self class] format:@"%@ Passcode screen already displayed. Post-app foreground will continue after passcode challenge completes.", NSStringFromSelector(_cmd)];
        } else {
            // Check to display pin code screen.
            [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
                // Note: Failed passcode verification automatically logs out users, which the logout
                // delegate handler will catch and pass on.  We just log the error and reset launch
                // state here.
                [SFSDKCoreLogger e:[self class] format:@"Passcode validation failed.  Logging the user out."];
            }];
            
            [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction lockoutAction) {
                [SFSDKCoreLogger i:[self class] format:@"Passcode validation succeeded, or was not required, on app foreground.  Triggering postAppForeground handler."];
                [self sendPostAppForegroundIfRequired];
            }];
            
            [SFSecurityLockout validateTimer];
        }
    }
}

- (void)handleAppBackground:(NSNotification *)notification
{
    [SFSDKCoreLogger d:[self class] format:@"App is entering the background."];
    
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
    [SFSDKCoreLogger d:[self class] format:@"App is resuming active state."];
    
    [self enumerateDelegates:^(id<SalesforceSDKManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(sdkManagerDidBecomeActive)]) {
            [delegate sdkManagerDidBecomeActive];
        }
    }];
    
    @try {
        [self dismissSnapshot];
    }
    @catch (NSException *exception) {
        [SFSDKCoreLogger w:[self class] format:@"Exception thrown while removing security snapshot view: '%@'. Will continue to resume app.", [exception reason]];
    }
}

- (void)handleAppWillResignActive:(NSNotification *)notification
{
    [SFSDKCoreLogger d:[self class] format:@"App is resigning active state."];
    
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
        [SFSDKCoreLogger w:[self class] format:@"Exception thrown while setting up security snapshot view: '%@'. Continuing resign active.", [exception reason]];
    }
}

- (void)handleAuthCompleted:(NSNotification *)notification
{
    // Will set up the passcode timer for auth that occurs out of band from SDK Manager launch.
    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
}

- (void)handleIDPInitiatedAuthCompleted:(NSNotification *)notification
{
    // Will set up the passcode timer for auth that occurs out of band from SDK Manager launch.
    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
    NSDictionary *userInfo = notification.userInfo;
    SFUserAccount *userAccount = userInfo[kSFNotificationUserInfoAccountKey];
    [[SFUserAccountManager sharedInstance] switchToUser:userAccount];
    [self sendPostLaunch];
}

- (void)handleIDPUserAddCompleted:(NSNotification *)notification
{
   
    NSDictionary *userInfo = notification.userInfo;
    SFUserAccount *userAccount = userInfo[kSFNotificationUserInfoAccountKey];
    // this is the only user context in the idp app.
    if ([userAccount isEqual:[SFUserAccountManager sharedInstance].currentUser]) {
        [SFSecurityLockout setupTimer];
        [SFSecurityLockout startActivityMonitoring];
        [[SFUserAccountManager sharedInstance] switchToUser:userAccount];
        [self sendPostLaunch];
    }
}

- (void)handlePostLogout
{
    // Close the passcode screen and reset passcode monitoring.
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
    [self sendPostLogout];
}

- (void)handleUserWillSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    [SFSecurityLockout cancelPasscodeScreen];
    [SFSecurityLockout stopActivityMonitoring];
    [SFSecurityLockout removeTimer];
}

- (void)handleUserDidSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    [SFSecurityLockout setupTimer];
    [SFSecurityLockout startActivityMonitoring];
    [self sendUserAccountSwitch:fromUser toUser:toUser];
}

- (void)savePasscodeActivityInfo
{
    [SFSecurityLockout removeTimer];
    [SFInactivityTimerCenter saveActivityTimestamp];
}
    
- (BOOL)isSnapshotPresented
{
    return [[SFSDKWindowManager sharedManager].snapshotWindow isEnabled];
}

- (void)presentSnapshot
{
    if (!self.useSnapshotView) {
        return;
    }

    // Try to retrieve a custom snapshot view controller
    UIViewController* customSnapshotViewController = nil;
    if (self.snapshotViewControllerCreationAction) {
        customSnapshotViewController = self.snapshotViewControllerCreationAction();
    }
    
    // Custom snapshot view controller provided
    if (customSnapshotViewController) {
        _snapshotViewController = customSnapshotViewController;
    }
    // No custom snapshot view controller provided
    else {
        _snapshotViewController =  [[SnapshotViewController alloc] initWithNibName:nil bundle:nil];
    }
    
    // Presentation
    __weak typeof (self) weakSelf = self;
    [[SFSDKWindowManager sharedManager].snapshotWindow  presentWindowAnimated:NO withCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.snapshotPresentationAction && strongSelf.snapshotDismissalAction) {
            strongSelf.snapshotPresentationAction(strongSelf->_snapshotViewController);
        }else {
            [SFSDKWindowManager.sharedManager.snapshotWindow.viewController presentViewController:strongSelf->_snapshotViewController animated:NO completion:nil];
        }
    }];
    
}

- (void)dismissSnapshot
{
    if ([self isSnapshotPresented]) {
        if (self.snapshotPresentationAction && self.snapshotDismissalAction) {
            self.snapshotDismissalAction(_snapshotViewController);
            if ([SFSecurityLockout isPasscodeNeeded]) {
                [SFSecurityLockout validateTimer];
            }
        } else {
            [[SFSDKWindowManager sharedManager].snapshotWindow.viewController dismissViewControllerAnimated:NO completion:^{
                [[SFSDKWindowManager sharedManager].snapshotWindow dismissWindowAnimated:NO  withCompletion:^{
                    if ([SFSecurityLockout isPasscodeNeeded]) {
                        [SFSecurityLockout validateTimer];
                    }
                }];
            }];
            
        }
    }
    
}

- (void)clearClipboard
{
    if ([SFManagedPreferences sharedPreferences].clearClipboardOnBackground) {
        [SFSDKCoreLogger i:[self class] format:@"%@: Clearing clipboard on app background.", NSStringFromSelector(_cmd)];
        [UIPasteboard generalPasteboard].strings = @[ ];
        [UIPasteboard generalPasteboard].URLs = @[ ];
        [UIPasteboard generalPasteboard].images = @[ ];
        [UIPasteboard generalPasteboard].colors = @[ ];
    }
}

- (void)passcodeValidationAtLaunch
{
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [SFSDKCoreLogger i:[self class] format:@"Passcode verified, or not configured.  Proceeding with authentication validation."];
        [self passcodeValidatedToAuthValidation];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        
        // Note: Failed passcode verification automatically logs out users, which the logout
        // delegate handler will catch and pass on.  We just log the error and reset launch
        // state here.
        [SFSDKCoreLogger e:[self class] format:@"Passcode validation failed.  Logging the user out."];
    }];
    [SFSecurityLockout lock];
}

- (void)passcodeValidatedToAuthValidation
{
    self.launchActions |= SFSDKLaunchActionPasscodeVerified;
    self.hasVerifiedPasscodeAtStartup = YES;
    [self authValidationAtLaunch];
}

- (void)authValidationAtLaunch
{
    if (self.appConfig.shouldAuthenticate &&  [SFUserAccountManager sharedInstance].currentUser.credentials.accessToken==nil) {
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
    [SFSDKCoreLogger i:[self class] format:@"No valid credentials found.  Proceeding with authentication."];
    
    SFOAuthFlowSuccessCallbackBlock successBlock = ^(SFOAuthInfo *authInfo,SFUserAccount *userAccount) {
        [SFSDKCoreLogger i:[self class] format:@"Authentication (%@) succeeded.  Launch completed.", authInfo.authTypeDescription];
        [SFUserAccountManager sharedInstance].currentUser = userAccount;
        [SFSecurityLockout setupTimer];
        [SFSecurityLockout startActivityMonitoring];
        [self authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
    };
    
    SFOAuthFlowFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *authError) {
        [SFSDKCoreLogger e:[self class] format:@"Authentication (%@) failed: %@.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh"), [authError localizedDescription]];
        [self sendLaunchError:authError];
    };
    
    if (self.useLegacyAuthenticationManager) {
        SFSDK_USE_DEPRECATED_BEGIN

        [[SFAuthenticationManager sharedManager] loginWithCompletion:successBlock failure:failureBlock];
        
        SFSDK_USE_DEPRECATED_END

    } else {
        [[SFUserAccountManager sharedInstance] loginWithCompletion:successBlock failure:failureBlock];
    }
}

- (void)authBypassAtLaunch
{
    // If there is a current user (from a previous authentication), we still need to set up the
    // in-memory auth state of that user.
    if ([SFUserAccountManager sharedInstance].currentUser != nil && self.useLegacyAuthenticationManager) {
        SFSDK_USE_DEPRECATED_BEGIN

        [[SFAuthenticationManager sharedManager] setupWithCredentials:[SFUserAccountManager sharedInstance].currentUser.credentials];
        
        SFSDK_USE_DEPRECATED_END

    }
    
    SFSDKLaunchAction noAuthLaunchAction;
    if (!self.appConfig.shouldAuthenticate) {
        [SFSDKCoreLogger i:[self class] format:@"SDK Manager is configured not to attempt authentication at launch.  Skipping auth."];
        noAuthLaunchAction = SFSDKLaunchActionAuthBypassed;
    } else {
        [SFSDKCoreLogger i:[self class] format:@"Credentials already present.  Will not attempt to authenticate."];
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
    [[SFUserAccountManager sharedInstance] dismissAuthViewControllerIfPresent];

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
        NSString *webViewUserAgent = [self getUIWebViewUserAgent];

        // App type.
        NSString *appTypeStr = [self getAppTypeAsString];
        NSString *myUserAgent = [NSString stringWithFormat:
                                 @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@%@ uid_%@ ftr_%@ %@",
                                 SALESFORCE_SDK_VERSION,
                                 [curDevice systemName],
                                 [curDevice systemVersion],
                                 [curDevice model],
                                 appName,
                                 appVersion,
                                 appTypeStr,
                                 (qualifier != nil ? qualifier : @""),
                                 uid,
                                 [[[SFSDKAppFeatureMarkers appFeatures].allObjects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@"."],
                                 webViewUserAgent
                                 ];
        return myUserAgent;
    };
}

- (NSString *)getUIWebViewUserAgent {
    static NSString *webViewUserAgent = nil;
    static dispatch_once_t onceToken;
    dispatch_once_on_main_thread(&onceToken, ^{
        // Grabs the current user agent. This is very hackish but WKWebView, which we
        // want to transition too currently evaluates Javscript asynchronously (11/2/17)
        UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        webViewUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    });
    
    return webViewUserAgent;
}

void dispatch_once_on_main_thread(dispatch_once_t *predicate, dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        dispatch_once(predicate, block);
    } else {
        if (DISPATCH_EXPECT(*predicate == 0L, NO)) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                dispatch_once(predicate, block);
            });
        }
    }
}

- (NSString *)getAppTypeAsString {
    NSString* appTypeStr;
    switch (self.appType) {
            case kSFAppTypeNative: appTypeStr = kSFMobileSDKNativeDesignator; break;
            case kSFAppTypeHybrid: appTypeStr = kSFMobileSDKHybridDesignator; break;
            case kSFAppTypeReactNative: appTypeStr = kSFMobileSDKReactNativeDesignator; break;
            case kSFAppTypeNativeSwift: appTypeStr = kSFMobileSDKNativeSwiftDesignator; break;
        }
    return appTypeStr;
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
SFSDK_USE_DEPRECATED_BEGIN

#pragma mark - SFAuthenticationManagerDelegate
- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self.sdkManagerFlow handlePostLogout];
}

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user
{

}
SFSDK_USE_DEPRECATED_END

#pragma mark - SFUserAccountManagerDelegate

- (void)handleUserDidLogout:(NSNotification *)notification {
    [self.sdkManagerFlow handlePostLogout];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self.sdkManagerFlow handleUserWillSwitch:fromUser toUser:toUser];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self.sdkManagerFlow handleUserDidSwitch:fromUser toUser:toUser];
}

#pragma mark - SFSecurityLockoutDelegate

- (void)passcodeFlowWillBegin:(SFPasscodeControllerMode)mode
{
    self.passcodeDisplayed = YES;
}

- (void)passcodeFlowDidComplete:(BOOL)success
{
    self.passcodeDisplayed = NO;
    [self sendPostAppForegroundIfRequired];
}

@end

