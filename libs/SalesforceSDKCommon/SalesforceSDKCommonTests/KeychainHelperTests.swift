//
//  KeychainHelperTests.swift
//  SalesforceSDKCommon
//
//  Created by Raj Rao on 3/30/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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

final class KeychainHelperTests: XCTestCase {
    
    override func tearDownWithError() throws {
        _ = KeychainHelper.removeAll()
    }
    
    func testCreateIfNotPresent() {
        let accountName = "account.two"
        let serviceName = "test.two"
        var readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readResult.success)
        let creationResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(creationResult.success)
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNil(readResult.data)
    }
    
    func testCreateIfNotPresentNilAccount() {
        let serviceName = "test.two"
        var readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertFalse(readResult.success)
        let creationResult = KeychainHelper.createIfNotPresent(service: serviceName, account: nil)
        XCTAssertTrue(creationResult.success)
        readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertTrue(readResult.success)
        XCTAssertNil(readResult.data)
    }
    
    func testConcurrentCreateIfNotPresent() {
        DispatchQueue.concurrentPerform(iterations: 500) { index in
            let keychainResult = KeychainHelper.createIfNotPresent(service: "test", account: "\(index%2)")
            XCTAssertTrue(keychainResult.success)
        }
    }
    
    func testCreateMultipleTimes() {
        let accountName = "account.two"
        let serviceName = "test.two"
        var readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readResult.success)
        var creationResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(creationResult.success)
        
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
        
        creationResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(creationResult.success)
        
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
    }
    
    func testWriteAndReadItem() {
        let serviceName = "test.two"
        let accountName = "account.two"
        var readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecItemNotFound)
        XCTAssertNotNil(readResult.error)
        
        let data = Data("ATESTSTRING2".utf8)
        let writeResult = KeychainHelper.write(service: serviceName, data: data, account: accountName)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        XCTAssertEqual(writeResult.status, errSecSuccess)
        XCTAssertNil(writeResult.error)
        
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
        
        let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
        XCTAssertEqual(removeResult.status, errSecSuccess)
        XCTAssertNil(removeResult.error)
        
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecItemNotFound)
        XCTAssertNotNil(readResult.error)
    }
    
    func testWriteAndReadItemNilAccount() {
        let serviceName = "test.two"
        var readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertFalse(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecItemNotFound)
        XCTAssertNotNil(readResult.error)
        
        let data = Data("ATESTSTRING2".utf8)
        let writeResult = KeychainHelper.write(service: serviceName, data: data, account: nil)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        XCTAssertEqual(writeResult.status, errSecSuccess)
        XCTAssertNil(writeResult.error)
        
        readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
        
        let removeResult = KeychainHelper.remove(service: serviceName, account: nil)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
        XCTAssertEqual(removeResult.status, errSecSuccess)
        XCTAssertNil(removeResult.error)
        
        readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertFalse(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecItemNotFound)
        XCTAssertNotNil(readResult.error)
    }
    
    func testUpdateItem() {
        let serviceName = "test.two"
        let data1 = Data("ATESTSTRING2".utf8)
        let data2 = Data("ATESTSTRING3".utf8)
        var writeResult = KeychainHelper.write(service: serviceName, data: data1, account: nil)
        XCTAssertTrue(writeResult.success)
        writeResult = KeychainHelper.write(service: serviceName, data: data2, account: nil)
        XCTAssertTrue(writeResult.success)
        let readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertTrue(readResult.success)
        XCTAssertEqual(readResult.data, data2)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
    }
    
    func testDeleteNonexistentItem() {
        let serviceName = "test.two"
        let accountName = "account.two"
        let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
        XCTAssertFalse(removeResult.success)
        XCTAssertNil(removeResult.data)
        XCTAssertNotNil(removeResult.error)
        XCTAssertEqual(removeResult.status, errSecItemNotFound)
    }
    
    func testDeleteNonexistentItemNilAccount() {
        let serviceName = "test.two"
        let removeResult = KeychainHelper.remove(service: serviceName, account: nil)
        XCTAssertFalse(removeResult.success)
        XCTAssertNil(removeResult.data)
        XCTAssertNotNil(removeResult.error)
        XCTAssertEqual(removeResult.status, errSecItemNotFound)
    }
    
    func testRemoveAll() {
        let accounts = [("test.one", "account.one"),
                        ("test.two", "account.two"),
                        ("test.three", "account.three"),
                        ("test.four", "account.four")]
        
        accounts.forEach {
            let keychainResult = KeychainHelper.createIfNotPresent(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success)
        }
        
        let deleteResult = KeychainHelper.removeAll()
        XCTAssertTrue(deleteResult.success)
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertFalse(keychainResult.success)
            XCTAssertEqual(keychainResult.status, errSecItemNotFound)
        }
    }
    
    func testReset() {
        let serviceName = "test.two"
        let accountName = "account.two"
        let data = Data("ATESTSTRING2".utf8)
        
        let writeResult = KeychainHelper.write(service: serviceName, data: data, account: accountName)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        XCTAssertEqual(writeResult.status, errSecSuccess)
        XCTAssertNil(writeResult.error)
        
        var readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertEqual(readResult.data, data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
        
        let resetResult = KeychainHelper.reset(service: serviceName, account: accountName)
        XCTAssertTrue(resetResult.success)
        XCTAssertNil(resetResult.data)
        XCTAssertEqual(resetResult.status, errSecSuccess)
        XCTAssertNil(resetResult.error)
        
        readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNil(readResult.data)
        XCTAssertEqual(readResult.status, errSecSuccess)
        XCTAssertNil(readResult.error)
    }
    
    func testChangeAccesibilityAttribute() throws {
        let accounts = [("test.one", "account.one"),
                        ("test.two", "account.two"),
                        ("test.three", "account.three"),
                        ("test.four", "account.four")]
        
        accounts.forEach {
            let keychainResult = KeychainHelper.createIfNotPresent(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success)
        }
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success)
            XCTAssertEqual(keychainResult.status, errSecSuccess)
        }
        
        for (service, account) in accounts {
            let keychainResult = try readKeychainItem(service: service, account: account)
            let accessibilityAttr = try XCTUnwrap(keychainResult[String(kSecAttrAccessible)])
            XCTAssertEqual(accessibilityAttr as! CFString, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
        
        let attrResult = KeychainHelper.setAccessibleAttribute(.whenUnlocked)
        XCTAssertTrue(attrResult.success)
        
        for (service, account) in accounts {
            let keychainResult = try readKeychainItem(service: service, account: account)
            let accessibilityAttr = try XCTUnwrap(keychainResult[String(kSecAttrAccessible)])
            XCTAssertEqual(accessibilityAttr as! CFString, kSecAttrAccessibleWhenUnlocked)
        }
        
        let deleteResult = KeychainHelper.removeAll()
        XCTAssertTrue(deleteResult.success)
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertFalse(keychainResult.success)
            XCTAssertEqual(keychainResult.status, errSecItemNotFound)
        }
    }
    
    func testCacheConfigurationEnabled() throws {
        // Cache enabled at class level
        KeychainHelper.cacheEnabled = true
        
        let service = "testService"
        let originalData = try XCTUnwrap("FirstWrite".data(using: .utf8))
        let updatedData = try XCTUnwrap("SecondWrite".data(using: .utf8))
        
        // Write an item that should go through cache by default
        var result = KeychainHelper.write(service: service, data: originalData, account: nil)
        XCTAssert(result.success)
        
        // Write another item not using cache
        result = KeychainHelper.write(service: service, data: updatedData, account: nil, cacheMode: .disabled)
        XCTAssert(result.success)
        
        // Read using cache by default should retrieve original value
        result = KeychainHelper.read(service: service, account: nil)
        XCTAssert(result.success)
        XCTAssertEqual(originalData, result.data)
        
        // Read without cache should retrieve latest value
        result = KeychainHelper.read(service: service, account: nil, cacheMode: .disabled)
        XCTAssert(result.success)
        XCTAssertEqual(updatedData, result.data)
    }
    
    func testCacheConfigurationDisabled() throws {
        // Cache enabled at class level
        KeychainHelper.cacheEnabled = false
        
        let service = "testService"
        let originalData = try XCTUnwrap("FirstWrite".data(using: .utf8))
        let updatedData = try XCTUnwrap("SecondWrite".data(using: .utf8))
        
        // Write an item using the cache
        var result = KeychainHelper.write(service: service, data: originalData, account: nil, cacheMode: .enabled)
        XCTAssert(result.success)
        
        // Write an item that should not go through cache by default
        result = KeychainHelper.write(service: service, data: updatedData, account: nil)
        XCTAssert(result.success)
        
        // Read from cache, should get original value
        result = KeychainHelper.read(service: service, account: nil, cacheMode: .enabled)
        XCTAssert(result.success)
        XCTAssertEqual(originalData, result.data)
        
        // Read without cache by default, should get latest value
        result = KeychainHelper.read(service: service, account: nil)
        XCTAssert(result.success)
        XCTAssertEqual(updatedData, result.data)
    }
    
    private func readKeychainItem(service: String, account: String) throws -> [String : Any] {
        let query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                                    String(kSecAttrService): service,
                                    String(kSecMatchLimit): kSecMatchLimitOne,
                                    String(kSecReturnAttributes): kCFBooleanTrue as Any,
                                    String(kSecReturnData): kCFBooleanTrue as Any]
        
        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)
        
        guard status == errSecSuccess else {
            throw KeychainTestError.failed(osStatus: status)
        }
        
        guard let item = queryResult as? [String: Any] else {
            throw KeychainTestError.failedToRead
        }
        
        return item
    }
    
    private enum KeychainTestError: Error {
        case failed(osStatus: OSStatus)
        case failedToRead
    }

}
