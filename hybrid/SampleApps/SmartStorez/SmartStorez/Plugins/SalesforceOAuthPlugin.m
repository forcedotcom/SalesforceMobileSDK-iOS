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

#import <PhoneGap/PGPlugin.h>
#import <PhoneGap/PhoneGapViewController.h>

#import "SalesforceOAuthPlugin.h"
#import "SFContainerAppDelegate.h"
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

// Value for kPrimaryLoginHostUserDefault when a custom host is chosen.
NSString * const kPrimaryLoginHostCustomValue = @"CUSTOM";

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
 Initializes the app settings, in the event that the user has not configured
 them before the first launch of the application.
 */
+ (void)ensureAccountDefaultsExist;

/**
 Adds the access (session) token cookie to the web view, for authentication.
 */
- (void)addSidCookieForDomain:(NSString*)domain;

/**
 Convert the post-authentication credentials into a Dictionary, to return to
 the calling client code.
 @return Dictionary representation of oauth credentials.
 */
- (NSDictionary *)credentialsAsDictionary;

/**
 Converts the OAuth properties JSON input string into an object, and populates
 the OAuth properties of the plug-in with the values.
 */
- (void)populateOAuthProperties:(NSString *)propsJsonString;

/**
 Broadcast a document event to js that we've updated the Salesforce session.
 @param creds  OAuth credentials as a dictionary
 */
- (void)fireSessionRefreshEvent:(NSDictionary*)creds;

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
@synthesize lastRefreshCompleted = _lastRefreshCompleted;
@synthesize autoRefreshOnForeground = _autoRefreshOnForeground;

#pragma mark - init/dealloc

/**
 This is PhoneGap's default initializer for plugins.
 */
- (PGPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        [[self class] ensureAccountDefaultsExist];
    }
    
    return self;
}

- (void)dealloc
{
    [_coordinator setDelegate:nil];
    [_coordinator release]; _coordinator = nil;
    [_authCallbackId release]; _authCallbackId = nil;
    [_remoteAccessConsumerKey release]; _remoteAccessConsumerKey = nil;
    [_oauthRedirectURI release]; _oauthRedirectURI = nil;
    [_oauthLoginDomain release]; _oauthLoginDomain = nil;
    [_oauthScopes release]; _oauthScopes = nil;
    
    [super dealloc];
}

#pragma mark - PhoneGap plugin methods


- (void)getAuthCredentials:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options
{
    NSLog(@"getAuthCredentials:withDict: arguments: %@ options: %@",arguments,options);
    
    NSString *callbackId = [arguments objectAtIndex:0];
    NSLog(@"callbackId: %@", callbackId);
    
    NSDictionary *authDict = [self credentialsAsDictionary];

    if (nil != self.lastRefreshCompleted) {
        //we've refreshed during the lifetime of this (singleton) plugin:
        //check for timeout
        
        NSDate *curDate = [NSDate date];
        NSTimeInterval delta = [curDate timeIntervalSinceDate:self.lastRefreshCompleted];
        NSLog(@"lastRefreshCompleted %0.2f seconds ago",delta);

        if (delta < 120.0f) { //seconds            
            PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsDictionary:authDict];
            [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
        } else {
            [self authenticate:arguments withDict:nil];
        }
        
    } else {
        //If authdict is not nil and we have a refresh token then we can ask for a refresh.
        NSLog(@"We have not authenticated during app lifetime! ");
        if (nil != authDict) {
            [self authenticate:arguments withDict:nil];
        } else {
            NSString *errorMessage = @"No auth info available.";
            PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_ERROR messageAsString:errorMessage];
            [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        }
    }
 
}

- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"authenticate:withDict:");
    NSString *callbackId = [arguments pop];

    //Verify that we're not already authenticating
    if (nil != _authCallbackId) {
        NSString *errorMessage = @"Authentication is already in progress.";
        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_ERROR messageAsString:errorMessage];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        return;
    }
    
    _authCallbackId = [callbackId copy];

    NSString *argsString = [arguments pop];
    //if we are refreshing, there will be no options: just reuse the known options
    if (nil != argsString) {
        // Build the OAuth args from the JSON object string argument.
        [self populateOAuthProperties:argsString];
    }
    
    [self login];
}

