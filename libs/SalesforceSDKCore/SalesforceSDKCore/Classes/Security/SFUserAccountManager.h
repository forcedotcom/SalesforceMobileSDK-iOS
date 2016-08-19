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

#import "SFUserAccount.h"
#import "SFOAuthCredentials.h"
#import "SFUserAccountIdentity.h"
#import "SFUserAccountConstants.h"

NS_ASSUME_NONNULL_BEGIN
/** Notification sent when something has changed with the current user
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerDidChangeCurrentUserNotification;

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 The value is a NSNumber that can be casted to the option SFUserAccountChange
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeKey;

/**
 Identifies the notification for the login host changing in the app's settings.
 */
FOUNDATION_EXTERN NSString * const kSFLoginHostChangedNotification;

/**
 The key for the original host in a login host change notification.
 */
FOUNDATION_EXTERN NSString * const kSFLoginHostChangedNotificationOriginalHostKey;

/**
 The key for the updated host in a login host change notification.
 */
FOUNDATION_EXTERN NSString * const kSFLoginHostChangedNotificationUpdatedHostKey;

@class SFUserAccountManager;

/**
 Protocol for handling callbacks from SFUserAccountManager.
 */
@protocol SFUserAccountManagerDelegate <NSObject>

@optional

/**
 Called before the user account manager switches from one user to another.
 @param userAccountManager The SFUserAccountManager instance making the switch.
 @param fromUser The user being switched away from.
 @param toUser The user to be switched to.  `nil` if the user context is being switched back
 to no user.
 */
- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(nullable SFUserAccount *)toUser;

/**
 Called after the user account manager switches from one user to another.
 @param userAccountManager The SFUserAccountManager instance making the switch.
 @param fromUser The user that was switched away from.
 @param toUser The user that was switched to.  `nil` if the user context is being switched back
 to no user.
 */
- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(nullable SFUserAccount *)toUser;

@end

/** Class used to manage the accounts functions used across the app.
 It supports multiple accounts and their associated credentials.
 */
@interface SFUserAccountManager : NSObject

/** The current user account.  This property may be nil if the user
 has never logged in.
 */
@property (nonatomic, strong, nullable) SFUserAccount *currentUser;

/** The user identity for the temporary user account.
 */
@property (nonatomic, readonly, nullable) SFUserAccountIdentity *temporaryUserIdentity;

/** The "temporary" account user.  Useful for determining whether there's a valid user context.
 */
@property (nonatomic, readonly, nullable) SFUserAccount *temporaryUser;

/** Returns YES if the application supports anonymous user, no otherwise.
 
 Note: the application must add the kSFUserAccountSupportAnonymousUsage value
 to its Info.plist file in order to enable this flag.
 */
@property (nonatomic, readonly) BOOL supportsAnonymousUser;

/** Returns YES if the application wants the anonymous user to be
  created automatically at startup, no otherwise.
  
  Note: the application must add the kSFUserAccountSupportAnonymousUsage value
  to its Info.plist file in order to enable this flag.
  */
@property (nonatomic, readonly) BOOL autocreateAnonymousUser;

/** Returns the anonymous user or nil if none exists
  */
@property (nonatomic, strong, readonly, nullable) SFUserAccount *anonymousUser;

/** Returns YES if the current user is anonymous, no otherwise
  */
@property (nonatomic, readonly, getter=isCurrentUserAnonymous) BOOL currentUserAnonymous;

/**  Convenience property to retrieve the current user's identity.
 */
@property (nonatomic, readonly, nullable) SFUserAccountIdentity *currentUserIdentity;

/**  Convenience property to retrieve the current user's communityId.
 This property is an alias for `currentUser.communityId`
 */
@property (nonatomic, readonly, nullable) NSString *currentCommunityId;

/** An NSArray of all the SFUserAccount instances for the app.
 */
@property (nonatomic, readonly) NSArray<SFUserAccount*> *allUserAccounts;

/** Returns all the user identities sorted by Org ID and User ID.
 */
@property (nonatomic, readonly) NSArray<SFUserAccountIdentity*> *allUserIdentities;

/** The most recently active user identity. Note that this may be temporarily
 different from currentUser if the user associated with the activeUserIdentity
 is removed from the accounts list.
 */
@property (nonatomic, copy, nullable) SFUserAccountIdentity *activeUserIdentity;

/** The most recently active community ID. Set when a user
 is changed and stored to disk for retrieval after bootup
 */
@property (nonatomic, copy, nullable) NSString *activeCommunityId;

/** A convenience property to store the previous community
 id as it may change during early OAuth flow and we want to retain it
 */
@property (nonatomic, strong, nullable) NSString *previousCommunityId;

/** The host that will be used for login.
 */
@property (nonatomic, strong, nullable) NSString *loginHost;

