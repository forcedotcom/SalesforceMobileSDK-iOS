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
#import <SalesforceSDKCore/SalesforceSDKCoreDefines.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SFUserAccountIdentity.h>
#import <SalesforceSDKCore/SFUserAccountConstants.h>
#import <SalesforceSDKCore/SFOAuthCoordinator.h>
#import <SalesforceSDKCore/SFOAuthCoordinator.h>
#import <SalesforceSDKCore/SFSDKLoginViewControllerConfig.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Callback block definition for OAuth completion callback.
 */
typedef id<SFSDKOAuthProtocol> __nonnull (^SFAuthClientFactoryBlock)(void);

/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFUserAccountManagerSuccessCallbackBlock)(SFOAuthInfo *, SFUserAccount *) NS_SWIFT_NAME(AccountManagerSuccessCallbackBlock);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFUserAccountManagerFailureCallbackBlock)(SFOAuthInfo *, NSError *) NS_SWIFT_NAME(AccountManagerFailureCallbackBlock);

/**Notification sent when user has been created or is set as current User. In swift access this constant using Notification.Name.SFUserAccountManagerDidChangeUser
 */
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidChangeUserNotification NS_SWIFT_NAME(UserAccountManager.didChangeUser);

/** Notification sent when something has changed with the current user. In swift access this constant using Notification.Name.SFUserAccountManagerDidChangeUserData
 */
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidChangeUserDataNotification NS_SWIFT_NAME(UserAccountManager.didChangeUserData);

/** Notification sent when something user init has finished. In swift access this constant using Notification.Name.SFUserAccountManagerDidFinishUserInit
 */
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidFinishUserInitNotification NS_SWIFT_NAME(UserAccountManager.didFinishUserInit);

/** Notification sent prior to user logout. In swift access this constant using Notification.Name.SFUserAccountManagerWillLogoutUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillLogout NS_SWIFT_NAME(UserAccountManager.willLogoutUser);

/** Notification sent after user logout. In swift access this constant using Notification.Name.SFUserAccountManagerDidLogoutUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidLogout NS_SWIFT_NAME(UserAccountManager.didLogoutUser);

/** Notification sent prior to user switch. In swift access this constant using Notification.Name.SFUserAccountManagerWillSwitchUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSwitch NS_SWIFT_NAME(UserAccountManager.willSwitchUser);

/** Notification sent after user switch. In swift access this constant using Notification.Name.SFUserAccountManagerDidSwitchUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidSwitch NS_SWIFT_NAME(UserAccountManager.didSwitchUser);

/** Notification sent after user switch. In swift access this constant using Notification.Name.didChangeLoginHost
*/
FOUNDATION_EXTERN NSNotificationName kSFNotificationDidChangeLoginHost  NS_SWIFT_NAME(UserAccountManager.didChangeLoginHost);
/** Notification sent when all users of org have logged off. In swift access this constant using Notification.Name.SFUserAccountManagerDidLogoutOrg
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationOrgDidLogout NS_SWIFT_NAME(UserAccountManager.didLogoutOrg);

/** Notification sent when a oauth refresh flow succeeds.
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidRefreshToken  NS_SWIFT_NAME(UserAccountManager.didRefreshToken);

/** Notification sent prior to display of Auth View. In swift access this constant using Notification.Name.SFUserAccountManagerWillShowAuthenticationView
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillShowAuthView NS_SWIFT_NAME(UserAccountManager.willShowAuthenticationView);

/** Notification sent when user cancels authentication. In swift access this constant using Notification.Name.SFUserAccountManagerUserCancelledAuthentication
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserCancelledAuth NS_SWIFT_NAME(UserAccountManager.userCancelledAuthentication);

/** Notification sent prior to user log in. In swift access this constant using Notification.Name.SFUserAccountManagerWillLogInUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillLogIn NS_SWIFT_NAME(UserAccountManager.willLogInUser);

/** Notification sent after user log in. In swift access this constant using Notification.Name.SFUserAccountManagerDidLogInUser
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidLogIn NS_SWIFT_NAME(UserAccountManager.didLogInUser);

/**  Notification sent before SP APP invokes IDP APP for authentication. In swift access this constant using Notification.Name.SFUserAccountManagerWillSendIDPRequest
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSendIDPRequest NS_SWIFT_NAME(UserAccountManager.willSendIDPRequest);

/**  Notification sent before IDP APP invokes SP APP with auth code. In swift access this constant using Notification.Name.SFUserAccountManagerWillSendIDPResponse
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSendIDPResponse NS_SWIFT_NAME(UserAccountManager.willSendIDPResponse);

/**  Notification sent when  IDP APP receives request for authentication from SP APP. In swift access this constant using Notification.Name.SFUserAccountManagerDidReceiveIDPRequest
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidReceiveIDPRequest NS_SWIFT_NAME(UserAccountManager.didReceiveIDPRequest);

/**  Notification sent when  SP APP receives successful response of authentication from IDP APP. In swift access this constant using Notification.Name.SFUserAccountManagerDidReceiveIDPResponse
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidReceiveIDPResponse NS_SWIFT_NAME(UserAccountManager.didReceiveIDPResponse);

/**  Notification sent when  SP APP has log in  is successful when initiated from IDP APP. In swift access this constant using Notification.Name.SFUserAccountManagerDidLogInAfterIDPInit
 */
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserIDPInitDidLogIn  NS_SWIFT_NAME(UserAccountManager.didLogInAfterIDPInit);

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 The value is a NSNumber that can be casted to the option SFUserAccountChange. In swift access this constant using UserAccountManager.ChangeSetKey
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeKey NS_SWIFT_NAME(UserAccountManager.changeSetKey);

