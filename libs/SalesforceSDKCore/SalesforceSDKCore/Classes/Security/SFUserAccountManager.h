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
#import "SalesforceSDKCoreDefines.h"
#import "SFUserAccount.h"
#import "SFOAuthCredentials.h"
#import "SFUserAccountIdentity.h"
#import "SFUserAccountConstants.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCoordinator.h"
#import "SFSDKLoginViewControllerConfig.h"
NS_ASSUME_NONNULL_BEGIN

/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFUserAccountManagerSuccessCallbackBlock)(SFOAuthInfo *, SFUserAccount *);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFUserAccountManagerFailureCallbackBlock)(SFOAuthInfo *, NSError *);

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

/**
  Default used as last resort
 */
FOUNDATION_EXTERN NSString * const kSFUserAccountOAuthLoginHostDefault;

/**
 Key identifying login host
 */
FOUNDATION_EXTERN NSString * const kSFUserAccountOAuthLoginHost;

/**
 The key for storing the persisted OAuth scopes.
 */
FOUNDATION_EXTERN  NSString * const kOAuthScopesKey;

/**
The key for storing the persisted OAuth client ID.
 */
FOUNDATION_EXTERN  NSString * const kOAuthClientIdKey;

/**
The key for storing the persisted OAuth redirect URI.
 */
FOUNDATION_EXTERN  NSString * const kOAuthRedirectUriKey;

/** Notification sent prior to user logout
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserWillLogout;

/** Notification sent after user logout
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserDidLogout;

/** Notification sent when all users of org have logged off.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationOrgDidLogout;

/** Notification sent prior to display of Auth View
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserWillShowAuthView;

/** Notification sent when user cancels authentication
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserCanceledAuth;

/** Notification sent prior to user log in
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserWillLogIn;

/** Notification sent after user log in
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserDidLogIn;

/**  Notification sent before SP APP invokes IDP APP for authentication
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserWillSendIDPRequest;

/**  Notification sent before IDP APP invokes SP APP with auth code
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserWillSendIDPResponse;

/**  Notification sent when  IDP APP receives request for authentication from SP APP
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserDidReceiveIDPRequest;

/**  Notification sent when  SP APP receives successful response of authentication from IDP APP
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserDidReceiveIDPResponse;

/**  Notification sent when  SP APP has log in  is successful when initiated from IDP APP
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserIDPInitDidLogIn;

/**  Key to use to lookup userAccount associated with  NSNotification userInfo
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAccountKey;

/**  Key to use to lookup credentials associated with  NSNotification userInfo
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoCredentialsKey;

/**  Key to use to lookup authinfo type associated with  NSNotification userInfo
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAuthTypeKey;

/**  Key to use to lookup dictionary of nv-pairs type associated with NSNotification userInfo
 */
FOUNDATION_EXTERN NSString * const kSFUserInfoAddlOptionsKey;

/**  Key to use to lookup SFNotificationUserInfo object in Notitications dictionary
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoKey;

@protocol SFSDKOAuthClientDelegate;
@protocol SFSDKOAuthClientSafariViewDelegate;
@protocol SFSDKOAuthClientWebViewDelegate;
@protocol SFSDKIDPAuthClientDelegate;

@class SFUserAccountManager;
@class SFSDKAlertMessage;
@class SFSDKWindowContainer;
@class SFSDKAuthViewHandler;

/**
 Protocol for handling callbacks from SFUserAccountManager.
 */
@protocol SFUserAccountManagerDelegate <NSObject>


@optional
/**
 Called when the account manager wants to determine if the network is available.
 @param userAccountManager The instance of SFUserAccountManager making the call.
 @return YES if the network is available, NO otherwise
 */
- (BOOL)userAccountManagerIsNetworkAvailable:(SFUserAccountManager *)userAccountManager;

/**
 *
 * @param userAccountManager The instance of SFUserAccountManager
 * @param error The Error that occurred
 * @param info  The info for the auth request
 * @return YES if the error has been handled by the delegate. SDK will attempt to handle the error if the result is NO.
 */
- (BOOL)userAccountManager:(SFUserAccountManager *)userAccountManager error:(NSError*)error info:(SFOAuthInfo *)info;

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

/** User Information for post logout notifications.
 */
@interface SFNotificationUserInfo : NSObject
@property (nonatomic,readonly) SFUserAccountIdentity *accountIdentity;
@property (nonatomic, readonly, nullable) NSString *communityId;
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

/**
 Returns YES if the logout is requested by the app settings.
 */
@property (nonatomic, readonly) BOOL logoutSettingEnabled;

/**
 Advanced authentication configuration.  Default is SFOAuthAdvancedAuthConfigurationNone.  Leave the
 default value unless you need advanced authentication, as it requires an additional round trip to the
 service to retrieve org authentication configuration.
 */
@property (nonatomic, assign) SFOAuthAdvancedAuthConfiguration advancedAuthConfiguration;

/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray * additionalOAuthParameterKeys;

/**
 A dictionary of additional parameters (key value pairs) to send during token refresh
 */
@property (nonatomic, strong) NSDictionary * additionalTokenRefreshParams;

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
@property (nonatomic, copy) NSString *oauthClientId;

/** OAuth callback url to use for the OAuth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main
 bundle property SFDCOAuthRedirectUri
 default: @"sfdc:///axm/detect/oauth/done")
 */
@property (nonatomic, copy) NSString *oauthCompletionUrl;

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, nullable, copy) NSString *brandLoginPath;

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet<NSString*> *scopes;

