/*
 SFOAuthCoordinatorAppAttestationTests.swift
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

final class SFOAuthCoordinatorAppAttestationTests: XCTestCase, SFOAuthCoordinatorDelegate {

    private var coordinator: SFOAuthCoordinator!
    private var lastFailureError: NSError?
    private var delegateExpectation: XCTestExpectation?

    override class func setUp() {
        SFSDKLogoutBlocker.block()
        super.setUp()
    }

    override func setUp() {
        super.setUp()
        lastFailureError = nil
    }

    override func tearDown() {
        coordinator = nil
        lastFailureError = nil
        delegateExpectation = nil
        super.tearDown()
    }

    // MARK: - Constants

    private let appAttestFailed = SFOAuthErrorCode.appAttestationFailed.wireValue!
    private let appAttestFailedRetry = SFOAuthErrorCode.appAttestationFailedRetry.wireValue!
    private let invalidGrant = SFOAuthErrorCode.invalidGrant.wireValue!
    private let attestationMessage = SFSDKResourceUtils.localizedString("appAttestationFailedError")
    private let testDomain = "myorg.my.salesforce.com"

    // MARK: - Helpers

    private func handleTokenResponse(errorCode: String, errorDescription: String = "server error description") throws {
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "com.salesforce.ios.oauth.attesttest", clientId: "TestClientId", encrypted: false))
        credentials.domain = testDomain
        credentials.redirectUri = "testapp://callback"
        coordinator = SFOAuthCoordinator(credentials: credentials)
        coordinator.delegate = self
        delegateExpectation = expectation(description: "Delegate called")

        let params = ["error": errorCode, "error_description": errorDescription]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: params, parseAdditionalFields: nil)
        coordinator.handle(response)

        waitForExpectations(timeout: 2.0)
        XCTAssertNotNil(lastFailureError, "Delegate should have received a failure error")
    }

    // MARK: - Attestation failures get localized message

    func test_givenAppAttestFailed_whenHandleResponse_thenDelegateReceivesLocalizedMessage() throws {
        try handleTokenResponse(errorCode: appAttestFailed, errorDescription: "This client has been blocked")
        XCTAssertEqual(lastFailureError?.localizedDescription, attestationMessage)
    }

    func test_givenAppAttestFailedRetry_whenHandleResponse_thenDelegateReceivesLocalizedMessage() throws {
        try handleTokenResponse(errorCode: appAttestFailedRetry, errorDescription: "Retry app attestation")
        XCTAssertEqual(lastFailureError?.localizedDescription, attestationMessage)
    }

    // MARK: - Wire string preserved in userInfo

    func test_givenAppAttestFailed_whenHandleResponse_thenWireStringPreservedInUserInfo() throws {
        try handleTokenResponse(errorCode: appAttestFailed)
        XCTAssertEqual(lastFailureError?.userInfo[kSFOAuthError] as? String, appAttestFailed)
    }

    // MARK: - Non-attestation error passes raw description through

    func test_givenInvalidGrant_whenHandleResponse_thenDelegateReceivesRawServerDescription() throws {
        let rawDescription = "expired authorization code"
        try handleTokenResponse(errorCode: invalidGrant, errorDescription: rawDescription)
        XCTAssertEqual(lastFailureError?.localizedDescription, rawDescription)
        XCTAssertNotEqual(lastFailureError?.localizedDescription, attestationMessage)
    }

    // MARK: - Error domain preserved after userInfo swap

    func test_givenAppAttestFailed_whenHandleResponse_thenErrorDomainPreserved() throws {
        try handleTokenResponse(errorCode: appAttestFailed)
        XCTAssertEqual(lastFailureError?.domain, kSFOAuthErrorDomain)
    }

    // MARK: - SFOAuthCoordinatorDelegate

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo: AuthInfo?) {
        lastFailureError = error as NSError
        delegateExpectation?.fulfill()
    }

    func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo: AuthInfo) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWith view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
}
