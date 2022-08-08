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
#import "SFUserAccountManager+Internal.h"
#import "SFSDKWindowManager.h"
#import "SFManagedPreferences.h"
#import "SFInactivityTimerCenter.h"
#import "SFApplicationHelper.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKDevInfoViewController.h"
#import "SFDefaultUserManagementViewController.h"
#import <SalesforceSDKCommon/SFSwiftDetectUtil.h>
#import "SFSDKEncryptedURLCache.h"
#import "SFSDKNullURLCache.h"
#import "UIColor+SFColors.h"
#import "SFDirectoryManager+Internal.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import "SFSDKResourceUtils.h"
#import "SFSDKMacDetectUtil.h"
#import "SFSDKSalesforceSDKUpgradeManager.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>

static NSString * const kSFAppFeatureSwiftApp    = @"SW";
static NSString * const kSFAppFeatureMultiUser   = @"MU";
static NSString * const kSFAppFeatureMacApp      = @"MC";

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

// Device id
static NSString* uid = nil;

// Instance class
static Class InstanceClass = nil;

// AILTN app name
static NSString* ailtnAppName = nil;

// App name
static NSString* appName = nil;

// Dev support
static NSString *const SFSDKShowDevDialogNotification = @"SFSDKShowDevDialogNotification";
static IMP motionEndedImplementation = nil;

// User agent constants
static NSString * const kSFMobileSDKNativeDesignator = @"Native";
static NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";
static NSString * const kSFMobileSDKReactNativeDesignator = @"ReactNative";
static NSString * const kSFMobileSDKNativeSwiftDesignator = @"NativeSwift";
static NSString * const kWebViewUserAgentKey = @"web_view_user_agent";

// URL cache
static NSInteger const kDefaultCacheMemoryCapacity = 1024 * 1024 * 4; // 4MB
static NSInteger const kDefaultCacheDiskCapacity = 1024 * 1024 * 20;  // 20MB

NSString * const kSFScreenLockFlowWillBegin = @"SFScreenLockFlowWillBegin";
NSString * const kSFScreenLockFlowCompleted = @"SFScreenLockFlowCompleted";

@implementation UIWindow (SalesforceSDKManager)

- (void)sfsdk_motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.subtype == UIEventSubtypeMotionShake) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SFSDKShowDevDialogNotification object:nil];
    }
    // Doing this instead of exchanging the implementations and calling sfsdk_motionEnded:withEvent: so that
    // it has the correct value for _cmd (motionEnded:withEvent:)
    ((void(*)(id, SEL, long, id))motionEndedImplementation)(self, _cmd, motion, event);
}

@end

@implementation SnapshotViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor salesforceSystemBackgroundColor];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
   return UIInterfaceOrientationMaskAll;
}
@end

@implementation SFSDKDevAction
- (instancetype)initWith:(NSString *)name handler:(void (^)(void))handler {
    if (self = [super init]) {
        _name = name;
        _handler = handler;
    }
    return self;
}
@end

@interface SalesforceSDKManager ()

@property(nonatomic, strong) UIAlertController *actionSheet;
@property(nonatomic, strong) WKWebView *webView; // for calculating user agent
@property(nonatomic, strong) NSString *webViewUserAgent; // for calculating user agent

@end

@implementation SalesforceSDKManager

@synthesize webViewUserAgent = _webViewUserAgent;

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

+ (void)setAppName:(NSString *)newAppName {
    @synchronized (appName) {
        if (newAppName) {
            appName = newAppName;
        }
    }
}

+ (NSString *)appName {
    return appName;
}

+ (void)initialize {
    if (self == [SalesforceSDKManager class]) {

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

        /*
         * Checks if an app name has already been set by the app.
         * If not, fetches the default app name to be used and sets it.
         */
        NSString *currentAppName = [SalesforceSDKManager appName];
        if (!currentAppName) {
            NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
            if (appName) {
                [SalesforceSDKManager setAppName:appName];
            }
        }
    }
}

+ (void)initializeSDK {
    [self initializeSDKWithClass:InstanceClass];
}

