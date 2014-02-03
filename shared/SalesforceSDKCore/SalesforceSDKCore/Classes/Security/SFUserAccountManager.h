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

/** Flags controlling specifics of the logout process
 */
typedef NS_ENUM(NSUInteger, SFUserAccountLogoutFlags) {
    SFUserAccountLogoutFlagNone = 0,
    
    /** Flag indicating that the user's activation code should not be revoked on logout.
     */
    SFUserAccountLogoutFlagPreserveActivationCode
};

// The various notifications
extern NSString * const SFUserAccountManagerCurrentUserDidChangeNotification;
extern NSString * const SFUserAccountManagerDidCreateUserNotification;
extern NSString * const SFUserAccountManagerDidLoadNotification;
extern NSString * const SFUserAccountManagerDidSaveNotification;
extern NSString * const SFUserAccountManagerWillOpenLoginViewNotification;
extern NSString * const SFUserAccountManagerDidLoginNotification;
extern NSString * const SFUserAccountManagerWillLogoutNotification;
extern NSString * const SFUserAccountManagerDidLogoutNotification;
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

/*!
 Allows you to configure the appearance of UI elements related to login
 */
@protocol SFUserAccountManagerDelegate<NSObject>

@optional

/*!
 Called whenever the manager starts the login process. 
 */
- (void)userAccountManagerWillBeginLogin:(SFUserAccountManager*)accountManager;

/*!
 Called whenever the manager completes a login (with or without error).
 */
- (void)userAccountManagerHandleLoginCompletion:(SFUserAccountManager*)accountManager withError:(NSError*)errorOrNil;

/*!
 Called whenever the manager wants to present a web view containing the login screen.
 */
- (void)userAccountManager:(SFUserAccountManager*)accountManager shouldDisplayWebView:(UIWebView*)webView;

/*!
 Called when the web view starts to load its content.
 */
- (void)userAccountManagerDidStartLoad:(SFUserAccountManager*)accountManager;

/*!
 Called when the web view finishes to load its content.
 */
- (void)userAccountManagerDidFinishLoad:(SFUserAccountManager*)accountManager;

/*!
 Called when the user credentials have changed
 */
- (void)userAccountManagerDidUpdateCredentials:(SFUserAccountManager*)accountManager;

/**
 The delegate can implement this method to return a BOOL indicating if the network is available or not
 */
- (BOOL)userAccountManagerIsNetworkAvailable:(SFUserAccountManager*)accountManager;

@end

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

/** Do we have a current valid Salesforce session?
 You may use KVO in your app to monitor session validity.
 */
@property (nonatomic, readonly) BOOL haveValidSession;

/**
 * Whether or not there is a mobile pin code policy configured for this app.
 * @return YES if so, NO if not.
 */
@property (nonatomic, readonly) BOOL mobilePinPolicyConfigured;

/**
 * The OAuth Coordinator associated with the current account.
 */
@property (nonatomic, strong) SFOAuthCoordinator *coordinator;

/**
 * The Identity Coordinator associated with the current account.
 */
@property (nonatomic, strong) SFIdentityCoordinator *idCoordinator;

/**
 * Allows the consumer to set its OAuth delegate for handling authentication responses.
 */
@property (nonatomic, weak) id<SFOAuthCoordinatorDelegate> oauthDelegate;

/**
 * Allows the consumer to set its Identity delegate for handling identity responses.
 */
@property (nonatomic, strong) id<SFIdentityCoordinatorDelegate> idDelegate;

/** Shared singleton
 */
+ (instancetype)sharedInstance;

/** Applies the current log level to the oauth credentials that
 controls the oauth library log level.
 */
+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials;

/** Default identifier used for initializing SFUserAccount credentials
 */
+ (NSString *)defaultClientIdentifier;

/**
 * @return The OAuth scopes associated with the app.
 */
+ (NSSet *)scopes;

/**
 * Sets a new value for the OAuth scopes associated with the app.
 * @param newScopes The new value for the OAuth scopes of the app.
 */
+ (void)setScopes:(NSSet *)newScopes;

/** Registers a new delegate
 */
- (void)addDelegate:(id<SFUserAccountManagerDelegate>)delegate;

/** Removes a previously registered delegate
 */
- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate;

/** Main login method. Typically if you don't care about managing account creation yourself, you can simply call this
 when your app is foregrounded to ensure that you have a current Salesforce session ID.
 */
- (void)login;

/** Use this method only if you wish to select which user account is used for login;
 otherwise, use `login`.
 
 @param account User account to use for the login, overwriting any existing current user login.
 */
- (void)loginWithAccount:(SFUserAccount*)account;

/** Revokes the current user's credentials and activation code and resets the client ID to the default value.
 */
- (void)logout;

/** Revokes the current user's credentials, resets the client ID to the default value, and may perform other functions
 based on the flags specified.
 @param flags used to control specific aspects of the logout
 */
- (void)logout:(SFUserAccountLogoutFlags)flags;

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

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData;

/** Call this method if you wish to refresh the current user's session ID.
 This causes immediate expiration of the current user's session.
 */
- (void)requestSessionRefresh;

/** Expire both the current session ID as well as any refresh token etc that we may have persisted
 */
- (void)expireAuthenticationInfo;

/** Call this method to apply the activation code. The activation code
 is not going to be persisted in this account manager (but it will be
 in the user credentials managed by the OAuth library).
 */
- (void)applyActivationCode:(NSString*)activationCode;

/** Truncate user ID to 15 chars
 */
- (NSString *)makeUserIdSafe:(NSString*)aUserId;

/**
 * Evaluates an NSError object to see if it represents a network failure during
 * an attempted connection.
 * @param error The NSError to evaluate.
 * @return YES if the error represents a network failure, NO otherwise.
 */
+ (BOOL)errorIsNetworkFailure:(NSError *)error;

@end
