/*
 SFSDKOAuth2.h
 SalesforceSDKCore
 
 Created by Raj Rao on 7/11/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

/** SFOAuth default network timeout in seconds.
 */
extern const NSTimeInterval kSFOAuthDefaultTimeout;

/** This constant defines the SFOAuth framework error domain.
 
 Domain indicating an error occurred during OAuth authentication.
 */
extern NSString * _Nonnull const kSFOAuthErrorDomain;

/**
 @enum SFOAuthErrorDomain related error codes
 Constants used by SFOAuthCoordinator to indicate errors in the SFOAuth domain
 */
enum {
    kSFOAuthErrorUnknown = 666,
    kSFOAuthErrorTimeout,
    kSFOAuthErrorMalformed,
    kSFOAuthErrorAccessDenied,              // end user denied authorization
    kSFOAuthErrorInvalidClientId,
    kSFOAuthErrorInvalidClientCredentials,  // client secret invalid
    kSFOAuthErrorInvalidGrant,              // expired access/refresh token, or IP restricted, or invalid login hours
    kSFOAuthErrorInvalidRequest,
    kSFOAuthErrorInactiveUser,
    kSFOAuthErrorInactiveOrg,
    kSFOAuthErrorRateLimitExceeded,
    kSFOAuthErrorUnsupportedResponseType,
    kSFOAuthErrorWrongVersion,              // credentials do not match current Connected App version in the org
    kSFOAuthErrorBrowserLaunchFailed,
    kSFOAuthErrorUnknownAdvancedAuthConfig,
    kSFOAuthErrorInvalidMDMConfiguration,
    kSFOAuthErrorJWTInvalidGrant,
    kSFOAuthErrorRequestCancelled,
    kSFOAuthErrorRefreshFailed, //generic error
    kSFOAuthErrorInvalidURL
};

NS_ASSUME_NONNULL_BEGIN
@class SFOAuthCredentials;
@interface SFSDKOAuthTokenEndpointErrorResponse : NSObject
@property  (nonatomic, readonly) NSString *tokenEndpointErrorCode;
@property  (nonatomic, readonly) NSString *tokenEndpointErrorDescription;
@property  (nonatomic, readonly) NSError *error;
@end

@interface SFSDKOAuthTokenEndpointRequest : NSObject
@property (nonatomic, copy) NSString *refreshToken;
@property (nonatomic, copy, nullable) NSString *userAgentForAuth;
@property (nonatomic, copy) NSString *redirectURI;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy, nullable) NSString *approvalCode;
@property (nonatomic, copy, nullable) NSString *codeVerifier;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, strong) NSURL *serverURL;
@property (nonatomic, strong, nullable) NSDictionary * additionalTokenRefreshParams;
@property (nonatomic, strong, nullable) NSArray<NSString *> *additionalOAuthParameterKeys;
@end

@interface SFSDKOAuthTokenEndpointResponse : NSObject
@property (nonatomic, readonly) BOOL hasError;
@property (nonatomic, readonly, nullable) SFSDKOAuthTokenEndpointErrorResponse *error;
@property (nonatomic, readonly) NSString *accessToken;
@property (nonatomic, readonly) NSString *refreshToken;
@property (nonatomic, readonly) NSDate *issuedAt;
@property (nonatomic, readonly) NSURL *instanceUrl;
@property (nonatomic, readonly) NSURL *identityUrl;
@property (nonatomic, readonly, nullable) NSString *idToken;
@property (nonatomic, readonly, nullable) NSString *communityId;
@property (nonatomic, readonly, nullable) NSURL *communityUrl;
@property (nonatomic, readonly, nullable) NSURL *apiUrl;
@property (nonatomic, readonly, nullable) NSString *signature;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *scopes;
@property (nonatomic, readonly, nullable) NSDictionary *additionalOAuthFields;
@property (nonatomic, readonly, nullable) NSString *lightningDomain;
@property (nonatomic, readonly, nullable) NSString *lightningSid;
@property (nonatomic, readonly, nullable) NSString *vfDomain;
@property (nonatomic, readonly, nullable) NSString *vfSid;
@property (nonatomic, readonly, nullable) NSString *contentDomain;
@property (nonatomic, readonly, nullable) NSString *contentSid;
@property (nonatomic, readonly, nullable) NSString *csrfToken;
- (NSDictionary *)asDictionary;
@end

@protocol SFSDKOAuthProtocol<NSObject>
- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock;
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock;
- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(NSString *))completionBlock;
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials;
@end

@protocol SFSDKOAuthSessionManaging<NSObject>
- (NSURLSession *)createURLSessionWithIdentifier:(nonnull NSString *)identifier;
@end

@interface SFSDKOAuth2 : NSObject<SFSDKOAuthProtocol, SFSDKOAuthSessionManaging>

@end

NS_ASSUME_NONNULL_END