+ (void)initializeSDKWithClass:(Class)className {
    [self setInstanceClass:className];
    [SalesforceSDKManager sharedManager];
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
        if ([SFSDKMacDetectUtil isOnMac]) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMacApp];
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

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // For dev support
        Method sfsdkMotionEndedMethod = class_getInstanceMethod([UIWindow class], @selector(sfsdk_motionEnded:withEvent:));
        IMP sfsdkMotionEndedImplementation = method_getImplementation(sfsdkMotionEndedMethod);
        motionEndedImplementation = method_setImplementation(class_getInstanceMethod([UIWindow class], @selector(motionEnded:withEvent:)), sfsdkMotionEndedImplementation);

        // Pasteboard
        // Get implementation of general pasteboard and store it
        Method generalPasteboardMethod = class_getClassMethod([UIPasteboard class], @selector(generalPasteboard));
        IMP generalPasteboardImplementation = method_getImplementation(generalPasteboardMethod);
        method_setImplementation(class_getClassMethod([SalesforceSDKManager class], @selector(generalPasteboard)), generalPasteboardImplementation);
        
        // Set general pasteboard to sdkPasteboard that will either direct to a named pasteboard or the original [UIPasteboard generalPasteboard]
        Method sdkPasteboardMethod = class_getClassMethod([SalesforceSDKManager class], @selector(sdkPasteboard));
        IMP sdkPasteboardImplementation = method_getImplementation(sdkPasteboardMethod);
        method_setImplementation(class_getClassMethod([UIPasteboard class], @selector(generalPasteboard)), sdkPasteboardImplementation);
    });
}

+ (UIPasteboard *)generalPasteboard {
    // As a result of swizzling, will contain the implementation of [UIPasteboard generalPasteboard]
    return nil;
}

+ (UIPasteboard *)sdkNamedPasteboard {
     return [UIPasteboard pasteboardWithName:@"com.salesforce.mobilesdk.pasteboard" create:YES];
}

+ (UIPasteboard *)sdkPasteboard {
    if ([SFManagedPreferences sharedPreferences].shouldDisableExternalPasteDefinedByConnectedApp) {
        return [SalesforceSDKManager sdkNamedPasteboard];
    }
    return [SalesforceSDKManager generalPasteboard];
}

- (instancetype)init {
    self = [super init];
    if (self) {
#ifdef DEBUG
        self.isDevSupportEnabled = YES;
#endif
        self.sdkManagerFlow = self;
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleAppTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleSceneDidActivate:) name:UISceneDidActivateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleSceneDidEnterBackground:) name:UISceneDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleSceneWillConnect:) name:UISceneWillConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleSceneDidDisconnect:) name:UISceneDidDisconnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow
                                                selector:@selector(handleAuthCompleted:)
                                                     name:kSFNotificationUserDidLogIn object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleIDPInitiatedAuthCompleted:)
                                                     name:kSFNotificationUserIDPInitDidLogIn object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleIDPUserAddCompleted:)
                                                     name:kSFNotificationUserWillSendIDPResponse object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserWillLogout:) name:kSFNotificationUserWillLogout object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self.sdkManagerFlow selector:@selector(handleUserDidLogout:) name:kSFNotificationUserDidLogout object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenLockFlowWillBegin:) name:kSFScreenLockFlowWillBegin object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenLockFlowDidComplete:) name:kSFScreenLockFlowCompleted object:nil];
        
        _useSnapshotView = ![SFSDKMacDetectUtil isOnMac];
        [self computeWebViewUserAgent]; // web view user agent is computed asynchronously so very first call to self.userAgentString(...) will be missing it
        self.userAgentString = [self defaultUserAgentString];
        self.URLCacheType = kSFURLCacheTypeEncrypted;
        self.useEphemeralSessionForAdvancedAuth = YES;
        [self setupServiceConfiguration];
        _snapshotViewControllers = [SFSDKSafeMutableDictionary new];
        [SFSDKSalesforceSDKUpgradeManager upgrade];
        [[SFScreenLockManager shared] checkForScreenLockUsers]; // This is necessary because keychain values can outlive the app.
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

- (NSString *)brandLoginPath
{
    return [SFUserAccountManager sharedInstance].brandLoginPath;
}

- (void)setBrandLoginPath:(NSString *)brandLoginPath
{
    [SFUserAccountManager sharedInstance].brandLoginPath = brandLoginPath;
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
    SFSDKWindowContainer *activeWindow = [[SFSDKWindowManager sharedManager] activeWindow:nil];
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
    self.actionSheet = [UIAlertController alertControllerWithTitle:[self devInfoTitleString] message:@"" preferredStyle:style];
    NSArray<SFSDKDevAction *>* devActions = [self getDevActions:presentedViewController];
    for (int i = 0; i < devActions.count; i++) {
        [self.actionSheet addAction:[UIAlertAction actionWithTitle:devActions[i].name
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(__unused UIAlertAction *action) {
                                                               devActions[i].handler();
                                                               self.actionSheet = nil;
                                                           }]];
    }
    [self.actionSheet addAction:[UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"devInfoCancelKey"] style:UIAlertActionStyleCancel
                                                       handler:^(__unused UIAlertAction *action) {
                                                           self.actionSheet = nil;
                                                       }]];
    [presentedViewController presentViewController:self.actionSheet animated:YES completion:nil];
}

