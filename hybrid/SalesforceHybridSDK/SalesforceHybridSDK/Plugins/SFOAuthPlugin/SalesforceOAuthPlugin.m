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

#import <Cordova/NSMutableArray+QueueAdditions.h>
#import <Cordova/CDVConnection.h>
#import <Cordova/CDVPluginResult.h>

#import "SalesforceOAuthPlugin.h"
#import "SalesforceSDKConstants.h"
#import "SFContainerAppDelegate.h"
#import "SFJsonUtils.h"
#import "SFAccountManager.h"
#import "SFIdentityCoordinator.h"
#import "SFIdentityData.h"
#import "SFSecurityLockout.h"
#import "SFUserActivityMonitor.h"
#import "SFOAuthInfo.h"

// ------------------------------------------
// Private constants
// ------------------------------------------

static NSInteger  const kOAuthAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;

NSTimeInterval kSessionAutoRefreshInterval = 10*60.0; //  10 minutes

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin ()
{
    /**
     Whether this is the initial login to the application (i.e. no previous credentials).
     */
    BOOL _isInitialLogin;
}

/**
 Adds the access (session) token cookie to the web view, for authentication.
 */
- (void)addSidCookieForDomain:(NSString*)domain;

/**
 Called after identity data is retrieved from the service.
 */
- (void)retrievedIdentityData;

/**
 Remove any cookies with the given names from the given domains.
 */
- (void)removeCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames;

/**
 Convert the post-authentication credentials into a Dictionary, to return to
 the calling client code.
 @return Dictionary representation of oauth credentials.
 */
- (NSDictionary *)credentialsAsDictionary;

/**
 The method to call at the end of the auth bootstrapping process.  Any processes that
 should run prior to launching the app should be called here.
 */
- (void)finalizeBootstrap;

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

/**
 Dismisses the authentication retry alert box, if present.
 */
- (void)cleanupRetryAlert;

/**
 Displays an alert in the event of an unknown failure for OAuth or Identity requests, allowing the user
 to retry the process.
 @param tag The tag that identifies the process (OAuth or Identity).
 */
- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag;

/**
 Revokes the current user's credentials for the app, optionally redirecting her to the
 login screen.
 @param restartAuthentication Whether or not to immediately restart the authentication
                              process.
 */
- (void)logout:(BOOL)restartAuthentication;

/**
 Periodic check for auto refresh
 */
- (void)startSessionAutoRefreshTimer;
- (void)clearSessionAutoRefreshTimer;

- (void)sendSessionKeepaliveRequest;
- (void)cleanupSessionKeepaliveRequest;

@end

// ------------------------------------------
// Main implementation
// ------------------------------------------
@implementation SalesforceOAuthPlugin

@synthesize remoteAccessConsumerKey=_remoteAccessConsumerKey;
@synthesize oauthRedirectURI=_oauthRedirectURI;
@synthesize oauthLoginDomain=_oauthLoginDomain;
@synthesize oauthScopes=_oauthScopes;
@synthesize lastRefreshCompleted = _lastRefreshCompleted;
@synthesize autoRefreshOnForeground = _autoRefreshOnForeground;
@synthesize autoRefreshPeriodically = _autoRefreshPeriodically;

#pragma mark - init/dealloc

/**
 This is Cordova's default initializer for plugins.
 */
- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        
        // Strictly for internal tracking, assume we've got our initial credentials, until
        // OAuth tells us otherwise.  E.g. we only want to call the identity service after
        // we first authenticate.  If oauthCoordinator:didBeginAuthenticationWithView: isn't
        // called, we can assume we've already gone through initial authentication at some point.
        _isInitialLogin = NO;
        
        [SFAccountManager updateLoginHost];
    }
    
    return self;
}

- (void)dealloc
{
    [self clearPeriodicRefreshState];
    
    [[SFAccountManager sharedInstance] clearAccountState:NO];
    [self cleanupRetryAlert];
    
    SFRelease(_authCallbackId);
    SFRelease(_remoteAccessConsumerKey);
    SFRelease(_oauthRedirectURI);
    SFRelease(_oauthLoginDomain);
    SFRelease(_oauthScopes);
    
    [super dealloc];
}

