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

- (void)authenticate:(CDVInvokedUrlCommand*)command getCachedCredentials:(BOOL)getCachedCredentials;

/**
 Method to be called when the OAuth process completes.
 @param authDict The NSDictionary containing the authentication data.
 */
- (void)authenticationCompletion:(NSDictionary *)authDict;

@end

// ------------------------------------------
// Main implementation
// ------------------------------------------
@implementation SalesforceOAuthPlugin

/**
 This is Cordova's default initializer for plugins.
 */
- (CDVPlugin *)initWithWebView:(UIWebView *)theWebView
{
    self = (SalesforceOAuthPlugin *)[super initWithWebView:theWebView];
    if (self) {
        // Custom init.
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_authCallbackId);
}

#pragma mark - Cordova plugin methods and helpers

- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command
{
    [self log:SFLogLevelDebug format:@"getAuthCredentials: arguments: %@", command.arguments];
    /* NSString* jsVersionStr = */[self getVersion:@"getAuthCredentials" withArguments:command.arguments];
    [self authenticate:command getCachedCredentials:YES];
}

- (void)authenticate:(CDVInvokedUrlCommand*)command
{
    [self log:SFLogLevelDebug format:@"authenticate: arguments: %@", command.arguments];
    /* NSString* jsVersionStr = */[self getVersion:@"authenticate" withArguments:command.arguments];
    [self authenticate:command getCachedCredentials:NO];
}

- (void)logoutCurrentUser:(CDVInvokedUrlCommand *)command
{
    [self log:SFLogLevelDebug format:@"logoutCurrentUser: arguments: %@", command.arguments];
    /* NSString* jsVersionStr = */[self getVersion:@"logoutCurrentUser" withArguments:command.arguments];
    [[SFAuthenticationManager sharedManager] logout];
}

- (void)getAppHomeUrl:(CDVInvokedUrlCommand *)command
{
    [self log:SFLogLevelDebug format:@"getAppHomeUrl: arguments: %@", command.arguments];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getAppHomeUrl" withArguments:command.arguments];
    NSURL *url = ((SFHybridViewController *)self.viewController).appHomeUrl;
    NSString *urlString = (url == nil ? @"" : [url absoluteString]);
    [self log:SFLogLevelDebug format:@"AppHomeURL: %@",urlString];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:urlString];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}

- (void)authenticate:(CDVInvokedUrlCommand*)command getCachedCredentials:(BOOL)getCachedCredentials
{
    [self log:SFLogLevelDebug msg:@"authenticate:getCachedCredentials:"];
    NSString* callbackId = command.callbackId;
    _authCallbackId = [callbackId copy];
    SFOAuthPluginAuthSuccessBlock completionBlock = ^(SFOAuthInfo *authInfo, NSDictionary *authDict) {
        [self authenticationCompletion:authDict];
    };
    
    SFHybridViewController *hybridVc = (SFHybridViewController *)self.viewController;
    if (getCachedCredentials) {
        [hybridVc getAuthCredentialsWithCompletionBlock:completionBlock failureBlock:NULL];
    } else {
        [hybridVc authenticateWithCompletionBlock:completionBlock failureBlock:NULL];
    }
}

#pragma mark - Salesforce.com login helpers

- (void)authenticationCompletion:(NSDictionary *)authDict
{
    NSLog(@"authenticationCompletion: Authentication flow succeeded. Initiating post-auth configuration.");
    // Call back to the client with the authentication credentials.
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
    [self writeJavascript:[pluginResult toSuccessCallbackString:_authCallbackId]];
    SFRelease(_authCallbackId);
}

@end
