//
//  KeychaiinItemManagerTests.swift
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

class KeychainItemManagerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCreateIfNotPresent()  throws {
        let accountName = "test.account2"
        let serviceName = "test.two"
        _  = KeychainHelper.removeItem(identifier: serviceName, account: accountName)
        let keychainResult = KeychainHelper.createItemIfNotPresent(identifier: serviceName, account: accountName)
        XCTAssertTrue(keychainResult.success)
        
        let keychainReadResult = KeychainHelper.readItem(identifier: serviceName, account: accountName)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
        let writeResult = KeychainHelper.writeItem(identifier: serviceName, data: data, account: accountName)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        
        let readResult = KeychainHelper.readItem(identifier: serviceName, account: accountName)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        
        let removeResult = KeychainHelper.removeItem(identifier: serviceName, account: accountName)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
        
        let readAgainRTesult = KeychainHelper.readItem(identifier: serviceName, account: accountName)
        XCTAssertFalse(readAgainRTesult.success)
        XCTAssertNil(readAgainRTesult.data)
        
   }
    
  func testCreateIfNotPresentNilAccount()  throws {
        let serviceName = "test.two"
        let check = KeychainHelper.readItem(identifier: serviceName, account: nil)
        XCTAssertFalse(check.success)
    
        _  = KeychainHelper.removeItem(identifier: "test.two", account: nil)
        let keychainResult = KeychainHelper.createItemIfNotPresent(identifier: serviceName, account: nil);
        XCTAssertTrue(keychainResult.success)
        let keychainReadResult = KeychainHelper.readItem(identifier: serviceName, account: nil)
        XCTAssertTrue(keychainReadResult.success)
        XCTAssertNil(keychainReadResult.data)
        
        let data = "ATESTSTRING2".data(using: .utf8)  ?? Data()
        let writeResult = KeychainHelper.writeItem(identifier: serviceName, data: data, account: nil)
        XCTAssertTrue(writeResult.success)
        XCTAssertNotNil(writeResult.data)
        
        let readResult = KeychainHelper.readItem(identifier: serviceName, account: nil)
        XCTAssertTrue(readResult.success)
        XCTAssertNotNil(readResult.data)
        
        
        let removeResult = KeychainHelper.removeItem(identifier: serviceName, account: nil)
        XCTAssertTrue(removeResult.success)
        XCTAssertNil(removeResult.data)
    
        let readAgainRTesult = KeychainHelper.readItem(identifier: serviceName, account: nil)
        XCTAssertFalse(readAgainRTesult.success)
        XCTAssertNil(readAgainRTesult.data)
        
   }
  
}
