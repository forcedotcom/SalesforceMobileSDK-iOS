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

#import "SalesforceOAuthPlugin.h"
#import "CDVViewController.h"
#import "CDVPlugin+SFAdditions.h"
#import "SFContainerAppDelegate.h"
#import "SFJsonUtils.h"
#import "SFAccountManager.h"
#import "SFUserActivityMonitor.h"
#import "NSDictionary+SFAdditions.h"
#import "SFAuthenticationManager.h"
#import "SFSDKWebUtils.h"

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

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin()
{
}

/**
 Method to be called when the OAuth process completes.
 */
- (void)authenticationCompletion;

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
 Loads the VF ping page in an invisible UIWebView and sets session cookies
 for the VF domain.
 */
- (void)loadVFPingPage;

/**
 This method is called when the hidden UIWebView has finished loading
 the ping page.
 */
- (void)postPageLoad;

/**
 Hidden UIWebView used to load the VF ping page.
 */
@property (nonatomic, strong) UIWebView *hiddenWebView;

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
    SFRelease(_authCallbackId);
    SFRelease(_remoteAccessConsumerKey);
    SFRelease(_oauthRedirectURI);
    SFRelease(_oauthLoginDomain);
    SFRelease(_oauthScopes);
}

#pragma mark - Cordova plugin methods

- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command
{
    NSLog(@"getAuthCredentials: arguments: %@", command.arguments);
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getAuthCredentials" withArguments:command.arguments];
    
    // If authDict does not contain an access token, authenticate first.  Otherwise, send current credentials.
    NSDictionary *authDict = [self credentialsAsDictionary];
    if (authDict == nil || [authDict objectForKey:kAccessTokenCredentialsDictKey] == nil
        || [[authDict objectForKey:kAccessTokenCredentialsDictKey] length] == 0) {
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
    
    // Re-configure user agent.  Basically this ensures that Cordova whitelisting won't apply to the
    // UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
    [SFSDKWebUtils configureUserAgent];
    SFOAuthFlowSuccessCallbackBlock completionBlock = ^(SFOAuthInfo *authInfo) {
        // Reset the user agent back to Cordova.
        CDVViewController *cdvVc = (CDVViewController *)self.viewController;
        [SFSDKWebUtils configureUserAgent:cdvVc.userAgent];
        [self loadVFPingPage];
        [self authenticationCompletion];
    };
    SFOAuthFlowFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
        [[SFAuthenticationManager sharedManager] logout];
    };
    [[SFAuthenticationManager sharedManager] login:self.viewController completion:completionBlock failure:failureBlock];
}

- (void)logoutCurrentUser:(CDVInvokedUrlCommand *)command
{
    NSLog(@"logoutCurrentUser");
    /* NSString* jsVersionStr = */[self getVersion:@"logoutCurrentUser" withArguments:command.arguments];
    [[SFAuthenticationManager sharedManager] logout];
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

- (void)logout
{
    [[SFAuthenticationManager sharedManager] logout];
}

- (void)authenticationCompletion
{
    NSLog(@"authenticationCompletion: Authentication flow succeeded. Initiating post-auth configuration.");
    
    // First, remove any session cookies associated with the app, and reset the primary sid.
    // All other cookies should be reset with any new authentication (user agent, refresh, etc.).
    [SFAuthenticationManager resetSessionCookie];
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
}

- (void)populateOAuthProperties:(NSDictionary *)propsDict
{
    if (nil != propsDict) {
        self.remoteAccessConsumerKey = [propsDict objectForKey:@"remoteAccessConsumerKey"];
        self.oauthRedirectURI = [propsDict objectForKey:@"oauthRedirectURI"];
        self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
    }
}

- (void)fireSessionRefreshEvent:(NSDictionary*)creds
{
    NSString *credsStr = [SFJsonUtils JSONRepresentation:creds];
    NSString *eventStr = [[NSString alloc] initWithFormat:@"cordova.fireDocumentEvent('salesforceSessionRefresh',{data:%@});",
                          credsStr];
    [super writeJavascript:eventStr];
}

- (void)loadVFPingPage
{
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    NSMutableString *instanceUrl = [[NSMutableString alloc] initWithString:creds.instanceUrl.absoluteString];
    if (nil != instanceUrl) {
        [instanceUrl appendString:@"/visualforce/session?url=/apexpages/utils/ping.apexp&autoPrefixVFDomain=true"];
        self.hiddenWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
        [self.hiddenWebView setDelegate:self];
        NSURL *pingURL = [[NSURL alloc] initWithString:instanceUrl];
        NSURLRequest *pingRequest = [[NSURLRequest alloc] initWithURL:pingURL];
        [self.hiddenWebView loadRequest:pingRequest];
    }
}

- (void)postPageLoad
{
    [self.hiddenWebView setDelegate:nil];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self log:SFLogLevelDebug msg:@"SalesforceOAuthPlugin: Started loading page."];
}

- (void)webViewDidFinishLoad:(UIWebView*)webView
{
    [self log:SFLogLevelDebug msg:@"SalesforceOAuthPlugin: Finished loading page."];
    [self postPageLoad];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"SalesforceOAuthPlugin: Error: %@", error);
}

@end
