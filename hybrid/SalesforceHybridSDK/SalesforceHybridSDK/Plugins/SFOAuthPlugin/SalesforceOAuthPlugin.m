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

#import "NSMutableArray+QueueAdditions.h"
#import "CDVPluginResult.h"
#import "CDVInvokedUrlCommand.h"

#import "SalesforceOAuthPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import "SalesforceSDKConstants.h"
#import "SFContainerAppDelegate.h"
#import "SFJsonUtils.h"
#import "SFAccountManager.h"
#import "SFIdentityCoordinator.h"
#import "SFIdentityData.h"
#import "SFSecurityLockout.h"
#import "SFUserActivityMonitor.h"
#import "SFOAuthInfo.h"
#import "SFAuthorizingViewController.h"
#import "NSDictionary+SFAdditions.h"
#import "SFOAuthFlowManager.h"

// ------------------------------------------
// Private constants
// ------------------------------------------

static NSString * const kAccessTokenCredentialsDictKey  = @"accessToken";
static NSString * const kRefreshTokenCredentialsDictKey = @"refreshToken";
static NSString * const kClientIdCredentialsDictKey     = @"clientId";
static NSString * const kUserIdCredentialsDictKey       = @"userId";
static NSString * const kOrgIdCredentialsDictKey        = @"orgId";
static NSString * const kLoginUrlCredentialsDictKey     = @"loginUrl";
static NSString * const kInstanceUrlCredentialsDictKey  = @"instanceUrl";
static NSString * const kUserAgentCredentialsDictKey    = @"userAgentString";

NSTimeInterval kSessionAutoRefreshInterval = 10*60.0; //  10 minutes

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin ()
{
    
}

/**
 Revokes the current user's credentials for the app, optionally redirecting her to the
 login screen.
 @param restartAuthentication Whether or not to immediately restart the authentication
 process.
 */
- (void)logout:(BOOL)restartAuthentication;

/**
 Adds the access (session) token cookie to the web view, for authentication.
 */
- (void)addSidCookieForDomain:(NSString*)domain;

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
 Converts the OAuth properties JSON input string into an object, and populates
 the OAuth properties of the plug-in with the values.
 @param propsDict The NSDictionary containing the OAuth properties.
 */
- (void)populateOAuthProperties:(NSDictionary *)propsDict;

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

#pragma mark - init/dealloc

/**
 This is Cordova's default initializer for plugins.
 */
- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        
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

- (void)killSession:(CDVInvokedUrlCommand *)command
{
    NSLog(@"Killing the session.  Callback ID: %@", command.callbackId);
    [self removeCookies:[NSArray arrayWithObjects:@"sid", nil]
            fromDomains:[NSArray arrayWithObjects:@".salesforce.com", @".force.com", nil]];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self writeJavascript:[result toSuccessCallbackString:command.callbackId]];
}


- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command
{
    NSLog(@"getAuthCredentials: arguments: %@", command.arguments);
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getAuthCredentials" withArguments:command.arguments];
    
    // If authDict does not contain an access token, authenticate first.  Otherwise, send current credentials.
    NSDictionary *authDict = [self credentialsAsDictionary];
    if (authDict == nil || [authDict objectForKey:kAccessTokenCredentialsDictKey] == nil
        || [[authDict objectForKey:kAccessTokenCredentialsDictKey] length] == 0) {
        // TODO: Make this call the OAuthFlowManager too?
        [self authenticate:command];
    } else {
        // Send the credentials we've cached.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
        [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
    }
}

- (void)authenticate:(CDVInvokedUrlCommand*)command
{
    NSLog(@"authenticate:");
    NSString* callbackId = command.callbackId;
    _authCallbackId = [callbackId copy];
    /*NSString* jsVersionStr = */[self getVersion:@"authenticate" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSDictionary *oauthPropertiesDict = [argsDict nonNullObjectForKey:@"oauthProperties"];
    
    // If we are refreshing, there will be no options/properties: just reuse the known options.
    if (nil != oauthPropertiesDict) {
        // Build the OAuth args from the JSON object string argument.
        [self populateOAuthProperties:oauthPropertiesDict];
        [SFAccountManager setClientId:self.remoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:self.oauthRedirectURI];
        [SFAccountManager setScopes:self.oauthScopes];
    }
    
    [self login];
}

- (void)logoutCurrentUser:(CDVInvokedUrlCommand *)command
{
    NSLog(@"logoutCurrentUser");
    /* NSString* jsVersionStr = */[self getVersion:@"logoutCurrentUser" withArguments:command.arguments];
    [self logout];
}

- (void)getAppHomeUrl:(CDVInvokedUrlCommand *)command
{
    NSLog(@"getAppHomeUrl:");
    NSString* callbackId = command.callbackId;
    
    /* NSString* jsVersionStr = */[self getVersion:@"getAppHomeUrl" withArguments:command.arguments];
    
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
                           creds.accessToken, kAccessTokenCredentialsDictKey,
                           creds.refreshToken, kRefreshTokenCredentialsDictKey,
                           creds.clientId, kClientIdCredentialsDictKey,
                           creds.userId, kUserIdCredentialsDictKey,
                           creds.organizationId, kOrgIdCredentialsDictKey,
                           loginUrl, kLoginUrlCredentialsDictKey,
                           instanceUrl, kInstanceUrlCredentialsDictKey,
                           uaString, kUserAgentCredentialsDictKey,
                           nil];
        
    }
    
    
    return credentialsDict;
}



#pragma mark - Salesforce.com login helpers

- (void)authenticationSuccess
{
    // First, remove any session cookies associated with the app.
    // All cookies should be reset with any new authentication (user agent, refresh, etc.).
    [self removeCookies:[NSArray arrayWithObjects:@"sid", nil]
            fromDomains:[NSArray arrayWithObjects:@".salesforce.com", @".force.com", nil]];
    [self addSidCookieForDomain:@".salesforce.com"];
    
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
    
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
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

- (void)populateOAuthProperties:(NSDictionary *)propsDict
{
    if (nil != propsDict) {
        self.remoteAccessConsumerKey = [propsDict objectForKey:@"remoteAccessConsumerKey"];
        self.oauthRedirectURI = [propsDict objectForKey:@"oauthRedirectURI"];
        self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
    }
}

@end