- (void)logoutCurrentUser:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"logoutCurrentUser");
    [self logout];
}


#pragma  mark - Plugin utilities

- (NSDictionary*)credentialsAsDictionary {
    NSDictionary *credentialsDict = nil;
    
    SFOAuthCredentials *creds = self.coordinator.credentials;
    if (nil != creds) {
        NSString *instanceUrl = creds.instanceUrl.absoluteString;
        NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
        NSString *uaString = [_appDelegate userAgentString];
        
        credentialsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                    creds.accessToken, @"accessToken",
                                    creds.refreshToken,@"refreshToken",
                                    creds.clientId, @"clientId",
                                    creds.userId, @"userId",
                                    creds.organizationId, @"orgId",
                                    loginUrl, @"loginUrl",
                                    instanceUrl, @"instanceUrl",
                                    uaString, @"userAgentString",
                                    nil];
            
    }

    
    return credentialsDict;
}



#pragma mark - AppDelegate interaction

- (BOOL)resetAppState
{
    NSLog(@"resetAppState");
    
    BOOL shouldReset = NO;
    
    BOOL shouldLogout = [self checkForUserLogout] ;
    if (shouldLogout) {
        shouldReset = YES;
        [self.coordinator revokeAuthentication];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAccountLogoutUserDefault];
        [defs synchronize];
    } else {
        BOOL loginHostChanged = [[self class] updateLoginHost];
        if (loginHostChanged) {
            shouldReset = YES;
            [_coordinator setDelegate:nil];
            [_coordinator release]; _coordinator = nil;
        }
    }
    
    if (!shouldReset) {
        if (self.autoRefreshOnForeground) {
            [self login];
        }
    }
    
    return shouldReset;
}

#pragma mark - Salesforce.com login helpers

- (SFOAuthCoordinator*)coordinator
{
    // Create a new coordinator instance if we don't already have one.
    if (nil == _coordinator) {
        
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *loginDomain = self.oauthLoginDomain;
        NSString *accountIdentifier = @"Default"; //TODO support multiple accounts someday
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
    
    self.lastRefreshCompleted = [NSDate date];
    
    NSDictionary *authDict = [self credentialsAsDictionary];
    if (nil != _authCallbackId) {
        // Call back to the client with the authentication credentials.    
        PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsDictionary:authDict];
        [self writeJavascript:[pluginResult toSuccessCallbackString:_authCallbackId]];
        
        [_authCallbackId release]; _authCallbackId = nil;
    } else {
        //fire a notification that the session has been refreshed
        [self fireSessionRefreshEvent:authDict];
    }
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
    self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
    self.autoRefreshOnForeground =   [[propsDict objectForKey :@"autoRefreshOnForeground"] boolValue];
}


- (void)fireSessionRefreshEvent:(NSDictionary*)creds
{
    NSString *credsStr = [creds JSONString];
    NSString *eventStr = [[NSString alloc] initWithFormat:@"PhoneGap.fireDocumentEvent('salesforceSessionRefresh',%@);",
                          credsStr];
    [super writeJavascript:eventStr];
    [eventStr release];
}


#pragma mark - Settings utilities

- (NSString*)oauthLoginDomain
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *loginHost = [defs objectForKey:kLoginHostUserDefault];
    
    return loginHost;
}

+ (BOOL)updateLoginHost
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    
	NSString *previousLoginHost = [defs objectForKey:kLoginHostUserDefault];
	NSString *currentLoginHost = [[self class] primaryLoginHost];
    
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

- (BOOL)checkForUserLogout
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
	return [userDefaults boolForKey:kAccountLogoutUserDefault];
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

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view
{
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view
{
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    [_appDelegate addOAuthViewToMainView:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator
{
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@", coordinator.credentials.userId);
    [coordinator.view removeFromSuperview];
    [self loggedIn];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error
{
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self login];    
}

@end
