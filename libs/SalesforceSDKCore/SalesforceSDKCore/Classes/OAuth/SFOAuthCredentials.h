/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

NS_ASSUME_NONNULL_BEGIN

/**
 @enum OAuth credential storage type
 */
typedef NS_ENUM(NSInteger, SFOAuthCredentialsStorageType){
    /**
     No storage or persistence of OAuth credentials will be attempted
     */
    SFOAuthCredentialsStorageTypeNone = -1,
    /**
     OAuth credentials will be stored securely within the keychain.
     */
    SFOAuthCredentialsStorageTypeKeychain,
} NS_SWIFT_NAME(OAuthCredentials.StorageType);

/** Object representing an individual user account's logon credentials.
 
 This object represents information about a user account necessary to authenticate and
 reauthenticate against Salesforce.com servers using OAuth2. It includes information such as
 the user's account ID, the protocol to use, and any session or refresh tokens assigned
 by the server.
 
 The secure information contained in this object is persisted securely within the
 device's Keychain, and is accessed by using the `identifier` property.
 
 Instances of this object are used to begin the authentication process, by supplying
 it to an `SFOAuthCoordinator` instance which conducts the authentication workflow.
 
 The credentials stored in this object include:
 
 - Consumer key and secret

 - Request token and secret

 - Access token and secret

 @see SFOAuthCoordinator
 */
NS_SWIFT_NAME(OAuthCredentials)
@interface SFOAuthCredentials : NSObject <NSSecureCoding, NSCopying>

/** Protocol scheme for authenticating this account.
 */
@property (nonatomic, readonly, strong, nullable) NSString *protocol;

/** Logon host domain name.
 
 The domain used to initiate a user login, for example _login.salesforce.com_
 or _test.salesforce.com_. The default is _login.salesforce.com_.
 */
@property (nonatomic, readonly, nullable) NSString *domain;

/** Credential identifier used to uniquely identify this credential in the keychain. 
 
 @warning This property is used by many underlying internal functions of this class and therefore must not be set to a 
 `nil` or empty value prior to accessing properties or methods identified in the documentation regarding this prohibition.
 @warning This property must not be modified while authenticating.
 */
@property (nonatomic, readonly, nonnull) NSString *identifier;

/** Client consumer key.
 
 Identifies the client for remote authentication. 
 
 @warning This property must not be `nil` or empty when authentication is initiated or an exception will be raised.
 @warning This property must not be modified while authenticating.
 */
@property (nonatomic, readonly, nullable) NSString *clientId;

/** Callback URL to load at the end of the authentication process.
 
 This must match the callback URL in the Remote Access object exactly, or authentication will fail.
 */
@property (nonatomic, readonly, nullable) NSString *redirectUri;

/** JWT.
 
 JWT code used in the client breeze link flow.
 @warning This property must not be modified while authenticating.
 @warning This property should be set to nil after authentication.
 */
@property (nonatomic, readonly, nullable) NSString *jwt;

/** Token used to refresh the user's session.
 
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should use the revoke methods instead.
 @exception NSInternalInconsistencyException If this property is accessed when the identifier property is `nil`.
 */
@property (nonatomic, readonly, nullable) NSString *refreshToken;

/** The access token for the user's session.
 
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should use the revoke methods instead.
 @exception NSInternalInconsistencyException If accessed while the identifier property is `nil`.
 */
@property (nonatomic, readonly, nullable) NSString *accessToken;

@property (nonatomic, readonly, nullable) NSString *lightningDomain;
@property (nonatomic, readonly, nullable) NSString *lightningSid;
@property (nonatomic, readonly, nullable) NSString *vfDomain;
@property (nonatomic, readonly, nullable) NSString *vfSid;
@property (nonatomic, readonly, nullable) NSString *contentDomain;
@property (nonatomic, readonly, nullable) NSString *contentSid;
@property (nonatomic, readonly, nullable) NSString *csrfToken;
@property (nonatomic, readonly, nullable) NSString *cookieClientSrc;
@property (nonatomic, readonly, nullable) NSString *cookieSidClient;
@property (nonatomic, readonly, nullable) NSString *sidCookieName;
@property (nonatomic, readonly, nullable) NSString *parentSid;
@property (nonatomic, readonly, nullable) NSString *tokenFormat;
@property (nonatomic, readonly, nullable) NSString *beaconChildConsumerKey;
@property (nonatomic, readonly, nullable) NSString *beaconChildConsumerSecret;


/** A readonly convenience property returning the Salesforce Organization ID provided in the path component of the identityUrl.
 
 This property is available after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 @exception NSInternalInconsistencyException If accessed while the identifier property is `nil`.
 */
@property (nonatomic, readonly, nullable) NSString *organizationId;

/** The URL of the server instance for this session. This URL always refers to the base organization
 instance, even if the user has logged through a community-based login flow.
 See `community_id` and `community_url`.
 
 This is the URL that client requests should be made to after authentication completes.
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 */
@property (nonatomic, readonly, nullable) NSURL *instanceUrl;

