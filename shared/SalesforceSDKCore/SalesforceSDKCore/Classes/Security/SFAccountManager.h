/*
 Copyright (c) 2012-2013, salesforce.com, inc. All rights reserved.
 
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
#import "SFIdentityCoordinator.h"

@class SFOAuthCredentials;
@class SFIdentityData;

#warning TODO this class is not enabled for this project but should be removed once the SFUserAccountManager is done and reviewed.

/** The default account identifier for the account manager.
 */
extern NSString *const SFDefaultAccountIdentifier;

/**
 * Class used to manage common account functions used across the app.
 */
@interface SFAccountManager : NSObject <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate>

/**
 * Returns the singleton instance of this class for the currently configured account.
 * @see currentAccountIdentifier
 */
+ (SFAccountManager *)sharedInstance;

/**
 * Returns the singleton instance of this class for the given account.
 * @param accountIdentifier The account identifier of the class.
 */
+ (SFAccountManager *)sharedInstanceForAccount:(NSString *)accountIdentifier;

/**
 * @return The account identifier associated with the current application.
 */
+ (NSString *)currentAccountIdentifier;

/**
 * Sets (copies) the current account identifier for the application.  There's really only
 * one active account identifier for the lifetime of the running application.
 */
+ (void)setCurrentAccountIdentifier:(NSString *)newAccountIdentifier;

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
 *
 * NOTE: Be careful using this method.  The default behavior of the app is to make a determination
 * about login host from the app settings of the application, based on the user's configuration.
 * There are normally many changes around app state that happen on the boundary of changing to a
 * different login host, and if you use this method, you're responsible for managing that state
 * change.  Make sure you know what you're doing before calling this method.
 *
 * @param newLoginHost The new host value to set.
 */
+ (void)setLoginHost:(NSString *)newLoginHost;

/**
 * Synchronizes the app-level login host setting with the value in app settings.
 * @return SFLoginHostUpdateResult object containing the original hostname, the new hostname
 * (possibly the same), and whether or not the hostname changed.
 */
+ (SFLoginHostUpdateResult *)updateLoginHost;

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
 * The auth credentials maintained for this app.
 */
@property (nonatomic, strong) SFOAuthCredentials *credentials;

@end