- (NSString *)devInfoTitleString
{
    return [SFSDKResourceUtils localizedString:@"devInfoTitle"];
}

- (NSArray<SFSDKDevAction *>*) getDevActions:(UIViewController *)presentedViewController
{
    return @[
             [[SFSDKDevAction alloc]initWith:@"Show dev info" handler:^{
                 SFSDKDevInfoViewController *devInfo = [[SFSDKDevInfoViewController alloc] init];
                 [presentedViewController presentViewController:devInfo animated:NO completion:nil];
             }],
             [[SFSDKDevAction alloc]initWith:@"Logout" handler:^{
                 [[SFUserAccountManager  sharedInstance] logout];
             }],
             [[SFSDKDevAction alloc]initWith:@"Switch user" handler:^{
                 SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
                     [presentedViewController dismissViewControllerAnimated:YES completion:nil];
                 }];
                 [presentedViewController presentViewController:umvc animated:YES completion:nil];
             }],
             [[SFSDKDevAction alloc]initWith:@"Inspect Key-Value Store" handler:^{
                 UIViewController *keyValueStoreInspector = [[SFSDKKeyValueEncryptedFileStoreViewController new] createUI];
                 [presentedViewController presentViewController:keyValueStoreInspector animated:YES completion:nil];
             }]
    ];
}