/** The URL of the  SFAP  server instance for this session.
 
 This is the URL that client SFAP requests should be made to after authentication completes.
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 This URL is only defined when sfap_api scope is used.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 */
@property (nonatomic, readonly, nullable) NSURL *apiInstanceUrl;

/** The community ID the user choose to log into. This usually happens when the user
 logs into the app using a community-based login page
 
 Note: this property is nil of the user logs into the internal community or into an org that doesn't have communities.
 */
@property (nonatomic, readonly, nullable) NSString *communityId;

/** The community-base URL the user choose to log into. This usually happens when the user
 logs into the app using a community-based login page
 
 Note: this property is nil if the user logs into the internal community or into an org that doesn't have communities.
 */
@property (nonatomic, readonly, nullable) NSURL *communityUrl;

/** The timestamp when the session access token was issued.
 
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 */
@property (nonatomic, readonly, nullable) NSDate *issuedAt;

/** The identity URL for the user returned as part of a successful authentication response.
 The format of the URL is: _https://login.salesforce.com/ID/orgID/userID_ where orgId is the ID of the Salesforce organization 
 that the user belongs to, and userID is the Salesforce user ID.
 
 This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 */
@property (nonatomic, readonly, nullable) NSURL *identityUrl;

/** The community URL, if present. The instance URL, otherwise.
 */
@property (nonatomic, readonly, nullable) NSURL *apiUrl;

/** A readonly convenience property returning the first 15 characters of the Salesforce User ID provided in the final path 
 component of the identityUrl.
 
 This property is available after authentication has successfully completed.
 
 @warning The setter for this property is exposed publicly only for unit tests. Client code should not set this property.
 */
@property (nonatomic, readonly, nullable) NSString *userId;

/**
 Determines if sensitive data such as the `refreshToken` and `accessToken` are encrypted
 */
@property (nonatomic, readonly, getter = isEncrypted) BOOL encrypted;

/**
 A dictionary containing key-value pairs for any of the keys provided via the additionalOAuthParameterKeys property of SFUserAccountManager.
 If a key does not match a value in the parsed response, then it will not exist in the dictionary.
 */
@property (nonatomic, readonly, nullable) NSDictionary * additionalOAuthFields;

@property (nonatomic, readonly, nullable) NSString *challengeString;

@property (nonatomic, readonly, nullable) NSString *authCode;

///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/** Initializes an authentication credential object with the given identifier and client ID. 
 
 The identifier uniquely identifies the credentials object within the device's secure keychain. 
 The client ID identifies the client for remote authentication. 

 @param theIdentifier An identifier for this credential instance.
 @param theClientId The client ID (also known as consumer key) to be used for the OAuth session.
 @param encrypted Determines if the sensitive data like refreshToken and accessToken should be encrypted
 @return An initialized authentication credential object.
 */
- (_Nullable instancetype)initWithIdentifier:(NSString * _Nonnull)theIdentifier clientId:(NSString * _Nullable )theClientId encrypted:(BOOL)encrypted;

/** Initializes an authentication credential object with the given identifier and client ID. This is the designated initializer.
 
 If <code>type</code> is set to <code>SFOAuthCredentialsStorageTypeKeychain</code>, the given identifier uniquely identifies the credentials object within that keychain.
 The client ID identifies the client for remote authentication.
 
 @param theIdentifier An identifier for this credential instance.
 @param theClientId The client ID (also known as consumer key) to be used for the OAuth session.
 @param encrypted Determines if the sensitive data like refreshToken and accessToken should be encrypted
 @param type Indicates whether the OAuth credentials are stored in the keychain
 @return An initialized authentication credential object.
 */
- (_Nullable instancetype)initWithIdentifier:(NSString * _Nonnull )theIdentifier clientId:(NSString * _Nullable)theClientId encrypted:(BOOL)encrypted storageType:(SFOAuthCredentialsStorageType)type;

- (id)initWithCoder:(NSCoder *)coder;
/** Revoke the OAuth access and refresh tokens.
 
 @warning Calling this method when the identifier property is `nil` will raise an NSInternalInconsistencyException.
 */
- (void)revoke;

/** Revoke the OAuth access token.
 
 @exception NSInternalInconsistencyException If called when the identifier property is `nil`.
 */
- (void)revokeAccessToken;

/** Revoke the OAuth refresh token.
 
 @exception NSInternalInconsistencyException If called while the identifier property is `nil`.
 */
- (void)revokeRefreshToken;

- (NSURL *)overrideDomainIfNeeded;

- (void)updateCredentials:(NSDictionary *)params;

/** Returns the oauth client id to use for refresh
 In the case of beacon app, the beacon child consumer key returned during login should be used instead of the configured consumer key
 */
- (NSString*)getClientIdForRefresh;

@end

NS_ASSUME_NONNULL_END
