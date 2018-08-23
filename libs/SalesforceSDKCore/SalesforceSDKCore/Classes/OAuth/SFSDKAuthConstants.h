/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#ifndef SFSDKAuthConstants_h
#define SFSDKAuthConstants_h

typedef NSString * const UserAccountManagerConstants NS_TYPED_ENUM NS_SWIFT_NAME(UserAccountManager.Constants);

typedef NSString * const UserAccountManagerNotification NS_TYPED_ENUM NS_SWIFT_NAME(UserAccountManager.Notification);

typedef NSString * const UserAccountManagerPreferences NS_TYPED_ENUM NS_SWIFT_NAME(UserAccountManager.Preferences);

/**Notification sent when user has been created or is set as current User. In swift access this constant using UserAccountManager.Notification.didChangeUser
 */

FOUNDATION_EXTERN UserAccountManagerNotification SFUserAccountManagerDidChangeUserNotification NS_SWIFT_NAME(didChangeUser);

/** Notification sent when something has changed with the current user. In swift access this constant using UserAccountManager.Notification.didChangeUserData
 */
FOUNDATION_EXTERN UserAccountManagerNotification SFUserAccountManagerDidChangeUserDataNotification NS_SWIFT_NAME(didChangeUserData);

/** Notification sent when something user init has finished. In swift access this constant using UserAccountManager.Notification.didFinishUserInit
 */
FOUNDATION_EXTERN UserAccountManagerNotification SFUserAccountManagerDidFinishUserInitNotification NS_SWIFT_NAME(didFinishUserInit);

/** Notification sent prior to user logout. In swift access this constant using UserAccountManager.Notification.userWillLogout
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillLogout NS_SWIFT_NAME(userWillLogout);

/** Notification sent after user logout. In swift access this constant using UserAccountManager.Notification.userDidLogout
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserDidLogout NS_SWIFT_NAME(userDidLogout);

/** Notification sent prior to user switch. In swift access this constant using UserAccountManager.Notification.userDidLogout
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillSwitch NS_SWIFT_NAME(userWillSwitch);

/** Notification sent after user switch
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserDidSwitch NS_SWIFT_NAME(userDidSwitch);

/** Notification sent when all users of org have logged off. In swift access this constant using UserAccountManager.Notification.orgDidLogout
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationOrgDidLogout NS_SWIFT_NAME(orgDidLogout);

/** Notification sent prior to display of Auth View. In swift access this constant using UserAccountManager.Notification.willShowAuthView
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillShowAuthView NS_SWIFT_NAME(willShowAuthView);

/** Notification sent when user cancels authentication. In swift access this constant using UserAccountManager.Notification.userCanceledAuth
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserCanceledAuth NS_SWIFT_NAME(userCanceledAuth);

/** Notification sent prior to user log in. In swift access this constant using UserAccountManager.Notification.userWillLogIn
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillLogIn NS_SWIFT_NAME(userWillLogIn);

/** Notification sent after user log in. In swift access this constant using UserAccountManager.Notification.userDidLogIn
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserDidLogIn NS_SWIFT_NAME(userDidLogIn);

/**  Notification sent before SP APP invokes IDP APP for authentication. In swift access this constant using UserAccountManager.Notification.willSendIDPRequest
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillSendIDPRequest NS_SWIFT_NAME(willSendIDPRequest);

/**  Notification sent before IDP APP invokes SP APP with auth code. In swift access this constant using UserAccountManager.Notification.willSendIDPResponse
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserWillSendIDPResponse NS_SWIFT_NAME(willSendIDPResponse);

/**  Notification sent when  IDP APP receives request for authentication from SP APP. In swift access this constant using UserAccountManager.Notification.didReceiveIDPRequest
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserDidReceiveIDPRequest NS_SWIFT_NAME(didReceiveIDPRequest);

/**  Notification sent when  SP APP receives successful response of authentication from IDP APP. In swift access this constant using UserAccountManager.Notification.didReceiveIDPResponse
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserDidReceiveIDPResponse NS_SWIFT_NAME(didReceiveIDPResponse);

/**  Notification sent when  SP APP has log in  is successful when initiated from IDP APP. In swift access this constant using UserAccountManager.Notification.idpInitDidLogIn
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFNotificationUserIDPInitDidLogIn  NS_SWIFT_NAME(idpInitDidLogIn);

/** The key containing the type of change for the SFUserAccountManagerDidChangeCurrentUserNotification
 The value is a NSNumber that can be casted to the option SFUserAccountChange. In swift access this constant using UserAccountManager.Constants.changeSetKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants SFUserAccountManagerUserChangeKey NS_SWIFT_NAME(changeSetKey);

/** The key containing the  for the user in the Notification. In swift access this constant using UserAccountManager.Constants.userKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants SFUserAccountManagerUserChangeUserKey NS_SWIFT_NAME(userKey);

/**  Key to use to lookup userAccount associated with  NSNotification userInfo. In swift access this constant using UserAccountManager.Constants.accountKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationUserInfoAccountKey NS_SWIFT_NAME(accountKey);

/**  Key to use to lookup credentials associated with  NSNotification userInfo. In swift access this constant using UserAccountManager.Constants.credentialsKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationUserInfoCredentialsKey NS_SWIFT_NAME(credentialsKey);

/**  Key to use to lookup authinfo type associated with  NSNotification userInfo. In swift access this constant using UserAccountManager.Constants.authTypeKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationUserInfoAuthTypeKey  NS_SWIFT_NAME(authTypeKey);

/**  Key to use to lookup dictionary of nv-pairs type associated with NSNotification userInfo. In swift access this constant using UserAccountManager.Constants.addlOptionsKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFUserInfoAddlOptionsKey NS_SWIFT_NAME(addlOptionsKey);

/**  Key to use to lookup SFNotificationUserInfo object in Notifications dictionary. In swift access this constant using UserAccountManager.Constants.sfUserInfoKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationUserInfoKey NS_SWIFT_NAME(sfUserInfoKey);

/**  Key to used to lookup current previous current User object in Notifications dictionary. In swift access this constant using UserAccountManager.Constants.fromUserKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationFromUserKey NS_SWIFT_NAME(fromUserKey);

/**  Key to used to lookup new cuurent User object in Notifications dictionary. In swift access this constant using UserAccountManager.Constants.toUserKey
 */