/** The key containing the  for the user in the Notification.
 */
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeUserKey NS_SWIFT_NAME(UserAccountManager.userInfoUserKey);

/**  Key to use to lookup userAccount associated with  NSNotification userInfo.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAccountKey NS_SWIFT_NAME(UserAccountManager.userInfoAccountKey);

/**  Key to use to lookup credentials associated with  NSNotification userInfo.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoCredentialsKey NS_SWIFT_NAME(UserAccountManager.userInfoCredentialsKey);

/**  Key to use to lookup authinfo type associated with  NSNotification userInfo.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAuthTypeKey  NS_SWIFT_NAME(UserAccountManager.userInfoAuthenticationTypeKey);

/**  Key to use to lookup dictionary of nv-pairs type associated with NSNotification userInfo.
 */
FOUNDATION_EXTERN NSString * const kSFUserInfoAddlOptionsKey NS_SWIFT_NAME(UserAccountManager.userInfoAdditionalOptionsKey);

/**  Key to use to lookup SFNotificationUserInfo object in Notifications dictionary.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoKey NS_SWIFT_NAME(UserAccountManager.userInfoSfUserInfoKey);

/**  Key to used to lookup current previous current User object in Notifications dictionary.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationFromUserKey NS_SWIFT_NAME(UserAccountManager.userInfoFromUserKey);

/**  Key to used to lookup new cuurent User object in Notifications dictionary.
 */
FOUNDATION_EXTERN NSString * const kSFNotificationToUserKey NS_SWIFT_NAME(UserAccountManager.userInfoToUserKey);

/**  Key used to provide triggering scene info for IDP flow from a scene delegate.
 */
FOUNDATION_EXTERN NSString * const kSFIDPSceneIdKey NS_SWIFT_NAME(UserAccountManager.IDPSceneKey);

@class SFUserAccountManager;
@class SFSDKAlertMessage;
@class SFSDKWindowContainer;
@class SFSDKAuthViewHandler;

/**
 Protocol for handling callbacks from SFUserAccountManager.
 */
NS_SWIFT_NAME(UserAccountManagerDelegate)
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
- (BOOL)userAccountManager:(SFUserAccountManager *)userAccountManager error:(NSError*)error info:(SFOAuthInfo *)info  NS_SWIFT_NAME(userAccountManager(accountManager:didFailAuthenticationWith:info:));

/**
 Called before the user account manager switches from one user to another.
 @param userAccountManager The SFUserAccountManager instance making the switch.
 @param currentUserAccount The user being switched away from.
 @param anotherUserAccount The user to be switched to.  `nil` if the user context is being switched back
 to no user.
 */
- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)currentUserAccount
                    toUser:(nullable SFUserAccount *)anotherUserAccount NS_SWIFT_NAME(userAccountManager(accountManager:willSwitchFrom:to:));

/**
 Called after the user account manager switches from one user to another.
 @param userAccountManager The SFUserAccountManager instance making the switch.
 @param previousUserAccount The user that was switched away from.
 @param currentUserAccount The user that was switched to.  `nil` if the user context is being switched back
 to no user.
 */
- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)previousUserAccount
                    toUser:(nullable SFUserAccount *)currentUserAccount NS_SWIFT_NAME(userAccountManager(accountManager:didSwitchFrom:to:));

@end

/** User Information for post logout notifications.
 */
NS_SWIFT_NAME(UserAccountManager.NotificationUserInfo)
@interface SFNotificationUserInfo : NSObject
@property (nonatomic,readonly) SFUserAccountIdentity *accountIdentity;
@property (nonatomic, readonly, nullable) NSString *communityId;
@end

