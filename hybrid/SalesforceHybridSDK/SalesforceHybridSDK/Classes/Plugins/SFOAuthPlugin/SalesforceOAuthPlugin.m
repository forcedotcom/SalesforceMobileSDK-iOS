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
#import "SFHybridViewController.h"

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin()

/**
 Broadcast a document event to js that we've updated the Salesforce session.
 @param creds  OAuth credentials as a dictionary
 */
- (void)fireSessionRefreshEvent:(NSDictionary*)creds;

/**
 Method to be called when the OAuth process completes.
 */
- (void)authenticationCompletion;

@end

// ------------------------------------------
// Main implementation
// ------------------------------------------
@implementation SalesforceOAuthPlugin

/**
 This is Cordova's default initializer for plugins.
 */
- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        [SFAccountManager updateLoginHost];
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_authCallbackId);
}

#pragma mark - Cordova plugin methods

- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command
{
    NSLog(@"getAuthCredentials: arguments: %@", command.arguments);
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getAuthCredentials" withArguments:command.arguments];
    NSDictionary *authDict = [(SFHybridViewController *)self.viewController getAuthCredentials];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}

- (void)authenticate:(CDVInvokedUrlCommand*)command
{
    NSLog(@"authenticate:");
    NSString* callbackId = command.callbackId;
    if (nil != callbackId) {
        _authCallbackId = [callbackId copy];
    }
    SFOAuthFlowSuccessCallbackBlock completionBlock = ^(SFOAuthInfo *authInfo) {
        // Reset the user agent back to Cordova.
        [SFSDKWebUtils configureUserAgent:((SFHybridViewController *)self.viewController).userAgent];
        if (authInfo.authType == SFOAuthTypeRefresh) {
            [(SFHybridViewController *)self.viewController loadVFPingPage];
        }
        [self authenticationCompletion];
    };
    SFOAuthFlowFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
        [[SFAuthenticationManager sharedManager] logout];
    };
    /*NSString* jsVersionStr = */[self getVersion:@"authenticate" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSDictionary *oauthPropertiesDict = [argsDict nonNullObjectForKey:@"oauthProperties"];
    [(SFHybridViewController *)self.viewController authenticate:argsDict:oauthPropertiesDict:completionBlock:failureBlock];
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

#pragma mark - Salesforce.com login helpers

- (void)logout
{
    [[SFAuthenticationManager sharedManager] logout];
}

- (void)authenticationCompletion
{
    NSLog(@"postAuthConfig: Authentication flow succeeded. Initiating post-auth configuration.");
    // First, remove any session cookies associated with the app, and reset the primary sid.
    // All other cookies should be reset with any new authentication (user agent, refresh, etc.).
    [SFAuthenticationManager resetSessionCookie];
    NSDictionary *authDict = [(SFHybridViewController *)self credentialsAsDictionary];
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

- (void)fireSessionRefreshEvent:(NSDictionary*)creds
{
    NSString *credsStr = [SFJsonUtils JSONRepresentation:creds];
    NSString *eventStr = [[NSString alloc] initWithFormat:@"cordova.fireDocumentEvent('salesforceSessionRefresh',{data:%@});",
                          credsStr];
    [super writeJavascript:eventStr];
}

@end
