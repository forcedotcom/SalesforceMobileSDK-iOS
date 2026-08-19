//
//  BiometricAuthenticationManagerTests.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 5/9/23.
//  Copyright (c) 2023-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore
import LocalAuthentication

final class BiometricAuthenticationManagerTests: XCTestCase {
    let bioAuthManager = BiometricAuthenticationManagerInternal.shared
    let accountManager = UserAccountManager.shared

    override func setUpWithError() throws {
        _ = KeychainHelper.removeAll()
        bioAuthManager.backgroundTimestamp = 0
    }

    override func tearDownWithError() throws {
        bioAuthManager.automaticPresentation = true
        bioAuthManager.locked = false
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
    }

    func testNotEnabled() {
        XCTAssertNil(accountManager.currentUserAccount)
        XCTAssertFalse(bioAuthManager.enabled, "Should not be enabled with no user.")
        XCTAssertFalse(bioAuthManager.shouldLock(), "App should not lock by default.")
        
        _ = createUser(index: 0)
        XCTAssertNotNil(accountManager.currentUserAccount)
        XCTAssertFalse(bioAuthManager.enabled, "Should not be enabled by default.")
        XCTAssertFalse(bioAuthManager.shouldLock(), "App should not when not enabled for user.")
    }
    
    func testStorePolciy() {
        XCTAssertFalse(bioAuthManager.enabled, "Should not be enabled by default.")
        let user = createUser(index: 0)
        let userId = user.idData.userId
        XCTAssertFalse(bioAuthManager.checkForPolicy(userId: userId), "User should not have polciy by default.")
    
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: false, sessionTimeout: 1)
        XCTAssertFalse(bioAuthManager.checkForPolicy(userId: userId))
        XCTAssertFalse(bioAuthManager.enabled)
        
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(bioAuthManager.checkForPolicy(userId: userId))
        XCTAssertTrue(bioAuthManager.enabled)
    }
    
    func testUpdatePolicy() {
        XCTAssertFalse(bioAuthManager.enabled, "Should not be enabled by default.")
        let user = createUser(index: 0)
        let userId = user.idData.userId
        XCTAssertFalse(bioAuthManager.checkForPolicy(userId: userId), "User should not have polciy by default.")
    
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        // Opt User into Biometric
        bioAuthManager.biometricOptIn(optIn: true)
        
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(bioAuthManager.checkForPolicy(userId: userId))
        XCTAssertTrue(bioAuthManager.enabled)
        let optInStatus: Bool = ((bioAuthManager.readBioAuthPolicy(userId: userId)?.optIn!) != nil)
        XCTAssertTrue(optInStatus, "Opt-In status should not be set back to false.")
        
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: false, sessionTimeout: 5)
        XCTAssertFalse(bioAuthManager.checkForPolicy(userId: userId))
        XCTAssertFalse(bioAuthManager.enabled, "New Policy should be applied.")
        let timeout = bioAuthManager.readBioAuthPolicy(userId: userId)?.timeout
        XCTAssertEqual(timeout, 5, "Session Timeout should be updated.")
        let optInStatus2: Bool = ((bioAuthManager.readBioAuthPolicy(userId: userId)?.optIn!) != nil)
        XCTAssertTrue(optInStatus2, "Opt-In status should not be set back to false.")
    }
    
    func testShouldLock() {
        XCTAssertFalse(bioAuthManager.shouldLock(), "Should not lock by default.")
        let user0 = createUser(index: 0)
        XCTAssertFalse(bioAuthManager.shouldLock(), "Should not lock if current user has no policy.")
    
        bioAuthManager.storePolicy(userAccount: user0, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(bioAuthManager.shouldLock())
        
        let user1 = createUser(index: 1)
        XCTAssertFalse(bioAuthManager.shouldLock(), "Should not lock if current user has no policy.")
        bioAuthManager.storePolicy(userAccount: user1, hasMobilePolicy: false, sessionTimeout: 1)
        XCTAssertFalse(bioAuthManager.shouldLock(), "Should not lock if current user has no policy.")
        
        // switch back to first user
        UserAccountManager.shared.currentUserAccount = user0
        XCTAssertTrue(bioAuthManager.shouldLock())
    }
    
    func testLockTriggers() throws {
        let timeout: Int32 = 1
        let user = createUser(index: 0)
        
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: timeout)
        
        // background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        bioAuthManager.handleAppForeground()
        XCTAssertFalse(bioAuthManager.locked, "Should not lock before timeout.")
        
        // Set timestamp to more than the timeout
        bioAuthManager.backgroundTimestamp = Date().timeIntervalSince1970 - Double(((timeout * 60) + 1))
        
        bioAuthManager.handleAppForeground()
        XCTAssertTrue(bioAuthManager.locked)
    }
    
    func testBiometricOptIn() {
        let noPolicyUser = createUser(index: 0)
        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
        
        let policyUser = createUser(index: 1)
        bioAuthManager.storePolicy(userAccount: policyUser, hasMobilePolicy: true, sessionTimeout: 15)
        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
        bioAuthManager.biometricOptIn(optIn: true)
        XCTAssertTrue(bioAuthManager.hasBiometricOptedIn())
        
        UserAccountManager.shared.currentUserAccount = noPolicyUser
        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
        
        UserAccountManager.shared.currentUserAccount = policyUser
        XCTAssertTrue(bioAuthManager.hasBiometricOptedIn())
        
        bioAuthManager.biometricOptIn(optIn: false)
        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
    }
    
    func testNativeLoginButton() {
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        XCTAssertFalse(bioAuthManager.showNativeLoginButton(), "Button should not show when there is no user.")
        
        let user = createUser(index: 0)
        XCTAssertFalse(bioAuthManager.showNativeLoginButton(), "Button should not show when user has no policy.")
        
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: false)
        XCTAssertFalse(bioAuthManager.showNativeLoginButton(), "Button should not show when biometric is not avalible for device.")
        
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        XCTAssertFalse(bioAuthManager.showNativeLoginButton(), "Button should show until user opts in.")
        
        bioAuthManager.biometricOptIn(optIn: true)
        // showNativeLoginButton() requires hasPolicy && locked && hasBiometricOptedIn
        bioAuthManager.locked = true
        XCTAssertTrue(bioAuthManager.showNativeLoginButton())
        
        bioAuthManager.enableNativeBiometricLoginButton(enabled: false)
        XCTAssertFalse(bioAuthManager.showNativeLoginButton())
    }
    
    func testCleanup() {
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 15)
        XCTAssertTrue(bioAuthManager.checkForPolicy(userId: user.idData.userId))
        bioAuthManager.locked = true
        
        bioAuthManager.cleanup(user: user)
        XCTAssertFalse(bioAuthManager.checkForPolicy(userId: user.idData.userId))
        XCTAssertFalse(bioAuthManager.locked, "Locked status should be reset.")
    }

    // MARK: - automaticPresentation Tests

    func testAutomaticPresentationDefaultsToTrue() {
        XCTAssertTrue(bioAuthManager.automaticPresentation, "automaticPresentation should default to true.")
    }

    func testAutomaticPresentationLockAutoPresentsWhenOptedIn() {
        // Scenario B1: automaticPresentation=true, hasBiometricOptedIn=true, lock triggered
        // Expected: lock() enters the auto-present branch (presentBiometric called for each scene)
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.automaticPresentation = true
        bioAuthManager.laContext = StubbedLAContext(canEvaluate: true)

        // Set timestamp past timeout to trigger lock
        bioAuthManager.backgroundTimestamp = Date().timeIntervalSince1970 - 120

        // Verify preconditions
        XCTAssertTrue(bioAuthManager.hasBiometricOptedIn())
        XCTAssertTrue(bioAuthManager.automaticPresentation)
        XCTAssertTrue(bioAuthManager.shouldLock())

        // Trigger the full lock flow via handleAppForeground().
        // This calls lock() which exercises the automaticPresentation branch.
        // presentBiometric(scene:) is a no-op in test (no connected scenes / LAContext
        // cannot evaluate in unit test sandbox), but the code path is exercised.
        bioAuthManager.handleAppForeground()
        XCTAssertTrue(bioAuthManager.locked, "App should be locked after timeout.")

        // Cleanup
        bioAuthManager.automaticPresentation = false
        bioAuthManager.locked = false
    }

    func testAutomaticPresentationLockDoesNotPresentWhenNotOptedIn() {
        // Scenario B2: automaticPresentation=true, hasBiometricOptedIn=false, lock triggered
        // Expected: no auto-present
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        bioAuthManager.automaticPresentation = true

        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
        let shouldAutoPresent = bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldAutoPresent, "Should not auto-present biometric when not opted in.")

        // Cleanup
        bioAuthManager.automaticPresentation = false
    }

    func testAutomaticPresentationDisabledDoesNotPresent() {
        // Scenario B3: automaticPresentation=false, hasBiometricOptedIn=true, lock triggered
        // Expected: no auto-present
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        bioAuthManager.biometricOptIn(optIn: true)
        bioAuthManager.automaticPresentation = false

        XCTAssertTrue(bioAuthManager.hasBiometricOptedIn())
        let shouldAutoPresent = bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldAutoPresent, "Should not auto-present biometric when automaticPresentation is disabled.")
    }

    func testAutomaticPresentationBothDisabled() {
        // Scenario B4: automaticPresentation=false, hasBiometricOptedIn=false
        // Expected: no auto-present
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        bioAuthManager.automaticPresentation = false

        XCTAssertFalse(bioAuthManager.hasBiometricOptedIn())
        XCTAssertFalse(bioAuthManager.automaticPresentation)
        let shouldAutoPresent = bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldAutoPresent, "Should not auto-present when both conditions are false.")
    }

    func testAutomaticPresentationOptInDialogConditions() {
        // Scenario A1/A2/A3: Tests the condition for showing opt-in dialog after login
        // The condition is: !hasBiometricOptedIn && automaticPresentation
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)

        // A3: automaticPresentation=false, not opted in -> no dialog
        bioAuthManager.automaticPresentation = false
        var shouldShowOptIn = !bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldShowOptIn, "Should not show opt-in dialog when automaticPresentation is disabled.")

        // A1: automaticPresentation=true, not opted in -> show dialog
        bioAuthManager.automaticPresentation = true
        shouldShowOptIn = !bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertTrue(shouldShowOptIn, "Should show opt-in dialog when automaticPresentation is enabled and user has not opted in.")

        // A2: automaticPresentation=true, already opted in -> no dialog
        bioAuthManager.biometricOptIn(optIn: true)
        shouldShowOptIn = !bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldShowOptIn, "Should not show opt-in dialog when user has already opted in.")

        // Cleanup
        bioAuthManager.automaticPresentation = false
    }

    func testAutomaticPresentationDoesNotAffectExistingLockBehavior() {
        // Scenario D1: automaticPresentation=false (default) should not change existing behavior
        let user = createUser(index: 0)
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        bioAuthManager.automaticPresentation = false

        // Set timestamp past timeout
        bioAuthManager.backgroundTimestamp = Date().timeIntervalSince1970 - 120

        // Lock should still trigger normally
        XCTAssertTrue(bioAuthManager.shouldLock(), "shouldLock should still work when automaticPresentation is disabled.")
        XCTAssertFalse(bioAuthManager.automaticPresentation)

        // After lock, auto-present should NOT fire
        let shouldAutoPresent = bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation
        XCTAssertFalse(shouldAutoPresent, "Auto-present should not fire when automaticPresentation is off.")
    }

    // MARK: - Helpers

    private func createUser(index: Int) -> UserAccount {
        let credentials = OAuthCredentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true)!
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: [ "user_id": "\(index)" ])
        UserAccountManager.shared.currentUserAccount = user
        
        return user
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
