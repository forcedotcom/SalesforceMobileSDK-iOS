/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

@class SFOAuthCoordinator;
@class SFOAuthCredentials;
@class SFIdentityCoordinator;
@class SFIdentityData;

/**
 * Class used to manage a common account functions used across the app.
 */
@interface SFAccountManager : NSObject

/**
 * Returns the singleton instance of this class for the default account.
 */
+ (SFAccountManager *)sharedInstance;

/**
 * Returns the singleton instance of this class for the given account.
 * @param accountIdentifier The account identifier of the class.
 */
+ (SFAccountManager *)sharedInstanceForAccount:(NSString *)accountIdentifier;

/**
 * Wheher or not the Logout app setting is enabled.
 * @return YES if so, NO if not.
 */
+ (BOOL)logoutSettingEnabled;

/**
 * Makes sure that the app-level configuration for the login host has been populated with the
 * current value in the app settings of the app.
 */
+ (void)ensureAccountDefaultsExist;

/**
 * @return The configured login host for the app.
 */
+ (NSString *)loginHost;

/**
 * Sets a new value for the login host for the app.
 * @param newLoginHost The new host value to set.
 */
+ (void)setLoginHost:(NSString *)newLoginHost;

/**
 * Synchronizes the app-level login host setting with the value in app settings.
 * @return YES if the two values were initially different, NO otherwise.
 */
+ (BOOL)updateLoginHost;

/**
 * @return The OAuth client ID of the app.
 */
+ (NSString *)clientId;

/**
 * Sets a new value for the app's OAuth client ID.
 * @param newClientId The new value for the client ID.
 */
+ (void)setClientId:(NSString *)newClientId;

/**
 * @return The app's OAuth redirect URI.
 */
+ (NSString *)redirectUri;

/**
 * Sets a new value for the app's OAuth redirect URI.
 * @param newRedirectUri The new value for the app's OAuth redirect URI.
 */
+ (void)setRedirectUri:(NSString *)newRedirectUri;

/**
 * @return The OAuth scopes associated with the app.
 */
+ (NSSet *)scopes;

/**
 * Sets a new value for the OAuth scopes associated with the app.
 * @param newScopes The new value for the OAuth scopes of the app.
 */
+ (void)setScopes:(NSSet *)newScopes;

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData;

/**
 * Whether or not there is a mobile pin code policy configured for this app.
 * @return YES if so, NO if not.
 */
- (BOOL)mobilePinPolicyConfigured;

/**
 * The account identifier for a given account manager instance.
 */
@property (nonatomic, readonly) NSString *accountIdentifier;

/**
 * The OAuth Coordinator associated with this account.
 */
@property (nonatomic, retain) SFOAuthCoordinator *coordinator;

/**
 * The Identity Coordinator associated with this account.
 */
@property (nonatomic, retain) SFIdentityCoordinator *idCoordinator;

/**
 * The auth credentials maintained for this app.
 */
@property (nonatomic, retain) SFOAuthCredentials *credentials;

/**
 * The Identity data associated with this account.
 */
@property (nonatomic, retain) SFIdentityData *idData;

@end
