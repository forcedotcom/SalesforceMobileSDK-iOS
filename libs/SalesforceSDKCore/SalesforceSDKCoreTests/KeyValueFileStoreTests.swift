//
//  KeyValueFileStoreTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 9/17/21.
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
@testable import SalesforceSDKCore

class KeyValueFileStoreTests: XCTestCase {
    override func tearDownWithError() throws {
        if let globalPath = KeyValueEncryptedFileStore.globalStoresDirectory() {
            try FileManager.default.removeItem(atPath: globalPath)
        }
    }

    func testEncryptionUpdateGlobalStore() throws {
        // Set up store store data encrypted with old key
        let legacyKey = try XCTUnwrap(SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: "kv_key_upgrade", autoCreate: true))
        let storeName = "kv_upgrade"
        let globalStoreDirectory = URL(fileURLWithPath: KeyValueEncryptedFileStore.globalStoresDirectory()!)
        let storeDirectory = globalStoreDirectory.appendingPathComponent(storeName)
        try SFDirectoryManager.ensureDirectoryExists(storeDirectory.path)
        
        let key = "key1"
        let content = "my secret content"
        let encodedKey = (Data(key.utf8) as NSData).sha256()
        let fileURL = storeDirectory.appendingPathComponent(encodedKey)
        let encryptedData = try XCTUnwrap(legacyKey.encryptData(Data(content.utf8)))
        try encryptedData.write(to: fileURL)
        
        // Upgrade encryption + access store to verify contents
        KeyValueEncryptedFileStore.updateEncryption(parentDirectory: globalStoreDirectory.path, name: storeName, legacyKey: legacyKey)
        let store = try XCTUnwrap(KeyValueEncryptedFileStore(parentDirectory: globalStoreDirectory.path, name: storeName))
        XCTAssertEqual(store[key], content)
        
        // Call upgrade again + verify nothing changes
        KeyValueEncryptedFileStore.updateEncryption(parentDirectory: globalStoreDirectory.path, name: storeName, legacyKey: legacyKey)
        XCTAssertEqual(store[key], content)
    }
    
    func testEncryptionUpdateSharedGlobal() throws {
        // Set up store data encrypted with old key
        let legacyKey = try XCTUnwrap(SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: "com.salesforce.keyValueStores.encryptionKey", autoCreate: true))
        let storeName = "kv_upgrade_global_shared"
        let globalStoreDirectory = URL(fileURLWithPath: KeyValueEncryptedFileStore.globalStoresDirectory()!)
        let storeDirectory = globalStoreDirectory.appendingPathComponent(storeName)
        try SFDirectoryManager.ensureDirectoryExists(storeDirectory.path)
        
        let key = "key1"
        let content = "my secret content"
        let encodedKey = (Data(key.utf8) as NSData).sha256()
        let fileURL = storeDirectory.appendingPathComponent(encodedKey)
        let encryptedData = try XCTUnwrap(legacyKey.encryptData(Data(content.utf8)))
        try encryptedData.write(to: fileURL)
        
        // Upgrade encryption + access store to verify contents
        let store = try XCTUnwrap(KeyValueEncryptedFileStore.sharedGlobal(withName: storeName))
        XCTAssertEqual(store[key], content)
        
        // Access again + verify nothing changes
        KeyValueEncryptedFileStore.clearGlobalCache()
        let storeAgain = try XCTUnwrap(KeyValueEncryptedFileStore.sharedGlobal(withName: storeName))
        XCTAssertEqual(storeAgain[key], content)
    }
    
    func testSameStoreNoCache() throws {
        // Create legacy key to simulate scenario where app has existing stores that originally used the old key
        // and then validate new stores can be created and reinitialized
        let _ = try XCTUnwrap(SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: "com.salesforce.keyValueStores.encryptionKey", autoCreate: true))
        let storeName = "kv_global_shared_recreate"
       
        KeyValueEncryptedFileStore.clearGlobalCache()
        var store = try XCTUnwrap(KeyValueEncryptedFileStore.sharedGlobal(withName: storeName))
        store["key1"] = "value1"
        
        KeyValueEncryptedFileStore.clearGlobalCache()
        
        store = try XCTUnwrap(KeyValueEncryptedFileStore.sharedGlobal(withName: storeName))
        XCTAssertEqual(store["key1"], "value1")
    }
}
