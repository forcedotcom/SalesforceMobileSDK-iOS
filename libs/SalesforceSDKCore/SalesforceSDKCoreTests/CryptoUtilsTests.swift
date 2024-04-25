//
//  CryptoUtilsTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 3/1/24.
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

import Foundation
import SalesforceSDKCore
import Security.SecKey
import XCTest

class CryptoUtilsTests: XCTestCase {
    let rsaKeyPairName = "CryptoUtilsTests"
    private var privateKey: SecKey!
    private var publicKey: SecKey!
    
    override func setUpWithError() throws {
        SFSDKCryptoUtils.createRSAKeyPair(withName: rsaKeyPairName, keyLength: 2048, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        publicKey = try XCTUnwrap(SFSDKCryptoUtils.getRSAPublicKeyRef(withName: rsaKeyPairName, keyLength: 2048)?.takeUnretainedValue())
        privateKey = try XCTUnwrap(SFSDKCryptoUtils.getRSAPrivateKeyRef(withName: rsaKeyPairName, keyLength: 2048)?.takeUnretainedValue())
    }
    
    func testEncryptDecrypt() throws {
        let stringToEncrypt = "Test string"
        let data = try XCTUnwrap(stringToEncrypt.data(using: .utf8))
        
        // rsaEncryptionPKCS1
        var encryptedData = try XCTUnwrap(SFSDKCryptoUtils.encrypt(data: data, key: publicKey, algorithm: SecKeyAlgorithm.rsaEncryptionPKCS1))
        var decryptedData = try XCTUnwrap(SFSDKCryptoUtils.decrypt(data: encryptedData, key: privateKey, algorithm: SecKeyAlgorithm.rsaEncryptionPKCS1))
        XCTAssertEqual(stringToEncrypt, String(bytes: decryptedData, encoding: .utf8))
        
        // rsaEncryptionOAEPSHA256
        encryptedData = try XCTUnwrap(SFSDKCryptoUtils.encrypt(data: data, key: publicKey, algorithm: SecKeyAlgorithm.rsaEncryptionOAEPSHA256))
        decryptedData = try XCTUnwrap(SFSDKCryptoUtils.decrypt(data: encryptedData, key: privateKey, algorithm: SecKeyAlgorithm.rsaEncryptionOAEPSHA256))
        XCTAssertEqual(stringToEncrypt, String(bytes: decryptedData, encoding: .utf8))
    }

    func testEncryptWithOldPKCS1MethodDecryptWithNew() throws {
        let stringToEncrypt = "Test string"
        let data = try XCTUnwrap(stringToEncrypt.data(using: .utf8))

        // Old encrypt
        let encryptedData = try XCTUnwrap(SFSDKCryptoUtils.encrypt(usingRSAforData: data, withKeyRef: publicKey)) // Deprecated method
        // New decrypt
        let decryptedData = try XCTUnwrap(SFSDKCryptoUtils.decrypt(data: encryptedData, key: privateKey, algorithm: SecKeyAlgorithm.rsaEncryptionPKCS1))
        XCTAssertEqual(stringToEncrypt, String(bytes: decryptedData, encoding: .utf8))
    }
}
