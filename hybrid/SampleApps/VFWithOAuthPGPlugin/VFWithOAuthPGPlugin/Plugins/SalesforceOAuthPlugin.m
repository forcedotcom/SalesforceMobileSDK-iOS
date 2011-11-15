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
#import "NSObject+SBJson.h"

// ------------------------------------------
// Private constants
// ------------------------------------------

// Key for storing the user's configured login host.
NSString * const kLoginHostUserDefault = @"login_host_pref";

// Key for the primary login host, as defined in the app settings.
NSString * const kPrimaryLoginHostUserDefault = @"primary_login_host_pref";

// Key for the custom login host value in the app settings.
NSString * const kCustomLoginHostUserDefault = @"custom_login_host_pref";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
NSString * const kAccountLogoutUserDefault = @"account_logout_pref";

/// Value to use for login host if user never opens the app settings.
NSString * const kDefaultLoginHost = @"login.salesforce.com";

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin (private)

/**
 @return  YES if  user requested a logout in Settings.
 */
- (BOOL)checkForUserLogout;

/**
 Update the configured login host based on the user-defined app settings. 
 @return  YES if login host has changed in the app settings, NO otherwise. 
 */
- (BOOL)updateLoginHost;

/**
 Initializes the app settings, in the event that the user has not configured
 them before the first launch of the application.
 */
+ (void)ensureAccountDefaultsExist;

/**
 Adds the access (session) token cookie to the web view, for authentication.
 */
- (void)addSidCookieForDomain:(NSString*)domain;

/**
 Convert the post-authentication credentials into a JSON string, to return to
 the calling client code.
 */
- (NSString *)credentialsAsJson;

/**
 Converts the OAuth properties JSON input string into an object, and populates
 the OAuth properties of the plug-in with the values.
 */
- (void)populateOAuthProperties:(NSString *)propsJsonString;

@end

// ------------------------------------------
// Main implementation
// ------------------------------------------
@implementation SalesforceOAuthPlugin

@synthesize coordinator=_coordinator;
@synthesize remoteAccessConsumerKey=_remoteAccessConsumerKey;
@synthesize oauthRedirectURI=_oauthRedirectURI;
@synthesize oauthLoginDomain=_oauthLoginDomain;
@synthesize oauthScopes=_oauthScopes;
@synthesize userAccountIdentifier=_userAccountIdentifier;

#pragma mark - init/dealloc

/**
 This is PhoneGap's default initializer for plugins.
 */
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
    [_remoteAccessConsumerKey release]; _remoteAccessConsumerKey = nil;
    [_oauthRedirectURI release]; _oauthRedirectURI = nil;
    [_oauthLoginDomain release]; _oauthLoginDomain = nil;
    [_oauthScopes release]; _oauthScopes = nil;
    [_userAccountIdentifier release]; _userAccountIdentifier = nil;
    
    [super dealloc];
}

#pragma mark - PhoneGap plugin methods

- (void)getLoginHost:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options  
{
    NSLog(@"getLoginHost:withDict:");
    
    NSString *callbackId = [arguments pop];
    NSLog(@"callbackId: %@", callbackId);
    
    NSString *loginHost = [self oauthLoginDomain];
    NSLog(@"In getLoginHost:withDict: loginHost = %@", loginHost);
    
    PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:loginHost];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}

- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"authenticate:withDict:");
    
    NSString *callbackId = [arguments pop];
    if (_isAuthenticating) {
        NSString *errorMessage = @"Authentication is already in progress.";
        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:errorMessage];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        return;
    }
    
    _isAuthenticating = YES;
    
    // Build the OAuth args from the JSON object string argument.
    NSString *argsString = [arguments pop];
    [self populateOAuthProperties:argsString];
    
    _callbackId = [callbackId copy];
    [self login];
}

#pragma mark - AppDelegate interaction

- (BOOL)resetAppState
{
    NSLog(@"resetAppState");
    
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

- (SFOAuthCoordinator*)coordinator
{
    //create a new coordinator if we don't already have one
    if (nil == _coordinator) {
        
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *loginDomain = self.oauthLoginDomain;
        NSString *accountIdentifier = self.userAccountIdentifier;
        // Here we use the login domain as part of the identifier
        // to distinguish between e.g. sandbox and production credentials.
        NSString *fullKeychainIdentifier = [NSString stringWithFormat:@"%@-%@-%@", appName, accountIdentifier, loginDomain];
        
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] 
                                     initWithIdentifier:fullKeychainIdentifier  
                                     clientId:self.remoteAccessConsumerKey ];
        
        creds.domain = loginDomain;
        creds.redirectUri = self.oauthRedirectURI;
        
        SFOAuthCoordinator *coord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
        coord.scopes = self.oauthScopes; 
        
        coord.delegate = self;
        _coordinator = coord;        
    } 
    
    return _coordinator;
}

- (void)login
{
    // Kick off authentication.
    [self.coordinator authenticate];
}

- (void)logout
{
    [self.coordinator revokeAuthentication];
    [self.coordinator authenticate];
}

