/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import "CDVPlugin+SFAdditions.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFUserActivityMonitor.h>
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import "SFHybridViewController.h"

// ------------------------------------------
// Private methods interface
// ------------------------------------------
@interface SalesforceOAuthPlugin()

- (void)authenticate:(CDVInvokedUrlCommand*)command getCachedCredentials:(BOOL)getCachedCredentials;

/**
 Method to be called when the OAuth process completes.
 @param authDict The NSDictionary containing the authentication data.
 @param callbackId The plugin callback ID associated with the request.
 */
- (void)authenticationCompletion:(NSDictionary *)authDict callbackId:(NSString *)callbackId;

/**
 Creates an error dictionary to send back in an auth error case.
 @param error The OAuth error that occurred.
 @param authInfo The OAuth info associated with the auth attempt.
 @return An NSDictionary of error information.
 */
+ (NSDictionary *)authErrorDictionaryFromError:(NSError *)error authInfo:(SFOAuthInfo *)authInfo;

@end

// ------------------------------------------
// Main implementation
// ------------------------------------------
@implementation SalesforceOAuthPlugin

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
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)authenticate:(CDVInvokedUrlCommand*)command getCachedCredentials:(BOOL)getCachedCredentials
{
    [self log:SFLogLevelDebug msg:@"authenticate:getCachedCredentials:"];
    NSString* callbackId = command.callbackId;
    SFOAuthPluginAuthSuccessBlock completionBlock = ^(SFOAuthInfo *authInfo, NSDictionary *authDict) {
        [self authenticationCompletion:authDict callbackId:callbackId];
    };
    SFOAuthFlowFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsDictionary:[[self class] authErrorDictionaryFromError:error authInfo:authInfo]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    };
    
    SFHybridViewController *hybridVc = (SFHybridViewController *)self.viewController;
    if (getCachedCredentials) {
        [hybridVc getAuthCredentialsWithCompletionBlock:completionBlock failureBlock:failureBlock];
    } else {
        [hybridVc authenticateWithCompletionBlock:completionBlock failureBlock:failureBlock];
    }
}

+ (NSDictionary *)authErrorDictionaryFromError:(NSError *)error authInfo:(SFOAuthInfo *)authInfo
{
    NSMutableDictionary *authDict = [NSMutableDictionary dictionary];
    authDict[@"Domain"] = error.domain;
    authDict[@"Code"] = @(error.code);
    authDict[@"Description"] = error.localizedDescription;
    if ((error.userInfo)[@"error"] != nil)
        authDict[@"Type"] = (error.userInfo)[@"error"];
    authDict[@"AuthInfo"] = [authInfo description];
    return authDict;
}

#pragma mark - Salesforce.com login helpers

- (void)authenticationCompletion:(NSDictionary *)authDict callbackId:(NSString *)callbackId
{
    [self log:SFLogLevelDebug msg:@"authenticationCompletion: Authentication flow succeeded. Initiating post-auth configuration."];
    // Call back to the client with the authentication credentials.
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

@end