- (NSArray<NSString *>*) getDevSupportInfos
{
    SFUserAccountManager* userAccountManager = [SFUserAccountManager sharedInstance];
    NSMutableArray * devInfos = [NSMutableArray arrayWithArray:@[
            @"SDK Version", SALESFORCE_SDK_VERSION,
            @"App Type", [self getAppTypeAsString],
            @"User Agent", self.userAgentString(@""),
            @"Browser Login Enabled", [SFUserAccountManager sharedInstance].useBrowserAuth? @"YES" : @"NO",
            @"IDP Enabled", [self idpEnabled] ? @"YES" : @"NO",
            @"Identity Provider", [self isIdentityProvider] ? @"YES" : @"NO",
            @"Current User", [self userToString:userAccountManager.currentUser],
            @"Authenticated Users", [self usersToString:userAccountManager.allUserAccounts],
            @"User Key-Value Stores", [self safeJoin:[SFSDKKeyValueEncryptedFileStore allStoreNames] separator:@", "],
            @"Global Key-Value Stores", [self safeJoin:[SFSDKKeyValueEncryptedFileStore allGlobalStoreNames] separator:@", "]
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
    return user ? user.idData.username : @"";
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

- (void)configureManagedSettings
{
    if ([SFManagedPreferences sharedPreferences].requireCertificateAuthentication) {
        [SFUserAccountManager sharedInstance].useBrowserAuth = YES;
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

- (void)handleAppForeground:(NSNotification *)notification
{
    [SFSDKSalesforceSDKUpgradeManager upgrade];
    [[SFScreenLockManager shared] handleAppForeground];
}

- (void)handleAppBackground:(NSNotification *)notification
{
    [SFSDKCoreLogger d:[self class] format:@"App is entering the background."];
    [self clearClipboard];
}

- (void)handleAppTerminate:(NSNotification *)notification { }

- (void)handleSceneDidActivate:(NSNotification *)notification {
     UIScene *scene = (UIScene *)notification.object;
     NSString *sceneId = scene.session.persistentIdentifier;
     [SFSDKCoreLogger d:[self class] format:@"Scene %@ is resuming active state.", sceneId];

     @try {
         [self dismissSnapshot:scene completion:nil];
     }
     @catch (NSException *exception) {
         [SFSDKCoreLogger w:[self class] format:@"Exception thrown while removing security snapshot view for scene %@: '%@'. Will continue to resume scene.", sceneId, [exception reason]];
     }
}

- (void)handleSceneWillConnect:(NSNotification *)notification {
    UIScene *scene = (UIScene *)notification.object;
    if (scene.activationState == UISceneActivationStateBackground) {
        SFSDKWindowContainer *activeWindow = [[SFSDKWindowManager sharedManager] activeWindow:scene];
        if ([activeWindow isAuthWindow] || [activeWindow isScreenLockWindow]) {
            return;
        }
        [self presentSnapshot:scene];
    }
}

- (void)handleSceneDidEnterBackground:(NSNotification *)notification {
    UIScene *scene = (UIScene *)notification.object;
    NSString *sceneId = scene.session.persistentIdentifier;

    [SFSDKCoreLogger d:[self class] format:@"Scene %@ is entering background.", sceneId];

    // Don't present snapshot during advanced authentication or Screen Lock Presentation
    // ==============================================================================
    // During advanced authentication, application is briefly backgrounded then foregrounded
    // The ASWebAuthenticationSession's view controller is pushed into the key window
    // If we make the snapshot window the active window now, that's where the ASWebAuthenticationSession's view controller will end up
    // Then when the application is foregrounded and the snapshot window is dismissed, we will lose the ASWebAuthenticationSession
    SFSDKWindowContainer *activeWindow = [[SFSDKWindowManager sharedManager] activeWindow:scene];
    if ([activeWindow isAuthWindow] || [activeWindow isScreenLockWindow]) {
        return;
    }

    // Set up snapshot security view, if it's configured.
    @try {
        [self presentSnapshot:scene];
    }
    @catch (NSException *exception) {
        [SFSDKCoreLogger w:[self class] format:@"Exception thrown while setting up security snapshot view for scene %@: '%@'. Continuing background.", sceneId, [exception reason]];
    }
}

- (void)handleSceneDidDisconnect:(NSNotification *)notification {
    UIScene *scene = (UIScene *)notification.object;
    [self.snapshotViewControllers removeObject:scene.session.persistentIdentifier];
}

- (void)handleAuthCompleted:(NSNotification *)notification { }

- (void)handleIDPInitiatedAuthCompleted:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    SFUserAccount *userAccount = userInfo[kSFNotificationUserInfoAccountKey];
    [[SFUserAccountManager sharedInstance] switchToUser:userAccount];
}

- (void)handleIDPUserAddCompleted:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    SFUserAccount *userAccount = userInfo[kSFNotificationUserInfoAccountKey];
    // this is the only user context in the idp app.
    if ([userAccount isEqual:[SFUserAccountManager sharedInstance].currentUser]) {
        [[SFUserAccountManager sharedInstance] switchToUser:userAccount];
    }
}
- (void)handleUserWillLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
    [SFSDKKeyValueEncryptedFileStore removeAllStoresForUser:user];
}

- (void)handlePostLogout
{
    [[SFScreenLockManager shared] checkForScreenLockUsers];
}
    
- (BOOL)isSnapshotPresented:(UIScene *)scene {
    return [[[SFSDKWindowManager sharedManager] snapshotWindow:scene] isEnabled];
}

- (void)presentSnapshot:(UIScene *)scene {
    if (!_useSnapshotView) {
        return;
    }
    NSString *sceneId = scene.session.persistentIdentifier;
    [SFSDKCoreLogger d:[self class] format:@"Scene %@ is trying to present snapshot.", sceneId];
    // Try to retrieve a custom snapshot view controller
    UIViewController* customSnapshotViewController = nil;
    if (self.snapshotViewControllerCreationAction) {
        customSnapshotViewController = self.snapshotViewControllerCreationAction();
    }
    
    // Custom snapshot view controller provided
    if (customSnapshotViewController) {
        _snapshotViewControllers[sceneId] = customSnapshotViewController;
    }
    // No custom snapshot view controller provided
    else {
        _snapshotViewControllers[sceneId] = [[SnapshotViewController alloc] initWithNibName:nil bundle:nil];
    }
    _snapshotViewControllers[sceneId].modalPresentationStyle = UIModalPresentationFullScreen;
    // Presentation
    SFSDKWindowContainer *snapshotWindow = [[SFSDKWindowManager sharedManager] snapshotWindow:scene];
    __weak typeof (self) weakSelf = self;
    [snapshotWindow presentWindowAnimated:NO withCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.snapshotPresentationAction && strongSelf.snapshotDismissalAction) {
            strongSelf.snapshotPresentationAction(strongSelf.snapshotViewControllers[sceneId]);
        } else {
            [snapshotWindow.viewController presentViewController:strongSelf.snapshotViewControllers[sceneId] animated:NO completion:nil];
        }
    }];
}