#pragma mark - Cordova plugin methods


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
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
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
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        }
    }
    
}

- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"authenticate:withDict:");
    NSString *callbackId = [arguments pop];
    
    _authCallbackId = [callbackId copy];
    
    NSString *argsString = [arguments pop];
    //if we are refreshing, there will be no options: just reuse the known options
    if (nil != argsString) {
        // Build the OAuth args from the JSON object string argument.
        [self populateOAuthProperties:argsString];
        [SFAccountManager setClientId:self.remoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:self.oauthRedirectURI];
        [SFAccountManager setScopes:self.oauthScopes];
    }
    
    [self login];
}

- (void)logoutCurrentUser:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"logoutCurrentUser");
    [self logout];
}

- (void)getAppHomeUrl:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSLog(@"getAppHomeUrl:withDict:");
    NSString *callbackId = [arguments pop];
    
    NSURL *url = [[NSUserDefaults standardUserDefaults] URLForKey:kAppHomeUrlPropKey];
    NSString *urlString = (url == nil ? @"" : [url absoluteString]);
    NSLog(@"AppHomeURL: %@",urlString);
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:urlString];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}


#pragma  mark - Plugin utilities

- (NSDictionary*)credentialsAsDictionary {
    NSDictionary *credentialsDict = nil;
    
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
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

#pragma mark - Session Auto Refresh handling

- (void)refreshTimerExpired:(NSTimer*)timer
{
    NSLog(@"refreshTimerExpired");
    [self sendSessionKeepaliveRequest];
}

- (void)clearSessionAutoRefreshTimer
{
    //clear any existing autorefresh timer
    [_autoRefreshTimer invalidate]; _autoRefreshTimer = nil;
}

- (void)startSessionAutoRefreshTimer
{
    [self clearSessionAutoRefreshTimer];

    _autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:kSessionAutoRefreshInterval
                                     target:self
                                   selector:@selector(refreshTimerExpired:)
                                   userInfo:nil
                                    repeats:YES]; 
}

- (void)clearPeriodicRefreshState
{
    [self cleanupSessionKeepaliveRequest];
    [self clearSessionAutoRefreshTimer];
}

- (void)setAutoRefreshPeriodically:(BOOL)autoRefreshPeriodically
{
    _autoRefreshPeriodically = autoRefreshPeriodically;
    
    if (!_autoRefreshPeriodically) {
        [self clearPeriodicRefreshState];
    }
    
}


- (void)cleanupSessionKeepaliveRequest {
    [_sessionKeepaliveConnection cancel];
    SFRelease(_sessionKeepaliveConnection);
}

- (void)sendSessionKeepaliveRequest 
{
    [self cleanupSessionKeepaliveRequest];
    
    NSLog(@"sendSessionKeepaliveRequest");

    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    //retrieve "Versions" -- should remain the same across all API versions
    NSURL *fullUrl = [[NSURL alloc] initWithScheme:creds.protocol host: creds.instanceUrl.host path:@"/services/data/"];
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:fullUrl];
    [fullUrl release];
    
    NSString *authHeader = [[NSString alloc] initWithFormat:@"OAuth %@", creds.accessToken];
    
    //[req setHTTPMethod:@"GET"];
    [req setValue:authHeader forHTTPHeaderField:@"Authorization"];
    [authHeader release];
    
    _sessionKeepaliveConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
    [req release];
}



#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([connection isEqual:_sessionKeepaliveConnection]) {
        NSLog(@"keepalive conn failed with error: %@",error);

        [self clearPeriodicRefreshState];

        //renew the session
        [self performSelector:@selector(login) withObject:nil afterDelay:0];
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([connection isEqual:_sessionKeepaliveConnection]) {
        NSInteger statusCode = [(NSHTTPURLResponse*)response statusCode];
        
        [self clearPeriodicRefreshState];
        
        if (401 == statusCode) { //unauthorized --- session timeout
            NSLog(@"keepalive request received session timeout -- renewing session");
            //renew the session
            [self performSelector:@selector(login) withObject:nil afterDelay:0];
        } else {
            //restart the refresh timer from now, to correct for drift due to network response time
            [self startSessionAutoRefreshTimer];
        }
    }
}

