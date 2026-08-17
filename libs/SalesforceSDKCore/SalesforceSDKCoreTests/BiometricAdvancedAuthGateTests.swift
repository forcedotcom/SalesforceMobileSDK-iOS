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
import LocalAuthentication
@testable import SalesforceSDKCore

// MARK: - Biometric + Advanced Auth Gate Tests
//
// Covers SFUserAccountManager's `oauthCoordinator:willBeginBrowserAuthentication:` gate together
// with BiometricAuthenticationManagerInternal.suppressInitialBrowserAuthentication, the one-shot
// flag `lock()` arms right before it triggers the very browser-auth attempt that would otherwise
// race the biometric prompt `lock()` also presents. The gate consumes (clears) that flag on its
// very next check, win or lose -- being locked must never again suppress a later attempt (e.g. a
// server picked from the fallback picker, or a retry from the login-options gear menu). This
// intentionally does NOT re-derive the decision from `locked`/`showNativeLoginButton()` on every
// call, unlike the superseded implementation this file used to pin.

class BiometricAdvancedAuthGateTests: XCTestCase {

    let bioAuthManager = BiometricAuthenticationManagerInternal.shared
    private var originalAuthCancelledByUserHandlerBlock: (() -> Void)?

    override func setUpWithError() throws {
        try super.setUpWithError()
        _ = KeychainHelper.removeAll()
        bioAuthManager.locked = false
        bioAuthManager.automaticPresentation = true
        bioAuthManager.suppressInitialBrowserAuthentication = false
        originalAuthCancelledByUserHandlerBlock = UserAccountManager.shared.authCancelledByUserHandlerBlock
        // The gate's biometric-fallback branch presents a host-list screen unless a handler
        // block is installed; force the nil/default path so the fallback UI is deterministic.
        UserAccountManager.shared.authCancelledByUserHandlerBlock = nil
    }

    override func tearDownWithError() throws {
        bioAuthManager.locked = false
        bioAuthManager.automaticPresentation = true
        bioAuthManager.suppressInitialBrowserAuthentication = false
        UserAccountManager.shared.authCancelledByUserHandlerBlock = originalAuthCancelledByUserHandlerBlock
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        try super.tearDownWithError()
    }

    // MARK: - Tests

