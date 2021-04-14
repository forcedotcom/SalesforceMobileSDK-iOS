//
//  KeychainItemManagerTests.swift
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
enum KeychainTestError: Error {
    case failed(osStatus: OSStatus)
    case failedToRead
}

class KeychainItemManagerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateIfNotPresent()  throws {
        let accountName = "account.two"
        let serviceName = "test.two"
        _  = KeychainHelper.remove(service: serviceName, account: accountName)
        let keychainResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(keychainResult.success)

        let keychainReadResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
        let writeResult = KeychainHelper.write(service: serviceName, data: data, account: accountName)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        
        let readResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        
        let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
        
        let readAgainRTesult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readAgainRTesult.success)
        XCTAssertNil(readAgainRTesult.data)
        
   }
    
  func testCreateIfNotPresentNilAccount()  throws {
        let serviceName = "test.two"
        let check = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertFalse(check.success)
    
        let keychainResult = KeychainHelper.createIfNotPresent(service: serviceName, account: nil)
        XCTAssertTrue(keychainResult.success)
        let keychainReadResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
        let writeResult = KeychainHelper.write(service: serviceName, data: data, account: nil)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        
        let readResult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        
        
        let removeResult = KeychainHelper.remove(service: serviceName, account: nil)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
    
        let readAgainRTesult = KeychainHelper.read(service: serviceName, account: nil)
        XCTAssertFalse(readAgainRTesult.success)
        XCTAssertNil(readAgainRTesult.data)
        
   }
    
    func testWriteAndReadItem()  throws {
          let serviceName = "test.two"
          let check = KeychainHelper.read(service: serviceName, account: nil)
          XCTAssertFalse(check.success)
      
          let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
          let writeResult = KeychainHelper.write(service: serviceName, data: data, account: nil)
          XCTAssertTrue(writeResult.success)
          XCTAssertNotNil(writeResult.data)
          
          let readResult = KeychainHelper.read(service: serviceName, account: nil)
          XCTAssertTrue(readResult.success)
          XCTAssertNotNil(readResult.data)
          
          let removeResult = KeychainHelper.remove(service: serviceName, account: nil)
          XCTAssertTrue(removeResult.success)
          XCTAssertNil(removeResult.data)
      
          let readAgainRTesult = KeychainHelper.read(service: serviceName, account: nil)
          XCTAssertFalse(readAgainRTesult.success)
          XCTAssertNil(readAgainRTesult.data)
    }
    
    func testWriteAndReadItemWithAccount()  throws {
          let serviceName = "test.two"
          let accountName = "account.two"
          let check = KeychainHelper.read(service: serviceName, account: accountName)
          XCTAssertFalse(check.success)
      
          let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
          let writeResult = KeychainHelper.write(service: serviceName, data: data, account: accountName)
          XCTAssertTrue(writeResult.success)
          XCTAssertNotNil(writeResult.data)
          XCTAssertTrue(writeResult.status == errSecSuccess)
          
          let readResult = KeychainHelper.read(service: serviceName, account: accountName)
          XCTAssertTrue(readResult.success)
          XCTAssertNotNil(readResult.data)
          XCTAssertTrue(readResult.status == errSecSuccess)
          
          
          let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
          XCTAssertTrue(removeResult.success)
          XCTAssertNil(removeResult.data)
          XCTAssertTrue(readResult.status == errSecSuccess)
      
          let readAgainRTesult = KeychainHelper.read(service: serviceName, account: accountName)
          XCTAssertFalse(readAgainRTesult.success)
          XCTAssertNil(readAgainRTesult.data)
          XCTAssertTrue(readResult.status == errSecSuccess)
    }
    
    func testDeleteItemIfNotPresent()  throws {
          let serviceName = "test.two"
          let removeResult = KeychainHelper.remove(service: serviceName, account: nil)
          XCTAssertFalse(removeResult.success)
          XCTAssertNil(removeResult.data)
          XCTAssertNotNil(removeResult.error)
          XCTAssertTrue(removeResult.status == errSecItemNotFound)
    }
    
    func testDeleteItemIfNotPresentWithAccount()  throws {
          let serviceName = "test.two"
          let accountName = "account.two"
          let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
          XCTAssertFalse(removeResult.success)
          XCTAssertNil(removeResult.data)
          XCTAssertNotNil(removeResult.error)
          XCTAssertTrue(removeResult.status == errSecItemNotFound)
    }
    
    func testCreateMultipleTimes()  throws {
        let accountName = "account.two"
        let serviceName = "test.two"
        _  = KeychainHelper.remove(service: serviceName, account: accountName)
        var keychainResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(keychainResult.success)

        var keychainReadResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        keychainResult = KeychainHelper.createIfNotPresent(service: serviceName, account: accountName)
        XCTAssertTrue(keychainResult.success)

        keychainReadResult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        let removeResult = KeychainHelper.remove(service: serviceName, account: accountName)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
        
        let readAgainRTesult = KeychainHelper.read(service: serviceName, account: accountName)
        XCTAssertFalse(readAgainRTesult.success)
        XCTAssertNil(readAgainRTesult.data)
    }
    
    func testCreateAndRemoveAll()  throws {
       
        let accounts = [( "test.one", "account.one"),
                        ( "test.two", "account.two"),
                        ( "test.three", "account.three"),
                        ( "test.four", "account.four")]
        
        accounts.forEach {
            let keychainResult = KeychainHelper.createIfNotPresent(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success)
        }
        
        let deleteResult = KeychainHelper.removeAll()
        XCTAssertTrue(deleteResult.success)
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertFalse(keychainResult.success && keychainResult.status==errSecItemNotFound)
        }
    }
    
    func testChangeAccesibilityAttribute() throws {
       
        let accounts = [( "test.one", "account.one"),
                        ( "test.two", "account.two"),
                        ( "test.three", "account.three"),
                        ( "test.four", "account.four")]
        
        accounts.forEach {
            let keychainResult = KeychainHelper.createIfNotPresent(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success)
        }
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertTrue(keychainResult.success && keychainResult.status == errSecSuccess)
        }
        
        for (service, account) in accounts {
            let keychainResult: [String: Any]? = try readKeychainItem(service: service, account: account)
            let accessibilityAttr = try XCTUnwrap(keychainResult?[String(kSecAttrAccessible)])
            XCTAssertEqual(accessibilityAttr as! CFString , kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        }
        
        let attrResult = KeychainHelper.setAccessibleAttribute(.whenUnlocked)
        XCTAssertTrue(attrResult.success)
        
        for (service, account) in accounts {
            let keychainResult: [String: Any]? = try readKeychainItem(service: service, account: account)
            let accessibilityAttr = try XCTUnwrap(keychainResult?[String(kSecAttrAccessible)])
            XCTAssertEqual(accessibilityAttr as! CFString , kSecAttrAccessibleWhenUnlocked)
        }
        
        let deleteResult = KeychainHelper.removeAll()
        XCTAssertTrue(deleteResult.success)
        
        accounts.forEach {
            let keychainResult = KeychainHelper.read(service: $0.0, account: $0.1)
            XCTAssertFalse(keychainResult.success && keychainResult.status==errSecItemNotFound)
        }
    }
    
    
    private func readKeychainItem(service: String, account: String) throws -> [String : Any] {
        let query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                                    String(kSecAttrService): service,
                                    String(kSecMatchLimit): kSecMatchLimitOne,
                                    String(kSecReturnAttributes): kCFBooleanTrue as Any,
                                    String(kSecReturnData): kCFBooleanTrue as Any]
        
        
        
        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)
        
        guard errSecSuccess == status else {
            throw KeychainTestError.failed(osStatus: status)
        }
        
        guard let item = queryResult as? [String: Any] else {
            throw KeychainTestError.failedToRead
        }
        
        return item
    }
    
   
}