- (void)dismissSnapshot:(UIScene *)scene completion:(void (^ __nullable)(void))completion {
    if ([self isSnapshotPresented:scene]) {
        if (self.snapshotPresentationAction && self.snapshotDismissalAction) {
            self.snapshotDismissalAction(self.snapshotViewControllers[scene.session.persistentIdentifier]);
        } else {
            SFSDKWindowContainer *snapshotWindow = [[SFSDKWindowManager sharedManager] snapshotWindow:scene];
            [snapshotWindow.viewController dismissViewControllerAnimated:NO completion:^{
                [snapshotWindow dismissWindowAnimated:NO withCompletion:^{
                    if (completion) {
                        completion();
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
        [SalesforceSDKManager generalPasteboard].strings = @[ ];
        [SalesforceSDKManager generalPasteboard].URLs = @[ ];
        [SalesforceSDKManager generalPasteboard].images = @[ ];
        [SalesforceSDKManager generalPasteboard].colors = @[ ];
        [SalesforceSDKManager sdkNamedPasteboard].strings = @[ ];
        [SalesforceSDKManager sdkNamedPasteboard].URLs = @[ ];
        [SalesforceSDKManager sdkNamedPasteboard].images = @[ ];
        [SalesforceSDKManager sdkNamedPasteboard].colors = @[ ];
    }
}

- (SFSDKUserAgentCreationBlock)defaultUserAgentString {
    return ^NSString *(NSString *qualifier) {
        UIDevice *curDevice = [UIDevice currentDevice];
        NSString *appName = [SalesforceSDKManager appName];
        NSString *prodAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
        NSString *appVersion = [NSString stringWithFormat:@"%@(%@)", prodAppVersion, buildNumber];

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
                                 self.webViewUserAgent == nil ? @"" : self.webViewUserAgent
                                 ];
        return myUserAgent;
    };
}

- (void)computeWebViewUserAgent {
    static dispatch_once_t onceToken;
    __weak typeof(self) weakSelf = self;
    dispatch_once_on_main_thread(&onceToken, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        [strongSelf.webView loadHTMLString:@"<html></html>" baseURL:nil];
        [strongSelf.webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id __nullable userAgent, NSError * __nullable error) {
            strongSelf.webViewUserAgent = userAgent;
            strongSelf.webView = nil;
        }];
    });
}

- (void)setWebViewUserAgent:(NSString *)webViewUserAgent {
    _webViewUserAgent = webViewUserAgent;
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults msdkUserDefaults];
    [standardUserDefaults setObject:webViewUserAgent forKey:kWebViewUserAgentKey];
    [standardUserDefaults synchronize];
}

- (NSString *)webViewUserAgent {
    if (_webViewUserAgent) {
        return _webViewUserAgent;
    } else {
        return [[NSUserDefaults msdkUserDefaults] stringForKey:kWebViewUserAgentKey];
    }
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
    return SFAppTypeGetDescription(self.appType);
}

- (void)setURLCacheType:(SFURLCacheType)URLCacheType {
    if (_URLCacheType != URLCacheType) {
        _URLCacheType = URLCacheType;
        [NSURLCache.sharedURLCache removeAllCachedResponses];
        NSURLCache *cache;
        switch (URLCacheType) {
            case kSFURLCacheTypeEncrypted:
                cache = [[SFSDKEncryptedURLCache alloc] initWithMemoryCapacity:kDefaultCacheMemoryCapacity diskCapacity:kDefaultCacheDiskCapacity directoryURL:nil];
                break;
            case kSFURLCacheTypeNull:
                cache = [[SFSDKNullURLCache alloc] initWithMemoryCapacity:kDefaultCacheMemoryCapacity diskCapacity:kDefaultCacheDiskCapacity directoryURL:nil];
                break;
            case kSFURLCacheTypeStandard:
                cache = [[NSURLCache alloc] initWithMemoryCapacity:kDefaultCacheMemoryCapacity diskCapacity:kDefaultCacheDiskCapacity directoryURL:nil];
                break;
        }
        [NSURLCache setSharedURLCache:cache];
    }
}

- (NSString*) safeJoin:(NSArray*)array separator:(NSString*)separator {
    return array ? [array componentsJoinedByString:separator] : @"";
}


#pragma mark - SFUserAccountManagerDelegate
- (void)handleUserDidLogout:(NSNotification *)notification {
    [self.sdkManagerFlow handlePostLogout];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{ }

#pragma mark - ScreenLock

- (void)screenLockFlowWillBegin:(NSNotification *)notification { }

- (void)screenLockFlowDidComplete:(NSNotification *)notification { }

@end

NSString *SFAppTypeGetDescription(SFAppType appType){
    NSString* appTypeStr;
    switch (appType) {
            case kSFAppTypeNative: appTypeStr = kSFMobileSDKNativeDesignator; break;
            case kSFAppTypeHybrid: appTypeStr = kSFMobileSDKHybridDesignator; break;
            case kSFAppTypeReactNative: appTypeStr = kSFMobileSDKReactNativeDesignator; break;
            case kSFAppTypeNativeSwift: appTypeStr = kSFMobileSDKNativeSwiftDesignator; break;
    }
    return appTypeStr;
}

