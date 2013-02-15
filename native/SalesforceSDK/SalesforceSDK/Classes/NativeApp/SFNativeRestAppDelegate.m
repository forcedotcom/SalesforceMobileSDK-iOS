/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFNativeRestAppDelegate.h"
#import "SFOAuthCredentials.h"
#import "SFAuthorizingViewController.h"
#import "SFRestAPI.h"
#import "SalesforceSDKConstants.h"
#import "SFIdentityData.h"
#import "SFAccountManager.h"
#import "SFSecurityLockout.h"
#import "SFNativeRootViewController.h"
#import "SFUserActivityMonitor.h"
#import "SFInactivityTimerCenter.h"
#import "SFOAuthInfo.h"
#import "SFSDKWebUtils.h"
#import "SFAuthenticationManager.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFLogger.h"

#if defined(DEBUG)
static SFLogLevel const kAppLogLevel = SFLogLevelDebug;
#else
static SFLogLevel const kAppLogLevel = SFLogLevelInfo;
#endif

@interface SFNativeRestAppDelegate () {
    /**
     Whether the app is in its initialization run (vs. just being brought to the foreground).
     */
    BOOL _isAppInitialization;
    
    /**
     The instance of the shared SFAccountManager to use for this class.
     */
    SFAccountManager *_accountMgr;
}

/**
 The initial view of the underlying root view controller.  Will be used as the "initial"
 page when the app is reset in situ.
 */
@property (nonatomic, strong) UIView *baseView;

/**
 Snapshot view for the app.
 */
@property (nonatomic, strong) UIView *snapshotView;

/**
 The callback block that will be executed after successful authentication.
 */
@property (nonatomic, copy) SFOAuthFlowSuccessCallbackBlock authSuccessBlock;

/**
 The callback block that will be executed in the event of a failed authentication attempt.
 */
@property (nonatomic, copy) SFOAuthFlowFailureCallbackBlock authFailureBlock;

/**
 Called after the authentication process completes successfully.
 */
- (void)postAuthSuccessProcesses:(SFOAuthInfo *) authInfo;

/**
 Will reset the app into its initial view state.  Primarily for when the user is logged out
 and the app starts over.
 */
- (void)resetRootPresentation;

/**
 Called when the app is entering the background, or in the process of being shut down.
 */
- (void)prepareToShutDown;

/**
 Set up and present the user-defined app root window.
 */
- (void)setupNewRootViewController;

@end

@implementation SFNativeRestAppDelegate

@synthesize viewController = _viewController;
@synthesize window = _window;
@synthesize baseView = _baseView;
@synthesize appLogLevel = _appLogLevel;
@synthesize snapshotView = _snapshotView;
@synthesize authSuccessBlock = _authSuccessBlock;
@synthesize authFailureBlock = _authFailureBlock;

#pragma mark - init/dealloc

- (id) init
{	
    self = [super init];
    if (nil != self) {
        [SFAccountManager setLoginHost:[self oauthLoginDomain]];
        [SFAccountManager setClientId:[self remoteAccessConsumerKey]];
        [SFAccountManager setRedirectUri:[self oauthRedirectURI]];
        [SFAccountManager setScopes:[[self class] oauthScopes]];
        [SFAccountManager setCurrentAccountIdentifier:[self userAccountIdentifier]];
        _accountMgr = [SFAccountManager sharedInstance];
        
        // Our preferred passcode provider as of this release.
        // NOTE: If you wanted to set a different provider (or your own), you would do the
        // following in your app delegate's init method:
        //   id<SFPasscodeProvider> *myProvider = [[MyProvider alloc] initWithProviderName:myProviderName];
        //   [SFPasscodeProviderManager addPasscodeProvider:myProvider];
        //   [SFPasscodeManager sharedManager].preferredPasscodeProvider = myProviderName;
        [SFPasscodeManager sharedManager].preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
        
        // Set up the authentication callback blocks.
        self.authSuccessBlock = ^(SFOAuthInfo *authInfo) {
            [self postAuthSuccessProcesses:authInfo];
        };
        self.authFailureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
            [self log:SFLogLevelWarning format:@"Login failed with the following error: %@.  Logging out.", [error localizedDescription]];
            [self logout];
        };
        
        self.appLogLevel = kAppLogLevel;
    }
    return self;
}

- (void)dealloc
{
    [_accountMgr clearAccountState:NO];
    SFRelease(_baseView);
    SFRelease(_snapshotView);
    SFRelease(_viewController);
    SFRelease(_window);
    SFRelease(_authSuccessBlock);
    SFRelease(_authFailureBlock);
    
}

#pragma mark - App lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _isAppInitialization = YES;
    [SFLogger setLogLevel:self.appLogLevel];
    
    //Replace the app-wide HTTP User-Agent before the first UIWebView is created
    [SFSDKWebUtils configureUserAgent];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // TODO: The SFNativeRootViewController.xib file is currently shipped as part of the native app template.
    // This should delivered in an SDK bundle, so that it's not dependent on that resource split outside of
    // the SDK code proper.
    self.viewController = [[SFNativeRootViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = self.viewController;
    self.baseView = self.viewController.view;
    self.snapshotView = [self createSnapshotView];
    [self.window makeKeyAndVisible];
    return YES;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    //Apparently when app is foregrounded, NSUserDefaults can be stale
	[defs synchronize];
    
    BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
    BOOL loginHostChanged = [SFAccountManager updateLoginHost];
    if (shouldLogout) {
        [self logout];
    } else if (loginHostChanged) {
        [_accountMgr clearAccountState:NO];
        [self clearDataModel];
        [self login];
    } else {
        // Refresh session or login for the first time.
        [self login];
    }
}

- (UIView*)createSnapshotView
{
    UIView* view = [[UIView alloc] initWithFrame:self.window.frame];
    view.backgroundColor = [UIColor whiteColor];
    return view;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self.viewController.view addSubview:self.snapshotView];
    [self prepareToShutDown];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self.snapshotView removeFromSuperview];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self prepareToShutDown];
}

