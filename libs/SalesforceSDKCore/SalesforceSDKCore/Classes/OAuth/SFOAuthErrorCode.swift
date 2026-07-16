/*
 SFOAuthErrorCode.swift
 SalesforceSDKCore

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

import Foundation

/// Typed representation of the OAuth token endpoint error values defined by the
/// Salesforce server in OauthErrorCode.java (core/identity-common-api).
///
/// Use ``from(_:)`` to parse the raw `error` string from a token endpoint response.
@objc public enum SFOAuthErrorCode: Int, CaseIterable {
    case unknown = 0
    case accessDenied
    case appBlocked
    case appNotFound
    case authorizationPending
    case badJtiClaim
    case appAttestationFailed
    case appAttestationFailedRetry
    case ecAppPolicyNotFound
    case exceededRegistrationLimit
    case failCloseAppBlocked
    case failedRegistration
    case immediateUnsuccessful
    case installationError
    case invalidAppAccess
    case invalidAssertionType
    case invalidBasicAuthHeader
    case invalidClient
    case invalidClientId
    case invalidDpopProof
    case invalidDistributionState
    case invalidExpid
    case invalidGrant
    case invalidOtp
    case invalidRequest
    case invalidScope
    case invalidSessionLevel
    case invalidToken
    case loginError
    case oauthFlowDisabled
    case oauthPolicyNotFound
    case otpError
    case redirectUriMissing
    case redirectUriMismatch
    case registrationError
    case serverError
    case serviceUnavailable
    case slowDown
    case systemDown
    case unknownError
    case unsupportedExpid
    case unsupportedGrantType
    case unsupportedResponseType
    case unsupportedTokenType
    case useDpopNonce

    /// Returns the ``SFOAuthErrorCode`` whose wire value matches `string`,
    /// or `.unknown` if `string` is nil, empty, or not recognized.
    public static func from(_ string: String?) -> SFOAuthErrorCode {
        guard let string = string, !string.isEmpty else { return .unknown }
        return SFOAuthErrorCode.allCases.first { $0.wireValue == string } ?? .unknown
    }
}

/// Objective-C–accessible bridge for ``SFOAuthErrorCode``.
/// Use `SFOAuthErrorCodeHelper.from(_:)` from Objective-C to parse error wire strings.
@objc public class SFOAuthErrorCodeHelper: NSObject {
    /// Returns the integer raw value of the ``SFOAuthErrorCode`` matching `string`,
    /// or the raw value of `.unknown` (0) if not recognized.
    @objc public static func from(_ string: String?) -> NSInteger {
        return SFOAuthErrorCode.from(string).rawValue
    }
}

public extension SFOAuthErrorCode {
    /// The wire string value sent in the token endpoint error JSON response.
    /// Returns `nil` for `.unknown`.
    var wireValue: String? {
        switch self {
        case .unknown: return nil
        case .accessDenied: return "access_denied"
        case .appBlocked: return "app_blocked"
        case .appNotFound: return "app_not_found"
        case .authorizationPending: return "authorization_pending"
        case .badJtiClaim: return "bad_jti_claim"
        case .appAttestationFailed: return "client_blocked"
        case .appAttestationFailedRetry: return "client_blocked_retry"
        case .ecAppPolicyNotFound: return "ecapp_policy_not_found"
        case .exceededRegistrationLimit: return "exceeded_registration_limit"
        case .failCloseAppBlocked: return "fail_close_app_blocked"
        case .failedRegistration: return "failed_registration"
        case .immediateUnsuccessful: return "immediate_unsuccessful"
        case .installationError: return "installation_error"
        case .invalidAppAccess: return "invalid_app_access"
        case .invalidAssertionType: return "invalid_assertion_type"
        case .invalidBasicAuthHeader: return "invalid_basic_auth_header"
        case .invalidClient: return "invalid_client"
        case .invalidClientId: return "invalid_client_id"
        case .invalidDpopProof: return "invalid_dpop_proof"
        case .invalidDistributionState: return "invalid_distribution_state"
        case .invalidExpid: return "invalid_expid"
        case .invalidGrant: return "invalid_grant"
        case .invalidOtp: return "invalid_otp"
        case .invalidRequest: return "invalid_request"
        case .invalidScope: return "invalid_scope"
        case .invalidSessionLevel: return "invalid_session_level"
        case .invalidToken: return "invalid_token"
        case .loginError: return "login_error"
        case .oauthFlowDisabled: return "oauth_flow_disabled"
        case .oauthPolicyNotFound: return "oauth_policy_not_found"
        case .otpError: return "otp_error"
        case .redirectUriMissing: return "redirect_uri_missing"
        case .redirectUriMismatch: return "redirect_uri_mismatch"
        case .registrationError: return "registration_error"
        case .serverError: return "server_error"
        case .serviceUnavailable: return "service_unavailable"
        case .slowDown: return "slow_down"
        case .systemDown: return "system_down"
        case .unknownError: return "unknown_error"
        case .unsupportedExpid: return "unsupported_expid"
        case .unsupportedGrantType: return "unsupported_grant_type"
        case .unsupportedResponseType: return "unsupported_response_type"
        case .unsupportedTokenType: return "unsupported_token_type"
        case .useDpopNonce: return "use_dpop_nonce"
        @unknown default: return nil
        }
    }
}
