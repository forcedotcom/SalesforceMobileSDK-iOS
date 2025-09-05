//
//  FrontdoorBridgeUrlAppLoginHostMatchTests.swift
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

// MARK: - Test Implementation of SFSDKLoginHostStoring

fileprivate class TestLoginHostStore: NSObject, SFSDKLoginHostStoring {
    
    private var loginHosts: [SalesforceLoginHost] = []
    
    init(loginHosts: [SalesforceLoginHost] = []) {
        super.init()
        self.loginHosts = loginHosts
    }
    
    func loginHost(at index: UInt) -> SalesforceLoginHost {
        return loginHosts[Int(index)]
    }
    
    func numberOfLoginHosts() -> UInt {
        return UInt(loginHosts.count)
    }
    
    // Helper method to add login hosts for testing
    func addLoginHost(_ host: SalesforceLoginHost) {
        loginHosts.append(host)
    }
    
    // Helper method to clear all login hosts
    func clearLoginHosts() {
        loginHosts.removeAll()
    }
}

// MARK: - Main Test Class

class FrontdoorBridgeUrlAppLoginHostMatchTests: XCTestCase {
    
    private var testLoginHostStore: TestLoginHostStore!
    
    override func setUp() {
        super.setUp()
        testLoginHostStore = TestLoginHostStore()
    }
    
    override func tearDown() {
        testLoginHostStore = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createLoginHost(name: String, host: String) -> SalesforceLoginHost {
        return SalesforceLoginHost(name: name, host: host, deletable: true)
    }
    
    // MARK: - Tests with .my. domain URLs
    
    func testMyDomainUrl_WithMatchingLoginHost_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://example.my.salesforce.com/frontdoor")!
        let matchingHost = createLoginHost(name: "Test", host: "test.my.salesforce.com")
        let nonMatchingHost = createLoginHost(name: "Other", host: "other.my.different.com")
        testLoginHostStore.addLoginHost(matchingHost)
        testLoginHostStore.addLoginHost(nonMatchingHost)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertEqual(match.appLoginHostMatch, "test.my.salesforce.com")
    }
    