+ (BOOL) isIPad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

#pragma mark - Salesforce.com login helpers

- (NSString *)userAgentString
{
    return [SFRestAPI userAgentString];
}

- (void)login {
    // Kick off authentication.
    [[SFAuthenticationManager sharedManager] login:self.viewController completion:self.authSuccessBlock failure:self.authFailureBlock];
}


- (void)logout {
    [_accountMgr clearAccountState:YES];
    [self clearDataModel];
    [self login];
}

- (SFAuthorizingViewController *)authViewController
{
    return [SFAuthenticationManager sharedManager].authViewController;
}

- (void)setAuthViewController:(SFAuthorizingViewController *)authViewController
{
    [SFAuthenticationManager sharedManager].authViewController = authViewController;
}

- (void)postAuthSuccessProcesses:(SFOAuthInfo *)authInfo
{
    if (_isAppInitialization) {
        // We'll ask for a passcode every time the application is initialized, regardless of activity.
        // But, if the user just went through credentials initialization, she's already just created
        // a passcode, so she gets a pass here.
        if (authInfo.authType == SFOAuthTypeUserAgent) {
            [self setupNewRootViewController];
        } else {
            if ([_accountMgr mobilePinPolicyConfigured]) {
                [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
                    [self setupNewRootViewController];
                }];
                [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
                    [self logout];
                }];
                [SFSecurityLockout lock];
            } else {
                [self setupNewRootViewController];
            }
        }
    } else if ([_accountMgr mobilePinPolicyConfigured]) {
        // App is foregrounding.  Passcode check subject to standard inactivity.
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self logout];
        }];
        [SFSecurityLockout validateTimer];
    }
    
    [self loggedIn];
}

- (void)setupNewRootViewController
{
    UIViewController *rootVC = [self newRootViewController];
    self.viewController = rootVC;
    [self.window.rootViewController presentViewController:self.viewController animated:YES completion:NULL];
}

- (void)loggedIn
{
    // For now, let's only monitor user activity if there are pin code policies to support it.
    // If someone decides they want to monitor user activity outside of screen lock, we can revisit.
    if ([_accountMgr mobilePinPolicyConfigured]) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
    }
    _isAppInitialization = NO;
}

- (UIViewController*)newRootViewController {
    [self log:SFLogLevelError msg:@"You must override this method in your subclass"];
    [self doesNotRecognizeSelector:@selector(newRootViewController)];
    return nil;
}


- (void)clearDataModel
{
    _isAppInitialization = YES;
    [self resetRootPresentation];
}

- (void)resetRootPresentation
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resetRootPresentation];
        });
        return;
    }
    
    self.viewController = nil;
    
    // If the root view controller has been changed out from our original one, just recreate it.
    if (self.window.rootViewController == nil
        || ![self.window.rootViewController isKindOfClass:[SFNativeRootViewController class]]) {
        self.viewController = [[SFNativeRootViewController alloc] initWithNibName:nil bundle:nil];
        self.window.rootViewController = self.viewController;
        self.baseView = self.viewController.view;
    } else {
        // Clear any other presented view controllers and/or subviews.
        UIViewController *rvc = self.window.rootViewController;
        self.viewController = rvc;
        if (rvc.presentedViewController != nil) {
            [rvc dismissViewControllerAnimated:NO completion:NULL];
        }
        for (UIView *subView in [NSArray arrayWithArray:self.window.subviews]) {
            [subView removeFromSuperview];
        }
        
        // Go back to the original "base" view.
        [self.window addSubview:self.baseView];
    }
}

+ (NSSet *)oauthScopes {
    return [NSSet setWithObjects:@"web",@"api",nil] ; 
}

#pragma mark - Other view lifecycle helpers

- (void)prepareToShutDown {
    [SFSecurityLockout removeTimer];
    if (_accountMgr.credentials != nil) {
		[SFInactivityTimerCenter saveActivityTimestamp];
	}
}

#pragma mark - Public

- (NSString*)remoteAccessConsumerKey {
    [self log:SFLogLevelError msg:@"You must override this method in your subclass"];
    [self doesNotRecognizeSelector:@selector(remoteAccessConsumerKey)];
    return nil;
}

- (NSString*)oauthRedirectURI {
    [self log:SFLogLevelError msg:@"You must override this method in your subclass"];
    [self doesNotRecognizeSelector:@selector(oauthRedirectURI)];
    return nil;
}

- (NSString *)oauthLoginDomain
{
    return [SFAccountManager loginHost];
}

- (NSString*)userAccountIdentifier {
    //OAuth credentials can have an identifier associated with them,
    //such as an account identifier.  For this app we only support one
    //"account" but you could provide your own means (eg NSUserDefaults) of 
    //storing which account the user last accessed, and using that here
    return @"Default";
}

@end
