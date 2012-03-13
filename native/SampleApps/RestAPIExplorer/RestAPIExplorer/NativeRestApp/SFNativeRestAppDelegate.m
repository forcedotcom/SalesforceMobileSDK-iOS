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



static NSString * const kUserAgentPropKey = @"UserAgent";


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



@interface SFNativeRestAppDelegate (private)


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
 Set the SFAuthorzingViewController as the root view controller.
 */
- (void)setupAuthorizingViewController;

@end

@implementation SFNativeRestAppDelegate

@synthesize authViewController=_authViewController;
@synthesize  coordinator = _coordinator;
@synthesize  viewController = _viewController;
@synthesize  window = _window;

#pragma mark - init/dealloc

- (id) init
{	
    self = [super init];
    if (nil != self) {
        //Replace the app-wide HTTP User-Agent before the first UIWebView is created
        NSString *uaString =  [SFRestAPI userAgentString];
        [[NSUserDefaults standardUserDefaults] setValue:uaString forKey:kUserAgentPropKey];
        
        [[self class] ensureAccountDefaultsExist];
    }
    return self;
}

- (void)dealloc
{
    self.authViewController = nil;
    
    [_coordinator setDelegate:nil];
    [_coordinator release]; _coordinator = nil;
    self.window = nil;
    self.viewController = nil;
    
	[ super dealloc ];
}

#pragma mark - App lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupAuthorizingViewController];
    return YES;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    //Apparently when app is foregrounded, NSUserDefaults can be stale
	[defs synchronize];
    
    BOOL shouldLogout = [self checkForUserLogout] ;
    if (shouldLogout) {
        [self logout];
        [self clearDataModel];
        
        [defs setBool:NO forKey:kAccountLogoutUserDefault];
        [defs synchronize];
        [self setupAuthorizingViewController];
    } else {
        BOOL loginHostChanged = [[self class] updateLoginHost];
        if (loginHostChanged) {
            [_coordinator setDelegate:nil];
            [_coordinator release]; _coordinator = nil;
            
            [self clearDataModel];
            [self setupAuthorizingViewController];
        }
    }
    
	// refresh session or login for the first time
	[self login];
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
    [self.coordinator authenticate];
}

- (void)loggedIn {
    //provide the Rest API with a reference to the coordinator we used for login
    [[SFRestAPI sharedInstance] setCoordinator:self.coordinator];
    
    // now show the true app view controller if it's not already shown
    if (nil != self.authViewController) {
        self.authViewController = nil;
    }
    
    if (nil == self.viewController) {
        UIViewController *rootVC = [self newRootViewController];
        self.viewController = rootVC;
        [rootVC release];
        self.window.rootViewController = self.viewController;
        [self.window makeKeyAndVisible];
    }
}

- (UIViewController*)newRootViewController {
    NSLog(@"You must override this method in your subclass");
    [self doesNotRecognizeSelector:@selector(newRootViewController)];
    return nil;
}


- (void)clearDataModel {
    self.viewController = nil;
}

+ (NSSet *)oauthScopes {
    return [NSSet setWithObjects:@"visualforce",@"api",nil] ; 
}


- (void)setupAuthorizingViewController {
    
    //clear all children of the existing window, if any
    if (nil != self.window) {
        NSLog(@"SFNativeRestAppDelegate clearing self.window");
        [self.window.subviews  makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.window = nil;
    }
    
    //(re)init window
    CGRect screenBounds = [ [ UIScreen mainScreen ] bounds ];
    UIWindow *rootWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	self.window = rootWindow;
    [rootWindow release];
    
    // Set up a view controller for the authentication process.
    SFAuthorizingViewController *authVc = [[SFAuthorizingViewController alloc] initWithNibName:@"SFAuthorizingViewController" bundle:nil];
    self.authViewController = authVc;
    self.window.rootViewController = self.authViewController;
    self.window.autoresizesSubviews = YES;
    [authVc release];
    
    [self.window makeKeyAndVisible];
    
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    
    if (nil != self.authViewController) {
        // We're in the initialization of the app.  Make sure the auth view is in the foreground.
        [self.window bringSubviewToFront:self.authViewController.view];
        [self.authViewController setOauthView:view];
    }
    else
        [self.viewController.view addSubview:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@", coordinator.credentials.userId);
    [coordinator.view removeFromSuperview];
    [self loggedIn];
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);
    [coordinator.view removeFromSuperview];
    
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
        [alert show];
        [alert release];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.coordinator authenticate];    
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