/** Class used to manage the accounts functions used across the app.
 It supports multiple accounts and their associated credentials.
 */
NS_SWIFT_NAME(UserAccountManager)
@interface SFUserAccountManager : NSObject

/**
 * Completion block for when auth is cancelled.
 */
@property (nonatomic, readwrite, copy, nullable) void (^authCancelledByUserHandlerBlock)(void);

/** The current user account.  This property may be nil if the user
 has never logged in.
 */
@property (nonatomic, strong, nullable) SFUserAccount *currentUser NS_SWIFT_NAME(currentUserAccount);

/** Returns YES if the current user is anonymous, no otherwise
  */
@property (nonatomic, readonly, getter=isCurrentUserAnonymous) BOOL currentUserAnonymous;

/**
 Returns YES if the logout is requested by the app settings.
 */
@property (nonatomic, readonly, getter=isLogoutSettingEnabled) BOOL logoutSettingEnabled;

/**
 Indicates if the app is configured to require browser based authentication.
 */
@property (nonatomic, readonly) BOOL useBrowserAuth NS_SWIFT_NAME(usesAdvancedAuthentication);
/**
 An array of additional keys (NSString) to parse during OAuth
 */
@property (nonatomic, strong) NSArray<NSString *> *additionalOAuthParameterKeys;

/**
 A dictionary of additional parameters (key value pairs) to send during token refresh
 */
@property (nonatomic, strong) NSDictionary<NSString *,id> * additionalTokenRefreshParams  NS_SWIFT_NAME(additionalTokenRefreshParameters);

/** The host that will be used for login.
 */
@property (nonatomic, strong) NSString *loginHost;

/** Should the login process start again if it fails (default: YES)
 */
@property (nonatomic, assign) BOOL retryLoginAfterFailure NS_SWIFT_NAME(retriesLoginAfterFailure);

/** OAuth client ID to use for login.  Apps may customize
 by setting this property before login; otherwise, this
 value is determined by the SFDCOAuthClientIdPreference
 configured via the settings bundle.
 */
@property (nonatomic, copy) NSString *oauthClientId NS_SWIFT_NAME(oauthClientID);

/** OAuth callback url to use for the OAuth login process.
 Apps may customize this by setting this property before login.
 By default this value is picked up from the main
 bundle property SFDCOAuthRedirectUri
 default: @"sfdc:///axm/detect/oauth/done")
 */
@property (nonatomic, copy) NSString *oauthCompletionUrl NS_SWIFT_NAME(oauthCompletionURL);

/**
 The Branded Login path configured for this application.
 */
@property (nonatomic, nullable, copy) NSString *brandLoginPath;

/**
 The OAuth scopes associated with the app.
 */
@property (nonatomic, copy) NSSet<NSString*> *scopes;

@property (nonatomic, copy, nullable) SFAuthClientFactoryBlock authClient;

/**  Convenience property to retrieve the current user's identity.
 */
@property (readonly, nonatomic, nullable) SFUserAccountIdentity *currentUserIdentity  NS_SWIFT_NAME(currentUserAccountIdentity);

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
@property (nonatomic,assign, readonly) BOOL idpEnabled  NS_SWIFT_NAME(isIDPEnabled);

/** Use this property to indicate the url scheme  for the Identity Provider app
 *
 */
@property (nonatomic, copy, nullable) NSString *idpAppURIScheme;

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
@property (class,nonatomic,readonly) SFUserAccountManager *sharedInstance NS_SWIFT_NAME(shared);

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
- (BOOL)loadAccounts:(NSError**)error NS_SWIFT_NAME(loadAllUserAccounts());

/** An NSArray of all the SFUserAccount instances for the app.
 */
- (nullable NSArray <SFUserAccount *> *) allUserAccounts NS_SWIFT_NAME(userAccounts());

/** Returns all the user identities sorted by Org ID and User ID.
 */
- (nullable NSArray<SFUserAccountIdentity*> *) allUserIdentities NS_SWIFT_NAME(userIdentities());

/** Create an account when necessary using the credentials provided.
  @param credentials The credentials to use.
 */
- (SFUserAccount*)createUserAccount:(SFOAuthCredentials *)credentials NS_SWIFT_NAME(createUserAccount(with:));


/** Allows you to look up the user account associated with a given user identity.
 @param userIdentity The user identity of the user account to be looked up
 */
- (nullable SFUserAccount *)userAccountForUserIdentity:(SFUserAccountIdentity *)userIdentity NS_SWIFT_NAME(userAccount(for:));

