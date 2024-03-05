//
//  PushNotificationDecryptionTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 3/4/24.
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

@testable import SalesforceSDKCore
import Foundation
import XCTest

class PushNotificationDecryptionTests: XCTestCase {
    private var publicKey: SecKey!
    private let contentDictionary: [String: Any] = ["uid": "005B0000006nrtjIAA",
                                                    "alertBody": "Matt D updated Jane Smith (CEO, Acme)",
                                                    "notifType": "0MLB0000000Kz9TOAS",
                                                    "nid": "ad6a7f58e12729ca202e73a26830f7e9",
                                                    "oid": "00DB0000000ToZ3MAK",
                                                    "type": -1,
                                                    "alertTitle": "Contact Updated",
                                                    "cid": "all",
                                                    "sid": "0031Q00002kRzYLQA0"]
    
    override func setUpWithError() throws {
        SFSDKCryptoUtils.createRSAKeyPair(withName: "com.salesforce.mobilesdk.notificationKey", keyLength: 2048, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        publicKey = try XCTUnwrap(SFSDKCryptoUtils.getRSAPublicKeyRef(withName: "com.salesforce.mobilesdk.notificationKey", keyLength: 2048)).takeUnretainedValue()
    }
    
    func testPKCS1Secret() throws {
        let notificationContent = baseNotificationContent()
        
        // Symmetric encryption for payload
        let key = SFSDKCryptoUtils.randomByteData(withLength: 16)
        let iv = SFSDKCryptoUtils.randomByteData(withLength: 16)
        let jsonContent = try JSONSerialization.data(withJSONObject: contentDictionary)
        let encryptedContent = try XCTUnwrap(SFSDKCryptoUtils.aes128EncryptData(jsonContent, withKey: key, iv: iv)).base64EncodedString()
        
        // RSA-PKCS1 encryption for secret
        let secret = key + iv
        let encryptedSecret = try XCTUnwrap(SFSDKCryptoUtils.encrypt(usingRSAforData: secret, withKeyRef: publicKey))
        let secretString = encryptedSecret.base64EncodedString()
        
        notificationContent.userInfo[kRemoteNotificationKeySecret] = secretString
        notificationContent.userInfo[kRemoteNotificationKeyContent] = encryptedContent
        
        // Decrypt
        try SFSDKPushNotificationDecryption.decryptNotificationContent(notificationContent)
        XCTAssertEqual("Matt D updated Jane Smith (CEO, Acme)", notificationContent.body)
        XCTAssertEqual("Contact Updated", notificationContent.title)
    }
    
    func testOAEPSecret() throws {
        let notificationContent = baseNotificationContent()
        
        // Symmetric encryption for payload
        let key = SFSDKCryptoUtils.randomByteData(withLength: 16)
        let iv = SFSDKCryptoUtils.randomByteData(withLength: 16)
        let jsonContent = try JSONSerialization.data(withJSONObject: contentDictionary)
        let encryptedContent = try XCTUnwrap(SFSDKCryptoUtils.aes128EncryptData(jsonContent, withKey: key, iv: iv)).base64EncodedString()
        
        // RSA-OAEP encryption for secret
        let secret = key + iv
        let encryptedSecret = try XCTUnwrap(SFSDKCryptoUtils.encrypt(data: secret, key: publicKey, algorithm: SecKeyAlgorithm.rsaEncryptionOAEPSHA256))
        let secretString = encryptedSecret.base64EncodedString()
        
        notificationContent.userInfo[kRemoteNotificationKeySecret] = secretString
        notificationContent.userInfo[kRemoteNotificationKeyContent] = encryptedContent
        
        // Decrypt
        try SFSDKPushNotificationDecryption.decryptNotificationContent(notificationContent)
        XCTAssertEqual("Matt D updated Jane Smith (CEO, Acme)", notificationContent.body)
        XCTAssertEqual("Contact Updated", notificationContent.title)
    }
    
    func baseNotificationContent() -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.userInfo[kRemoteNotificationKeyEncrypted] = 1
        
        let title = "Plain text notification title"
        let body = "Plain text notification body"
        let alertDictionary = [kRemoteNotificationKeyTitle: title, kRemoteNotificationKeyBody: body]
        let apsDictionary = [kRemoteNotificationKeyAlert: alertDictionary]
        notificationContent.userInfo[kRemoteNotificationKeyAps] = apsDictionary
        
        return notificationContent
    }
}