#pragma mark - Salesforce.com login helpers

- (void)login
{
    //verify that we have a network connection
    CDVConnection *connectionPlugin = (CDVConnection *)[self.commandDelegate getCommandInstance:@"NetworkStatus"];
    NSString *connType = connectionPlugin.connectionType;
    
    if ((nil != connType) && 
        ![connType isEqualToString:@"unknown"] && 
        ![connType isEqualToString:@"none"]) {
        
        [self cleanupRetryAlert];
         
        // Kick off authentication.
        [SFAccountManager sharedInstance].oauthDelegate = self;
        [[SFAccountManager sharedInstance].coordinator authenticate];
    } else {
        //TODO some kinda dialog here?
        NSLog(@"Invalid network connection (%@) -- cannot authenticate",connType);
    }

}

- (void)logout
{
    [self logout:YES];
}

- (void)logout:(BOOL)restartAuthentication
{
    [_appDelegate clearAppState:restartAuthentication];
}

- (void)autoRefresh
{
    if (self.autoRefreshOnForeground || self.autoRefreshPeriodically) {
        [self performSelector:@selector(login) withObject:nil afterDelay:3.0];
    }
}

- (void)loggedIn
{
    // If this is the initial login, or there's no persisted identity data, get the data
    // from the service.
    if (_isInitialLogin || [SFAccountManager sharedInstance].idData == nil) {
        [SFAccountManager sharedInstance].idDelegate = self;
        [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
    } else {
        // Just go directly to the post-processing step.
        [self finalizeBootstrap];
    }
}

- (void)removeCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames
{
    NSAssert(cookieNames != nil && [cookieNames count] > 0, @"No cookie names given to delete.");
    NSAssert(domainNames != nil && [domainNames count] > 0, @"No domain names given for deleting cookies.");
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        for (NSString *cookieToRemoveName in cookieNames) {
            if ([[[cookie name] lowercaseString] isEqualToString:[cookieToRemoveName lowercaseString]]) {
                for (NSString *domainToRemoveName in domainNames) {
                    if ([[[cookie domain] lowercaseString] hasSuffix:[domainToRemoveName lowercaseString]])
                    {
                        [cookieStorage deleteCookie:cookie];
                    }
                }
            }
        }
    }
}

- (void)addSidCookieForDomain:(NSString*)domain
{
    NSAssert(domain != nil && [domain length] > 0, @"addSidCookieForDomain: domain cannot be empty");
    NSLog(@"addSidCookieForDomain: %@", domain);
    
    // Set the session ID cookie to be used by the web view.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    NSMutableDictionary *newSidCookieProperties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                   domain, NSHTTPCookieDomain,
                                                   @"/", NSHTTPCookiePath,
                                                   [SFAccountManager sharedInstance].coordinator.credentials.accessToken, NSHTTPCookieValue,
                                                   @"sid", NSHTTPCookieName,
                                                   @"TRUE", NSHTTPCookieDiscard,
                                                   nil];
    if ([[SFAccountManager sharedInstance].coordinator.credentials.protocol isEqualToString:@"https"]) {
        [newSidCookieProperties setObject:@"TRUE" forKey:NSHTTPCookieSecure];
    }
    
    NSHTTPCookie *sidCookie0 = [NSHTTPCookie cookieWithProperties:newSidCookieProperties];
    [cookieStorage setCookie:sidCookie0];
}

- (void)finalizeBootstrap
{
    // First, remove any session cookies associated with the app.
    // All cookies should be reset with any new authentication (user agent, refresh, etc.).
    [self removeCookies:[NSArray arrayWithObjects:@"sid", nil]
            fromDomains:[NSArray arrayWithObjects:@".salesforce.com", @".force.com", nil]];
    [self addSidCookieForDomain:@".salesforce.com"];
    
    self.lastRefreshCompleted = [NSDate date];
    
    NSDictionary *authDict = [self credentialsAsDictionary];
    if (nil != _authCallbackId) {
        // Call back to the client with the authentication credentials.    
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
        [self writeJavascript:[pluginResult toSuccessCallbackString:_authCallbackId]];
        
        SFRelease(_authCallbackId);
    } else {
        //fire a notification that the session has been refreshed
        [self fireSessionRefreshEvent:authDict];
    }
    
    if (self.autoRefreshPeriodically) {
        [self startSessionAutoRefreshTimer];
    }
    
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
    }
    
    _isInitialLogin = NO;
}

