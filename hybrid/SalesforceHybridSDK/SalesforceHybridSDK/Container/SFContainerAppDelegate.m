/*
 Copyright (c) 2011-2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova 
 
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

#import "SFContainerAppDelegate.h"
#import "SFHybridViewController.h"
#import "SalesforceSDKConstants.h"
#import "SalesforceOAuthPlugin.h"
#import "SFAccountManager.h"
#import "SFSecurityLockout.h"
#import "SFSDKWebUtils.h"
#import "NSURL+SFStringUtils.h"
#import "SFInactivityTimerCenter.h"
#import "SFSmartStore.h"
#import "CDVURLProtocol.h"
#import "CDVCommandDelegate.h"

// Public constants
NSString * const kSFMobileSDKVersion = @"2.0.0";
NSString * const kAppHomeUrlPropKey = @"AppHomeUrl";
NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";
NSString * const kSFOAuthPluginName = @"com.salesforce.oauth";
NSString * const kSFSmartStorePluginName = @"com.salesforce.smartstore";

// Private constants
NSString * const kDefaultHybridAccountIdentifier = @"Default";

// The default logging level of the app.
#if defined(DEBUG)
static SFLogLevel const kAppLogLevel = SFLogLevelDebug;
#else
static SFLogLevel const kAppLogLevel = SFLogLevelInfo;
#endif

@interface SFContainerAppDelegate ()
{
    NSString *_invokeString;
}

- (void)setupUi;
- (void)resetUi;
- (void)setupViewController;

/**
 * Removes any cookies from the cookie store.  All app cookies are reset with
 * new authentication.
 */
+ (void)removeCookies;

/**
 * Tasks to run when the app is backgrounding or terminating.
 */
- (void)prepareToShutDown;

@end

@implementation SFContainerAppDelegate

@synthesize appLogLevel = _appLogLevel;
@synthesize window = _window;
@synthesize viewController = _viewController;

#pragma mark - init/dealloc

