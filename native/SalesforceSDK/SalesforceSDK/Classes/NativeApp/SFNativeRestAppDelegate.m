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
#import "SFCredentialsManager.h"
#import "SFSecurityLockout.h"
#import "SFNativeRootViewController.h"
#import "SFUserActivityMonitor.h"
#import "SFInactivityTimerCenter.h"



static NSString * const kUserAgentPropKey     = @"UserAgent";
static NSInteger  const kOAuthAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;

#if defined(DEBUG)
static SFLogLevel const kAppLogLevel = Debug;
#else
static SFLogLevel const kAppLogLevel = Info;
#endif


// Key for storing the user's configured login host.
NSString * const kLoginHostUserDefault = @"login_host_pref";

// Key for the primary login host, as defined in the app settings.
NSString * const kPrimaryLoginHostUserDefault = @"primary_login_host_pref";

// Key for the custom login host value in the app settings.
NSString * const kCustomLoginHostUserDefault = @"custom_login_host_pref";

// Value for kPrimaryLoginHostUserDefault when a custom host is chosen.
NSString * const kPrimaryLoginHostCustomValue = @"CUSTOM";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
NSString * const kAccountLogoutUserDefault = @"account_logout_pref";

/// Value to use for login host if user never opens the app settings.
NSString * const kDefaultLoginHost = @"login.salesforce.com";



@interface SFNativeRestAppDelegate () {
    /**
     Whether this is the initial login to the application (i.e. no previous credentials).
     */
    BOOL _isInitialLogin;
    
    /**
     The identity coordinator used to retrieve data from the ID service.
     */
    SFIdentityCoordinator *_idCoordinator;
    
    /**
     Whether the app is in its initialization run (vs. just being brought to the foreground).
     */
    BOOL _isAppInitialization;
}

/**
 The initial view of the underlying root view controller.  Will be used as the "initial"
 page when the app is reset in situ.
 */
@property (nonatomic, retain) UIView *baseView;

/**
 Initializes the app settings, in the event that the user has not configured
 them before the first launch of the application.
 */
+ (void)ensureAccountDefaultsExist;

/**
 @return  YES if  user requested a logout in Settings.
 */
- (BOOL)checkForUserLogout;

/**
 Gets the primary login host value from app settings, initializing it to a default
 value first, if a valid one did not previously exist.
 @return The login host value from the app settings.
 */
+ (NSString *)primaryLoginHost;

/**
 Update the configured login host based on the user-defined app settings. 
 @return  YES if login host has changed in the app settings, NO otherwise. 
 */
+ (BOOL)updateLoginHost;

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
 Sets the identity data property with the given data.
 @param newIdData The identity data to set.
 */
- (void)setIdentityData:(SFIdentityData *)newIdData;

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
 Convenience method to determine whether all of the mobile passcode policy properties have
 valid values to establish a passcode.
 */
- (BOOL)mobilePinPolicyConfigured;

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
@synthesize  coordinator = _coordinator;
@synthesize  viewController = _viewController;
@synthesize  window = _window;
@synthesize idData = _idData;
@synthesize baseView = _baseView;
@synthesize appLogLevel = _appLogLevel;

#pragma mark - init/dealloc

- (id) init
{	
    self = [super init];
    if (nil != self) {
        //Replace the app-wide HTTP User-Agent before the first UIWebView is created
        NSString *uaString =  [SFRestAPI userAgentString];
        [[NSUserDefaults standardUserDefaults] setValue:uaString forKey:kUserAgentPropKey];
        
        [[self class] ensureAccountDefaultsExist];
        
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
    [_coordinator setDelegate:nil];
    SFRelease(_coordinator)
    SFRelease(_idCoordinator);
    SFRelease(_idData);
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
    
    BOOL shouldLogout = [self checkForUserLogout] ;
    if (shouldLogout) {
        [self logout];
    } else {
        BOOL loginHostChanged = [[self class] updateLoginHost];
        if (loginHostChanged) {
            [_coordinator setDelegate:nil];
            SFRelease(_coordinator);
            [self clearDataModel];
        }
    }
    
	// refresh session or login for the first time
	[self login];
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


- (SFOAuthCoordinator*)coordinator {
    //create a new coordinator if we don't already have one
    if (nil == _coordinator) {
        
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *loginDomain = [self oauthLoginDomain];
        NSString *accountIdentifier = [self userAccountIdentifier];
        //here we use the login domain as part of the identifier
        //to distinguish between eg  sandbox and production credentials
        NSString *fullKeychainIdentifier = [NSString stringWithFormat:@"%@-%@-%@",appName,accountIdentifier,loginDomain];
        
        
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] 
                                     initWithIdentifier:fullKeychainIdentifier  
                                     clientId: [self remoteAccessConsumerKey] 
                                     encrypted:YES
                                     ];
        
        
        creds.domain = loginDomain;
        creds.redirectUri = [self oauthRedirectURI];
        
        SFOAuthCoordinator *coord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
        [creds release];
        coord.scopes = [[self class] oauthScopes]; 
        
        coord.delegate = self;
        _coordinator = coord;        
    } 
    
    return _coordinator;
}

