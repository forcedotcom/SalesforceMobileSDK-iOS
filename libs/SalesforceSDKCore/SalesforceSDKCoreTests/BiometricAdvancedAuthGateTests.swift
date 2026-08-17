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

    // MARK: - Helpers

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
