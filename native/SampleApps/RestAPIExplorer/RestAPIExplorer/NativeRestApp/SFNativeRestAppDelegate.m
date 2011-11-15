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



static NSString * const kSFMobileSDKVersion = @"0.9";
static NSString * const kRestAPIVersion = @"v23.0";


NSString * const kLoginHostUserDefault = @"login_host_pref";

// key for primary login host
NSString * const kPrimaryLoginHostUserDefault = @"primary_login_host_pref";
// key for custom login host
NSString * const kCustomLoginHostUserDefault = @"custom_login_host_pref";
/// Value to use for login host if user never opens Settings
NSString * const kDefaultLoginHost = @"login.salesforce.com";

NSString * const kAccountLogoutUserDefault = @"account_logout_pref";


@interface SFNativeRestAppDelegate (private)

- (NSString *)getUserAgentString;
+ (void)ensureAccountDefaultsExist;

/**
 @return  YES if  user requested a logout in Settings.
 */
- (BOOL)checkForUserLogout;

/**
 Update login host from user Settings. 
 @return  YES if login host has changed. 
 */
- (BOOL)updateLoginHost;


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
        NSString *uaString = [self getUserAgentString];
        NSDictionary *appUserAgent = [[NSDictionary alloc] initWithObjectsAndKeys:uaString, @"UserAgent", nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:appUserAgent];
        [appUserAgent release];
        
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
        BOOL loginHostChanged = [self updateLoginHost];
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
                                     clientId: [self remoteAccessConsumerKey] ];
        
        
        creds.domain = loginDomain;
        creds.redirectUri = [self oauthRedirectURI];
        
        SFOAuthCoordinator *coord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
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


- (NSString *)getUserAgentString {
    //set a user agent string based on the mobile sdk version
    //We are building a user agent of the form:
    //SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad)
    
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@)",
                             kSFMobileSDKVersion,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model]
                             ];
    
    
    return myUserAgent;
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

/*
 Update login host. Returns true if login host is changed. 
 */
- (BOOL)updateLoginHost{
    
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	//the old calculated login host, if any.  Will be nil if this method has never run before
	NSString *prevLoginHost = [defs objectForKey:kLoginHostUserDefault];
    
	//kPrimaryLoginHostUserDefault is either the actual production or sandbox hostname, or special value @"CUSTOM",
	//which indicates that kCustomLoginHostUserDefault should be used to set kLoginHostUserDefault
	NSString *loginHost = [defs objectForKey:kPrimaryLoginHostUserDefault];
	NSString *customLoginHost = [defs objectForKey:kCustomLoginHostUserDefault];
    NSLog(@"Hosts before update: loginHost=%@ customLoginHost=%@", loginHost, customLoginHost);
    
	//user can type whatever they want into kCustomLoginHostUserDefault:
	//here we sanitize it a bit by downcasing it
    customLoginHost = (customLoginHost != nil) ? [customLoginHost lowercaseString] : customLoginHost; 
	
	if([loginHost isEqualToString:@"CUSTOM"]){
		//use custom login host if it is valid
		if (!([customLoginHost length] > 0)) {
			//looks like user selected "custom" and forgot to type custom hostname. Reset it back to whatever it was before. 
			//see what user is currently using in the app. 
			loginHost = prevLoginHost;
			//if it is not valid, reset it to default one. 
			loginHost = (!([loginHost length] > 0))? kDefaultLoginHost : loginHost;
			NSLog(@"Reseting the loginhost Settings back to previous settings: %@", loginHost);
			//reflect the changes back in Settings app. 
			[defs setValue:loginHost forKey:kPrimaryLoginHostUserDefault];
		}else {
			//use custom login host. 
			loginHost = customLoginHost; 
		}
	}
	
	//kPrimaryLoginHostUserDefault is user selected value in Settings app. No need to change that here.
	//kLoginHostUserDefault contains actual (generated) value of the host used for login.
	[defs setValue:loginHost forKey:kLoginHostUserDefault];
    
	NSLog(@"loginHost=%@ customLoginHost=%@", loginHost, customLoginHost);
    
	//return if hostname changed
	BOOL result = (prevLoginHost && ![prevLoginHost isEqualToString:loginHost]);
	if (result) {
		NSLog(@"updateLoginHost detected host change");
	}
	
	return result;
}

+ (void)ensureAccountDefaultsExist {
	//ensure that we have some default settings in case the user
	//doesn't ever open Settings
	
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    //Apparently when app is foregrounded, NSUserDefaults can be stale
	[defs synchronize];
    
	//user may have set a custom primary kPrimaryLoginHostUserDefault, 
	//and login kLoginHostUserDefault might not yet have been updated
	//(this sometimes happens when user sets prefs before a fresh boot)
	NSString *primaryLoginHost = [defs objectForKey:kPrimaryLoginHostUserDefault];
	if (!([primaryLoginHost length] > 0)) {
		//Set values for "production"
		[defs setValue:kDefaultLoginHost forKey:kPrimaryLoginHostUserDefault];
		[defs setValue:kDefaultLoginHost forKey:kLoginHostUserDefault];
	}	
}

- (BOOL)checkForUserLogout {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kAccountLogoutUserDefault];
}

@end
