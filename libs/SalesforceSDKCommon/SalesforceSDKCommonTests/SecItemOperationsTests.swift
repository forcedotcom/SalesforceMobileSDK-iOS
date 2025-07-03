//
//  SecItemOperationsTests.swift
//  SalesforceSDKCommon
//
//  Created by Brianna Birman on 7/2/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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
@testable import SalesforceSDKCommon

final class SecItemOperationsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        cleanupTestItems()
    }
    
    override func tearDown() {
        cleanupTestItems()
        super.tearDown()
    }
    
    private func cleanupTestItems() {
        // Use non-MSDK delete to get everything from tests
        let deleteQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
        ]

        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        XCTAssert(deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound)
    }
    
    func testMsdkTaggedQuery() throws {
        let serviceValue = "test-service"
        let originalQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): serviceValue
        ]
        // Verify tag is added
        let taggedQuery = SecItemOperations.msdkTaggedQuery(originalQuery)
        let taggedDict = try XCTUnwrap(taggedQuery as? [String: Any])
        XCTAssertEqual(taggedDict[String(kSecClass)] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(taggedDict[String(kSecAttrService)] as? String, serviceValue)
        XCTAssertEqual(taggedDict[String(kSecAttrCreator)] as? String, String(KeychainItemManager.tag))
    }
    
    func testAddAndCopyMatching() throws {
        // Add item through MSDK
        let testData = try XCTUnwrap("test-password".data(using: .utf8))
        let testService = "test-service"
        let addQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): testService,
            String(kSecValueData): testData
        ]
        let addStatus = SecItemOperations.add(addQuery, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
        // Retrieve same item through MSDK
        let copyQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): testService,
            String(kSecReturnData): true
        ]
        var result: CFTypeRef?
        let copyStatus = SecItemOperations.copyMatching(copyQuery, &result)
        XCTAssertEqual(copyStatus, errSecSuccess)
        XCTAssertEqual(result as? Data, testData)
    }
    
    func testCopyMatchingScope() throws {
        // Add without MSDK
        let testData = try XCTUnwrap("test-password".data(using: .utf8))
        let addQuery: [String: Any] = [
            String(kSecAttrService): "test-non-msdk-service",
            String(kSecAttrAccount): "test-account",
            String(kSecClass): kSecClassGenericPassword,
            String(kSecValueData): testData
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
        // Query with MSDK
        let copyQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
        ]
        
        // MSDK shouldn't find non-MSDK values
        let copyStatus = SecItemOperations.copyMatching(copyQuery, nil)
        XCTAssertEqual(copyStatus, errSecItemNotFound)
    }
    
    func testUpdateScope() throws {
        let msdkService = "msdk-service"
        let msdkPassword = try XCTUnwrap("original-msdk-password".data(using: .utf8))
        let nonMsdkService = "non-msdk-service"
        let nonMsdkPassword = try XCTUnwrap("original-non-msdk-password".data(using: .utf8))
        
        // Add a MSDK item
        var addQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): msdkService,
            String(kSecValueData): msdkPassword
        ]
        var addStatus = SecItemOperations.add(addQuery, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
        
        // Add a non-MSDK item
       addQuery = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): nonMsdkService,
            String(kSecValueData): nonMsdkPassword
        ]
        addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
        // Broad update query through MSDK
        let updateQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
        ]
        
        let newData = "updated-password".data(using: .utf8)!
        let attributesToUpdate: [String: Any] = [
            String(kSecValueData): newData
        ]
        
        let updateStatus = SecItemOperations.update(updateQuery, attributesToUpdate)
        XCTAssertEqual(updateStatus, errSecSuccess)
        
        // Verify the update applied to MSDK item
        var copyQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): msdkService,
            String(kSecReturnData): true
        ]
        var copyResult: CFTypeRef?
        var copyStatus = SecItemOperations.copyMatching(copyQuery, &copyResult)
        XCTAssertEqual(copyStatus, errSecSuccess)
        XCTAssertEqual(copyResult as? Data, newData, "MSDK password should be updated")
        
        // Verify the update didn't apply to the non-MSDK item
        copyQuery = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): nonMsdkService,
            String(kSecReturnData): true
        ]
        copyStatus = SecItemCopyMatching(copyQuery as CFDictionary, &copyResult)
        XCTAssertEqual(copyStatus, errSecSuccess)
        XCTAssertEqual(copyResult as? Data, nonMsdkPassword, "Non-MSDK password should not be updated")
    }

    
    func testDeleteScope() {
        let msdkService = "msdk-service"
        let nonMsdkService = "non-msdk-service"
        
        // Add MSDK item
        var addQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): msdkService,
        ]
        var addStatus = SecItemOperations.add(addQuery, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
       // Add non-MSDK item
        addQuery = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): nonMsdkService,
        ]
        addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        XCTAssertEqual(addStatus, errSecSuccess)
        
        // Broad delete through MSDK
        let deleteQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
        ]
        let deleteStatus = SecItemOperations.delete(deleteQuery)
        XCTAssertEqual(deleteStatus, errSecSuccess)
        
        // Verify MSDK item deletion by trying to retrieve the item
        var copyQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): msdkService,
        ]
        var copyStatus = SecItemOperations.copyMatching(copyQuery, nil)
        
        XCTAssertEqual(copyStatus, errSecItemNotFound)
        
        // Verify MSDK item not deleted
        copyQuery = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrService): nonMsdkService,
        ]
        copyStatus = SecItemCopyMatching(copyQuery as CFDictionary, nil)
        XCTAssertEqual(copyStatus, errSecSuccess)
    }
}
