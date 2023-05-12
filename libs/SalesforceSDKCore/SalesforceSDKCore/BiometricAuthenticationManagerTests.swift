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
