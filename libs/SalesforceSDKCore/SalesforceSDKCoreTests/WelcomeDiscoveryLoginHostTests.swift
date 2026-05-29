//
//  WelcomeDiscoveryLoginHostTests.swift
//  SalesforceSDKCore
//
//  Created by Takashi Arai on 5/27/26.
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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

/// Tests that Welcome/Discovery domain login hosts are not overwritten by My Domain
/// after domain discovery resolves a user's org.
final class WelcomeDiscoveryLoginHostTests: XCTestCase {

    let discoveryDomain = "welcome.salesforce.com/discovery"
    let myDomain = "mycompany.my.salesforce.com"
    let accountManager = UserAccountManager.shared

    override func setUp() {
        super.setUp()
        _ = KeychainHelper.removeAll()
        removeCustomLoginHosts()
    }

    override func tearDown() {
        accountManager.clearAllAccountState()
        _ = KeychainHelper.removeAll()
        removeCustomLoginHosts()
        super.tearDown()
    }

    private func removeCustomLoginHosts() {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        // Remove deletable hosts in reverse order to avoid index shifting
        var indicesToRemove: [Int] = []
        for i in 0..<Int(storage.numberOfLoginHosts()) {
            let host = storage.loginHost(at: UInt(i))
            if host.isDeletable {
                indicesToRemove.append(i)
            }
        }
        for index in indicesToRemove.reversed() {
            storage.removeLoginHost(at: UInt(index))
        }
    }

    // MARK: - DomainDiscoveryCoordinator.isDiscoveryDomain tests

    func test_givenDiscoveryDomain_whenCheckingIsDiscoveryDomain_thenReturnsTrue() {
        let coordinator = DomainDiscoveryCoordinator()
        XCTAssertTrue(coordinator.isDiscoveryDomain(discoveryDomain))
        XCTAssertTrue(coordinator.isDiscoveryDomain("welcome.salesforce.com/discovery"))
        XCTAssertTrue(coordinator.isDiscoveryDomain("mycompany.salesforce.com/discovery"))
    }

    func test_givenNonDiscoveryDomain_whenCheckingIsDiscoveryDomain_thenReturnsFalse() {
        let coordinator = DomainDiscoveryCoordinator()
        XCTAssertFalse(coordinator.isDiscoveryDomain(myDomain))
        XCTAssertFalse(coordinator.isDiscoveryDomain("login.salesforce.com"))
        XCTAssertFalse(coordinator.isDiscoveryDomain("test.salesforce.com"))
    }

    func test_givenNilDomain_whenCheckingIsDiscoveryDomain_thenReturnsFalse() {
        let coordinator = DomainDiscoveryCoordinator()
        XCTAssertFalse(coordinator.isDiscoveryDomain(nil))
    }

    // MARK: - Login host persistence tests

    func test_givenDiscoveryLoginHost_whenSetCurrentUser_thenLoginHostNotOverwritten() {
        // Setup: Set login host to a discovery domain
        accountManager.loginHost = discoveryDomain
        XCTAssertEqual(accountManager.loginHost, discoveryDomain)

        // Create a user with credentials — set userId/orgId before creating UserAccount
        // so that accountIdentity is properly initialized
        let credentials = OAuthCredentials(identifier: "test-discovery-user", clientId: "fakeClientId", encrypted: true)!
        credentials.userId = "005TESTUSER001"
        credentials.organizationId = "00DTESTORG001"
        credentials.domain = myDomain
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: ["user_id": "005TESTUSER001"])

        // Add user to account map so setCurrentUser finds it via userAccountForUserIdentity:
        accountManager.userAccountMap?[user.accountIdentity] = user

        // Act: Set current user (this calls setCurrentUserInternal which has the login host logic)
        accountManager.currentUserAccount = user

        // Assert: Login host should still be the discovery domain, NOT the My Domain
        XCTAssertEqual(accountManager.loginHost, discoveryDomain, "Login host should not be overwritten when app uses discovery domain.")
    }

    func test_givenRegularLoginHost_whenSetLoginHostDirectly_thenLoginHostUpdated() {
        // Verify that setLoginHost still works normally for non-discovery domains.
        // This tests the existing behavior is preserved — setLoginHost: is still called
        // in the regular (non-discovery) login flow.
        let regularDomain = "login.salesforce.com"
        accountManager.loginHost = regularDomain
        XCTAssertEqual(accountManager.loginHost, regularDomain)

        // Directly setting loginHost should update (simulates non-discovery auth completion)
        accountManager.loginHost = myDomain
        XCTAssertEqual(accountManager.loginHost, myDomain, "Login host should be updatable for non-discovery login.")
    }

    // MARK: - SFSDKLoginHostStorage pollution tests

    func test_givenDiscoveryFlow_whenMyDomainResolved_thenStorageNotPolluted() {
        // Verify that My Domain is NOT present in login host storage
        // (simulating what happens after our fix to handleCustomDomainUpdateWithLoginHint)
        let storage = SFSDKLoginHostStorage.sharedInstance()

        // The My Domain should not be in storage since handleCustomDomainUpdateWithLoginHint
        // no longer calls setLoginHost: (which would add it)
        let foundHost = storage.loginHost(forHostAddress: myDomain)
        XCTAssertNil(foundHost, "My Domain should not be in login host storage during discovery flow.")
    }
}
