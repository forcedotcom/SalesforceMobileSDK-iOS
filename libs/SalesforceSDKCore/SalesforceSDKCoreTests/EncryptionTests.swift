//
//  EncryptionTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 2/9/21.
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

class EncryptionTests: XCTestCase {

    override func setUpWithError() throws {
        _ = KeychainHelper.removeAll()
    }
    
    func testEncryptDecrypt() throws {
        let key = try KeyGenerator.encryptionKey(for: "test1")
        let sensitiveInfo = "My sensitive info"
        let sensitiveData = Data(sensitiveInfo.utf8)
        let encryptedData = try Encryptor.encrypt(data: sensitiveData, using: key)
        XCTAssertNotEqual(sensitiveData, encryptedData)
        
        let keyAgain = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertEqual(key, keyAgain)
        
        let decryptedData = try Encryptor.decrypt(data: encryptedData, using: keyAgain)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        XCTAssertEqual(decryptedString, sensitiveInfo)
    }
    
    func testEncryptDecryptWrongKey() throws {
        let key = try KeyGenerator.encryptionKey(for: "test1")
        let sensitiveInfo = "My sensitive info"
        let sensitiveData = Data(sensitiveInfo.utf8)
        let encryptedData = try Encryptor.encrypt(data: sensitiveData, using: key)
        XCTAssertNotEqual(sensitiveData, encryptedData)
        
        let differentKey = try KeyGenerator.encryptionKey(for: "test2")
        XCTAssertNotEqual(key, differentKey)
        XCTAssertThrowsError(try Encryptor.decrypt(data: encryptedData, using: differentKey))
    }
    
    func testECKeyCreationDeletion() throws {
        let publicKeyTag = try KeyGenerator.keyTag(name: "ECTest", prefix: KeyGenerator.ecPublicKeyTagPrefix)
        let privateKeyTag = try KeyGenerator.keyTag(name: "ECTest", prefix: KeyGenerator.ecPrivateKeyTagPrefix)
        
        _ = try KeyGenerator.createECKeyPair(privateTag: privateKeyTag, publicTag: publicKeyTag)
        XCTAssertNotNil(try KeyGenerator.ecKey(tag: publicKeyTag))
        XCTAssertNotNil(try KeyGenerator.ecKey(tag: privateKeyTag))
        
        KeyGenerator.removeECKeyPair(privateTag: privateKeyTag, publicTag: publicKeyTag)
        XCTAssertNil(try KeyGenerator.ecKey(tag: publicKeyTag))
        XCTAssertNil(try KeyGenerator.ecKey(tag: privateKeyTag))
    }
    
    func testSymmetricKeyRetrievalECKeyReset() throws {
        let publicKeyTag = try KeyGenerator.keyTag(name: KeyGenerator.defaultKeyName, prefix: KeyGenerator.ecPublicKeyTagPrefix)
        let privateKeyTag = try KeyGenerator.keyTag(name: KeyGenerator.defaultKeyName, prefix: KeyGenerator.ecPrivateKeyTagPrefix)
        
        // Just remove private key
        XCTAssertNotNil(try KeyGenerator.encryptionKey(for: "reset1"))
        XCTAssertTrue(KeyGenerator.removeKey(tag: privateKeyTag))
        KeyGenerator.keyCache.removeValue(forKey: "reset1")
        var key = try KeyGenerator.encryptionKey(for: "reset1")
        XCTAssertNotNil(key, "Couldn't generate new symmetric key after EC private key removal")
        // Read the key from the keychain (not cache) to make sure it can be decrypted with new EC key pair
        KeyGenerator.keyCache.removeValue(forKey: "reset1")
        var keyAgain = try KeyGenerator.encryptionKey(for: "reset1")
        XCTAssertEqual(key, keyAgain)
        
        // Just remove public key
        XCTAssertNotNil(try KeyGenerator.encryptionKey(for: "reset2"))
        XCTAssertTrue(KeyGenerator.removeKey(tag: publicKeyTag))
        KeyGenerator.keyCache.removeValue(forKey: "reset2")
        key = try KeyGenerator.encryptionKey(for: "reset2")
        XCTAssertNotNil(key, "Couldn't generate new symmetric key after EC public key removal")
        KeyGenerator.keyCache.removeValue(forKey: "reset2")
        keyAgain = try KeyGenerator.encryptionKey(for: "reset2")
        XCTAssertEqual(key, keyAgain)

        // Remove key pair
        XCTAssertNotNil(try KeyGenerator.encryptionKey(for: "reset3"))
        XCTAssertTrue(KeyGenerator.removeECKeyPair(privateTag: privateKeyTag, publicTag: publicKeyTag))
        KeyGenerator.keyCache.removeValue(forKey: "reset3")
        key = try KeyGenerator.encryptionKey(for: "reset3")
        XCTAssertNotNil(key, "Couldn't generate new symmetric key after EC key pair removal")
        KeyGenerator.keyCache.removeValue(forKey: "reset3")
        keyAgain = try KeyGenerator.encryptionKey(for: "reset3")
        XCTAssertEqual(key, keyAgain)
    }