- (void)loggedIn
{
    NSURL *instanceUrl = self.coordinator.credentials.instanceUrl;
    NSString *domain = [instanceUrl host]; 
    
    // addSidCookieForDomain can be called before the web view exists.
    [self addSidCookieForDomain:domain];
    [self addSidCookieForDomain:@".force.com"];
    [self addSidCookieForDomain:@".salesforce.com"];
    
    // Call back to the client with the authentication credentials.
    NSString *jsonCreds = [self credentialsAsJson];
    PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:jsonCreds];
    [self writeJavascript:[pluginResult toSuccessCallbackString:_callbackId]];
    _isAuthenticating = NO;
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
    NSString *uaString = [[NSUserDefaults standardUserDefaults] objectForKey:kUserAgentPropKey];
    
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

- (void)addSidCookieForDomain:(NSString*)domain
{
    NSLog(@"addSidCookieForDomain: %@", domain);
    
    // Set the session ID cookie to be used by the web view.
    NSURL *hostURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableArray *newCookies = [NSMutableArray arrayWithArray:[cookieStorage cookiesForURL:hostURL]];
    
    // Remove any stale sid cookies with the same domain.
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

#pragma mark - Settings utilities

- (NSString*)oauthLoginDomain {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *loginHost = [defs objectForKey:kLoginHostUserDefault];
    
    return loginHost;
}

- (BOOL)updateLoginHost
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    
	// The old calculated login host, if any.  This will be nil if this method has never run before.
	NSString *prevLoginHost = [defs objectForKey:kLoginHostUserDefault];
    
	// kPrimaryLoginHostUserDefault is either the actual production or sandbox login host name, or the
    // special value @"CUSTOM", which indicates that kCustomLoginHostUserDefault should be used to
    // set the kLoginHostUserDefault property.
	NSString *loginHost = [defs objectForKey:kPrimaryLoginHostUserDefault];
	NSString *customLoginHost = [defs objectForKey:kCustomLoginHostUserDefault];
    NSLog(@"Hosts before update: loginHost=%@ customLoginHost=%@", loginHost, customLoginHost);
    
	// The user can type whatever they want into kCustomLoginHostUserDefault.  Here we sanitize it a
    // bit by downcasing it.
    customLoginHost = (customLoginHost != nil) ? [customLoginHost lowercaseString] : customLoginHost; 
	
	if ([loginHost isEqualToString:@"CUSTOM"]) {
        
		// Use the custom login host if it is valid.
        if (nil != customLoginHost && [customLoginHost length] > 0) {
            loginHost = customLoginHost;
        } else {
			// Looks like the user selected "custom" but forgot to give a custom hostname.
            // Reset it back to whatever it was before, or the default value if no value
            // was previously set. 
			loginHost = (nil != prevLoginHost ? prevLoginHost : kDefaultLoginHost);
            
			// Reflect the changes back into app settings.
            NSLog(@"The custom login host value was not set in the app settings.  Resetting the login host app settings back to previous value: %@", loginHost);
			[defs setValue:loginHost forKey:kPrimaryLoginHostUserDefault];
		}
	}
	
	// kPrimaryLoginHostUserDefault is the user-selected value in the app settings. No need to change that here.
	// kLoginHostUserDefault contains the generated value of the host used for login, based on kPrimaryLoginHostUserDefault.
	[defs setValue:loginHost forKey:kLoginHostUserDefault];
    
	NSLog(@"loginHost=%@ customLoginHost=%@", loginHost, customLoginHost);
    
	BOOL hostnameChanged = (nil != prevLoginHost && ![prevLoginHost isEqualToString:loginHost]);
	if (hostnameChanged) {
		NSLog(@"updateLoginHost detected a host change in the app settings.");
	}
	
	return hostnameChanged;
}

- (BOOL)checkForUserLogout {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
	return [userDefaults boolForKey:kAccountLogoutUserDefault];
}

+ (void)ensureAccountDefaultsExist {
	// Ensure that we have some default settings in case the user
	// doesn't ever open the app settings.
	
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    // Apparently when the app is foregrounded, NSUserDefaults can be stale.
	[defs synchronize];
    
	// User may have set a custom primary kPrimaryLoginHostUserDefault, 
	// and the calculated login host (kLoginHostUserDefault) may not yet have been updated.
	// (This sometimes happens when user sets prefs before a fresh boot.)
	NSString *primaryLoginHost = [defs objectForKey:kPrimaryLoginHostUserDefault];
    if (nil != primaryLoginHost && [primaryLoginHost length] > 0) {
        NSString *calculatedHost = [defs objectForKey:kLoginHostUserDefault];
        if (nil == calculatedHost || [calculatedHost length] == 0) {
            [defs setValue:primaryLoginHost forKey:kLoginHostUserDefault];
        }
    } else {  // No values have been set yet.  Set everything to default.
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
    
    if (error.code == kSFOAuthErrorInvalidGrant) {  // Invalid cached refresh token.
        // Restart the login process asynchronously.
        NSLog(@"Logging out because oauth failed with error code: %d", error.code);
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
    [self login];    
}

@end
