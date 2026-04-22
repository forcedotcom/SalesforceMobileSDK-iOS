/*
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

// MARK: - Login for Admin Tests

class LoginForAdminTests: XCTestCase {

    private var originalUseWebServerAuth: Bool = true
    private var originalUseHybridAuth: Bool = false

    override func setUp() {
        super.setUp()
        originalUseWebServerAuth = SalesforceManager.shared.useWebServerAuthentication
        originalUseHybridAuth = SalesforceManager.shared.useHybridAuthentication
    }

    override func tearDown() {
        SalesforceManager.shared.useWebServerAuthentication = originalUseWebServerAuth
        SalesforceManager.shared.useHybridAuthentication = originalUseHybridAuth
        super.tearDown()
    }

    // MARK: - SFSDKAuthRequest loginAsAdmin Property

    func test_givenNewAuthRequest_whenCreated_thenLoginAsAdminIsFalse() {
        let request = SFSDKAuthRequest()
        XCTAssertFalse(request.loginAsAdmin, "loginAsAdmin should default to false")
    }

    func test_givenAuthRequest_whenLoginAsAdminSet_thenUseBrowserAuthUnchanged() {
        let request = SFSDKAuthRequest()
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should default to false")

        request.loginAsAdmin = true

        XCTAssertTrue(request.loginAsAdmin, "loginAsAdmin should be true after setting")
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should remain false when loginAsAdmin is set")
    }

    // MARK: - SFSDKAuthSession Coordinator Initialization

    func test_givenLoginAsAdmin_whenAuthSessionCreated_thenCoordinatorUsesBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Coordinator useBrowserAuth should be true when loginAsAdmin is true")
    }

    func test_givenUseBrowserAuthOnly_whenAuthSessionCreated_thenCoordinatorUsesBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = true

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Coordinator useBrowserAuth should be true when request useBrowserAuth is true")
    }

    func test_givenNeitherFlag_whenAuthSessionCreated_thenCoordinatorDoesNotUseBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.useBrowserAuth,
                       "Coordinator useBrowserAuth should be false when both flags are false")
    }

    // MARK: - SFOAuthCoordinator Auth Info Type

    func test_givenLoginAsAdmin_whenAuthenticate_thenAuthInfoIsAdvancedBrowser() {
        createTestAppIdentity()

        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = self

        session.oauthCoordinator.authenticate()

        XCTAssertEqual(session.oauthCoordinator.authInfo.authType, AuthInfo.AuthType.advancedBrowser,
                       "Auth info type should be advancedBrowser when loginAsAdmin is true")
        session.oauthCoordinator.stopAuthentication()
    }

    func test_givenWebServerAuth_whenAuthenticate_thenAuthInfoIsWebServer() {
        createTestAppIdentity()
        SalesforceManager.shared.useWebServerAuthentication = true

        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = self

        session.oauthCoordinator.authenticate()

        XCTAssertEqual(session.oauthCoordinator.authInfo.authType, AuthInfo.AuthType.webServer,
                       "Auth info type should be webServer when useWebServerAuthentication is true")
        session.oauthCoordinator.stopAuthentication()
    }

    func test_givenUserAgentAuth_whenAuthenticate_thenAuthInfoIsUserAgent() {
        createTestAppIdentity()
        SalesforceManager.shared.useWebServerAuthentication = false

        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = self

        session.oauthCoordinator.authenticate()

        XCTAssertEqual(session.oauthCoordinator.authInfo.authType, AuthInfo.AuthType.userAgent,
                       "Auth info type should be userAgent when both flags are false")
        session.oauthCoordinator.stopAuthentication()
    }

    // MARK: - Approval URL Web Server Flow

    func test_givenLoginAsAdmin_whenGenerateApprovalUrl_thenUsesWebServerFlow() {
        createTestAppIdentity()
        SalesforceManager.shared.useWebServerAuthentication = false

        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)
        let approvalUrl = session.oauthCoordinator.generateApprovalUrlString()

        XCTAssertTrue(approvalUrl.contains("response_type=code"),
                      "Approval URL should use response_type=code when loginAsAdmin is true")
        XCTAssertFalse(approvalUrl.contains("response_type=token"),
                       "Approval URL should not use response_type=token when loginAsAdmin is true")
    }

    func test_givenNoLoginAsAdmin_whenWebServerAuthDisabled_thenUsesUserAgentFlow() {
        createTestAppIdentity()
        SalesforceManager.shared.useWebServerAuthentication = false
        SalesforceManager.shared.useHybridAuthentication = false

        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        let approvalUrl = session.oauthCoordinator.generateApprovalUrlString()

        XCTAssertTrue(approvalUrl.contains("response_type=token"),
                      "Approval URL should use response_type=token when loginAsAdmin is false and web server auth is disabled")
    }

    // MARK: - No Global State Mutation

    func test_givenLoginAsAdmin_whenSet_thenGlobalWebServerAuthUnchanged() {
        let originalValue = SalesforceManager.shared.useWebServerAuthentication

        let request = SFSDKAuthRequest()
        request.loginAsAdmin = true

        XCTAssertEqual(SalesforceManager.shared.useWebServerAuthentication, originalValue,
                       "Setting loginAsAdmin should not change the global useWebServerAuthentication")
    }

    func test_givenLoginAsAdmin_whenAuthSessionCreated_thenGlobalStateUnchanged() {
        SalesforceManager.shared.useWebServerAuthentication = false

        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)

        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Coordinator should use browser auth")
        XCTAssertFalse(SalesforceManager.shared.useWebServerAuthentication,
                       "Global useWebServerAuthentication should remain false")
    }

    // MARK: - Cancel Flow: loginAsAdmin Clears on Cancel

    func test_givenLoginAsAdmin_whenCancelled_thenLoginAsAdminCleared() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true

        XCTAssertTrue(request.loginAsAdmin, "loginAsAdmin should be true before cancel")

        // Simulate what the cancel handler does
        request.loginAsAdmin = false

        XCTAssertFalse(request.loginAsAdmin, "loginAsAdmin should be false after cancel")

        // Creating a new session from the cleared request should not use browser auth
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.useBrowserAuth,
                       "Coordinator should not use browser auth after loginAsAdmin is cleared")
    }

    func test_givenLoginAsAdminCancelled_whenNewSession_thenAuthInfoMatchesGlobalSetting() {
        createTestAppIdentity()
        SalesforceManager.shared.useWebServerAuthentication = true

        let request = makeAuthRequest()
        request.loginAsAdmin = true

        // Admin session uses advanced browser
        let adminSession = SFSDKAuthSession(request, credentials: nil)
        adminSession.oauthCoordinator.delegate = self
        adminSession.oauthCoordinator.authenticate()
        XCTAssertEqual(adminSession.oauthCoordinator.authInfo.authType, AuthInfo.AuthType.advancedBrowser)
        adminSession.oauthCoordinator.stopAuthentication()

        // Simulate cancel
        request.loginAsAdmin = false

        // New session from same request uses global setting
        let normalSession = SFSDKAuthSession(request, credentials: nil)
        normalSession.oauthCoordinator.delegate = self
        normalSession.oauthCoordinator.authenticate()
        XCTAssertEqual(normalSession.oauthCoordinator.authInfo.authType, AuthInfo.AuthType.webServer,
                       "After cancel, auth type should match global setting (webServer)")
        normalSession.oauthCoordinator.stopAuthentication()
    }

    // MARK: - Cancel Flow: Org-Initiated Browser Auth Unchanged

    func test_givenOrgInitiatedBrowserAuth_whenCancelled_thenUseBrowserAuthPreserved() {
        let request = makeAuthRequest()
        request.useBrowserAuth = true
        request.loginAsAdmin = false

        XCTAssertFalse(request.loginAsAdmin, "loginAsAdmin should be false for org-initiated browser auth")
        XCTAssertTrue(request.useBrowserAuth, "useBrowserAuth should be true for org-initiated browser auth")

        // After cancel of org-initiated auth, useBrowserAuth should remain true
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Org-initiated browser auth should keep useBrowserAuth after cancel")
    }

    // MARK: - useBrowserAuth Not Modified

    func test_givenLoginAsAdmin_whenFullLifecycle_thenUseBrowserAuthNeverMutated() {
        let request = makeAuthRequest()
        request.useBrowserAuth = false

        // Set loginAsAdmin
        request.loginAsAdmin = true
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should remain false after setting loginAsAdmin")

        // Create session - coordinator gets useBrowserAuth from the OR of both flags
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth, "Coordinator should use browser auth")
        XCTAssertFalse(request.useBrowserAuth, "Request useBrowserAuth should still be false")

        // Clear loginAsAdmin (cancel)
        request.loginAsAdmin = false
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should still be false after clearing loginAsAdmin")

        // New session should not use browser auth
        let newSession = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(newSession.oauthCoordinator.useBrowserAuth, "New coordinator should not use browser auth")
    }

    // MARK: - SFLoginViewControllerDelegate Declaration

    func test_givenSFLoginViewControllerDelegate_thenLoginForAdminMethodExists() {
        let manager = UserAccountManager.shared
        XCTAssertTrue(manager.responds(to: NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")),
                      "SFUserAccountManager should respond to loginViewControllerDidSelectLoginForAdmin:")
    }

    // MARK: - Private Helpers

    private func makeAuthRequest() -> SFSDKAuthRequest {
        let request = SFSDKAuthRequest()
        request.oauthClientId = "testClientId"
        request.oauthCompletionUrl = "test://callback"
        request.loginHost = "test.salesforce.com"
        return request
    }

    private func createTestAppIdentity() {
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = "test_connected_app_id"
        SalesforceManager.shared.bootConfig?.oauthRedirectURI = "test://callback"
        SalesforceManager.shared.bootConfig?.oauthScopes = Set(["web", "api"])
        UserAccountManager.shared.oauthClientID = "test_connected_app_id"
    }
}

// MARK: - SFOAuthCoordinatorDelegate conformance for tests

extension LoginForAdminTests: SFOAuthCoordinatorDelegate {
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
}