    func testSymmetricKeyRecoveryAfterECBug() throws {
        let publicKeyTag = try KeyGenerator.keyTag(name: KeyGenerator.defaultKeyName, prefix: KeyGenerator.ecPublicKeyTagPrefix)
        let privateKeyTag = try KeyGenerator.keyTag(name: KeyGenerator.defaultKeyName, prefix: KeyGenerator.ecPrivateKeyTagPrefix)
        KeyGenerator.removeECKeyPair(privateTag: privateKeyTag, publicTag: publicKeyTag)
        
        // Get symmetric key that generates pair
        let key = try KeyGenerator.encryptionKey(for: "keyName")

        // After restore to same device, public key would be present but not private key
        XCTAssertTrue(KeyGenerator.removeKey(tag: privateKeyTag))
        
        // Previous bug would mean another EC key pair would be created in addition to the existing single public key
        _ = try KeyGenerator.createECKeyPair(privateTag: privateKeyTag, publicTag: publicKeyTag)
        
        // Check that the public key will throw error because it found more than one
        XCTAssertThrowsError(try KeyGenerator.ecKey(tag: publicKeyTag))
        
        // This should regenerate a new key after being unable to decrypt the old key and deleting the EC duplicates
        KeyGenerator.keyCache.removeValue(forKey: "keyName")
        let resetKey = try KeyGenerator.encryptionKey(for: "keyName")
        XCTAssertNotEqual(key, resetKey)
        let unencryptedData = Data("this is a test".utf8)
        let encryptedData = try Encryptor.encrypt(data: unencryptedData, using: resetKey)
        let decryptedData = try Encryptor.decrypt(data: encryptedData, using: resetKey)
        XCTAssertEqual(unencryptedData, decryptedData)
        
        // Getting the key for a second time after reset should return the same key, make sure it can decrypt the same data
        KeyGenerator.keyCache.removeValue(forKey: "keyName")
        let resetKeyAgain = try KeyGenerator.encryptionKey(for: "keyName")
        XCTAssertEqual(resetKey, resetKeyAgain)
        let decryptedDataAgain = try Encryptor.decrypt(data: encryptedData, using: resetKeyAgain)
        XCTAssertEqual(unencryptedData, decryptedDataAgain)
    }
    
    func testConcurrency() throws {
        let result = SafeMutableArray()
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            if let symmetricKey = try? KeyGenerator.encryptionKey(for: "singleLabel") {
                result.add(symmetricKey.dataRepresentation as NSData)
            }
        }
        
        XCTAssertEqual(1000, result.count)
        let firstItem = try XCTUnwrap(result.object(atIndexed: 0) as? NSData)
        XCTAssertTrue(result.asArray().allSatisfy { item in
            return item as? NSData == firstItem
        })
    }
}