- (void)login {
    //kickoff authentication
    [self.coordinator authenticate];
}


- (void)logout {
    [self.coordinator revokeAuthentication];
    [SFCredentialsManager sharedInstance].credentials = nil;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAccountLogoutUserDefault];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self clearDataModel];
    [self login];
}

- (void)loggedIn {
    // Update the shared credentials.
    [SFCredentialsManager sharedInstance].credentials = self.coordinator.credentials;
    
    // If this is the initial login, or there's no persisted identity data, get the data
    // from the service.
    SFIdentityData *checkIdData = [SFIdentityCoordinator loadIdentityData];
    if (_isInitialLogin || checkIdData == nil) {
        _idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:self.coordinator.credentials];
        _idCoordinator.delegate = self;
        [_idCoordinator initiateIdentityDataRetrieval];
    } else {
        // Just go directly to the post-processing step.
        [self setIdentityData:checkIdData];
        [self postIdentityRetrievalProcesses];
    }
}

- (void)retrievedIdentityData
{
    // NB: This method is assumed to run after identity data has been refreshed from the service.
    NSAssert(_idCoordinator != nil, @"Identity coordinator should be populated at this point.");
    NSAssert(_idCoordinator.idData != nil, @"Identity data should not be nil/empty at this point.");
    [self setIdentityData:_idCoordinator.idData];
    [SFIdentityCoordinator saveIdentityData:_idCoordinator.idData];
    SFRelease(_idCoordinator);
    
    if ([self mobilePinPolicyConfigured]) {
        // Set the callback actions for post-passcode entry/configuration.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self postIdentityRetrievalProcesses];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{  // Don't know how this would happen, but if it does....
            [self logout];
        }];
        
        // setLockoutTime triggers passcode creation.  We could consider a more explicit call for visibility here?
        [SFSecurityLockout setPasscodeLength:self.idData.mobileAppPinLength];
        [SFSecurityLockout setLockoutTime:(self.idData.mobileAppScreenLockTimeout * 60)];
    } else {
        // No additional mobile policies.  So no passcode.
        [self postIdentityRetrievalProcesses];
    }
}