/**  Convenience property to retrieve the current user's identity.
 */
@property (readonly, nonatomic, nullable) SFUserAccountIdentity *currentUserIdentity;

/** Use this block to replace the Login flow selection dialog
 *
 */
@property (nonatomic, copy, nullable) SFIDPLoginFlowSelectionBlock idpLoginFlowSelectionAction;

/** Use this to replace the default User Selection Screen
 *
 */
@property (nonatomic, copy, nullable) SFIDPUserSelectionBlock idpUserSelectionAction;

/**  Use this property to enable an app to become and IdentityProvider for other apps
 *
 */
@property (nonatomic,assign) BOOL isIdentityProvider;

/**  Use this property to enable this app to be able to use another app that is an Identity Provider
 *
 */
@property (nonatomic,assign, readonly) BOOL idpEnabled;

/** Use this property to use SFAuthenticationManager for authentication
 *
 */
@property (nonatomic,assign) BOOL useLegacyAuthenticationManager;

/** Use this property to indicate the url scheme  for the Identity Provider app
 *
 */
@property (nonatomic, copy) NSString *idpAppURIScheme;

/** Use this property to indicate to provide a user-friendly name for your app. This name will be displayed
 *  in the user selection view of the identity provider app.
 *
 */
@property (nonatomic,copy) NSString *appDisplayName;

/** Use this property to indicate to provide LoginViewController customizations for themes,navbar and settigs icon.
 *
 */
@property (nonatomic,strong) SFSDKLoginViewControllerConfig *loginViewControllerConfig;

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

/** Returns all accounts that match a domain
 @param domain The domain.
 @return An array of accounts that match that instance URL
 */
- (NSArray *)userAccountsForDomain:(NSString *)domain;

/** Adds/Updates a user account
 @param userAccount The account to be added
 */
- (BOOL)saveAccountForUser:(SFUserAccount *)userAccount error:(NSError **) error;

/** Lookup  a user account
 @param credentials used to  up Account matching the credentials
 */
- (nullable SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials;

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
- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(nullable SFIdentityData *) identityData andNotification:(BOOL) shouldSendNotification;


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

/**
 Kick off the login process for credentials that's previously configured.
 @param completionBlock The block of code to execute when the authentication process successfully completes.
 @param failureBlock The block of code to execute when the authentication process has a fatal failure.
 @return YES if this call kicks off the authentication process.  NO if an authentication process has already
 started, in which case subsequent requests are queued up to have their completion or failure blocks executed
 in succession.
 */
- (BOOL)loginWithCompletion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                    failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock;

/**
 Kick off the refresh process for the specified credentials.
 @param credentials SFOAuthCredentials to be refreshed.
 @param completionBlock The block of code to execute when the refresh process successfully completes.
 @param failureBlock The block of code to execute when the refresh process has a fatal failure.
 @return YES if this call kicks off the authentication process.  NO if an authentication process has already
 started, in which case subsequent requests are queued up to have their completion or failure blocks executed
 in succession.
 */
- (BOOL)refreshCredentials:(nonnull SFOAuthCredentials *)credentials
                completion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                   failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock;

/**
 Login using the given JWT token to exchange with the service for credentials.
 @param jwtToken The JWT token (received out of band) to exchange for credentials.
 @param completionBlock The block of code to execute when the authentication process successfully completes.
 @param failureBlock The block of code to execute when the authentication process has a fatal failure.
 @return YES if this call kicks off the authentication process.  NO if an authentication process has already
 started, in which case subsequent requests are queued up to have their completion or failure blocks executed
 in succession.
 */
- (BOOL)loginWithJwtToken:(NSString *)jwtToken
               completion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                  failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock;

/**
 Forces a logout from the current account, redirecting the user to the login process.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 Performs a logout on the specified user.  Note that if the user is not the current user of the app, the
 specified user's authenticated state will be removed, but no other action will otherwise interrupt the
 current app state.
 @param user The user to log out.
 */
- (void)logoutUser:(SFUserAccount *)user;

/**
 Performs a logout for all users of the app, including the current user.
 */
- (void)logoutAllUsers;

/**
 Dismisses the auth view controller, resetting the UI state back to its original
 presentation.
 */
- (void)dismissAuthViewControllerIfPresent;

/**
 Handle an advanced authentication response from the external browser, continuing any
 in-progress adavanced authentication flow.
 @param appUrlResponse The URL response returned to the app from the external browser.
 @options Dictionary of name-value pairs received from open URL
 @return YES if this is a valid URL response from advanced authentication that should
 be handled, NO otherwise.
 */
- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse options:(NSDictionary *)options;

/**
 Set this block to handle presentation of the Authentication View Controller.
 */
@property (nonatomic, strong) SFSDKAuthViewHandler *authViewHandler;

/**
 Change this block to handle all alerts  required by the SFUserAccountManager.
 */
@property (nonatomic, copy, nonnull) void (^alertDisplayBlock)(SFSDKAlertMessage *,SFSDKWindowContainer *);

/**
 Change this block to customize behavior for user initiated auth cancellation
 */
@property (nonatomic, copy, nonnull) void (^authCancelledByUserHandlerBlock)(void);

/**
 Determines whether an error is due to invalid auth credentials.
 @param error The error to check against an invalid credentials error.
 @return YES if the error is due to invalid credentials, NO otherwise.
 */
+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
