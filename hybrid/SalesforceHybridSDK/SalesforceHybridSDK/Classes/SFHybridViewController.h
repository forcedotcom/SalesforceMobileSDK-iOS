/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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
#import "CDVViewController.h"
#import "SalesforceOAuthPlugin.h"
#import "SFAuthenticationManager.h"

/**
 * Base view controller for Salesforce hybrid apps.  Currently, this does not expose
 * functionality outside of the base Cordova view controller functionality, and
 * serves more as a placeholder for future customizations.
 */
@interface SFHybridViewController : CDVViewController
{
    SFContainerAppDelegate *_appDelegate;
}

/**
 The Remote Access object consumer key.
 */
@property (nonatomic, copy) NSString *remoteAccessConsumerKey;

/**
 The Remote Access object redirect URI
 */
@property (nonatomic, copy) NSString *oauthRedirectURI;

/**
 The Remote Access object Login Domain
 */
@property (nonatomic, copy) NSString *oauthLoginDomain;

/**
 The set of oauth scopes that should be requested for this app.
 */
@property (nonatomic, strong) NSSet *oauthScopes;

/**
 Used to authenticate.
 */
- (void)authenticate:(NSDictionary *)argsDict:(NSDictionary *)oauthPropertiesDict:(SFOAuthFlowSuccessCallbackBlock)completionBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock;

/**
 Loads a local start page.
 */
- (void)loadLocalStartPage;

/**
 Loads a remote start page.
 */
- (void)loadRemoteStartPage;

/**
 Loads an error page.
 */
- (void)loadErrorPage;

/**
 Gets the front door URL.
 */
- (NSString *)getFrontDoorURL:(NSString *)remoteStartPage;

/**
 Loads the VF ping page in an invisible UIWebView and sets session cookies
 for the VF domain.
 */
- (void)loadVFPingPage;

/**
 Convert the post-authentication credentials into a Dictionary, to return to
 the calling client code.
 @return Dictionary representation of oauth credentials.
 */
- (NSDictionary *)credentialsAsDictionary;

/**
 * Method to obtain the current login credentials, authenticating if needed.
 */
- (NSDictionary *)getAuthCredentials;

@end