- (void)postIdentityRetrievalProcesses
{
    // Provide the Rest API with a reference to the coordinator we used for login.
    [[SFRestAPI sharedInstance] setCoordinator:self.coordinator];
    
    if (_isAppInitialization) {
        // We'll ask for a passcode every time the application is initialized, regardless of activity.
        // But, if the user just went through credentials initialization, she's already just created
        // a passcode, so she gets a pass here.
        if (_isInitialLogin) {
            [self setupNewRootViewController];
        } else {
            if ([self mobilePinPolicyConfigured]) {
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
    } else if ([self mobilePinPolicyConfigured]) {
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
    [[SFUserActivityMonitor sharedInstance] startMonitoring];
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

- (void)setIdentityData:(SFIdentityData *)newIdData
{
    if (newIdData != _idData) {
        SFIdentityData *oldValue = _idData;
        _idData = [newIdData retain];
        [oldValue release];
    }
}

- (BOOL)mobilePinPolicyConfigured
{
    return (self.idData != nil
            && self.idData.mobilePoliciesConfigured
            && self.idData.mobileAppPinLength > 0
            && self.idData.mobileAppScreenLockTimeout > 0);
}

#pragma mark - Other view lifecycle helpers

- (void)prepareToShutDown {
    [SFSecurityLockout removeTimer];
    if ([SFCredentialsManager sharedInstance].credentials != nil) {
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

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@", coordinator.credentials.userId);
    [self dismissAuthViewControllerIfPresent:@selector(loggedIn)];
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);
    
    if (error.code == kSFOAuthErrorInvalidGrant) {  //invalid cached refresh token
        //restart the login process asynchronously
        NSLog(@"Logging out because oauth failed with error code: %d",error.code);
        [self performSelector:@selector(logout) withObject:nil afterDelay:0];
    }
    else {
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
        [_idCoordinator initiateIdentityDataRetrieval];
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

- (NSString*)oauthLoginDomain {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *loginHost = [defs objectForKey:kLoginHostUserDefault];
    
    return loginHost;
}

- (NSString*)userAccountIdentifier {
    //OAuth credentials can have an identifier associated with them,
    //such as an account identifier.  For this app we only support one
    //"account" but you could provide your own means (eg NSUserDefaults) of 
    //storing which account the user last accessed, and using that here
    return @"Default";
}



#pragma mark - Settings utilities

+ (BOOL)updateLoginHost
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    
	NSString *previousLoginHost = [defs objectForKey:kLoginHostUserDefault];
	NSString *currentLoginHost = [self primaryLoginHost];
	NSLog(@"Hosts before update: previousLoginHost=%@ currentLoginHost=%@", previousLoginHost, currentLoginHost);
    
    // Update the previous app settings value to current.
	[defs setValue:currentLoginHost forKey:kLoginHostUserDefault];
    
	BOOL hostnameChanged = (nil != previousLoginHost && ![previousLoginHost isEqualToString:currentLoginHost]);
	if (hostnameChanged) {
		NSLog(@"updateLoginHost detected a host change in the app settings, from %@ to %@.", previousLoginHost, currentLoginHost);
	}
	
	return hostnameChanged;
}


+ (NSString *)primaryLoginHost
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    NSString *primaryLoginHost = [defs objectForKey:kPrimaryLoginHostUserDefault];
    
    // If the primary host value is nil/empty, it's never been set.  Initialize it to default and return it.
    if (nil == primaryLoginHost || [primaryLoginHost length] == 0) {
        [defs setValue:kDefaultLoginHost forKey:kPrimaryLoginHostUserDefault];
        [defs synchronize];
        return kDefaultLoginHost;
    }
    
    // If a custom login host value was chosen and configured, return it.  If a custom value is
    // chosen but the value is *not* configured, reset the primary login host to a sane
    // value and return that.
    if ([primaryLoginHost isEqualToString:kPrimaryLoginHostCustomValue]) {  // User specified to use a custom host.
        NSString *customLoginHost = [defs objectForKey:kCustomLoginHostUserDefault];
        if (nil != customLoginHost && [customLoginHost length] > 0) {
            // Custom value is set.  Return that.
            return customLoginHost;
        } else {
            // The custom host value is empty.  We'll try to set a previous user-defined
            // value for the primary first, and if we can't set that, we'll just set it to the default host.
            NSString *prevUserDefinedLoginHost = [defs objectForKey:kLoginHostUserDefault];
            if (nil != prevUserDefinedLoginHost && [prevUserDefinedLoginHost length] > 0) {
                // We found a previously user-defined value.  Use that.
                [defs setValue:prevUserDefinedLoginHost forKey:kPrimaryLoginHostUserDefault];
                [defs synchronize];
                return prevUserDefinedLoginHost;
            } else {
                // No previously user-defined value either.  Use the default.
                [defs setValue:kDefaultLoginHost forKey:kPrimaryLoginHostUserDefault];
                [defs synchronize];
                return kDefaultLoginHost;
            }
        }
    }
    
    // If we got this far, we have a primary host value that exists, and isn't custom.  Return it.
    return primaryLoginHost;
}

+ (void)ensureAccountDefaultsExist
{
    
    // Getting primary login host will initialize it to a proper value if it isn't already
    // set.
	NSString *currentHostValue = [self primaryLoginHost];
    
    // Make sure we initialize the user-defined app setting as well, if it's not already.
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    NSString *userDefinedLoginHost = [defs objectForKey:kLoginHostUserDefault];
    if (nil == userDefinedLoginHost || [userDefinedLoginHost length] == 0) {
        [defs setValue:currentHostValue forKey:kLoginHostUserDefault];
        [defs synchronize];
    }
}

- (BOOL)checkForUserLogout {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kAccountLogoutUserDefault];
}

@end
