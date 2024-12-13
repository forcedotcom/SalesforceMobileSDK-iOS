//
//  ScreenLockManagerTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 10/12/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
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

class ScreenLockManagerTests: XCTestCase {
    override func setUpWithError() throws {
        ScreenLockManagerInternal.shared.backgroundTimestamp = 0
    }
    
    func testLockScreenTriggers() throws {
        // Login with first user with a mobile policy -- should trigger lock screen
        let user0 = try createNewUserAccount(index: 0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 1)
        XCTAssertTrue(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        
        // Backgrounding/foregrounding on lock -- lock screen should remain & callback shouldn't be called
        let expectation = XCTestExpectation(description: "Callback")
        expectation.isInverted = true
        ScreenLockManagerInternal.shared.setCallbackBlock {
            expectation.fulfill()
        }
        NotificationCenter.default.post(name:  UIApplication.didEnterBackgroundNotification, object: nil)
        ScreenLockManagerInternal.shared.handleAppForeground()
        XCTAssertTrue(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        wait(for: [expectation], timeout: 1)
        
        // Unlock
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        XCTAssertFalse(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        
        // Login with another user with a longer timeout -- should trigger lock screen
        let user1 = try createNewUserAccount(index: 1)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user1, hasMobilePolicy: true, lockTimeout: 20)
        XCTAssertTrue(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        XCTAssertFalse(SFSDKWindowManager.shared().screenLockWindow().isEnabled())

        // After backgrounding, adding a new user with a mobile policy should still trigger lock screen
        NotificationCenter.default.post(name:  UIApplication.didEnterBackgroundNotification, object: nil)
        let user2 = try createNewUserAccount(index: 2)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user2, hasMobilePolicy: true, lockTimeout: 5)
        XCTAssertTrue(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        XCTAssertFalse(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
        
        // Since the timeout hasn't expired, adding a new user without a mobile policy shouldn't trigger the lock screen
        let user3 = try createNewUserAccount(index: 3)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user3, hasMobilePolicy: false, lockTimeout: 5)
        XCTAssertFalse(SFSDKWindowManager.shared().screenLockWindow().isEnabled())

        // Since the timeout hasn't expired, backgrounding and adding a new user without a mobile policy shouldn't trigger the lock screen
        NotificationCenter.default.post(name:  UIApplication.didEnterBackgroundNotification, object: nil)
        let user4 = try createNewUserAccount(index: 4)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user4, hasMobilePolicy: false, lockTimeout: 5)
        ScreenLockManagerInternal.shared.handleAppForeground()
        XCTAssertFalse(SFSDKWindowManager.shared().screenLockWindow().isEnabled())
    }
    
    func createNewUserAccount(index: Int) throws -> UserAccount {
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true))
        let idDataDict = ["user_id" : String(index)]
        let idData = IdentityData(jsonDict: idDataDict)
        let user = UserAccount(credentials: credentials)
        user.idData = idData
        return user
    }
}
