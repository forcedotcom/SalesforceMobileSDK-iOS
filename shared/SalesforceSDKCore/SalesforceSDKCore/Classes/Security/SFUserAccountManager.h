/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import "SFIdentityCoordinator.h"
#import "SFAuthenticationManager.h"

/** Notification sent when the current user credentials have changed
 */
extern NSString * const SFUserAccountManagerDidUpdateCredentialsNotification;

/** Notification sent when a new user has been created
 */
extern NSString * const SFUserAccountManagerDidCreateUserNotification;

// The default temporary user ID
extern NSString * const SFUserAccountManagerDefaultUserAccountId;

/**
 Identifies the notification for the login host changing in the app's settings.
 */
extern NSString * const kSFLoginHostChangedNotification;

/**
 The key for the original host in a login host change notification.
 */
extern NSString * const kSFLoginHostChangedNotificationOriginalHostKey;

/**
 The key for the updated host in a login host change notification.
 */
extern NSString * const kSFLoginHostChangedNotificationUpdatedHostKey;

// Key containing the user id in the notification userInfo dictionary for SFUserAccountManagerDidCreateUserNotification
extern NSString * const SFUserAccountManagerUserIdKey;

// Key containing the user account in the notification userInfo dictionary for SFUserAccountManagerCurrentUserDidChangeNotification
extern NSString * const SFUserAccountManagerUserAccountKey;

@class SFUserAccount;
@class SFUserAccountManager;

/** Class used to manage the accounts functions used across the app.
 It supports multiple accounts and their associated credentials.
 */
@interface SFUserAccountManager : NSObject

/** The current user account.  This property may be nil if the user
 has never logged in.
 */
@property (nonatomic, strong) SFUserAccount *currentUser;

/**  Convenience property to retrieve the current user's ID.
 This property is an alias for `currentUser.credentials.userId`
 */
@property (nonatomic, readonly) NSString *currentUserId;

/**  Convenience property to retrieve the current user's communityId.
 This property is an alias for `currentUser.communityId`
 */
@property (nonatomic, readonly) NSString *currentCommunityId;

/** Returns all the user ids
 */
@property (nonatomic, readonly) NSArray *allUserIds;

/** The most recently active user ID.
 Note that this may be temporarily different from currentUser if the user with
 ID activeUserId is removed from the accounts list. 
 */
@property (nonatomic, copy) NSString *activeUserId;

/** The host that will be used for login.
 */
@property (nonatomic, strong) NSString *loginHost;

/** Should the login process start again if it fails (default: YES)
 */
@property (nonatomic, assign) BOOL retryLoginAfterFailure;

/** Oauth client ID to use for login.  Apps may customize
 by setting this property before login; otherwise, this
 value is determined by the SFDCOAuthClientIdPreference 
 configured via the settings bundle.
 */
@property (nonatomic, copy) NSString *oauthClientId;

/** Oauth callback url to use for the oauth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main 
 bundle property SFDCOAuthRedirectUri
 default: @"sfdc:///axm/detect/oauth/done")
 */
@property (nonatomic, copy) NSString *oauthCompletionUrl;

/** Shared singleton
 */
+ (instancetype)sharedInstance;

/** Applies the current log level to the oauth credentials that
 controls the oauth library log level.
 */
+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials;

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
 * @return The app's OAuth redirect URI.
 */
+ (NSString *)redirectUri;

/**
 * Sets a new value for the app's OAuth redirect URI.
 * @param newRedirectUri The new value for the app's OAuth redirect URI.
 */
+ (void)setRedirectUri:(NSString *)newRedirectUri;

/**
 * @return The OAuth client ID of the app.
 */
+ (NSString *)clientId;

/**
 * Sets a new value for the app's OAuth client ID.
 * @param newClientId The new value for the client ID.
 */
+ (void)setClientId:(NSString *)newClientId;

/** Loads all the accounts.
 */
- (void)loadAccounts;

/** Save all the accounts.
 */
- (void)saveAccounts;

/** Can be used to create an empty user account if you wish to configure all of the account info yourself.
 Otherwise, use `login` to allow SFUserAccountManager to automatically create an account when necessary.
 */
- (SFUserAccount*)createUserAccount;

/** Allows you to lookup the user account associated with a given user ID.
 */
- (SFUserAccount*)userAccountForUserId:(NSString*)userId;

/** Adds a user account
 */
- (void)addAccount:(SFUserAccount *)acct;

/** Allows you to remove a user account associated with the given user ID.
 */
- (void)deleteAccountForUserId:(NSString*)userId;

/** Truncate user ID to 15 chars
 */
- (NSString *)makeUserIdSafe:(NSString*)aUserId;

/** Invoke this method to apply the specified credentials to the
 current user. If no user exists, a new one is created.
 @param credentials The credentials to apply
 */
- (void)applyCredentials:(SFOAuthCredentials*)credentials;

/** Invoke this method to inform this manager
 that the user credentials have changed.
 */
- (void)userCredentialsChanged;

@end
