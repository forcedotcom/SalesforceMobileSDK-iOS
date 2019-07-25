//
//  SFSDKOAuthConstants.h
//  SalesforceSDKCore
//
//  Created by Raj Rao on 6/25/19.
//  Copyright © 2019 salesforce.com. All rights reserved.
//

#ifndef SFSDKOAuthConstants_h
#define SFSDKOAuthConstants_h
// Private constants

static NSString * const kSFOAuthEndPointAuthorize               = @"/services/oauth2/authorize";    // user agent flow
static NSString * const kSFOAuthEndPointToken                   = @"/services/oauth2/token";        // token refresh flow

// Advanced auth constants
static NSUInteger const kSFOAuthCodeVerifierByteLength          = 128;
static NSString * const kSFOAuthCodeVerifierParamName           = @"code_verifier";
static NSString * const kSFOAuthCodeChallengeParamName          = @"code_challenge";
static NSString * const kSFOAuthResponseTypeCode                = @"code";

static NSString * const kSFOAuthAccessToken                     = @"access_token";
static NSString * const kSFOAuthClientId                        = @"client_id";
static NSString * const kSFOAuthDeviceId                        = @"device_id";
static NSString * const kSFOAuthCustomPermissions               = @"custom_permissions";
static NSString * const kSFOAuthDisplay                         = @"display";
static NSString * const kSFOAuthDisplayTouch                    = @"touch";
static NSString * const kSFOAuthError                           = @"error";
static NSString * const kSFOAuthErrorDescription                = @"error_description";
static NSString * const kSFOAuthFormat                          = @"format";
static NSString * const kSFOAuthFormatJson                      = @"json";
static NSString * const kSFOAuthGrantType                       = @"grant_type";
static NSString * const kSFOAuthGrantTypeRefreshToken           = @"refresh_token";
static NSString * const kSFOAuthId                              = @"id";
static NSString * const kSFOAuthInstanceUrl                     = @"instance_url";
static NSString * const kSFOAuthCommunityId                     = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl                    = @"sfdc_community_url";
static NSString * const kSFOAuthIssuedAt                        = @"issued_at";
static NSString * const kSFOAuthRedirectUri                     = @"redirect_uri";
static NSString * const kSFOAuthRefreshToken                    = @"refresh_token";
static NSString * const kSFOAuthResponseType                    = @"response_type";
static NSString * const kSFOAuthResponseTypeToken               = @"token";
static NSString * const kSFOAuthScope                           = @"scope";
static NSString * const kSFOAuthSignature                       = @"signature";

// Used for the IP bypass flow, Advanced auth flow
static NSString * const kSFOAuthApprovalCode                    = @"code";
static NSString * const kSFOAuthGrantTypeAuthorizationCode      = @"authorization_code";
static NSString * const kSFOAuthResponseTypeActivatedClientCode = @"activated_client_code";
static NSString * const kSFOAuthResponseClientSecret            = @"client_secret";

// OAuth Error Descriptions
// see https://na1.salesforce.com/help/doc/en/remoteaccess_oauth_refresh_token_flow.htm

static NSString * const kSFOAuthErrorTypeMalformedResponse          = @"malformed_response";
static NSString * const kSFOAuthErrorTypeAccessDenied               = @"access_denied";
static NSString * const KSFOAuthErrorTypeInvalidClientId            = @"invalid_client_id"; // invalid_client_id:'client identifier invalid'
// this may be returned when the refresh token is revoked
// TODO: needs clarification
static NSString * const kSFOAuthErrorTypeInvalidClient              = @"invalid_client";    // invalid_client:'invalid client credentials'
// this is returned when refresh token is revoked
static NSString * const kSFOAuthErrorTypeInvalidClientCredentials   = @"invalid_client_credentials"; // this is documented but hasn't been witnessed
static NSString * const kSFOAuthErrorTypeInvalidGrant               = @"invalid_grant";
static NSString * const kSFOAuthErrorTypeInvalidRequest             = @"invalid_request";
static NSString * const kSFOAuthErrorTypeInactiveUser               = @"inactive_user";
static NSString * const kSFOAuthErrorTypeInactiveOrg                = @"inactive_org";
static NSString * const kSFOAuthErrorTypeRateLimitExceeded          = @"rate_limit_exceeded";
static NSString * const kSFOAuthErrorTypeUnsupportedResponseType    = @"unsupported_response_type";
static NSString * const kSFOAuthErrorTypeTimeout                    = @"auth_timeout";
static NSString * const kSFOAuthErrorTypeWrongVersion               = @"wrong_version";     // credentials do not match current Connected App version in the org
static NSString * const kSFOAuthErrorTypeBrowserLaunchFailed        = @"browser_launch_failed";
static NSString * const kSFOAuthErrorTypeUnknownAdvancedAuthConfig  = @"unknown_advanced_auth_config";
static NSString * const kSFOAuthErrorTypeJWTLaunchFailed            = @"jwt_launch_failed";
static NSString * const kSFOAuthErrorTypeAuthConfig  = @"auth_config";

static NSUInteger kSFOAuthReponseBufferLength                   = 512; // bytes

static NSString * const kHttpMethodPost                         = @"POST";
static NSString * const kHttpHeaderContentType                  = @"Content-Type";
static NSString * const kHttpPostContentType                    = @"application/x-www-form-urlencoded";
static NSString * const kHttpHeaderUserAgent                    = @"User-Agent";
static NSString * const kOAuthUserAgentUserDefaultsKey          = @"UserAgent";
static NSString * const kSFAppFeatureSafariBrowserForLogin      = @"BW";
static NSString * const kSFECParameter = @"ec";

#endif /* SFSDKOAuthConstants_h */
