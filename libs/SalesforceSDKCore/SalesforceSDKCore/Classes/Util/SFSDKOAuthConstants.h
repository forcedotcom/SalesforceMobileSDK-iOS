/*
 SFSDKOAuthConstants.h
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

#ifndef SFSDKOAuthConstants_h
#define SFSDKOAuthConstants_h

// Private constants
static NSString * const kSFOAuthEndPointAuthorize               = @"/services/oauth2/authorize";    // user agent flow
static NSString * const kSFOAuthEndPointToken                   = @"/services/oauth2/token";        // token refresh flow
static NSString * const kSFRevokePath                           = @"/services/oauth2/revoke";

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
static NSString * const kSFOAuthGrantTypeHybridRefresh          = @"hybrid_refresh";
static NSString * const kSFOAuthId                              = @"id";
static NSString * const kSFOAuthInstanceUrl                     = @"instance_url";
static NSString * const kSFOAuthCommunityId                     = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl                    = @"sfdc_community_url";
static NSString * const kSFOAuthIdToken                         = @"id_token";
static NSString * const kSFOAuthIssuedAt                        = @"issued_at";
static NSString * const kSFOAuthRedirectUri                     = @"redirect_uri";
static NSString * const kSFOAuthRefreshToken                    = @"refresh_token";
static NSString * const kSFOAuthResponseType                    = @"response_type";
static NSString * const kSFOAuthResponseTypeHybridToken         = @"hybrid_token";
static NSString * const kSFOAuthScope                           = @"scope";
static NSString * const kSFOAuthSignature                       = @"signature";
static NSString * const kSFOAuthLightningDomain                 = @"lightning_domain";
static NSString * const kSFOAuthLightningSID                    = @"lightning_sid";
static NSString * const kSFOAuthVFDomain                        = @"visualforce_domain";
static NSString * const kSFOAuthVFSID                           = @"visualforce_sid";
static NSString * const kSFOAuthContentDomain                   = @"content_domain";
static NSString * const kSFOAuthContentSID                      = @"content_sid";
static NSString * const kSFOAuthCSRFToken                       = @"csrf_token";

// Used for the IP bypass flow, Advanced auth flow
static NSString * const kSFOAuthApprovalCode                    = @"code";
static NSString * const kSFOAuthGrantTypeAuthorizationCode      = @"authorization_code";
static NSString * const kSFOAuthResponseTypeActivatedClientCode = @"activated_client_code";
static NSString * const kSFOAuthResponseClientSecret            = @"client_secret";

// OAuth Error Descriptions
// see https://na1.salesforce.com/help/doc/en/remoteaccess_oauth_refresh_token_flow.htm
static NSString * const kSFOAuthErrorTypeMalformedResponse      = @"malformed_response";
static NSString * const kSFOAuthErrorTypeAccessDenied           = @"access_denied";
static NSString * const KSFOAuthErrorTypeInvalidClientId        = @"invalid_client_id"; // invalid_client_id:'client identifier invalid'
// this may be returned when the refresh token is revoked
// TODO: needs clarification
static NSString * const kSFOAuthErrorTypeInvalidClient          = @"invalid_client";    // invalid_client:'invalid client credentials'
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
static NSString * const kSFOAuthErrorTypeAuthConfig                 = @"auth_config";
static NSUInteger kSFOAuthReponseBufferLength                       = 512; // bytes
static NSString * const kHttpMethodPost                             = @"POST";
static NSString * const kHttpHeaderContentType                      = @"Content-Type";
static NSString * const kHttpPostContentType                        = @"application/x-www-form-urlencoded";
static NSString * const kHttpHeaderUserAgent                        = @"User-Agent";
static NSString * const kOAuthUserAgentUserDefaultsKey              = @"UserAgent";
static NSString * const kSFAppFeatureSafariBrowserForLogin          = @"BW";
static NSString * const kSFECParameter                              = @"ec";

#endif /* SFSDKOAuthConstants_h */