- (id) init
{
    /** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    self = [super init];
    if (nil != self) {
        _isAppStartup = YES;
        [SFAccountManager setCurrentAccountIdentifier:kDefaultHybridAccountIdentifier];
        self.appLogLevel = kAppLogLevel;
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_invokeString);
    SFRelease(_viewController);
    SFRelease(_window);
    
	[ super dealloc ];
}

#pragma mark - App lifecycle

/**
 * This is main kick off after the app inits, the views and Settings are setup here. (preferred - iOS4 and up)
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [SFLogger setLogLevel:self.appLogLevel];
    
    // Replace the app-wide HTTP User-Agent before the first UIWebView is created.
    [SFSDKWebUtils configureUserAgent];
    
    // Cordova.  NB: invokeString is deprecated in Cordova 2.2.  We will ditch it when they do.
    NSURL *url = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if (url && [url isKindOfClass:[NSURL class]]) {
        _invokeString = [url absoluteString];
        NSLog(@"Hybrid app launch options = %@", url);
    }
    [self setupUi];
    
    // Reset app state if necessary (login settings have changed).  We have to do this in
    // both didFinishLaunchedWithOptions and applicationDidBecomeActive, because the latter
    // will conflict with Cordova's page launch process when the app starts.
    BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
    BOOL loginHostChanged = [SFAccountManager updateLoginHost];
    if (shouldLogout) {
        [self clearAppState:NO];
    } else if (loginHostChanged) {
        [[SFAccountManager sharedInstance] clearAccountState:NO];
    }
    
    return YES;
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if App-Info.plist specifies a protocol to handle
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
    if (!url) { 
        return NO; 
    }
    
	// calls into javascript global function 'handleOpenURL'
    NSString* jsString = [NSString stringWithFormat:@"handleOpenURL(\"%@\");", url];
    [self.viewController.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    // all plugins will get the notification, and their handlers will be called 
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {   
    
    // These actions only need to be taken when the app is coming back to the foreground, i.e. not when the app is first starting,
    // which has a separate bootstrapping process.
    if (!_isAppStartup) {
        BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
        BOOL loginHostChanged = [SFAccountManager updateLoginHost];
        if (shouldLogout) {
            [self clearAppState:YES];
        } else if (loginHostChanged) {
            [[SFAccountManager sharedInstance] clearAccountState:NO];
            [self resetUi];
        } else {
            [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
                [self clearAppState:YES];
            }];
            [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
                [self.viewController.commandDelegate getCommandInstance:kSFSmartStorePluginName];
            }];
            [SFSecurityLockout validateTimer];
        }
    } else {
        // Actions to take place exclusively when the app starts up.
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self clearAppState:YES];
        }];
        [SFSecurityLockout lock];
    }
    
    _isAppStartup = NO;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self prepareToShutDown];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self prepareToShutDown];
}

#pragma mark - Cordova helpers

+ (NSString *) startPage
{
    return @"bootstrap.html";
}

- (void)setupUi
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[[UIWindow alloc] initWithFrame:screenBounds] autorelease];
    self.window.autoresizesSubviews = YES;
    
    [self setupViewController];
    [self.window makeKeyAndVisible];
}

- (void)resetUi
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resetUi];
        });
        return;
    }
    
    self.viewController = nil;
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:NULL];  // If the auth view is presented.
    self.window.rootViewController = nil;
    
    [self setupViewController];
}

- (void)configureHybridViewController
{
    self.viewController = [[[SFHybridViewController alloc] init] autorelease];
}

- (void)setupViewController
{
    [self configureHybridViewController];
    self.viewController.useSplashScreen = NO;
    self.viewController.wwwFolderName = @"www";
    self.viewController.startPage = [[self class] startPage];
    self.viewController.invokeString = _invokeString;
    
    self.window.rootViewController = self.viewController;
}

+ (BOOL) isIPad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

#pragma mark - Salesforce.com helpers

/**
 * Append a user agent string to the current one, based on device, application, and SDK
 * version information.
 * We are building a user agent of the form:
 *   SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) appName/appVersion Hybrid [Current User Agent]
 */
- (NSString *)userAgentString
{
    static NSString *sUserAgentString = nil;
    
    // Only calculate this once in the app process lifetime.
    if (sUserAgentString == nil) {
        NSString *currentUserAgent = [SFSDKWebUtils currentUserAgentForApp];
        
        UIDevice *curDevice = [UIDevice currentDevice];
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
        
        sUserAgentString = [[NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@ %@",
                             kSFMobileSDKVersion,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model],
                             appName,
                             appVersion,
                             kSFMobileSDKHybridDesignator,
                             currentUserAgent
                             ] retain];
    }
    
    return sUserAgentString;
}


- (void)addOAuthViewToMainView:(UIView*)oauthView {
    UIView *containerView = self.viewController.view;
    [oauthView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    
    //ensure that oauthView fills the whole view
    [oauthView setFrame:containerView.bounds];
    [containerView addSubview:oauthView];

}

+ (SFContainerAppDelegate*)sharedInstance 
{
    return (SFContainerAppDelegate*)[[UIApplication sharedApplication] delegate];
}

- (void)logout
{
    [self clearAppState:YES];
}

- (void)clearAppState:(BOOL)restartAuthentication
{
    // Clear any cookies set by the app.
    [[self class] removeCookies];
    
    // Revoke all stored OAuth authentication.
    [[SFAccountManager sharedInstance] clearAccountState:YES];
    
    // Clear the home URL since we are no longer authenticated.
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setURL:nil forKey:kAppHomeUrlPropKey];
    [defs synchronize];
    
    if (restartAuthentication)
        [self resetUi];
}

+ (void)removeCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        [cookieStorage deleteCookie:cookie];
    }
}

- (void)prepareToShutDown {
    [SFSecurityLockout removeTimer];
    if ([SFAccountManager sharedInstance].credentials != nil) {
		[SFInactivityTimerCenter saveActivityTimestamp];
	}
}


@end
