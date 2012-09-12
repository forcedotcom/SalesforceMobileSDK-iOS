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



static NSString * const kUserAgentPropKey     = @"UserAgent";
static NSInteger  const kOAuthAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;

#if defined(DEBUG)
static SFLogLevel const kAppLogLevel = SFLogLevelDebug;
#else
static SFLogLevel const kAppLogLevel = SFLogLevelInfo;
#endif

@interface SFNativeRestAppDelegate () {
    /**
     Whether this is the initial login to the application (i.e. no previous credentials).
     */
    BOOL _isInitialLogin;
    
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
@property (nonatomic, retain) UIView *baseView;

/**
 Present the authentication view and controller modally, for the User Agent flow.
 @param webView The authentication web view to associate with the view controller.
 */
- (void)presentAuthViewController:(UIWebView *)webView;

/**
 Will dismiss the authentication view controller, if present.
 @param postDismissalAction Action to be taken after the view/controller is dismissed.  If
 the view controller is not present, this action will be taken immediately.
 */
- (void)dismissAuthViewControllerIfPresent:(SEL)postDismissalAction;

/**
 Called after identity data is retrieved from the service.
 */
- (void)retrievedIdentityData;

/**
 Called after the ID data retrieval process is complete.  Finalizes login, app startup.
 */
- (void)postIdentityRetrievalProcesses;

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

/**
 Clean up / finalize any state information, post-login workflow.  This should be the last
 method called before handing off to the consuming app.
 */
- (void)finalizeAppBootstrap;

@end

@implementation SFNativeRestAppDelegate

@synthesize authViewController=_authViewController;
@synthesize  viewController = _viewController;
@synthesize  window = _window;
@synthesize baseView = _baseView;
@synthesize appLogLevel = _appLogLevel;

#pragma mark - init/dealloc

- (id) init
{	
    self = [super init];
    if (nil != self) {
        //Replace the app-wide HTTP User-Agent before the first UIWebView is created
        NSString *uaString =  [SFRestAPI userAgentString];
        NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:uaString, kUserAgentPropKey, nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        [dictionary release];
        
        [SFAccountManager setLoginHost:[self oauthLoginDomain]];
        [SFAccountManager setClientId:[self remoteAccessConsumerKey]];
        [SFAccountManager setRedirectUri:[self oauthRedirectURI]];
        [SFAccountManager setScopes:[[self class] oauthScopes]];
        [SFAccountManager setCurrentAccountIdentifier:[self userAccountIdentifier]];
        _accountMgr = [SFAccountManager sharedInstance];
        
        // Strictly for internal tracking, assume we've got our initial credentials, until
        // OAuth tells us otherwise.  E.g. we only want to call the identity service after
        // we first authenticate.  If oauthCoordinator:didBeginAuthenticationWithView: isn't
        // called, we can assume we've already gone through initial authentication at some point.
        _isInitialLogin = NO;
        
        self.appLogLevel = kAppLogLevel;
    }
    return self;
}

- (void)dealloc
{
    [_accountMgr clearAccountState:NO];
    SFRelease(_authViewController);
    SFRelease(_baseView);
    SFRelease(_viewController);
    SFRelease(_window);
    
	[super dealloc];
}

#pragma mark - App lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _isAppInitialization = YES;
    [SFLogger setLogLevel:self.appLogLevel];
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    // TODO: The SFNativeRootViewController.xib file is currently shipped as part of the native app template.
    // This should delivered in an SDK bundle, so that it's not dependent on that resource split outside of
    // the SDK code proper.
    self.viewController = [[[SFNativeRootViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    self.window.rootViewController = self.viewController;
    self.baseView = self.viewController.view;
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
        // refresh session or login for the first time
        [self login];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self prepareToShutDown];
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

- (void)login {
    //kickoff authentication
    _accountMgr.oauthDelegate = self;
    [_accountMgr.coordinator authenticate];
}


- (void)logout {
    [_accountMgr clearAccountState:YES];
    [self clearDataModel];
    [self login];
}

- (void)loggedIn {
    // If this is the initial login, or there's no persisted identity data, get the data
    // from the service.
    if (_isInitialLogin || _accountMgr.idData == nil) {
        _accountMgr.idDelegate = self;
        [_accountMgr.idCoordinator initiateIdentityDataRetrieval];
    } else {
        // Just go directly to the post-processing step.
        [self postIdentityRetrievalProcesses];
    }
}

- (void)retrievedIdentityData
{
    // NB: This method is assumed to run after identity data has been refreshed from the service.
    NSAssert(_accountMgr.idData != nil, @"Identity data should not be nil/empty at this point.");
    
    if ([_accountMgr mobilePinPolicyConfigured]) {
        // Set the callback actions for post-passcode entry/configuration.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self postIdentityRetrievalProcesses];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{  // Don't know how this would happen, but if it does....
            [self logout];
        }];
        
        // setLockoutTime triggers passcode creation.  We could consider a more explicit call for visibility here?
        [SFSecurityLockout setPasscodeLength:_accountMgr.idData.mobileAppPinLength];
        [SFSecurityLockout setLockoutTime:(_accountMgr.idData.mobileAppScreenLockTimeout * 60)];
    } else {
        // No additional mobile policies.  So no passcode.
        [self postIdentityRetrievalProcesses];
    }
}

- (void)postIdentityRetrievalProcesses
{
    if (_isAppInitialization) {
        // We'll ask for a passcode every time the application is initialized, regardless of activity.
        // But, if the user just went through credentials initialization, she's already just created
        // a passcode, so she gets a pass here.
        if (_isInitialLogin) {
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
    
    [self finalizeAppBootstrap];
}

- (void)setupNewRootViewController
{
    UIViewController *rootVC = [[self newRootViewController] autorelease];
    self.viewController = rootVC;
    [self.window.rootViewController presentViewController:self.viewController animated:YES completion:NULL];
}

- (void)finalizeAppBootstrap
{
    // For now, let's only monitor user activity if there are pin code policies to support it.
    // If someone decides they want to monitor user activity outside of screen lock, we can revisit.
    if ([_accountMgr mobilePinPolicyConfigured]) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
    }
    _isAppInitialization = NO;
    _isInitialLogin = NO;
}

- (void)presentAuthViewController:(UIWebView *)webView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentAuthViewController:webView];
        });
        return;
    }
    
    // TODO: This is another NIB file that's delivered as part of the native app template, and should be
    // moved into a bundle (along with the root vc NIB file mentioned above.
    self.authViewController = [[[SFAuthorizingViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    [self.authViewController setOauthView:webView];
    [self.window.rootViewController presentViewController:self.authViewController animated:YES completion:NULL];
}

- (void)dismissAuthViewControllerIfPresent:(SEL)postDismissalAction
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent:postDismissalAction];
        });
        return;
    }
    
    if (self.authViewController != nil) {
        // TODO: Why do we not have the logging facilities calls in this class?
        NSLog(@"Dismissing the auth view controller.");
        [self.window.rootViewController dismissViewControllerAnimated:YES
                                                           completion:^{
                                                               SFRelease(_authViewController);
                                                               [self performSelector:postDismissalAction];
                                                           }];
    } else {
        [self performSelector:postDismissalAction];
    }
}

