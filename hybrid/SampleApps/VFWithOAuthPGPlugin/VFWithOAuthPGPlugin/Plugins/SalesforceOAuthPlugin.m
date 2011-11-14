//
//  SalesforceOAuthPlugin.m
//  VFWithOAuthPlugin
//
//  Created by Kevin Hawkins on 11/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <PhoneGap/PGPlugin.h>
#import <PhoneGap/PhoneGapViewController.h>

#import "SalesforceOAuthPlugin.h"
#import "AppDelegate.h"
#import "SFAuthorizingViewController.h"
#import "NSObject+SBJson.h"

static NSString *const kDefaultOAuthLoginDomain =  
@"test.salesforce.com"; //Sandbox:  use login.salesforce.com if you're sure you want to test with Production


NSString * const kLoginHostUserDefault = @"login_host_pref";

// key for primary login host
NSString * const kPrimaryLoginHostUserDefault = @"primary_login_host_pref";
// key for custom login host
NSString * const kCustomLoginHostUserDefault = @"custom_login_host_pref";
/// Value to use for login host if user never opens Settings
NSString * const kDefaultLoginHost = @"login.salesforce.com";

NSString * const kAccountLogoutUserDefault = @"account_logout_pref";

@interface SalesforceOAuthPlugin (private)

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

+ (void)ensureAccountDefaultsExist;
- (void)sendJavascriptLoginEvent:(UIWebView *)webView;
- (void)addSidCookieForDomain:(NSString*)domain;
- (NSString *)credentialsAsJson;
- (void)populateOAuthProperties:(NSString *)propsJsonString;

@end


@implementation SalesforceOAuthPlugin

@synthesize coordinator=_coordinator;
@synthesize authViewController=_authViewController;
@synthesize remoteAccessConsumerKey=_remoteAccessConsumerKey;
@synthesize oauthRedirectURI=_oauthRedirectURI;
@synthesize oauthLoginDomain=_oauthLoginDomain;
@synthesize oauthScopes=_oauthScopes;
@synthesize userAccountIdentifier=_userAccountIdentifier;

#pragma mark - init/dealloc

- (PGPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        _appDelegate = (AppDelegate *)[self appDelegate];
        [[self class] ensureAccountDefaultsExist];
    }
    
    return self;
}

- (void)dealloc
{
    [_coordinator setDelegate:nil];
    [_coordinator release]; _coordinator = nil;
    [_callbackId release];
    
    [super dealloc];
}

#pragma mark - Plugin methods

- (void)getLoginHost:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options  
{
    NSLog(@"getLoginHost:");
    
    NSString *callbackId = [arguments pop];
    
    NSString *loginHost = [self oauthLoginDomain];
    
    PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:[loginHost stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}

- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"authenticate:");
    
    NSString *callbackId = [arguments pop];
    if (_isAuthenticating) {
        NSString *errorMessage = @"Authentication is already in progress.";
        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK
                                                    messageAsString:[errorMessage stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        return;
    }
    
    _isAuthenticating = YES;
    
    // Build the OAuth args from the JSON object string argument.
    NSString *argsString = [arguments pop];
    [self populateOAuthProperties:argsString];
    
    _callbackId = [callbackId copy];
    [self.coordinator authenticate];
}

#pragma mark - AppDelegate interaction

- (BOOL)resetAppState
{
    BOOL shouldLogout = [self checkForUserLogout] ;
    if (shouldLogout) {
        [self.coordinator revokeAuthentication];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAccountLogoutUserDefault];
        [defs synchronize];
        return shouldLogout;
    } else {
        
        BOOL loginHostChanged = [self updateLoginHost];
        if (loginHostChanged) {
            [_coordinator setDelegate:nil];
            [_coordinator release]; _coordinator = nil;
        }
        return loginHostChanged;
    }
}

#pragma mark - Salesforce.com login helpers

- (SFOAuthCoordinator*)coordinator {
    //create a new coordinator if we don't already have one
    if (nil == _coordinator) {
        
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *loginDomain = self.oauthLoginDomain;
        NSString *accountIdentifier = self.userAccountIdentifier;
        //here we use the login domain as part of the identifier
        //to distinguish between eg  sandbox and production credentials
        NSString *fullKeychainIdentifier = [NSString stringWithFormat:@"%@-%@-%@",appName,accountIdentifier,loginDomain];
        
        
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] 
                                     initWithIdentifier:fullKeychainIdentifier  
                                     clientId: self.remoteAccessConsumerKey ];
        
        
        creds.domain = loginDomain;
        creds.redirectUri = self.oauthRedirectURI;
        
        SFOAuthCoordinator *coord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
        coord.scopes = self.oauthScopes; 
        
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
    
    NSURL *instanceUrl = self.coordinator.credentials.instanceUrl;
    NSString *domain = [instanceUrl host]; 
    
    //addSidCookieForDomain can be called before the webview exists
    [self addSidCookieForDomain:domain];
    [self addSidCookieForDomain:@".force.com"];
    [self addSidCookieForDomain:@".salesforce.com"];
    
    // If we have the authViewController, we're in the initialization of the app.
    // Remove this view controller, and let PhoneGap continue its initialization with the
    // standard view controller.
    if (nil != self.authViewController) {
        _appDelegate.window.rootViewController = nil;
        self.authViewController = nil;
        _appDelegate.window = nil;
    }
    else {
        // otherwise, simply notify the webview that we have logged in
        NSString *jsonCreds = [self credentialsAsJson];
//        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:[jsonCreds stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:jsonCreds];
        [self writeJavascript:[pluginResult toSuccessCallbackString:_callbackId]];
        _isAuthenticating = NO;
    }    
    
}

