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
#import "PGPlugin.h"
#import "SFOAuthCoordinator.h"
#import "SFIdentityCoordinator.h"

@class SFContainerAppDelegate;
@class SFIdentityData;

/**
 * PhoneGap plugin for managing authentication with the Salesforce service, via OAuth.
 */
@interface SalesforceOAuthPlugin : PGPlugin <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate, UIAlertViewDelegate> {
    SFContainerAppDelegate *_appDelegate;
    NSString *_authCallbackId;
    NSString *_remoteAccessConsumerKey;
    NSString *_oauthRedirectURI;
    NSString *_oauthLoginDomain;
    NSSet *_oauthScopes;
    NSDate *_lastRefreshCompleted;
    BOOL _autoRefreshOnForeground;
    UIAlertView *_statusAlert;
    BOOL _autoRefreshPeriodically;
    NSTimer *_autoRefreshTimer;
    NSURLConnection *_sessionKeepaliveConnection;
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
@property (nonatomic, retain) NSSet *oauthScopes;


/**
 The timestamp at which the last oauth refresh completed.
 */
@property (nonatomic, retain) NSDate *lastRefreshCompleted;


/**
 Whether the app should automatically refresh oauth session when foregrounded
 */
@property (nonatomic, assign) BOOL autoRefreshOnForeground;


/**
 Whether the app should automatically refresh oauth session every ~15 minutes
 while the app is running.
 */
@property (nonatomic, assign) BOOL autoRefreshPeriodically;

/**
 Forces a logout from the current account, redirecting the user to the login process.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 Kick off the login process.
 */
- (void)login;

/**
 Sent whenever the user has been logged in using current settings.
 Be sure to call super if you override this.
 */
- (void)loggedIn;

/**
 Resets the processes that perform periodic session refreshing.
 */
- (void)clearPeriodicRefreshState;

/**
 If auto refresh is configured, refresh the existing OAuth session.
 */
- (void)autoRefresh;

#pragma mark - Plugin exported to javascript

/**
 * PhoneGap plug-in method to obtain the current login credentials, authenticating if needed.
 * @param arguments PhoneGap arguments array, containing the OAuth configuration properties.
 * @param options Name/value pair options from PhoneGap, not used in this method.
 */
- (void)getAuthCredentials:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

/**
 * PhoneGap plug-in method to authenticate a user to the application.
 * @param arguments PhoneGap arguments array, containing the OAuth configuration properties.
 * @param options Name/value pair options from PhoneGap, not used in this method.
 */
- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

/**
 * Clear the current user's authentication credentials.
 * @param arguments Standard PhoneGap plugin arguments, not used in this method.
 * @param options Name/value pair options from PhoneGap, not used in this method.
 */
- (void)logoutCurrentUser:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

/**
 * Get the app's homepage URL, which can be used for loading the app in scenarios where it's offline.
 * @param arguments Standard PhoneGap plugin arguments, nominally used in this method.
 * @param options Name/value pair options from PhoneGap, not used in this method.
 */
- (void)getAppHomeUrl:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end
