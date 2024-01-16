//
//  NativeLoginManagerTests.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 1/12/24.
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

final class NativeLoginManagerTests: XCTestCase {
    let nativeLoginManager = NativeLoginManagerInternal(clientId: "", redirectUri: "", loginUrl: "")
    
    override func setUpWithError() throws {
        _ = KeychainHelper.removeAll()
    }

    override func tearDownWithError() throws {
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
    }
    
    func testUsername() async {
        var result = await nativeLoginManager.login(username: "", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow empty username.")
        result = await nativeLoginManager.login(username: "test@c", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow invalid username.")
        
        // success
        result = await nativeLoginManager.login(username: "test@c.co   ", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should allow username.")
    }
    
    func testPassword() async {
        var result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should not allow invalid password.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "test123")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password shorter than 7 chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "123456789")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any letter chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "abcdefghi")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any numbers.")
        result = await nativeLoginManager.login(username: "user@name.com", password: "passuser@name.comword")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password that contains username.")
        
        // success
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "mypass12")
        XCTAssertEqual(.invalidCredentials, result, "Should not allow password without any numbers.")
    }
    
    func testShouldShowBackButton() {
        let accountManager = UserAccountManager.shared
        XCTAssertNil(accountManager.currentUserAccount)
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button by default.")
        guard let _ = try? createUser() else {
            XCTFail()
            return
        }
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user.")
        
        // Clear accuount
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when there are no other accounts.")
    }
    
    func testShouldShowBackButtonWithBioAuth() {
        guard let user = try? createUser() else {
            XCTFail()
            return
        }
        let bioAuthManager = BiometricAuthenticationManagerInternal.shared
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user (but not locked).")

        bioAuthManager.locked = true
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when bio auth is locked.")
    }
    
    func testShouldShowBackButtonWithIDP() {
        SalesforceManager.shared.identityProviderURLScheme = "test"
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when app is an identity provider.")
    }
    
    private func createUser() throws -> UserAccount {
        let credentials = OAuthCredentials(identifier: "identifier-0", clientId: "fakeClientIdForTesting", encrypted: true)!
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: [ "user_id": "0" ])
        try UserAccountManager.shared.upsert(user)
        UserAccountManager.shared.currentUserAccount = user
        
        return user
    }
}