/** Should the login process start again if it fails (default: YES)
 */
@property (nonatomic, assign) BOOL retryLoginAfterFailure;

/** OAuth client ID to use for login.  Apps may customize
 by setting this property before login; otherwise, this
 value is determined by the SFDCOAuthClientIdPreference 
 configured via the settings bundle.
 */
@property (nonatomic, copy, nullable) NSString *oauthClientId;

/** OAuth callback url to use for the OAuth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main 
 bundle property SFDCOAuthRedirectUri
 default: @"sfdc:///axm/detect/oauth/done")
 */
@property (nonatomic, copy, nullable) NSString *oauthCompletionUrl;

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet<NSString*> *scopes;

/** Shared singleton
 */
+ (instancetype)sharedInstance;

/** Applies the current log level to the OAuth credentials that
 control the OAuth library log level.
 @param credentials OAuth credentials whose log level will be updated
 */
+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials;

/**
 Returns the path of the user account plist file for the specified user
 @param user The user
 @return the path to the user account plist of the specified user
 */
+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user;

/**
 Sets the active user identity without instantiating the class
 @param activeUserIdentity The desired active user
 */
+ (void)setActiveUserIdentity:(SFUserAccountIdentity *)activeUserIdentity;

/**
 Adds a delegate to this user account manager.
 @param delegate The delegate to add.
 */
- (void)addDelegate:(id<SFUserAccountManagerDelegate>)delegate;

/**
 Removes a delegate from this user account manager.
 @param delegate The delegate to remove.
 */
- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate;

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

/** This method ensures the anonymous user exists and if not, creates the anonymous
 user and saves it with the other users. This method doesn't change the current user.
 
 Note: this method is invoked automatically if `autocreateAnonymousUser` returns YES.
 */
- (void)enableAnonymousAccount;

/** Allows you to look up the user account associated with a given user identity.
 @param userIdentity The user identity of the user account to be looked up
 */
- (nullable SFUserAccount *)userAccountForUserIdentity:(SFUserAccountIdentity *)userIdentity;

/** Returns all accounts that have access to a particular org
 @param orgId The org to match accounts against
 @return An array of accounts that can access that org
 */
- (NSArray<SFUserAccount*> *)accountsForOrgId:(NSString *)orgId;

/** Returns all accounts that match a particular instance URL
 @param instanceURL The host parameter of a given instance URL
 @return An array of accounts that match that instance URL
 */
- (NSArray<SFUserAccount*> *)accountsForInstanceURL:(NSURL *)instanceURL;

/** Adds a user account
 @param acct The account to be added
 */
- (void)addAccount:(SFUserAccount *)acct;

/**
 Allows you to remove the given user account.
 @param user The user account to remove.
 @param error Output error parameter, populated if there was an error deleting
 the account (likely from the filesystem operations).
 @return YES if the deletion was successful, NO otherwise.  Note: If no persisted account matching
 the user parameter is found, no action will be taken, and deletion will be reported as successful.
 */
- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error;

/** Clear all the accounts state (but do not change anything on the disk).
 */
- (void)clearAllAccountState;

/** Invoke this method to apply the specified credentials to the
 current user. If no user exists, a new one is created.
 This will post user update notification.
 @param credentials The credentials to apply
 */
- (void)applyCredentials:(SFOAuthCredentials*)credentials;

/** Invoke this method to apply the specified id data to the
 current user. This will post user update notification.
 @param idData The ID data to apply
 */
- (void)applyIdData:(SFIdentityData *)idData;

/** This method will selectively update the custom attributes identity data for the current user.
 Other identity data will not be impacted.
 @param customAttributes The new custom attributes data to update in the identity data.
 */
- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes;

/** This method will selectively update the custom permissions identity data for the current user.
 Other identity data will not be impacted.
 @param customPermissions The new custom permissions data to update in the identity data.
 */
- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions;

/** Apply custom data to the SFUserAccount that can be
 accessed outside that user's sandbox. This data will be persisted
 between launches and should only be used for non-sensitive information.
 The NSDictionary should be NSCoder encodeable.
 @param object  The NScoding enabled object to set
 @param key     The key to retrieve this data for
 */
- (void)setObjectForCurrentUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key;
/**
 Switches away from the current user, to a new user context.
 */
- (void)switchToNewUser;

/**
 Switches away from the current user, to the given user account.
 @param newCurrentUser The user to switch to.
 */
- (void)switchToUser:(nullable SFUserAccount *)newCurrentUser;

/** Invoke this method to inform this manager
 that something has changed for the current user.
 @param change The type of change (enum type). Use SFUserAccountChangeUnknown
 if you don't know what kind of change was made to this object and this method
 will try to determine that.
 */
- (void)userChanged:(SFUserAccountChange)change;

@end

NS_ASSUME_NONNULL_END