    func test_willBeginBrowserAuth_whenSuppressionArmed_returnsNoAndPresentsBiometric() throws {
        let uam = UserAccountManager.shared
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.locked = true
        // Mirrors what lock() does: capture the suppression decision once, ahead of the browser
        // launch it's about to trigger, rather than the gate re-deriving it from `locked`.
        bioAuthManager.suppressInitialBrowserAuthentication = true

        let session = makeAuthSession(uam: uam)
        var capturedProceed: Bool?
        let expectation = expectation(description: "willBeginBrowserAuthentication callback invoked")

        uam.oauthCoordinator(session.oauthCoordinator, willBeginBrowserAuthentication: { proceed in
            capturedProceed = proceed
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(capturedProceed, false, "Callback must be invoked with NO to suppress the native browser launch when the one-shot flag is armed")
        XCTAssertNil(session.oauthCoordinator.asWebAuthenticationSession, "No ASWebAuthenticationSession should be allocated when the browser launch is suppressed")
        XCTAssertFalse(bioAuthManager.suppressInitialBrowserAuthentication, "The gate must consume (clear) the one-shot flag on this check, regardless of outcome")

        // Clean up the host-list fallback screen the gate presents on the auth window.
        dismissPresentedAuthWindow(uam: uam)
        removeSession(session, from: uam)
    }

    func test_willBeginBrowserAuth_whenSuppressionNotArmed_returnsYesEvenWhileLocked() throws {
        // This is the regression case: a picker-driven re-selection (or any
        // browser-auth attempt other than the one lock() itself triggered) must launch Advanced
        // Auth normally while still locked -- `locked` alone must never suppress it again.
        let uam = UserAccountManager.shared
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.locked = true
        XCTAssertTrue(bioAuthManager.showNativeLoginButton(), "Test precondition: this scenario is exercising the case where showNativeLoginButton() would be true, yet the gate must still proceed because the one-shot flag was already consumed")
        bioAuthManager.suppressInitialBrowserAuthentication = false

        let session = makeAuthSession(uam: uam)
        var capturedProceed: Bool?
        let expectation = expectation(description: "willBeginBrowserAuthentication callback invoked")

        uam.oauthCoordinator(session.oauthCoordinator, willBeginBrowserAuthentication: { proceed in
            capturedProceed = proceed
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(capturedProceed, true, "Callback must be invoked with YES once the one-shot flag has already been consumed, even while still locked")

        removeSession(session, from: uam)
    }

    func test_willBeginBrowserAuth_whenNotLocked_returnsYes() throws {
        let uam = UserAccountManager.shared
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.locked = false
        bioAuthManager.suppressInitialBrowserAuthentication = false

        let session = makeAuthSession(uam: uam)
        var capturedProceed: Bool?
        let expectation = expectation(description: "willBeginBrowserAuthentication callback invoked")

        uam.oauthCoordinator(session.oauthCoordinator, willBeginBrowserAuthentication: { proceed in
            capturedProceed = proceed
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(capturedProceed, true, "Callback must be invoked with YES for the regression (unlocked) case")

        removeSession(session, from: uam)
    }

    func test_lock_armsSuppressionFlagFromShowNativeLoginButtonAtCallTime() throws {
        // lock() must capture the suppression decision once, at the moment it's about to trigger
        // login() -- not leave it to be re-derived later from the (by-then-stale) `locked` state.
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.automaticPresentation = false
        bioAuthManager.locked = false

        bioAuthManager.lock()

        XCTAssertTrue(bioAuthManager.locked, "lock() must set locked = true")
        XCTAssertTrue(bioAuthManager.suppressInitialBrowserAuthentication, "lock() must arm the one-shot suppression flag when showNativeLoginButton() was true at call time")

        UserAccountManager.shared.stopCurrentAuthentication(nil)
    }

    func test_handleAppForeground_whenAlreadyLocked_doesNotRearmSuppressionFlag() throws {
        // Mirrors the guard already added to Android's AppLockManager.onAppForegrounded() for this
        // same bug: shouldLock() derives purely from a timeout elapsed since
        // backgroundTimestamp, without consulting `locked` -- so any foreground notification while
        // already locked (the OS backgrounding the app behind the Face ID sheet, or momentarily
        // losing/regaining foreground during presentBiometric's catch-block retry) calls lock()
        // again. That second lock() re-arms suppressInitialBrowserAuthentication, wrongly
        // suppressing the very retry that just cleared it -- reproducing the reported symptom
        // where cancelling Face ID or tapping "Use Password" lands on the fallback picker instead
        // of launching Advanced Auth.
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.automaticPresentation = false
        bioAuthManager.locked = true
        bioAuthManager.suppressInitialBrowserAuthentication = false

        bioAuthManager.handleAppForeground()

        XCTAssertFalse(bioAuthManager.suppressInitialBrowserAuthentication, "handleAppForeground() must not call lock() again while already locked, which would re-arm the one-shot suppression flag and strand a subsequent browser-auth attempt")

        UserAccountManager.shared.stopCurrentAuthentication(nil)
    }

    func test_willBeginBrowserAuth_whenSuppressedAndCancelHandlerSet_invokesHandlerInsteadOfPicker() throws {
        // presentLoginHostListViewControllerForBiometricFallback: short-circuits to the app-provided
        // authCancelledByUserHandlerBlock when one is installed, instead of presenting the built-in
        // host-list picker. This is the handler-block branch (the nil-handler picker branch is
        // covered by test_willBeginBrowserAuth_whenSuppressionArmed_...).
        let uam = UserAccountManager.shared
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.locked = true
        bioAuthManager.suppressInitialBrowserAuthentication = true

        let handlerCalled = expectation(description: "authCancelledByUserHandlerBlock invoked")
        uam.authCancelledByUserHandlerBlock = { handlerCalled.fulfill() }

        let session = makeAuthSession(uam: uam)
        let gateReturned = expectation(description: "willBeginBrowserAuthentication callback invoked")
        var capturedProceed: Bool?
        uam.oauthCoordinator(session.oauthCoordinator, willBeginBrowserAuthentication: { proceed in
            capturedProceed = proceed
            gateReturned.fulfill()
        })

        wait(for: [gateReturned, handlerCalled], timeout: 2.0)
        XCTAssertEqual(capturedProceed, false, "Browser launch must still be suppressed when a cancel handler is installed")

        removeSession(session, from: uam)
    }

    // MARK: - resumeBrowserAuthentication:

    func test_resumeBrowserAuthentication_whenBrowserBlockHeld_firesItWithYes() throws {
        // The no-teardown resume path: the suppressed attempt's held browser-launch callback is
        // fired with YES to continue Advanced Auth on the SAME session, leaving its covering window
        // in place.
        guard let scene = activeWindowScene() else {
            throw XCTSkip("No active UIWindowScene in the test host")
        }
        let uam = UserAccountManager.shared
        let session = makeAuthSession(uam: uam)

        let blockFired = expectation(description: "held browser block fired")
        var capturedProceed: Bool?
        session.authCoordinatorBrowserBlock = { proceed in
            capturedProceed = proceed
            blockFired.fulfill()
        }

        uam.resumeBrowserAuthentication(scene)

        wait(for: [blockFired], timeout: 2.0)
        XCTAssertEqual(capturedProceed, true, "resumeBrowserAuthentication: must fire the held callback with YES to resume the browser")

        removeSession(session, from: uam)
    }

    func test_resumeBrowserAuthentication_whenNoBrowserBlock_tearsDownSuppressedSession() throws {
        // Fallback path: with no held callback (e.g. the session was already torn down), the method
        // stops the current authentication and restarts login rather than doing nothing. Verify the
        // suppressed session is torn down via stopCurrentAuthentication.
        guard let scene = activeWindowScene() else {
            throw XCTSkip("No active UIWindowScene in the test host")
        }
        let uam = UserAccountManager.shared
        let session = makeAuthSession(uam: uam)
        session.isAuthenticating = true
        session.authCoordinatorBrowserBlock = nil
        let sceneId = session.sceneId as NSString

        uam.resumeBrowserAuthentication(scene)

        let stillSameSession = (uam.authSessions[sceneId] as AnyObject?) === session
        XCTAssertFalse(stillSameSession, "The suppressed session must be torn down by stopCurrentAuthentication before login is restarted")

        // login() may have started a fresh attempt / presented UI -- tear it all down.
        uam.stopCurrentAuthentication(nil)
        dismissPresentedAuthWindow(uam: uam)
        removeSession(session, from: uam)
    }

    // MARK: - Biometric cancellation resume (Swift)

    func test_handleBiometricCancellation_resumesHeldBrowserSession() throws {
        // handleBiometricCancellation(_:) is the extracted body of presentBiometric's catch block
        // (unreachable in CI because presentBiometric builds a real LAContext). It waits for the
        // scene to reactivate, then resumes the suppressed browser session.
        guard let scene = activeWindowScene() else {
            throw XCTSkip("No active UIWindowScene in the test host")
        }
        let uam = UserAccountManager.shared
        let session = makeAuthSession(uam: uam)

        let blockFired = expectation(description: "held browser block fired via cancellation handler")
        session.authCoordinatorBrowserBlock = { _ in blockFired.fulfill() }

        Task { await bioAuthManager.handleBiometricCancellation(scene) }
        // Unblock waitForSceneActive in case the test scene is not already active.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        }

        wait(for: [blockFired], timeout: 5.0)
        removeSession(session, from: uam)
    }

    func test_waitForSceneActive_returnsImmediatelyWhenAlreadyActive() throws {
        guard let scene = activeWindowScene() else {
            throw XCTSkip("No active UIWindowScene in the test host")
        }
        // The test host's scene is .foregroundActive, so this exercises the early-return guard.
        XCTAssertEqual(scene.activationState, .foregroundActive, "Test precondition: host scene must be active")
        let resolved = expectation(description: "waitForSceneActive resolved via early return")
        Task { @MainActor in
            await bioAuthManager.waitForSceneActive(scene)
            resolved.fulfill()
        }
        wait(for: [resolved], timeout: 5.0)
    }

    func test_awaitSceneActivation_resolvesOnActivationNotification() throws {
        guard let scene = activeWindowScene() else {
            throw XCTSkip("No active UIWindowScene in the test host")
        }
        // Exercises the continuation/observer path directly (the caller's early-return guard would
        // otherwise skip it, since the host scene is already active).
        let resolved = expectation(description: "awaitSceneActivation resolved on activation")
        Task { @MainActor in
            await bioAuthManager.awaitSceneActivation(scene)
            resolved.fulfill()
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        }
        wait(for: [resolved], timeout: 5.0)
    }

    func test_resumeGuard_permitsResumeExactlyOnce() throws {
        let guardLatch = BiometricAuthenticationManagerInternal.ResumeGuard()
        XCTAssertTrue(guardLatch.tryResume(), "First tryResume() must succeed")
        XCTAssertFalse(guardLatch.tryResume(), "Second tryResume() must fail -- the latch is one-shot")
        XCTAssertFalse(guardLatch.tryResume(), "Subsequent tryResume() calls must keep failing")
    }

    // MARK: - Helpers

    private func activeWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes.first as? UIWindowScene
    }

    private func createUser(index: Int) -> UserAccount {
        let credentials = OAuthCredentials(identifier: "gate-identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true)!
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: ["user_id": "\(index)"])
        UserAccountManager.shared.currentUserAccount = user
        return user
    }

    private func makeAuthRequest() -> SFSDKAuthRequest {
        let request = SFSDKAuthRequest()
        request.oauthClientId = "testClientId"
        request.oauthCompletionUrl = "test://callback"
        request.loginHost = "test.salesforce.com"
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            request.scene = windowScene
        }
        return request
    }

    /// Builds an SFSDKAuthSession with its coordinator delegate set to UserAccountManager.shared
    /// and registered in `authSessions`, mirroring LoginForAdminTests' pattern for directly
    /// invoking SFOAuthCoordinatorDelegate methods without running the full authenticate() flow.
    private func makeAuthSession(uam: UserAccountManager) -> SFSDKAuthSession {
        let request = makeAuthRequest()
        let session = SFSDKAuthSession(request, credentials: nil)
        session.oauthCoordinator.delegate = uam
        uam.authSessions[session.sceneId as NSString] = session
        return session
    }

    private func removeSession(_ session: SFSDKAuthSession, from uam: UserAccountManager) {
        uam.authSessions.removeObject(session.sceneId as NSString)
    }

    /// The gate's biometric-fallback branch presents a host-list screen on the auth window
    /// (mirroring oauthCoordinatorDidCancelBrowserAuthentication:'s existing fallback UI); tear
    /// it down so it doesn't leak into subsequent tests.
    private func dismissPresentedAuthWindow(uam: UserAccountManager) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let authWindow = SFSDKWindowManager.shared().authWindow(windowScene)
        authWindow.viewController?.dismiss(animated: false, completion: nil)
        authWindow.dismissWindow()
    }

    private class StubbedLAContext: LAContext {
        let canEvaluate: Bool

        init(canEvaluate: Bool) {
            self.canEvaluate = canEvaluate
        }

        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
            return canEvaluate
        }
    }
}