/** Returns all accounts that have access to a particular org
 @param orgId The org to match accounts against
 @return An array of accounts that can access that org
 */
- (NSArray<SFUserAccount*> *)accountsForOrgId:(NSString *)orgId NS_SWIFT_NAME(userAccounts(forOrg:));

/** Returns all accounts that match a particular instance URL
 @param instanceURL The host parameter of a given instance URL
 @return An array of accounts that match that instance URL
 */
- (NSArray<SFUserAccount*> *)accountsForInstanceURL:(NSURL *)instanceURL NS_SWIFT_NAME(userAccounts(at:));

/** Returns all accounts that match a domain
 @param domain The domain.
 @return An array of accounts that match that instance URL
 */
- (NSArray<SFUserAccount*> *)userAccountsForDomain:(NSString *)domain NS_SWIFT_NAME(userAccounts(forDomain:));

/** Adds/Updates a user account
 @param userAccount The account to be added
 */
- (BOOL)saveAccountForUser:(SFUserAccount *)userAccount error:(NSError **) error NS_SWIFT_NAME(upsert(_:));

/** Lookup  a user account
 @param credentials used to  up Account matching the credentials
 */
- (nullable SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials NS_SWIFT_NAME(userAccount(for:));

/**
 Allows you to remove the given user account.
 @param userAccount The user account to remove.
 @param error Output error parameter, populated if there was an error deleting
 the account (likely from the filesystem operations).
 @return YES if the deletion was successful, NO otherwise.  Note: If no persisted account matching
 the user parameter is found, no action will be taken, and deletion will be reported as successful.
 */
- (BOOL)deleteAccountForUser:(SFUserAccount *)userAccount error:(NSError **)error NS_SWIFT_NAME(delete(_:));

/** Clear all the accounts state (but do not change anything on the disk).
 */
- (void)clearAllAccountState;

/** Apply custom data to the SFUserAccount that can be
 accessed outside that user's sandbox. This data will be persisted
 between launches and should only be used for non-sensitive information.
 The NSDictionary should be NSCoder encodeable.
 @param object  The NScoding enabled object to set
 @param key     The key to retrieve this data for
 @param userAccount The SFUserAccount to apply this change to.
 */
- (void)setObjectForUserCustomData:(NSObject<NSCoding> *)object forKey:(NSString *)key andUser:(SFUserAccount *)userAccount NS_SWIFT_NAME(setCustomData(withObject:key:userAccount:));

/**
 Switches to a new user. Sets the current user only if the login succeeds. Completion block is
 invoked if the login flow completes, or if any errors are encountered during the flow.
 */
- (void)switchToNewUserWithCompletion:(void (^)(NSError * _Nullable, SFUserAccount * _Nullable))completion NS_REFINED_FOR_SWIFT;

/**
 Switches away from the current user, to the given user account.
 @param userAccount The user to switch to.
 */
- (void)switchToUser:(nullable SFUserAccount *)userAccount NS_SWIFT_NAME(switchToUserAccount(_:));

/**
 Kick off the login process for credentials that's previously configured.
 @param completionBlock The block of code to execute when the authentication process successfully completes.
 @param failureBlock The block of code to execute when the authentication process has a fatal failure.
 @return YES if this call kicks off the authentication process.  NO if an authentication process has already
 started, in which case subsequent requests are queued up to have their completion or failure blocks executed
 in succession.
 */
- (BOOL)loginWithCompletion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                    failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock NS_REFINED_FOR_SWIFT;

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
                   failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock NS_REFINED_FOR_SWIFT;

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
                  failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock NS_REFINED_FOR_SWIFT;

/**
Use this method to stop/clear any authentication which is has already been started
@param completionBlock The completion block is called with YES if a session was cleared successfully. 
*/
- (void)stopCurrentAuthentication:(nullable void (^)(BOOL))completionBlock;
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
- (void)logoutUser:(SFUserAccount *)user NS_SWIFT_NAME(logout(_:));

/**
 Performs a logout for all users of the app, including the current user.
 */
- (void)logoutAllUsers;

/**
 Handle an authentication response from the IDP application
 @param url The URL response returned to the app from the IDP application.
 @options Dictionary of name-value pairs received from open URL
 @return YES if this is a valid URL response from IDP authentication that should be handled, NO otherwise.
 */
- (BOOL)handleIDPAuthenticationResponse:(NSURL *)url options:(nonnull NSDictionary *)options NS_SWIFT_NAME(handleIdentityProviderResponse(from:with:));

@end

NS_ASSUME_NONNULL_END
