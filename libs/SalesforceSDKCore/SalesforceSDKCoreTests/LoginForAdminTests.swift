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
        let initialDomain = session.oauthCoordinator.credentials?.domain
        XCTAssertEqual(session.oauthRequest.loginHost, initialDomain,
                       "Test precondition: oauthRequest.loginHost should equal coordinator credentials.domain on a fresh non-discovery session")

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
        // The request's loginHost must NEVER be mutated — LFA carries its My Domain
        // through the LFA-scoped override field instead. This is the invariant that
        // keeps Reload / Clear Cache / post-cancel-restart pointed at the originally
        // configured host.
        XCTAssertEqual(session.oauthRequest.loginHost, initialDomain,
                       "loginHost must remain unchanged regardless of LFA invocation")
        XCTAssertEqual(session.oauthRequest.loginAsAdminMyDomain, initialDomain,
                       "loginAsAdminMyDomain should be set from coordinator.credentials.domain on a non-discovery host")

        // Clean up
        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    func test_givenPhase1Discovery_whenLoginForAdminSelected_thenIsNoOp() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        // Phase 1 of Welcome Discovery: loginHost is the discovery domain and the
        // coordinator has not yet observed a custom domain update.
        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        request.loginAsAdmin = false
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.domainUpdated,
                       "Test precondition: coordinator.domainUpdated should be NO in phase 1")
        uam.authSessions[sceneId as NSString] = session

        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        let selector = NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")
        uam.perform(selector, with: loginVC)

        XCTAssertFalse(session.oauthRequest.loginAsAdmin,
                       "loginAsAdmin must remain false during phase-1 Welcome Discovery — Login for Admin is a no-op")
        XCTAssertEqual(session.oauthRequest.loginHost, "welcome.salesforce.com/discovery",
                       "loginHost must remain the discovery host")
        XCTAssertNil(session.oauthRequest.loginAsAdminMyDomain,
                     "loginAsAdminMyDomain must remain nil — no override during phase 1")
        XCTAssertNil(session.oauthRequest.loginAsAdminLoginHint,
                     "loginAsAdminLoginHint must remain nil — no override during phase 1")

        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    func test_givenPhase2Discovery_whenLoginForAdminSelected_thenMyDomainOverrideSet() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        // Phase 2 of Welcome Discovery: the user has picked an account on the
        // discovery page and the coordinator has updated credentials.domain to
        // the resolved My Domain.
        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        request.loginAsAdmin = false
        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.domainUpdated = true
        session.oauthCoordinator.credentials?.domain = "mycompany.my.salesforce.com"
        session.oauthCoordinator.loginHint = "admin@mycompany.com"
        uam.authSessions[sceneId as NSString] = session

        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        let selector = NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")
        uam.perform(selector, with: loginVC)

        XCTAssertTrue(session.oauthRequest.loginAsAdmin,
                      "loginAsAdmin should be true after Login for Admin in phase 2")
        XCTAssertEqual(session.oauthRequest.loginHost, "welcome.salesforce.com/discovery",
                       "loginHost must remain the discovery host — Reload / Clear Cache / cancel-restart depend on this invariant")
        XCTAssertEqual(session.oauthRequest.loginAsAdminMyDomain, "mycompany.my.salesforce.com",
                       "loginAsAdminMyDomain should record the resolved My Domain (in-memory only, not persisted)")
        XCTAssertEqual(session.oauthRequest.loginAsAdminLoginHint, "admin@mycompany.com",
                       "loginAsAdminLoginHint should record the discovery-resolved hint so authenticateWithRequest: can forward it")

        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    func test_givenPhase2Discovery_whenLoginForAdminSelected_thenLoginHostStorageNotPolluted() {
        // The brief explicitly forbids persisting the My Domain to SFSDKLoginHostStorage
        // / NSUserDefaults during the discovery → admin transition.
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.domainUpdated = true
        session.oauthCoordinator.credentials?.domain = "mycompany.my.salesforce.com"
        uam.authSessions[sceneId as NSString] = session

        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        let selector = NSSelectorFromString("loginViewControllerDidSelectLoginForAdmin:")
        uam.perform(selector, with: loginVC)

        let storedHost = SFSDKLoginHostStorage.sharedInstance().loginHost(forHostAddress: "mycompany.my.salesforce.com")
        XCTAssertNil(storedHost, "Login for Admin must not persist the My Domain into SFSDKLoginHostStorage")

        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    func test_authRequestRoundTripsLoginAsAdminOverrides() {
        // The LFA-scoped override fields on SFSDKAuthRequest must round-trip so that
        // restartAuthentication: can forward them through authenticateWithRequest:loginHint:
        // without mutating the request's permanent loginHost.
        let request = makeAuthRequest()
        XCTAssertNil(request.loginAsAdminMyDomain, "loginAsAdminMyDomain should default to nil")
        XCTAssertNil(request.loginAsAdminLoginHint, "loginAsAdminLoginHint should default to nil")

        request.loginAsAdminMyDomain = "mycompany.my.salesforce.com"
        request.loginAsAdminLoginHint = "admin@mycompany.com"
        XCTAssertEqual(request.loginAsAdminMyDomain, "mycompany.my.salesforce.com")
        XCTAssertEqual(request.loginAsAdminLoginHint, "admin@mycompany.com")

        // After putting the request inside a session, the properties are still observable.
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertEqual(session.oauthRequest.loginAsAdminMyDomain, "mycompany.my.salesforce.com",
                       "Session.oauthRequest.loginAsAdminMyDomain should match the value set on the request")
        XCTAssertEqual(session.oauthRequest.loginAsAdminLoginHint, "admin@mycompany.com",
                       "Session.oauthRequest.loginAsAdminLoginHint should match the value set on the request")
    }

    func test_givenLfaOverridesSet_whenBrowserAuthCancelled_thenOverridesCleared() {
        // After the user backs out of the LFA browser session, both overrides and
        // the loginAsAdmin flag must be cleared so subsequent settings actions
        // (Reload, Clear Cache) and the next browser launch do not pick up stale state.
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        request.loginAsAdmin = true
        request.loginAsAdminMyDomain = "mycompany.my.salesforce.com"
        request.loginAsAdminLoginHint = "admin@mycompany.com"
        let session = SFSDKAuthSession(request, credentials: nil)
        uam.authSessions[sceneId as NSString] = session

        uam.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        XCTAssertFalse(session.oauthRequest.loginAsAdmin,
                       "loginAsAdmin must be cleared after the LFA browser session is cancelled")
        XCTAssertNil(session.oauthRequest.loginAsAdminMyDomain,
                     "loginAsAdminMyDomain must be cleared on cancel so a subsequent restart uses the original loginHost")
        XCTAssertNil(session.oauthRequest.loginAsAdminLoginHint,
                     "loginAsAdminLoginHint must be cleared on cancel so a subsequent restart does not carry stale hint")
        XCTAssertEqual(session.oauthRequest.loginHost, "welcome.salesforce.com/discovery",
                       "loginHost must remain the originally configured discovery host across the cancel path")

        uam.authSessions.removeObject(sceneId as NSString)
    }

    // MARK: - SFLoginViewController.shouldShowLoginForAdminForSession: helper

    func test_givenNilSession_whenShouldShowLoginForAdmin_thenReturnsTrue() {
        XCTAssertTrue(SalesforceLoginViewController.shouldShowLoginForAdmin(for: nil),
                      "Should default to YES (show) when no session is available")
    }

    func test_givenNonDiscoveryHost_whenShouldShowLoginForAdmin_thenReturnsTrue() {
        let request = makeAuthRequest()
        request.loginHost = "login.salesforce.com"
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertTrue(SalesforceLoginViewController.shouldShowLoginForAdmin(for: session),
                      "Login for Admin should be visible on a non-discovery host")
    }

    func test_givenPhase1DiscoveryHost_whenShouldShowLoginForAdmin_thenReturnsFalse() {
        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.domainUpdated,
                       "Test precondition: domainUpdated == NO for phase 1")
        XCTAssertFalse(SalesforceLoginViewController.shouldShowLoginForAdmin(for: session),
                       "Login for Admin should be hidden in phase 1 of Welcome Discovery")
    }

    func test_givenPhase2DiscoveryHost_whenShouldShowLoginForAdmin_thenReturnsTrue() {
        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.domainUpdated = true
        session.oauthCoordinator.credentials?.domain = "mycompany.my.salesforce.com"
        XCTAssertTrue(SalesforceLoginViewController.shouldShowLoginForAdmin(for: session),
                      "Login for Admin should be visible once Welcome Discovery has resolved a My Domain (phase 2)")
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

    @available(*, deprecated, message: "Exercises deprecated public API")
    func test_givenPhase1Discovery_whenPublicLoginForAdminCalled_thenIsNoOp() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        let request = makeAuthRequest()
        request.loginHost = "welcome.salesforce.com/discovery"
        request.loginAsAdmin = false
        let session = SFSDKAuthSession(request, credentials: nil)
        XCTAssertFalse(session.oauthCoordinator.domainUpdated,
                       "Test precondition: domainUpdated == NO for phase 1")
        uam.authSessions[sceneId as NSString] = session

        let loginVC = SalesforceLoginViewController()
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = loginVC
        window.makeKeyAndVisible()
        loginVC.loadViewIfNeeded()

        // Public API should match the protocol method's no-op behavior in phase 1.
        uam.loginViewControllerDidSelectLoginForAdmin(loginVC)

        XCTAssertFalse(session.oauthRequest.loginAsAdmin,
                       "Public loginViewControllerDidSelectLoginForAdmin must no-op during phase-1 discovery")
        XCTAssertEqual(session.oauthRequest.loginHost, "welcome.salesforce.com/discovery",
                       "loginHost must remain unchanged during phase-1 no-op")

        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    // MARK: - SFUserAccountManager hostListViewControllerDidChangeLoginOptions (forced advanced auth)

    func test_givenAuthSession_whenHostListChangesLoginOptions_thenAuthRequestRecreatedAndRestarted() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        let request = makeAuthRequest()
        request.loginHost = "test.salesforce.com"
        let session = SFSDKAuthSession(request, credentials: nil)
        uam.authSessions[sceneId as NSString] = session

        // Place a host list VC in the window so its view.window.windowScene resolves to the
        // same scene the session is keyed under. It must live inside a UINavigationController —
        // the host list styles its nav bar on appearance (self.navigationController), matching
        // how production presents it in the auth window.
        let hostListVC = LoginHostListViewController(style: .plain)
        let navController = UINavigationController(rootViewController: hostListVC)
        let window = windowScene.windows.first ?? UIWindow(windowScene: windowScene)
        window.rootViewController = navController
        window.makeKeyAndVisible()
        hostListVC.loadViewIfNeeded()
        // Force layout so the nav controller attaches the host list's view into the window
        // hierarchy; production reads hostListViewController.view.window.windowScene to find
        // the session, so view.window must be non-nil before we invoke the delegate.
        window.layoutIfNeeded()
        XCTAssertNotNil(hostListVC.view.window,
                        "Test precondition: host list view must be attached to the window")
        XCTAssertEqual(hostListVC.view.window?.windowScene?.session.persistentIdentifier, sceneId,
                       "Test precondition: host list must resolve to the seeded scene")

        // Invoke the delegate method via performSelector since the SFSDKLoginHostDelegate
        // conformance on UserAccountManager is internal.
        let selector = NSSelectorFromString("hostListViewControllerDidChangeLoginOptions:")
        XCTAssertTrue(uam.responds(to: selector),
                      "UserAccountManager should respond to hostListViewControllerDidChangeLoginOptions:")
        uam.perform(selector, with: hostListVC)

        // The session's request is recreated from the manager defaults (so changed login options
        // take effect) while preserving the originally configured login host.
        XCTAssertFalse(session.oauthRequest === request,
                       "oauthRequest should be recreated (a fresh default request) when login options change")
        XCTAssertEqual(session.oauthRequest.loginHost, "test.salesforce.com",
                       "The recreated request must preserve the originally configured login host")

        // Clean up
        uam.stopCurrentAuthentication()
        uam.authSessions.removeObject(sceneId as NSString)
        window.rootViewController = nil
    }

    // MARK: - SFUserAccountManager Cancel Browser Auth (forced-advanced-auth host list landing)

    func test_givenNoHandlerBlock_whenBrowserAuthCancelled_thenHostListPresentedWithChrome() {
        let uam = UserAccountManager.shared

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            XCTFail("Test requires a UIWindowScene from the running test app")
            return
        }
        let sceneId = windowScene.session.persistentIdentifier

        // Reach the host-list branch: not loginAsAdmin, not native-login fallback, and no
        // cancel handler block installed.
        let originalHandler = uam.authCancelledByUserHandlerBlock
        let originalNativeLogin = uam.nativeLoginEnabled
        let originalFallback = uam.shouldFallbackToWebAuthentication
        uam.authCancelledByUserHandlerBlock = nil
        uam.nativeLoginEnabled = false
        uam.shouldFallbackToWebAuthentication = false

        let request = makeAuthRequest()
        request.loginAsAdmin = false
        request.useBrowserAuth = true
        request.scene = windowScene
        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = uam
        uam.authSessions[sceneId as NSString] = session

        uam.oauthCoordinatorDidCancelBrowserAuthentication(session.oauthCoordinator)

        // The host list is presented on the auth window with the forced-advanced-auth chrome.
        let authWindow = SFSDKWindowManager.shared().authWindow(windowScene)
        let nav = authWindow.viewController?.presentedViewController as? UINavigationController
        let hostList = nav?.viewControllers.first as? LoginHostListViewController
        XCTAssertNotNil(hostList, "The host list should be presented on the auth window after cancelling browser auth")
        XCTAssertTrue(hostList?.showsBackButtonAndLoginOptions ?? false,
                      "The presented host list should surface the back button and Login Options chrome")
        XCTAssertTrue(hostList?.hidesCancelButton ?? false,
                      "The presented host list should hide the Cancel button in the forced-advanced-auth path")

        // Drive the back button from the presented host list. With no idp flow this takes the
        // non-idp branch, dismissing the presented view controller and then the auth window via
        // its completion block. This exercises handleBackButtonAction end-to-end against a real
        // presented VC (rather than the bare no-op case in SFSDKLoginHostTests).
        hostList?.perform(NSSelectorFromString("handleBackButtonAction"))

        // Clean up (idempotent even though the back action already dismisses)
        authWindow.viewController?.dismiss(animated: false, completion: nil)
        authWindow.dismissWindow()
        uam.authSessions.removeObject(sceneId as NSString)
        uam.authCancelledByUserHandlerBlock = originalHandler
        uam.nativeLoginEnabled = originalNativeLogin
        uam.shouldFallbackToWebAuthentication = originalFallback
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
