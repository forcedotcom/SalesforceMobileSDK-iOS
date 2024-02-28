//
//  KeychainItemManager.swift
//  SalesforceSDKCommon
//
//  Created by Xiaoguang Yang on 8/24/22.
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
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

internal class KeychainItemManager: NSObject {
    private let secureStoreQueryable: KeychainItemQueryable
    static let errorDomain = "com.salesforce.security.keychainException"
    static let tag = "com.salesforce.mobilesdk"

    let accessibleAttribute: CFString
    
    /// Initializer for kSecClassGenericPassword. Will create a keychain item manager
    /// for kSecClassGenericPassword operations
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - account: Account name for keychain item
    convenience init(service: String, account: String?) {
        self.init(service: service, account: account, accessibilityAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }

    /// Initializer for kSecClassGenericPassword. Will create a keychain item manager
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - account: Account name for keychain item
    ///   - accessibilityAttribute: kSecAttrAccessible attribute for keychain
    convenience init(service: String, account: String?, accessibilityAttribute: CFString) {
        self.init(service: service, account: account, accessibilityAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, accessGroup: nil)
    }
    
    /// Initializer for kSecClassGenericPassword
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - account: Account name for keychain item
    ///   - accessibilityAttribute: kSecAttrAccessible attribute for keychain
    ///   - accessGroup: kSecAttrAccessGroup attribute for keychain
    init(service: String, account: String?, accessibilityAttribute: CFString, accessGroup: String?) {
        self.secureStoreQueryable = GenericPasswordItemQuery(service: service,
                                                             account: account,
                                                             accessGroup: accessGroup)
        self.accessibleAttribute = accessibilityAttribute
    }

    /// Set a value into the keychain for a given identifier.
    /// - Parameters:
    ///   - data: Value to store
    /// - KeychainResult: success or error.
    func setValue(_ data: Data) -> KeychainResult {
        var query = self.secureStoreQueryable.query
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }

        if status == errSecItemNotFound {
            query[String(kSecValueData)] = data
            query[String(kSecAttrCreator)] = KeychainItemManager.tag
            status = SecItemAdd(query as CFDictionary, nil)
        } else {
            let attributesToUpdate: [String: Any] = [String(kSecValueData): data,
                                                     String(kSecAttrAccessible): self.accessibleAttribute,
                                                     String(kSecAttrCreator): KeychainItemManager.tag]

            status = SecItemUpdate(query as CFDictionary,
                                   attributesToUpdate as CFDictionary)
        }

        //failure to add or update
        if status != errSecSuccess {
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }
      
        return self.getValue()
    }

    /// Set a value into the keychain for a given identifier.
    /// - Parameters:
    ///   - data: Value to store
    /// - KeychainResult: success or error.
    func addEmptyValue() -> KeychainResult {
        var query = self.secureStoreQueryable.query
        query[String(kSecAttrCreator)] = KeychainItemManager.tag
        var status = SecItemCopyMatching(query as CFDictionary, nil)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }

        if status == errSecItemNotFound {
            query[String(kSecAttrAccessible)] = self.accessibleAttribute
            status = SecItemAdd(query as CFDictionary, nil)
        }

        //failure to add or update
        if status != errSecSuccess {
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }

        return self.getValue()
    }

    /// Get a value into the keychain for a given identifier.
    /// - Returns: KeychainResult retrieved for the given identifier
    func getValue() -> KeychainResult {
        let additions: [String: Any] = [String(kSecMatchLimit): kSecMatchLimitOne,
                                        String(kSecReturnAttributes): kCFBooleanTrue as Any,
                                        String(kSecReturnData): kCFBooleanTrue as Any]

        var query = secureStoreQueryable.query
        query.merge(additions) { (current, _) in current }

        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)

        guard errSecSuccess == status else {
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }

        guard let item = queryResult as? [String: Any],
              let resultData = item[String(kSecValueData)] as? Data else {
            return KeychainResult(data: nil, status: status)
        }
        
        return KeychainResult(data: resultData, status: status)
    }

    /// Remove value for a given identifier.
    /// - Parameter identifier: the key to use.
    /// - Throws: KeyStoreError wich wraps the underlying error message
    func removeValue() -> KeychainResult {
        let query = secureStoreQueryable.query

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            let error = KeychainItemManager.mapError(from: status)
            return KeychainResult(error: error, status: status)
        }
        return KeychainResult(data: nil, status: status)
    }

    static func mapError(from status: OSStatus) -> NSError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        let error = NSError(domain: KeychainItemManager.errorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message, "com.salesforce.security.keychainException.errorCode": status])
        return error
    }

    static func mapError(message: String) -> NSError {
        let error = NSError(domain: KeychainItemManager.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        return error
    }
}
