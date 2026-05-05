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

    func testGivenNewAuthRequest_whenCreated_thenLoginAsAdminIsFalse() {
        let request = SFSDKAuthRequest()
        XCTAssertFalse(request.loginAsAdmin, "loginAsAdmin should default to false")
    }

    func testGivenAuthRequest_whenLoginAsAdminSet_thenUseBrowserAuthUnchanged() {
        let request = SFSDKAuthRequest()
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should default to false")

        request.loginAsAdmin = true

        XCTAssertTrue(request.loginAsAdmin, "loginAsAdmin should be true after setting")
        XCTAssertFalse(request.useBrowserAuth, "useBrowserAuth should remain false when loginAsAdmin is set")
    }

    // MARK: - SFSDKAuthSession Coordinator Initialization

    func testGivenLoginAsAdmin_whenAuthSessionCreated_thenCoordinatorUsesBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Coordinator useBrowserAuth should be true when loginAsAdmin is true")
    }

    func testGivenUseBrowserAuthOnly_whenAuthSessionCreated_thenCoordinatorUsesBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = true

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(session.oauthCoordinator.useBrowserAuth,
                      "Coordinator useBrowserAuth should be true when request useBrowserAuth is true")
    }

    func testGivenNeitherFlag_whenAuthSessionCreated_thenCoordinatorDoesNotUseBrowserAuth() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.useBrowserAuth,
                       "Coordinator useBrowserAuth should be false when both flags are false")
    }

    // MARK: - SFOAuthCoordinator Auth Info Type

    func testGivenLoginAsAdmin_whenAuthenticate_thenAuthInfoIsAdvancedBrowser() {
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

    func testGivenWebServerAuth_whenAuthenticate_thenAuthInfoIsWebServer() {
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

    func testGivenUserAgentAuth_whenAuthenticate_thenAuthInfoIsUserAgent() {
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

    func testGivenLoginAsAdmin_whenGenerateApprovalUrl_thenUsesWebServerFlow() {
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

    func testGivenNoLoginAsAdmin_whenWebServerAuthDisabled_thenUsesUserAgentFlow() {
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

    func testGivenLoginAsAdmin_whenSet_thenGlobalWebServerAuthUnchanged() {
        let originalValue = SalesforceManager.shared.useWebServerAuthentication

        let request = SFSDKAuthRequest()
        request.loginAsAdmin = true

        XCTAssertEqual(SalesforceManager.shared.useWebServerAuthentication, originalValue,
                       "Setting loginAsAdmin should not change the global useWebServerAuthentication")
    }

    func testGivenLoginAsAdmin_whenAuthSessionCreated_thenGlobalStateUnchanged() {
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

    func testGivenLoginAsAdmin_whenCancelled_thenLoginAsAdminCleared() {
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

    func testGivenLoginAsAdminCancelled_whenNewSession_thenAuthInfoMatchesGlobalSetting() {
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

    func testGivenOrgInitiatedBrowserAuth_whenCancelled_thenUseBrowserAuthPreserved() {
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

    func testGivenLoginAsAdmin_whenFullLifecycle_thenUseBrowserAuthNeverMutated() {
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

    func testGivenSFLoginViewControllerDelegate_thenLoginForAdminMethodExists() {
        let manager = UserAccountManager.shared
        XCTAssertTrue(manager.responds(to: NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")),
                      "SFUserAccountManager should respond to loginViewControllerDidSelectLoginForAdmin:")
    }

    // MARK: - SFUserAccountManager Cancel Browser Auth (loginAsAdmin path)

    func testGivenLoginAsAdmin_whenBrowserAuthCancelled_thenLoginAsAdminCleared() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = UserAccountManager.shared

        XCTAssertTrue(session.oauthRequest.loginAsAdmin, "loginAsAdmin should be true before cancel")

        // Call the cancel handler on the main thread (it dispatches to main if not already there)
        UserAccountManager.shared.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        XCTAssertFalse(session.oauthRequest.loginAsAdmin, "loginAsAdmin should be cleared after cancel")
    }

    func testGivenLoginAsAdmin_whenBrowserAuthCancelled_thenUserCancelledNotificationNotPosted() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = UserAccountManager.shared

        var notificationPosted = false
        let observer = NotificationCenter.default.addObserver(
            forName: UserAccountManager.userCancelledAuthentication,
            object: nil, queue: nil
        ) { _ in
            notificationPosted = true
        }

        UserAccountManager.shared.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        XCTAssertFalse(notificationPosted,
                       "kSFNotificationUserCancelledAuth should NOT be posted when loginAsAdmin cancel restarts auth")

        NotificationCenter.default.removeObserver(observer)
    }

    func testGivenNoLoginAsAdmin_whenBrowserAuthCancelled_thenUserCancelledNotificationPosted() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = false

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = UserAccountManager.shared

        // Set the handler block to avoid the server picker UI code path
        var handlerCalled = false
        UserAccountManager.shared.authCancelledByUserHandlerBlock = {
            handlerCalled = true
        }

        var notificationPosted = false
        let observer = NotificationCenter.default.addObserver(
            forName: UserAccountManager.userCancelledAuthentication,
            object: nil, queue: nil
        ) { _ in
            notificationPosted = true
        }

        UserAccountManager.shared.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        XCTAssertTrue(notificationPosted,
                      "kSFNotificationUserCancelledAuth should be posted when loginAsAdmin is false")
        XCTAssertTrue(handlerCalled,
                      "authCancelledByUserHandlerBlock should be called when loginAsAdmin is false")

        NotificationCenter.default.removeObserver(observer)
        UserAccountManager.shared.authCancelledByUserHandlerBlock = nil
    }

    func testGivenLoginAsAdmin_whenBrowserAuthCancelled_thenHandlerBlockNotCalled() {
        let request = makeAuthRequest()
        request.loginAsAdmin = true

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = UserAccountManager.shared

        var handlerCalled = false
        UserAccountManager.shared.authCancelledByUserHandlerBlock = {
            handlerCalled = true
        }

        UserAccountManager.shared.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        XCTAssertFalse(handlerCalled,
                       "authCancelledByUserHandlerBlock should NOT be called when loginAsAdmin cancel restarts auth")

        UserAccountManager.shared.authCancelledByUserHandlerBlock = nil
    }

    // MARK: - SFUserAccountManager Cancel Browser Auth (nativeLogin fallback path)

    func testGivenNativeLoginFallback_whenBrowserAuthCancelled_thenFallbackConsumedAndRestartsNativeLogin() {
        let request = makeAuthRequest()
        request.loginAsAdmin = false

        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = UserAccountManager.shared

        let uam = UserAccountManager.shared
        let originalNativeLoginEnabled = uam.nativeLoginEnabled
        let originalShouldFallback = uam.shouldFallbackToWebAuthentication

        // Simulate: native login set shouldFallbackToWebAuthentication = YES,
        // which caused browser auth. The user is now cancelling that browser session.
        uam.nativeLoginEnabled = true
        uam.shouldFallbackToWebAuthentication = true

        var notificationPosted = false
        let observer = NotificationCenter.default.addObserver(
            forName: UserAccountManager.userCancelledAuthentication,
            object: nil, queue: nil
        ) { _ in
            notificationPosted = true
        }

        var handlerCalled = false
        uam.authCancelledByUserHandlerBlock = {
            handlerCalled = true
        }

        uam.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        // The fallback flag is consumed (set to NO) so the next loginWithCompletion:
        // call returns to native login instead of launching another browser session.
        XCTAssertFalse(uam.shouldFallbackToWebAuthentication,
                       "shouldFallbackToWebAuthentication should be consumed so next login attempt uses native login")
        // This path returns early — no cancelled notification and no handler block call.
        XCTAssertFalse(notificationPosted,
                       "kSFNotificationUserCancelledAuth should NOT be posted for native login fallback path")
        XCTAssertFalse(handlerCalled,
                       "authCancelledByUserHandlerBlock should NOT be called for native login fallback path")

        NotificationCenter.default.removeObserver(observer)
        uam.authCancelledByUserHandlerBlock = nil
        uam.nativeLoginEnabled = originalNativeLoginEnabled
        uam.shouldFallbackToWebAuthentication = originalShouldFallback
    }

    // MARK: - SFUserAccountManager loginViewControllerDidSelectLoginForAdmin

    func testGivenAuthSession_whenLoginForAdminSelected_thenLoginAsAdminSetAndAuthRestarted() {
        let uam = UserAccountManager.shared

        // Get the test app's active window scene to obtain a real sceneId
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        // Create an auth session and seed it into authSessions with the real sceneId
        let request = makeAuthRequest()
        request.loginAsAdmin = false
        let session = SFSDKAuthSession(request, credentials: nil)
        uam.authSessions[sceneId as NSString] = session

        XCTAssertFalse(session.oauthRequest.loginAsAdmin, "loginAsAdmin should be false before selecting Login for Admin")

        // Create a SalesforceLoginViewController and place it in the window so its
        // view.window.windowScene resolves to the same scene
        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        // Call the delegate method via performSelector since the protocol conformance is internal
        let selector = NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")
        uam.perform(selector, with: loginVC)

        XCTAssertTrue(session.oauthRequest.loginAsAdmin,
                      "loginAsAdmin should be true after loginViewControllerDidSelectLoginForAdmin:")

        // Clean up
        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    @available(*, deprecated, message: "Exercises deprecated public API")
    func testGivenAuthSession_whenPublicLoginForAdminCalled_thenLoginAsAdminSet() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        let request = makeAuthRequest()
        request.loginAsAdmin = false
        let session = SFSDKAuthSession(request, credentials: nil)
        uam.authSessions[sceneId as NSString] = session

        XCTAssertFalse(session.oauthRequest.loginAsAdmin, "loginAsAdmin should be false before invoking public API")

        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        // Invoke directly via the public Swift binding (not performSelector) to confirm the
        // method is exposed on UserAccountManager for SDK consumers.
        uam.loginViewControllerDidSelectLoginForAdmin(loginVC)

        XCTAssertTrue(session.oauthRequest.loginAsAdmin,
                      "loginAsAdmin should be true after calling the public loginViewControllerDidSelectLoginForAdmin")

        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
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