    func testMyDomainUrl_WithMultipleMatchingLoginHosts_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://example.my.salesforce.com/frontdoor")!
        let matchingHost1 = createLoginHost(name: "Test1", host: "test1.my.salesforce.com")
        let matchingHost2 = createLoginHost(name: "Test2", host: "test2.my.salesforce.com")
        testLoginHostStore.addLoginHost(matchingHost1)
        testLoginHostStore.addLoginHost(matchingHost2)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Should return the first matching host
        XCTAssertEqual(match.appLoginHostMatch, "test1.my.salesforce.com")
    }
    
    func testMyDomainUrl_WithNoMatchingLoginHost_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://example.my.salesforce.com/frontdoor")!
        let nonMatchingHost = createLoginHost(name: "Test", host: "test.my.different.com")
        testLoginHostStore.addLoginHost(nonMatchingHost)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testMyDomainUrl_WithMatchingLoginHost_AddingSwitchingDisabled() {
        // Given
        let frontdoorUrl = URL(string: "https://example.my.salesforce.com/frontdoor")!
        let matchingHost = createLoginHost(name: "Test", host: "test.my.salesforce.com")
        testLoginHostStore.addLoginHost(matchingHost)
        
        // When - selectedAppLoginHost matches the suffix
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: false,
            selectedAppLoginHost: "selected.my.salesforce.com"
        )
        
        // Then
        XCTAssertEqual(match.appLoginHostMatch, "selected.my.salesforce.com")
    }
    
    func testMyDomainUrl_WithNonMatchingSelectedHost_AddingSwitchingDisabled() {
        // Given
        let frontdoorUrl = URL(string: "https://example.my.salesforce.com/frontdoor")!
        let matchingHost = createLoginHost(name: "Test", host: "test.my.salesforce.com")
        testLoginHostStore.addLoginHost(matchingHost)
        
        // When - selectedAppLoginHost doesn't match the suffix
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: false,
            selectedAppLoginHost: "selected.my.different.com"
        )
        
        // Then
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testMyDomainUrl_ComplexDomainSuffix_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://complex.my.test.salesforce.com/frontdoor")!
        let matchingHost = createLoginHost(name: "Test", host: "matching.my.test.salesforce.com")
        let nonMatchingHost = createLoginHost(name: "Other", host: "other.my.different.salesforce.com")
        testLoginHostStore.addLoginHost(matchingHost)
        testLoginHostStore.addLoginHost(nonMatchingHost)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertEqual(match.appLoginHostMatch, "matching.my.test.salesforce.com")
    }
    
    // MARK: - Tests without .my. domain URLs
    
    func testNonMyDomainUrl_WithLoginHosts_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://login.salesforce.com/frontdoor")!
        let host1 = createLoginHost(name: "Production", host: "login.salesforce.com")
        let host2 = createLoginHost(name: "Sandbox", host: "test.salesforce.com")
        testLoginHostStore.addLoginHost(host1)
        testLoginHostStore.addLoginHost(host2)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Should return the first eligible host
        XCTAssertEqual(match.appLoginHostMatch, "login.salesforce.com")
    }
    
    func testNonMyDomainUrl_WithLoginHosts_AddingSwitchingDisabled() {
        // Given
        let frontdoorUrl = URL(string: "https://login.salesforce.com/frontdoor")!
        let host1 = createLoginHost(name: "Production", host: "login.salesforce.com")
        testLoginHostStore.addLoginHost(host1)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: false,
            selectedAppLoginHost: "test.salesforce.com"
        )
        
        // Then - Should return nil as adding/switching is disabled
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testNonMyDomainUrl_EmptyLoginHostStore_AddingSwitchingAllowed() {
        // Given
        let frontdoorUrl = URL(string: "https://login.salesforce.com/frontdoor")!
        // testLoginHostStore is empty by default
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testNonMyDomainUrl_EmptyLoginHostStore_AddingSwitchingDisabled() {
        // Given
        let frontdoorUrl = URL(string: "https://login.salesforce.com/frontdoor")!
        // testLoginHostStore is empty by default
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: false,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Should return nil since the store is empty and adding/switch is disabled
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    // MARK: - Edge Cases
    
    func testInvalidUrl_NoHost() {
        // Given
        let frontdoorUrl = URL(string: "file:///local/path")!
        let host = createLoginHost(name: "Test", host: "test.salesforce.com")
        testLoginHostStore.addLoginHost(host)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testMyDomainUrl_MalformedMyDomain() {
        // Given - URL contains ".my." but in an unusual position
        let frontdoorUrl = URL(string: "https://test.my./frontdoor")!
        let host = createLoginHost(name: "Test", host: "test.salesforce.com")
        testLoginHostStore.addLoginHost(host)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Should handle gracefully
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testMyDomainUrl_EmptySuffixAfterMyDomain() {
        // Given
        let frontdoorUrl = URL(string: "https://test.my.")!
        let host = createLoginHost(name: "Test", host: "test.salesforce.com")
        testLoginHostStore.addLoginHost(host)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then
        XCTAssertNil(match.appLoginHostMatch)
    }
    
    func testMyDomainUrl_ExactMatchWithDot() {
        // Given
        let frontdoorUrl = URL(string: "https://test.my.salesforce.com/frontdoor")!
        let exactMatchHost = createLoginHost(name: "Exact", host: "exact.my.salesforce.com")
        let suffixOnlyHost = createLoginHost(name: "Suffix", host: "salesforce.com")
        testLoginHostStore.addLoginHost(exactMatchHost)
        testLoginHostStore.addLoginHost(suffixOnlyHost)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Should match the full suffix, not just the end part
        XCTAssertEqual(match.appLoginHostMatch, "exact.my.salesforce.com")
    }
    
    // MARK: - Comprehensive Coverage Tests
    
    func testAllPermutations_MyDomain() {
        let testCases: [(frontdoorUrl: String, hosts: [(name: String, host: String)], addingSwitching: Bool, selectedHost: String, expectedResult: String?)] = [
            // .my. domain with matching hosts, adding/switching allowed
            ("https://test.my.salesforce.com/frontdoor", [("Match", "match.my.salesforce.com")], true, "selected.com", "match.my.salesforce.com"),
            
            // .my. domain with matching hosts, adding/switching disabled, matching selected
            ("https://test.my.salesforce.com/frontdoor", [("Match", "match.my.salesforce.com")], false, "selected.my.salesforce.com", "selected.my.salesforce.com"),
            
            // .my. domain with matching hosts, adding/switching disabled, non-matching selected
            ("https://test.my.salesforce.com/frontdoor", [("Match", "match.my.salesforce.com")], false, "selected.my.different.com", nil),
            
            // .my. domain with no matching hosts, adding/switching allowed
            ("https://test.my.salesforce.com/frontdoor", [("NoMatch", "nomatch.my.different.com")], true, "selected.com", nil),
            
            // .my. domain with no matching hosts, adding/switching disabled
            ("https://test.my.salesforce.com/frontdoor", [("NoMatch", "nomatch.my.different.com")], false, "selected.my.salesforce.com", "selected.my.salesforce.com"),
        ]
        
        for (index, testCase) in testCases.enumerated() {
            // Given
            testLoginHostStore.clearLoginHosts()
            for hostInfo in testCase.hosts {
                let host = createLoginHost(name: hostInfo.name, host: hostInfo.host)
                testLoginHostStore.addLoginHost(host)
            }
            
            let frontdoorUrl = URL(string: testCase.frontdoorUrl)!
            
            // When
            var match = FrontdoorBridgeUrlAppLoginHostMatch(
                frontdoorBridgeUrl: frontdoorUrl,
                loginHostStore: testLoginHostStore,
                addingAndSwitchingLoginHostsAllowed: testCase.addingSwitching,
                selectedAppLoginHost: testCase.selectedHost
            )
            
            // Then
            XCTAssertEqual(match.appLoginHostMatch, testCase.expectedResult, "Test case \(index + 1) failed")
        }
    }
    
    func testAllPermutations_NonMyDomain() {
        let testCases: [(frontdoorUrl: String, hosts: [(name: String, host: String)], addingSwitching: Bool, selectedHost: String, expectedResult: String?)] = [
            // Non-.my. domain with hosts, adding/switching allowed
            ("https://login.salesforce.com/frontdoor", [("Prod", "login.salesforce.com")], true, "selected.com", "login.salesforce.com"),
            
            // Non-.my. domain with hosts, adding/switching disabled
            ("https://login.salesforce.com/frontdoor", [("Prod", "login.salesforce.com")], false, "login.salesforce.com", "login.salesforce.com"),
            
            // Non-.my. domain with empty hosts, adding/switching allowed
            ("https://login.salesforce.com/frontdoor", [], true, "selected.com", nil),
            
            // Non-.my. domain with empty hosts, adding/switching disabled
            ("https://login.salesforce.com/frontdoor", [], false, "test.salesforce.com", nil),
            
            // Non-.my. domain with multiple hosts, adding/switching allowed (should return first)
            ("https://login.first.com/frontdoor", [("First", "login.first.com"), ("Second", "login.second.com")], true, "login.selected.com", "login.first.com"),
        ]
        
        for (index, testCase) in testCases.enumerated() {
            // Given
            testLoginHostStore.clearLoginHosts()
            for hostInfo in testCase.hosts {
                let host = createLoginHost(name: hostInfo.name, host: hostInfo.host)
                testLoginHostStore.addLoginHost(host)
            }
            
            let frontdoorUrl = URL(string: testCase.frontdoorUrl)!
            
            // When
            var match = FrontdoorBridgeUrlAppLoginHostMatch(
                frontdoorBridgeUrl: frontdoorUrl,
                loginHostStore: testLoginHostStore,
                addingAndSwitchingLoginHostsAllowed: testCase.addingSwitching,
                selectedAppLoginHost: testCase.selectedHost
            )
            
            // Then
            XCTAssertEqual(match.appLoginHostMatch, testCase.expectedResult, "Non-.my. domain test case \(index + 1) failed")
        }
    }
    
    // MARK: - Lazy Property Behavior Tests
    
    func testLazyPropertyComputation() {
        // Given
        let frontdoorUrl = URL(string: "https://test.my.salesforce.com/frontdoor")!
        let host = createLoginHost(name: "Test", host: "test.my.salesforce.com")
        testLoginHostStore.addLoginHost(host)
        
        // When
        var match = FrontdoorBridgeUrlAppLoginHostMatch(
            frontdoorBridgeUrl: frontdoorUrl,
            loginHostStore: testLoginHostStore,
            addingAndSwitchingLoginHostsAllowed: true,
            selectedAppLoginHost: "selected.host.com"
        )
        
        // Then - Access the property multiple times to ensure lazy behavior
        let result1 = match.appLoginHostMatch
        let result2 = match.appLoginHostMatch
        
        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result1, "test.my.salesforce.com")
    }
}