- (NSString *)credentialsAsJson {
    SFOAuthCredentials *creds = self.coordinator.credentials;
    NSString *accessToken = creds.accessToken;
    NSString *refreshToken = creds.refreshToken;
    NSString *clientId = creds.clientId;
    NSString *userId = creds.userId;
    NSString *orgId = creds.organizationId;
    NSString *instanceUrl = creds.instanceUrl.absoluteString;
    NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
    NSString *uaString = [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
    
    NSDictionary *credentialsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                     accessToken, @"accessToken",
                                     refreshToken, @"refreshToken",
                                     clientId, @"clientId",
                                     loginUrl, @"loginUrl",
                                     userId, @"userId",
                                     orgId, @"orgId",
                                     instanceUrl, @"instanceUrl",
                                     uaString, @"userAgent",
                                     kRestAPIVersion, @"apiVersion",
                                     nil];
    return [credentialsDict JSONRepresentation];
}

/**
 Using the oauth token we've obtained,
 set a cookie on the shared cookie storage,
 that will be used to authenticate our VisualForce page loads.
 */
- (void)addSidCookieForDomain:(NSString*)domain
{
    NSLog(@"addSidCookieForDomain: %@",domain);
    
    // Set the session ID cookie to be used by the web view.
    NSURL *hostURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableArray *newCookies = [NSMutableArray arrayWithArray:[cookieStorage cookiesForURL:hostURL]];
    
    //remove any stale sid cookies with the same domain
    for (NSHTTPCookie *cookie in newCookies) {
        if ([cookie.domain isEqualToString:domain] && [cookie.name isEqualToString:@"sid"]  ) {
            [newCookies removeObject:cookie];
            break;
        }
    }
    
    NSHTTPCookie *sidCookie0 = [NSHTTPCookie cookieWithProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   domain, NSHTTPCookieDomain,
                                                                   @"/", NSHTTPCookiePath,
                                                                   self.coordinator.credentials.accessToken, NSHTTPCookieValue,
                                                                   @"sid", NSHTTPCookieName,
                                                                   @"TRUE", NSHTTPCookieDiscard,
                                                                   @"TRUE", NSHTTPCookieSecure,
                                                                   nil]];
    
    
    [newCookies addObject:sidCookie0];
    
    [cookieStorage setCookies:newCookies forURL:hostURL mainDocumentURL:nil];
}
                        
- (void)populateOAuthProperties:(NSString *)propsJsonString
{
    NSDictionary *propsDict = [propsJsonString JSONValue];
    self.remoteAccessConsumerKey = [propsDict objectForKey:@"remoteAccessConsumerKey"];
    self.oauthRedirectURI = [propsDict objectForKey:@"oauthRedirectURI"];
    self.oauthLoginDomain = [propsDict objectForKey:@"oauthLoginDomain"];
    self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
    self.userAccountIdentifier = [propsDict objectForKey:@"userAccountIdentifier"];
}

- (void)setupAuthorizingViewController {
    
    //clear all children of the existing window, if any
    if (nil != _appDelegate.window) {
        NSLog(@"SFContainerAppDelegate clearing self.window");
        [_appDelegate.window.subviews  makeObjectsPerformSelector:@selector(removeFromSuperview)];
        _appDelegate.window = nil;
    }
    
    //(re)init window
    CGRect screenBounds = [ [ UIScreen mainScreen ] bounds ];
    UIWindow *rootWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	_appDelegate.window = rootWindow;
    [rootWindow release];
    
    // Set up a view controller for the authentication process.
    SFAuthorizingViewController *authVc = [[SFAuthorizingViewController alloc] initWithNibName:@"SFAuthorizingViewController" bundle:nil];
    self.authViewController = authVc;
    _appDelegate.window.rootViewController = self.authViewController;
    _appDelegate.window.autoresizesSubviews = YES;
    [authVc release];
    
    [_appDelegate.window makeKeyAndVisible];
    
}

- (void)clearDataModel {
    [self.webView removeFromSuperview];
    self.webView = nil; //clear the web view.    
}

+ (NSSet *)oauthScopes {
    return [NSSet setWithObjects:@"visualforce",@"api",nil] ; 
}


#pragma mark - Settings utilities

- (NSString*)oauthLoginDomain {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *loginHost = [defs objectForKey:kLoginHostUserDefault];
    
    return loginHost;
    
}

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

- (BOOL)checkForUserLogout {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kAccountLogoutUserDefault];
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

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}



- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    
    if (nil != self.authViewController) {
        // We're in the initialization of the app.  Make sure the auth view is in the foreground.
        [_appDelegate.window bringSubviewToFront:self.authViewController.view];
        [self.authViewController setOauthView:view];
    }
    else
        [_appDelegate.viewController.view addSubview:view];
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

@end
