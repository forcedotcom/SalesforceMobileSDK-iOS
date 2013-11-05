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

#import <Foundation/Foundation.h>
#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import "CDVPlugin.h"

@class CDVInvokedUrlCommand;

/**
 * Cordova plugin for managing authentication with the Salesforce service, via OAuth.
 */
@interface SalesforceOAuthPlugin : CDVPlugin

#pragma mark - Plugin exported to javascript

/**
 * Cordova plug-in method to obtain the current login credentials, authenticating if needed.
 * @param command Cordova plugin command object, containing input parameters.
 */
- (void)getAuthCredentials:(CDVInvokedUrlCommand *)command;

/**
 * Cordova plug-in method to authenticate a user to the application.
 * @param command Cordova plugin command object, containing the OAuth configuration properties.
 */
- (void)authenticate:(CDVInvokedUrlCommand *)command;

/**
 * Clear the current user's authentication credentials.
 * @param command Standard Cordova plugin arguments, not used in this method.
 */
- (void)logoutCurrentUser:(CDVInvokedUrlCommand *)command;

/**
 * Get the app's homepage URL, which can be used for loading the app in scenarios where it's offline.
 * @param command Standard Cordova plugin arguments, nominally used in this method.
 */
- (void)getAppHomeUrl:(CDVInvokedUrlCommand *)command;

@end