- (void)populateOAuthProperties:(NSString *)propsJsonString
{
    NSDictionary *propsDict = [SFJsonUtils objectFromJSONString:propsJsonString];

    if (nil != propsDict) {
        self.remoteAccessConsumerKey = [propsDict objectForKey:@"remoteAccessConsumerKey"];
        self.oauthRedirectURI = [propsDict objectForKey:@"oauthRedirectURI"];
        self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
        self.autoRefreshOnForeground =   [[propsDict objectForKey :@"autoRefreshOnForeground"] boolValue];
        self.autoRefreshPeriodically =  [[propsDict objectForKey :@"autoRefreshPeriodically"] boolValue];
    }
}


- (void)fireSessionRefreshEvent:(NSDictionary*)creds
{
    
    NSString *credsStr = [SFJsonUtils JSONRepresentation:creds];
    NSString *eventStr = [[NSString alloc] initWithFormat:@"cordova.fireDocumentEvent('salesforceSessionRefresh',{data:%@});",
                          credsStr];
    [super writeJavascript:eventStr];
    [eventStr release];
}

- (void)cleanupRetryAlert {
    [_statusAlert dismissWithClickedButtonIndex:-666 animated:NO];
    [_statusAlert setDelegate:nil];
    SFRelease(_statusAlert);
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (nil == _statusAlert) {
        // show alert and allow retry
        _statusAlert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error" 
                                                       message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                      delegate:self
                                             cancelButtonTitle:@"Retry"
                                             otherButtonTitles: nil];
        _statusAlert.tag = tag;
        [_statusAlert show];
    }
}

- (void)retrievedIdentityData
{
    // NB: This method is assumed to run after identity data has been refreshed from the service.
    NSAssert([SFAccountManager sharedInstance].idData != nil, @"Identity data should not be nil/empty at this point.");
    
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        // Set the callback actions for post-passcode entry/configuration.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self finalizeBootstrap];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{  // Don't know how this would happen, but if it does....
            [self logout];
        }];
        
        // setLockoutTime triggers passcode creation.  We could consider a more explicit call for visibility here?
        [SFSecurityLockout setPasscodeLength:[SFAccountManager sharedInstance].idData.mobileAppPinLength];
        [SFSecurityLockout setLockoutTime:([SFAccountManager sharedInstance].idData.mobileAppScreenLockTimeout * 60)];
    } else {
        // No additional mobile policies.  So no passcode.
        [self finalizeBootstrap];
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
    _isInitialLogin = YES;
    [_appDelegate addOAuthViewToMainView:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@, authInfo: %@", coordinator.credentials.userId, info);
    [coordinator.view removeFromSuperview];
    [self loggedIn];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    NSLog(@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info);
    
    // Clear account state before continuing.
    [[SFAccountManager sharedInstance] clearAccountState:NO];
    
    if (error.code == kSFOAuthErrorInvalidGrant) {  // Invalid cached refresh token.
        // Restart the login process asynchronously.
        NSLog(@"Logging out because oauth failed with error code: %d", error.code);
        [self performSelector:@selector(logout) withObject:nil afterDelay:0];
    }
    else {
        // show alert and allow retry
        [self showRetryAlertForAuthError:error alertTag:kOAuthAlertViewTag];
    }
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [self retrievedIdentityData];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag];
}

#pragma mark - UIAlertViewDelegate
//called after animation is finished
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == _statusAlert) {
        NSLog(@"clickedButtonAtIndex: %d",buttonIndex);
        if (alertView.tag == kOAuthAlertViewTag) {
            [self login];    
        } else if (alertView.tag == kIdentityAlertViewTag) {
            [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
        }
    }
}

@end