- (UIViewController*)newRootViewController {
    NSLog(@"You must override this method in your subclass");
    [self doesNotRecognizeSelector:@selector(newRootViewController)];
    return nil;
}


- (void)clearDataModel
{
    _isAppInitialization = YES;
    _isInitialLogin = YES;  // OAuth would flip this to YES anyway, but let's be complete.
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
        self.viewController = [[[SFNativeRootViewController alloc] initWithNibName:nil bundle:nil] autorelease];
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

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    
    _isInitialLogin = YES;
    [self presentAuthViewController:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info);
    [self dismissAuthViewControllerIfPresent:@selector(loggedIn)];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    NSLog(@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info);
    
    BOOL fatal = YES;
    if (info.authType == SFOAuthTypeRefresh) {
        if (error.code == kSFOAuthErrorInvalidGrant) {  //invalid cached refresh token
            // Restart the login process asynchronously.
            fatal = NO;
            NSLog(@"Logging out because oauth failed with error code: %d",error.code);
            [self performSelector:@selector(logout) withObject:nil afterDelay:0];
        } else if ([SFAccountManager errorIsNetworkFailure:error]) {
            // Couldn't connect to server to refresh.  Assume valid credentials until the next attempt.
            fatal = NO;
            NSLog(@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]);
            
            // If this is app startup, we need to go through the bootstrapping of the root view controller,
            // etc.
            if (_isAppInitialization) {
                [self loggedIn];
                return;
            }
        }
    }
    
    if (fatal) {
        // show alert and retry
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error" 
                                                        message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                       delegate:self
                                              cancelButtonTitle:@"Retry"
                                              otherButtonTitles: nil];
        alert.tag = kOAuthAlertViewTag;
        [alert show];
        [alert release];
    }
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [self retrievedIdentityData];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error" 
                                                    message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                   delegate:self
                                          cancelButtonTitle:@"Retry"
                                          otherButtonTitles: nil];
    alert.tag = kIdentityAlertViewTag;
    [alert show];
    [alert release];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == kOAuthAlertViewTag) {
        [self dismissAuthViewControllerIfPresent:@selector(login)];
    }
    else if (alertView.tag == kIdentityAlertViewTag)
        [_accountMgr.idCoordinator initiateIdentityDataRetrieval];
}


#pragma mark - Public 

- (NSString*)remoteAccessConsumerKey {
    NSLog(@"You must override this method in your subclass");
    [self doesNotRecognizeSelector:@selector(remoteAccessConsumerKey)];
    return nil;
}

- (NSString*)oauthRedirectURI {
    NSLog(@"You must override this method in your subclass");
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
