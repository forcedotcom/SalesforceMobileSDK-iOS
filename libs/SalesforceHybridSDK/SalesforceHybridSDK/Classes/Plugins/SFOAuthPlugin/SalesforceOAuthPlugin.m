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
SFSDK_USE_DEPRECATED_BEGIN
@implementation SalesforceOAuthPlugin

#pragma mark - Cordova plugin methods

- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"getAuthCredentials: arguments: %@", command.arguments];
    [self getVersion:@"getAuthCredentials" withArguments:command.arguments];

    SFHybridViewController *hybridVc = (SFHybridViewController *)self.viewController;
    NSDictionary *authDict = [hybridVc credentialsAsDictionary];
    if ([authDict[kAccessTokenCredentialsDictKey] length] > 0) {
        [self sendAuthCredentials:command authDict:authDict];
    } else {
        [self sendNotAuthenticated:command];
    }
}

- (void)authenticate:(CDVInvokedUrlCommand*)command
{
    [SFSDKHybridLogger d:[self class] format:@"authenticate: arguments: %@", command.arguments];
    [self getVersion:@"authenticate" withArguments:command.arguments];

    SFOAuthPluginAuthSuccessBlock completionBlock = ^(SFOAuthInfo *authInfo, NSDictionary *authDict) {
        [self sendAuthCredentials:command authDict:authDict];
    };

    SFOAuthFlowFailureCallbackBlock failureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsDictionary:[[self class] authErrorDictionaryFromError:error authInfo:authInfo]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    };
    SFHybridViewController *hybridVc = (SFHybridViewController *)self.viewController;
    [hybridVc authenticateWithCompletionBlock:completionBlock failureBlock:failureBlock];
}

- (void)logoutCurrentUser:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"logoutCurrentUser: arguments: %@", command.arguments];
    [self getVersion:@"logoutCurrentUser" withArguments:command.arguments];
    [[SFAuthenticationManager sharedManager] logout];
}

- (void)getAppHomeUrl:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"getAppHomeUrl: arguments: %@", command.arguments];
    NSString* callbackId = command.callbackId;
    [self getVersion:@"getAppHomeUrl" withArguments:command.arguments];
    NSURL *url = ((SFHybridViewController *)self.viewController).appHomeUrl;
    NSString *urlString = (url == nil ? @"" : [url absoluteString]);
    [SFSDKHybridLogger d:[self class] format:@"AppHomeURL: %@", urlString];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:urlString];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

#pragma mark - Cordova plugin helpers

- (void) sendAuthCredentials:(CDVInvokedUrlCommand *)command authDict:(NSDictionary*)authDict {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:authDict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) sendNotAuthenticated:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not authenticated"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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

@end
SFSDK_USE_DEPRECATED_END
