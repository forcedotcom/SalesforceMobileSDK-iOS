/*
 SFOAuthCoordinatorLightningURLTests.swift
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

final class SFOAuthCoordinatorLightningURLTests: XCTestCase, SFOAuthCoordinatorDelegate {

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

    private let lightningDomain = "myorg.lightning.force.com"
    private let lightningSubdomain = "myorg.lightning.pc-rnd.force.com"
    private let myDomain = "myorg.my.salesforce.com"
    private let unsupportedGrantType = SFOAuthErrorCode.unsupportedGrantType.wireValue!
    private let invalidGrant = SFOAuthErrorCode.invalidGrant.wireValue!
    private let lightningMessage = SFSDKResourceUtils.localizedString("lightningUrlCodeExchangeError")

    // MARK: - Helpers

    private func handleTokenResponse(domain: String, errorCode: String) throws {
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "com.salesforce.ios.oauth.lightningtest", clientId: "TestClientId", encrypted: false))
        credentials.domain = domain
        credentials.redirectUri = "testapp://callback"
        coordinator = SFOAuthCoordinator(credentials: credentials)
        coordinator.delegate = self
        delegateExpectation = expectation(description: "Delegate called")

        let params = ["error": errorCode, "error_description": "\(errorCode): grant type not supported"]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: params, parseAdditionalFields: nil)
        coordinator.handle(response)

        waitForExpectations(timeout: 2.0)
        XCTAssertNotNil(lastFailureError, "Delegate should have received a failure error")
    }

    // MARK: - SC-1: Warning triggers when BOTH conditions met

    func test_givenLightningURLAndUnsupportedGrantType_whenHandleResponse_thenDelegateReceivesLocalizedError() throws {
        try handleTokenResponse(domain: lightningDomain, errorCode: unsupportedGrantType)
        XCTAssertEqual(lastFailureError?.localizedDescription, lightningMessage)
    }

    func test_givenLightningSubdomainAndUnsupportedGrantType_whenHandleResponse_thenDelegateReceivesLocalizedError() throws {
        try handleTokenResponse(domain: lightningSubdomain, errorCode: unsupportedGrantType)
        XCTAssertEqual(lastFailureError?.localizedDescription, lightningMessage)
    }

    // MARK: - SC-2: Warning does NOT appear unless both conditions met

    func test_givenNonLightningURLAndUnsupportedGrantType_whenHandleResponse_thenDelegateReceivesGenericError() throws {
        try handleTokenResponse(domain: myDomain, errorCode: unsupportedGrantType)
        XCTAssertNotEqual(lastFailureError?.localizedDescription, lightningMessage)
    }

    func test_givenLightningURLAndDifferentError_whenHandleResponse_thenDelegateReceivesGenericError() throws {
        try handleTokenResponse(domain: lightningDomain, errorCode: invalidGrant)
        XCTAssertNotEqual(lastFailureError?.localizedDescription, lightningMessage)
    }

    // MARK: - SC-3: User-facing alert string is localized

    func test_givenLightningURLError_whenHandleResponse_thenErrorDescriptionMatchesLocalizedString() throws {
        try handleTokenResponse(domain: lightningDomain, errorCode: unsupportedGrantType)
        XCTAssertEqual(lastFailureError?.localizedDescription, lightningMessage)
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
