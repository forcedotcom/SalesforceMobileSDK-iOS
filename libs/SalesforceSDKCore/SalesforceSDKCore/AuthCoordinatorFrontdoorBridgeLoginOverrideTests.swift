//
//  AuthCoordinatorFrontdoorBridgeLoginOverrideTests.swift
//  SalesforceSDKCore
//
//  Created by Eric C. Johnson on 09/04/2025.
//  Copyright (c) 2025-present, Salesforce.com, Inc. All rights reserved.
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

// MARK: - Main Test Class

class AuthCoordinatorFrontdoorBridgeLoginOverrideTests: XCTestCase {
    
    private var originalConsumerKey: String?
    private var originalLoginHost: String?
    private var originalCurrentUser: UserAccount?
    
    override func setUp() {
        super.setUp()
        
        // Store original values
        originalConsumerKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey
        originalLoginHost = UserAccountManager.shared.loginHost
        originalCurrentUser = UserAccountManager.shared.currentUserAccount
    }
    
    override func tearDown() {
        // Restore original values
        if let originalConsumerKey = originalConsumerKey {
            SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = originalConsumerKey
        }
        if let originalLoginHost = originalLoginHost {
            UserAccountManager.shared.loginHost = originalLoginHost
        }
        //UserAccountManager.shared.setCurrentUserInternal(originalCurrentUser)
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createValidFrontdoorURL(host: String, clientId: String) -> URL {
        let startURL = "https://\(host)/services/oauth2/authorize?client_id=\(clientId)&redirect_uri=sfdc%3A%2F%2F%2Faxm%2Fdetect%2Foauth%2Fdone&response_type=code"
        let encodedStartURL = startURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? startURL
        return URL(string: "https://\(host)/frontdoor?startURL=\(encodedStartURL)")!
    }
    
    private func createInvalidFrontdoorURL(host: String) -> URL {
        return URL(string: "https://\(host)/frontdoor?invalid=parameter")!
    }
    
    // MARK: - Tests with Valid Consumer Key and Login Host Match (.my. domain)
    
    func testValidMyDomainURL_WithMatchingConsumerKeyAndLoginHost_WithCodeVerifier() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let codeVerifier = "test_code_verifier_456"
        let frontdoorUrl = createValidFrontdoorURL(host: "mycompany.my.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "mycompany.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: codeVerifier,
            selectedAppLoginHost: "mycompany.my.salesforce.com"
        )
        
        // Then
        XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl)
        XCTAssertEqual(override.codeVerifier, codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost)
    }
    
    func testValidMyDomainURL_WithMatchingConsumerKeyAndLoginHost_WithoutCodeVerifier() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = createValidFrontdoorURL(host: "example.my.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "example.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: nil,
            selectedAppLoginHost: "example.my.salesforce.com"
        )
        
        // Then
        XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost)
    }
    
    func testValidMyDomainURL_WithDifferentSelectedAppLoginHost() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = createValidFrontdoorURL(host: "company1.my.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "login.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "company2.my.salesforce.com"
        )
        
        // Then - Should still match because the system will find a matching host
        XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl)
        XCTAssertEqual(override.codeVerifier, "test_verifier")
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost)
    }
    
    // MARK: - Tests with Valid Consumer Key and Login Host Match (non-.my. domain)
    
    func testValidNonMyDomainURL_WithMatchingConsumerKeyAndLoginHost() {
        // Given
        let consumerKey = "prod_consumer_key_789"
        let codeVerifier = "prod_code_verifier_012"
        let frontdoorUrl = createValidFrontdoorURL(host: "login.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "login.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: codeVerifier,
            selectedAppLoginHost: "login.salesforce.com"
        )
        
        // Then
        XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl)
        XCTAssertEqual(override.codeVerifier, codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost)
    }
    
    func testValidSandboxURL_WithMatchingConsumerKeyAndLoginHost() {
        // Given
        let consumerKey = "sandbox_consumer_key_345"
        let frontdoorUrl = createValidFrontdoorURL(host: "test.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "test.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: nil,
            selectedAppLoginHost: "test.salesforce.com"
        )
        
        // Then
        XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost)
    }
    
    // MARK: - Tests with Mismatched Consumer Key
    
    func testValidURL_WithMismatchedConsumerKey_MyDomain() {
        // Given
        let appConsumerKey = "app_consumer_key_123"
        let urlConsumerKey = "different_consumer_key_456"
        let frontdoorUrl = createValidFrontdoorURL(host: "test.my.salesforce.com", clientId: urlConsumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = appConsumerKey
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Properties should not be set due to consumer key mismatch
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost) // Host still matches
    }
    
    func testValidURL_WithMismatchedConsumerKey_NonMyDomain() {
        // Given
        let appConsumerKey = "app_consumer_key_789"
        let urlConsumerKey = "different_consumer_key_012"
        let frontdoorUrl = createValidFrontdoorURL(host: "login.salesforce.com", clientId: urlConsumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = appConsumerKey
        UserAccountManager.shared.loginHost = "login.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "login.salesforce.com"
        )
        
        // Then - Properties should not be set due to consumer key mismatch
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost) // Host still matches
    }
    
    // MARK: - Tests with Mismatched Login Host
    
    func testValidURL_WithMismatchedLoginHost_MyDomain() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = createValidFrontdoorURL(host: "company1.my.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "company2.my.different.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "company2.my.different.com",
            addingAndSwitchingLoginHostsPerMdm: false,
            addingAndSwitchingLoginHostsOverride: false
        )
        
        // Then - Properties should not be set due to login host mismatch
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertFalse(override.matchesLoginHost)
    }
    
    func testValidURL_WithMismatchedLoginHost_NonMyDomain() {
        // Given
        let consumerKey = "test_consumer_key_456"
        let frontdoorUrl = createValidFrontdoorURL(host: "login.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "test.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "different.salesforce.com",
            addingAndSwitchingLoginHostsPerMdm: false,
            addingAndSwitchingLoginHostsOverride: false
        )
        
        // Then - Properties should not be set due to login host mismatch
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertTrue(override.matchesConsumerKey)
        XCTAssertFalse(override.matchesLoginHost)
    }
    
    // MARK: - Tests with Invalid URL Formats
    
    func testInvalidURL_MissingStartURL() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = URL(string: "https://test.my.salesforce.com/frontdoor?invalid=parameter")!
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Should fail early due to missing startURL
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertFalse(override.matchesLoginHost)
    }
    
    func testInvalidURL_MalformedStartURL() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = URL(string: "https://test.my.salesforce.com/frontdoor?startURL=invalid_url")!
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Should fail due to malformed startURL
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertFalse(override.matchesLoginHost)
    }
    
    func testInvalidURL_MissingClientId() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let startURL = "https://test.my.salesforce.com/services/oauth2/authorize?redirect_uri=sfdc%3A%2F%2F%2Faxm%2Fdetect%2Foauth%2Fdone&response_type=code"
        let encodedStartURL = startURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? startURL
        let frontdoorUrl = URL(string: "https://test.my.salesforce.com/frontdoor?startURL=\(encodedStartURL)")!
        
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = consumerKey
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Should fail due to missing client_id
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertFalse(override.matchesLoginHost)
    }
    
    // MARK: - Tests with Missing Boot Config
    
    func testValidURL_WithNilBootConfig() {
        // Given
        let consumerKey = "test_consumer_key_123"
        let frontdoorUrl = createValidFrontdoorURL(host: "test.my.salesforce.com", clientId: consumerKey)
        
        SalesforceManager.shared.bootConfig = nil
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Should fail due to missing boot config
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost) /* Matching continues for login host even after consumer key mismatch as designed */
    }
    
    func testValidURL_WithNilConsumerKey() {
        // Given
        let urlConsumerKey = "test_consumer_key_123"
        let frontdoorUrl = createValidFrontdoorURL(host: "test.my.salesforce.com", clientId: urlConsumerKey)
        
        SalesforceManager.shared.bootConfig = nil
        UserAccountManager.shared.loginHost = "test.my.salesforce.com"
        
        // When
        let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: frontdoorUrl,
            codeVerifier: "test_verifier",
            selectedAppLoginHost: "test.my.salesforce.com"
        )
        
        // Then - Should fail due to nil consumer key in boot config
        XCTAssertNil(override.frontdoorBridgeUrl)
        XCTAssertNil(override.codeVerifier)
        XCTAssertFalse(override.matchesConsumerKey)
        XCTAssertTrue(override.matchesLoginHost) /* Matching continues for login host even after consumer key mismatch as designed */
    }
    
    // MARK: - Comprehensive Test Cases
    
    func testAllPermutations_MyDomainUrls() {
        let testCases: [(frontdoorHost: String, clientId: String, appConsumerKey: String, selectedHost: String, codeVerifier: String?, expectedFrontdoorUrl: Bool, expectedCodeVerifier: Bool, expectedMatchesConsumerKey: Bool, expectedMatchesLoginHost: Bool, addingAndSwitchingLoginHostsPerMdm: Bool, addingAndSwitchingLoginHostsOverride: Bool)] = [
            // Valid cases with .my. domains
            ("company.my.salesforce.com", "key123", "key123", "company.my.salesforce.com", "verifier1", true, true, true, true, true, true),
            ("test.my.salesforce.com", "key456", "key456", "test.my.salesforce.com", nil, true, false, true, true, true, true),
            
            // Mismatched consumer key cases
            ("company.my.salesforce.com", "key123", "different_key", "company.my.salesforce.com", "verifier1", false, false, false, true, true, true),
            
            // Mismatched login host cases
            ("company1.my.salesforce.com", "key123", "key123", "company2.my.different.com", "verifier1", false, false, true, false, false, false),
        ]
        
        for (index, testCase) in testCases.enumerated() {
            // Given
            let frontdoorUrl = createValidFrontdoorURL(host: testCase.frontdoorHost, clientId: testCase.clientId)
            SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = testCase.appConsumerKey
            UserAccountManager.shared.loginHost = testCase.selectedHost
            
            // When
            let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: frontdoorUrl,
                codeVerifier: testCase.codeVerifier,
                selectedAppLoginHost: testCase.selectedHost,
                addingAndSwitchingLoginHostsPerMdm: testCase.addingAndSwitchingLoginHostsPerMdm,
                addingAndSwitchingLoginHostsOverride: testCase.addingAndSwitchingLoginHostsOverride
            )
            
            // Then
            if testCase.expectedFrontdoorUrl {
                XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl, "Test case \(index + 1): frontdoorBridgeUrl mismatch")
            } else {
                XCTAssertNil(override.frontdoorBridgeUrl, "Test case \(index + 1): frontdoorBridgeUrl should be nil")
            }
            
            if testCase.expectedCodeVerifier {
                XCTAssertEqual(override.codeVerifier, testCase.codeVerifier, "Test case \(index + 1): codeVerifier mismatch")
            } else {
                XCTAssertNil(override.codeVerifier, "Test case \(index + 1): codeVerifier should be nil")
            }
            
            XCTAssertEqual(override.matchesConsumerKey, testCase.expectedMatchesConsumerKey, "Test case \(index + 1): matchesConsumerKey mismatch")
            XCTAssertEqual(override.matchesLoginHost, testCase.expectedMatchesLoginHost, "Test case \(index + 1): matchesLoginHost mismatch")
        }
    }
    
    func testAllPermutations_NonMyDomainUrls() {
        let testCases: [(frontdoorHost: String, clientId: String, appConsumerKey: String, selectedHost: String, codeVerifier: String?, expectedFrontdoorUrl: Bool, expectedCodeVerifier: Bool, expectedMatchesConsumerKey: Bool, expectedMatchesLoginHost: Bool, addingAndSwitchingLoginHostsPerMdm: Bool, addingAndSwitchingLoginHostsOverride: Bool)] = [
            // Valid cases with non-.my. domains
            ("login.salesforce.com", "key123", "key123", "login.salesforce.com", "verifier1", true, true, true, true, true, true),
            ("test.salesforce.com", "key456", "key456", "test.salesforce.com", nil, true, false, true, true, true, true),
            
            // Mismatched consumer key cases
            ("login.salesforce.com", "key123", "different_key", "login.salesforce.com", "verifier1", false, false, false, true, true, true),
            
            // Mismatched login host cases
            ("login.salesforce.com", "key123", "key123", "test.salesforce.com", "verifier1", false, false, true, false, false, false),
        ]
        
        for (index, testCase) in testCases.enumerated() {
            // Given
            let frontdoorUrl = createValidFrontdoorURL(host: testCase.frontdoorHost, clientId: testCase.clientId)
            SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = testCase.appConsumerKey
            UserAccountManager.shared.loginHost = testCase.selectedHost
            
            // When
            let override = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: frontdoorUrl,
                codeVerifier: testCase.codeVerifier,
                selectedAppLoginHost: testCase.selectedHost,
                addingAndSwitchingLoginHostsPerMdm: testCase.addingAndSwitchingLoginHostsPerMdm,
                addingAndSwitchingLoginHostsOverride: testCase.addingAndSwitchingLoginHostsOverride
            )
            
            // Then
            if testCase.expectedFrontdoorUrl {
                XCTAssertEqual(override.frontdoorBridgeUrl, frontdoorUrl, "Non-.my. test case \(index + 1): frontdoorBridgeUrl mismatch")
            } else {
                XCTAssertNil(override.frontdoorBridgeUrl, "Non-.my. test case \(index + 1): frontdoorBridgeUrl should be nil")
            }
            
            if testCase.expectedCodeVerifier {
                XCTAssertEqual(override.codeVerifier, testCase.codeVerifier, "Non-.my. test case \(index + 1): codeVerifier mismatch")
            } else {
                XCTAssertNil(override.codeVerifier, "Non-.my. test case \(index + 1): codeVerifier should be nil")
            }
            
            XCTAssertEqual(override.matchesConsumerKey, testCase.expectedMatchesConsumerKey, "Non-.my. test case \(index + 1): matchesConsumerKey mismatch")
            XCTAssertEqual(override.matchesLoginHost, testCase.expectedMatchesLoginHost, "Non-.my. test case \(index + 1): matchesLoginHost mismatch")
        }
    }
}