FOUNDATION_EXTERN UserAccountManagerConstants kSFNotificationToUserKey NS_SWIFT_NAME(toUserKey);
/**
 Key identifying login host. In swift access this constant using UserAccountManager.Preferences.loginHostKey
 */
FOUNDATION_EXTERN UserAccountManagerPreferences kSFUserAccountOAuthLoginHost NS_SWIFT_NAME(loginHostKey);

/**
 The key for storing the persisted OAuth scopes. In swift access this constant using UserAccountManager.Preferences.scopesKey
 */
FOUNDATION_EXTERN  UserAccountManagerPreferences kOAuthScopesKey NS_SWIFT_NAME(scopesKey);

/**
 The key for storing the persisted OAuth client ID. In swift access this constant using UserAccountManager.Preferences.clientIdKey
 */
FOUNDATION_EXTERN  UserAccountManagerPreferences kOAuthClientIdKey NS_SWIFT_NAME(clientIdKey);

/**
 The key for storing the persisted OAuth redirect URI. In swift access this constant using UserAccountManager.Preferences.redirectUriKey
 */
FOUNDATION_EXTERN  UserAccountManagerPreferences kOAuthRedirectUriKey NS_SWIFT_NAME(redirectUriKey);

/**
 Identifies the notification for the login host changing in the app's settings. In swift access this constant using UserAccountManager.Notification.loginHostChanged
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFLoginHostChangedNotification NS_SWIFT_NAME(loginHostChanged);

/**
 The key for the original host in a login host change notification. In swift access this constant using UserAccountManager.Notification.loginHostChangedKey
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFLoginHostChangedNotificationOriginalHostKey NS_SWIFT_NAME(loginHostChangedKey);

/**
 The key for the updated host in a login host change notification. In swift access this constant using UserAccountManager.Notification.updatedHostKey
 */
FOUNDATION_EXTERN UserAccountManagerNotification kSFLoginHostChangedNotificationUpdatedHostKey NS_SWIFT_NAME(updatedHostKey);

/**
 Default used as last resort. In swift access this constant using UserAccountManager.Preferences.defaultLoginHostKey
 */
FOUNDATION_EXTERN UserAccountManagerPreferences kSFUserAccountOAuthLoginHostDefault NS_SWIFT_NAME(defaultLoginHostKey);

#endif /* SFSDKAuthConstants_h */
