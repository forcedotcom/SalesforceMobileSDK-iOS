/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

/**Notification sent when user has been created or is set as current User
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerDidChangeUserNotification;

/** Notification sent when something has changed with the current user
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerDidChangeUserDataNotification;

/** Notification sent when something user init has finished
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerDidFinishUserInitNotification;

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 The value is a NSNumber that can be casted to the option SFUserAccountChange
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeKey;

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeUserKey;

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

@protocol SFUserAccountPersister <NSObject>

/**
 Called when the Account manager requires to save the state of an account.
 @param userAccount The instance of SFUserAccount making the call.
 @param  error On output, the error if the return value is NO
 @return YES if the account was saved properly, NO in case of error
 */
- (BOOL)saveAccountForUser:(SFUserAccount *)userAccount error:(NSError **) error;

/** Fetches all the accounts.
  @param error On output, the error if the return value is NO
  @return NSDictionary with SFUserAccountIdentity as keys and SFUserAccount as values
  */
- (NSDictionary<SFUserAccountIdentity *,SFUserAccount *> *)fetchAllAccounts:(NSError **)error;

/**
 Allows you to remove the given user account.
 @param user The user account to remove.
 @param error Output error parameter, populated if there was an error deleting
 the account (likely from the filesystem operations).
 @return YES if the deletion was successful, NO otherwise.  Note: If no persisted account matching
 the user parameter is found, no action will be taken, and deletion will be reported as successful.
 */
- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error;

@end


/** Class used to manage the accounts functions used across the app.
 It supports multiple accounts and their associated credentials.
 */
@interface SFUserAccountManager : NSObject

/** The current user account.  This property may be nil if the user
 has never logged in.
 */
@property (nonatomic, strong, nullable) SFUserAccount *currentUser;

/** Returns YES if the current user is anonymous, no otherwise
  */
@property (nonatomic, readonly, getter=isCurrentUserAnonymous) BOOL currentUserAnonymous;

/**  Convenience property to retrieve the current user's identity.
 */
@property (readonly, nonatomic, nullable) SFUserAccountIdentity *currentUserIdentity;

/** Shared singleton
 */
+ (instancetype)sharedInstance;

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

/** An NSArray of all the SFUserAccount instances for the app.
 */
- (nullable NSArray <SFUserAccount *> *) allUserAccounts;

/** Returns all the user identities sorted by Org ID and User ID.
 */
- (nullable NSArray<SFUserAccountIdentity*> *) allUserIdentities;

/** Create an account when necessary using the credentials provided.
  @param credentials The credentials to use.
 */
- (SFUserAccount*)createUserAccount:(SFOAuthCredentials *)credentials;


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

/** Adds/Updates a user account
 @param userAccount The account to be added
 */
- (BOOL)saveAccountForUser:(SFUserAccount *)userAccount error:(NSError **) error;

/** Lookup  a user account
 @param credentials used to  up Account matching the credentials
 */
- (SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials;

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
 a user whose credentials match. If no user exists, a new one is created. Fire notifications.
 This will post user update notification.
 @param credentials The credentials to apply
 */
- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials;

/** Invoke this method to apply the specified credentials to the
 a user whose credentials match. If no user exists, a new one is created. Fire notifications.
 This will post user update notification.
 @param credentials The credentials to apply
 @param identityData The identityData to apply
 */
- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(nullable SFIdentityData *) identityData;

/** Invoke this method to apply the specified credentials to the
 a user whose credentials match. If no user exists, a new one is created.
 This will post user update notification.
 @param credentials The credentials to apply
 @param identityData The identityData to apply
 @param shouldSendNotification whether to post notifications.
 */
- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(SFIdentityData *) identityData andNotification:(BOOL) shouldSendNotification;


/** Invoke this method to apply the specified id data to the
  user. This will post user update notification.
  @param idData The ID data to apply
  @param user The SFUserAccount to apply this change to.
 */
- (void)applyIdData:(SFIdentityData *)idData forUser:(SFUserAccount *)user;

/** This method will selectively update the custom attributes identity data for the  user.
 Other identity data will not be impacted.
 @param customAttributes The new custom attributes data to update in the identity data.
 @param user The SFUserAccount to apply this change to.
 */
- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes forUser:(SFUserAccount *)user;

/** This method will selectively update the custom permissions identity data for the  user.
 Other identity data will not be impacted.
 @param customPermissions The new custom permissions data to update in the identity data.
 @param user The SFUserAccount to apply this change to.
 */
- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions forUser:(SFUserAccount *)user;

/** Apply custom data to the SFUserAccount that can be
 accessed outside that user's sandbox. This data will be persisted
 between launches and should only be used for non-sensitive information.
 The NSDictionary should be NSCoder encodeable.
 @param object  The NScoding enabled object to set
 @param key     The key to retrieve this data for
 @param user The SFUserAccount to apply this change to.
 */
- (void)setObjectForUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key andUser:(SFUserAccount *)user;
/**
 Switches away from the current user, to a new user context.
 */
- (void)switchToNewUser;

/**
 Switches away from the current user, to the given user account.
 @param newCurrentUser The user to switch to.
 */
- (void)switchToUser:(nullable SFUserAccount *)newCurrentUser;

/** Invoke this method to inform this manager that something has changed for the  user.
 @param user  The user
 @param change The type of change (enum type). Use SFUserAccountDataChange.
 */
- (void)userChanged:(SFUserAccount *)user change:(SFUserAccountDataChange)change;



@end

NS_ASSUME_NONNULL_END
