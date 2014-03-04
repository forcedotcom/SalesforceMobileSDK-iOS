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
#import "SFUserAccountConstants.h"

/** Notification sent when something has changed with the current user
 */
extern NSString * const SFUserAccountManagerDidChangeCurrentUserNotification;

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 The value is a NSNumber that can be casted to the option SFUserAccountChange
 */
extern NSString * const SFUserAccountManagerUserChangeKey;

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

// The default temporary user ID
extern NSString * const SFUserAccountManagerTemporaryUserAccountId;

/**
 * Data class for providing information about a login host change.
 */
@interface SFLoginHostUpdateResult : NSObject

/**
 * The original login host, prior to the change.
 */
@property (nonatomic, readonly) NSString *originalLoginHost;

/**
 * The updated (new) login host, after the change.
 */
@property (nonatomic, readonly) NSString *updatedLoginHost;

/**
 * Whether or not the login host actually changed.
 */
@property (nonatomic, readonly) BOOL loginHostChanged;

/**
 * Designated intializer for the data object.
 * @param originalLoginHost The login host prior to change.
 * @param updatedLoginHost The new login host after the change.
 * @param loginHostChanged Whether or not the login host actually changed.
 */
- (id)initWithOrigHost:(NSString *)originalLoginHost
           updatedHost:(NSString *)updatedLoginHost
           hostChanged:(BOOL)loginHostChanged;

@end

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

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet *scopes;

/** Shared singleton
 */
+ (instancetype)sharedInstance;

/** Applies the current log level to the oauth credentials that
 controls the oauth library log level.
 */
+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials;

/**
 Returns the path of the user account plist file for the specified user
 @param user The user
 @return the path to the user account plist of the specified user
 */
+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user;

/**
 * Synchronizes the app-level login host setting with the value in app settings.
 * @return SFLoginHostUpdateResult object containing the original hostname, the new hostname
 * (possibly the same), and whether or not the hostname changed.
 */
- (SFLoginHostUpdateResult *)updateLoginHost;

/** Loads all the accounts.
 @param error On output, the error if the return value is NO
 @return YES if the accounts were loaded properly, NO in case of error
 */
- (BOOL)loadAccounts:(NSError**)error;

/** Save all the accounts.
 @param error On output, the error if the return value is NO
 @return YES if the accounts were saved properly, NO in case of error
 */
- (BOOL)saveAccounts:(NSError**)error;

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

/** Clear all the accounts state (but do not change anything on the disk).
 */
- (void)clearAllAccountState;

/** Truncate user ID to 15 chars
 */
- (NSString *)makeUserIdSafe:(NSString*)aUserId;

/** Invoke this method to apply the specified credentials to the
 current user. If no user exists, a new one is created.
 @param credentials The credentials to apply
 */
- (void)applyCredentials:(SFOAuthCredentials*)credentials;

/** Invoke this method to inform this manager
 that something has changed for the current user.
 @param change The type of change (enum type). Use SFUserAccountChangeUnknown
 if you don't know what kind of change was made to this object and this method
 will try to determine that.
 */
- (void)userChanged:(SFUserAccountChange)change;

@end
