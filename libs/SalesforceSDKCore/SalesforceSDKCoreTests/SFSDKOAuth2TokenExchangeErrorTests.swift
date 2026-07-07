/*
 SFSDKOAuth2TokenExchangeErrorTests.swift
 SalesforceSDKCoreTests

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

import XCTest
@testable import SalesforceSDKCore

final class SFSDKOAuth2TokenExchangeErrorTests: XCTestCase {

    // MARK: - Helper

    /// Builds a response from a wire-format error dict and asserts all four
    /// observable error fields at once. Callers pass file/line so failing
    /// assertions carry the caller's location.
    private func assertError(
        wire: String,
        description: String,
        expectedEnum: SFOAuthErrorCode,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let params = ["error": wire, "error_description": description]
        guard let response = SFSDKOAuthTokenEndpointResponse(dictionary: params, parseAdditionalFields: nil) else {
            XCTFail("SFSDKOAuthTokenEndpointResponse initializer returned nil", file: file, line: line)
            return
        }

        XCTAssertTrue(response.hasError, "response.hasError should be true", file: file, line: line)
        XCTAssertEqual(response.error?.tokenEndpointErrorCode, wire, file: file, line: line)
        XCTAssertEqual(response.error?.errorCode, expectedEnum.rawValue, file: file, line: line)
        XCTAssertEqual(response.error?.tokenEndpointErrorDescription, description, file: file, line: line)

        // Sanity check: response.error.error is a non-nil NSError in kSFOAuthErrorDomain
        XCTAssertNotNil(response.error?.error, "response.error.error should be non-nil", file: file, line: line)
        let nsError = response.error?.error as NSError?
        XCTAssertEqual(nsError?.domain, kSFOAuthErrorDomain, file: file, line: line)
    }

    // MARK: - invalid_grant family
    //   Invalid, expired, and redirect_uri-mismatched authorization codes all
    //   collapse to the same client-side branch; we exercise the shared branch
    //   three times with distinct server-provided descriptions.

    func test_givenInvalidGrant_whenInitDictionary_thenClassifiedAsInvalidGrant() {
        let wire = SFOAuthErrorCode.invalidGrant.wireValue!

        // Invalid authorization code (garbage, replayed, or never issued)
        assertError(
            wire: wire,
            description: "authorization code invalid",
            expectedEnum: .invalidGrant
        )

        // Expired authorization code (>~10 min old)
        assertError(
            wire: wire,
            description: "expired authorization code",
            expectedEnum: .invalidGrant
        )

        // Mismatched redirect_uri at exchange
        assertError(
            wire: wire,
            description: "redirect_uri mismatch",
            expectedEnum: .invalidGrant
        )
    }

    // MARK: - invalid_client_id and invalid_client

    func test_givenInvalidClientId_whenInitDictionary_thenClassifiedAsInvalidClientId() {
        let wire = SFOAuthErrorCode.invalidClientId.wireValue!
        assertError(
            wire: wire,
            description: "client identifier invalid",
            expectedEnum: .invalidClientId
        )
    }

    func test_givenInvalidClient_whenInitDictionary_thenClassifiedAsInvalidClient() {
        let wire = SFOAuthErrorCode.invalidClient.wireValue!
        assertError(
            wire: wire,
            description: "client authentication failed",
            expectedEnum: .invalidClient
        )
    }

    // MARK: - unsupported_grant_type

    func test_givenUnsupportedGrantType_whenInitDictionary_thenClassifiedAsUnsupportedGrantType() {
        let wire = SFOAuthErrorCode.unsupportedGrantType.wireValue!
        assertError(
            wire: wire,
            description: "grant type not supported",
            expectedEnum: .unsupportedGrantType
        )
    }

    // MARK: - invalid_request

    func test_givenInvalidRequest_whenInitDictionary_thenClassifiedAsInvalidRequest() {
        let wire = SFOAuthErrorCode.invalidRequest.wireValue!
        assertError(
            wire: wire,
            description: "missing required parameter",
            expectedEnum: .invalidRequest
        )
    }

    // MARK: - Enum mapping lock-in for the five distinct wire values

    func test_from_allTokenEndpointWireValues_returnCorrectEnumCase() {
        let testCases: [(String, SFOAuthErrorCode)] = [
            ("invalid_grant", .invalidGrant),
            ("invalid_client_id", .invalidClientId),
            ("invalid_client", .invalidClient),
            ("unsupported_grant_type", .unsupportedGrantType),
            ("invalid_request", .invalidRequest)
        ]

        for (wire, expected) in testCases {
            XCTAssertEqual(SFOAuthErrorCode.from(wire), expected, "Wire '\(wire)' should map to \(expected)")
        }
    }

    // MARK: - Control — success response has no error

    func test_givenSuccessResponse_whenInitDictionary_thenHasErrorIsFalse() {
        let params = [
            "access_token": "00D1234567890abcd!ARMAQGu.test",
            "refresh_token": "5Aep1234567890abcd!AREAQItest",
            "instance_url": "https://na1.salesforce.com"
        ]
        guard let response = SFSDKOAuthTokenEndpointResponse(dictionary: params, parseAdditionalFields: nil) else {
            XCTFail("SFSDKOAuthTokenEndpointResponse initializer returned nil")
            return
        }

        XCTAssertFalse(response.hasError, "response.hasError should be false for success response")
        XCTAssertNil(response.error, "response.error should be nil for success response")
    }
}
