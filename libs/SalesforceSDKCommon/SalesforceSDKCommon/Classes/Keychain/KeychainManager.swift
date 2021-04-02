//
//  KeychainManager.swift
//  MobileSDK
//
//  Created by Raj Rao on 1/21/21.
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

import Foundation

internal protocol KeychainItemQueryable {
    var query: [String: Any] { get }
}

/// Adds kSecClassGenericPassword to the queryable
internal struct GenericPasswordItemQuery: KeychainItemQueryable {
    
    let service: String
    let account: String?
    let accessGroup: String?
    var query: [String: Any] {
        var query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                                    String(kSecAttrService): service,
                                    String(kSecAttrAccessible): kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        
        #if !targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            query[String(kSecAttrAccessGroup)] = accessGroup
        }
        #endif
        if let account = account {
            query[String(kSecAttrAccount)] = account
        }
        
        return query
    }
    
}

internal class KeychainItemManager: NSObject {
    private let secureStoreQueryable: KeychainItemQueryable
    static let errorDomain = "com.salesforce.security.keychainException"
    
    /// Initializer for kSecClassGenericPassword with accessgroup. Will create a keychain item manager for kSecClassGenericPassword operations
    init(service: String, account: String?) {
        self.secureStoreQueryable = GenericPasswordItemQuery(service: service,
                                                             account: account,
                                                             accessGroup: nil)
    }
    
    /// Initializer for kSecClassGenericPassword with accessgroup. Will create a keychain item manager for kSecClassGenericPassword operations
    init(service: String, account: String?, accessGroup: String?) {
        self.secureStoreQueryable = GenericPasswordItemQuery(service: service,
                                                             account: account,
                                                             accessGroup: accessGroup)
    }
    
    /// Set a value into the keychain for a given identifier.
    /// - Parameters:
    ///   - data: Value to store
    /// - KeychainResult: success or error.
    func setValue(_ data: Data) -> KeychainResult {
        var query = self.secureStoreQueryable.query
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return KeychainResult(error: mapError(from: status), status: status)
        }
        
        if status == errSecItemNotFound {
            query[String(kSecValueData)] = data
            status = SecItemAdd(query as CFDictionary, nil)
        } else {
            let attributesToUpdate: [String: Any] = [String(kSecValueData): data]
            status = SecItemUpdate(query as CFDictionary,
                                   attributesToUpdate as CFDictionary)
        }
        
        //failure to add or update
        if status != errSecSuccess {
            return KeychainResult(error: mapError(from: status), status: status)
        }
        
        return self.getValue()
    }
    
    /// Set a value into the keychain for a given identifier.
    /// - Parameters:
    ///   - data: Value to store
    /// - KeychainResult: success or error.
    func addEmptyValue() -> KeychainResult {
        let query = self.secureStoreQueryable.query
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return KeychainResult(error: mapError(from: status), status: status)
        }
        
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        //failure to add or update
        if status != errSecSuccess {
            return KeychainResult(error: mapError(from: status), status: status)
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
        let  status = SecItemCopyMatching(query as CFDictionary, &queryResult)
        
        guard errSecSuccess == status else {
            return KeychainResult(error: mapError(from: status), status: status)
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
            let error = mapError(from: status)
            return KeychainResult(error: error, status: status)
        }
        return KeychainResult(data: nil, status: status)
    }
    
    private func mapError(from status: OSStatus) -> NSError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        let error = NSError(domain: KeychainItemManager.errorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message, "com.salesforce.security.keychainException.errorCode": status])
        return error
    }
    
    private func mapError(message: String) -> NSError {
        let error = NSError(domain: KeychainItemManager.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        return error
    }
}

@objc(SFSDKKeychainResult)
public class KeychainResult: NSObject {
    @objc public let success: Bool
    @objc public var status: OSStatus
    @objc public var data: Data?
    @objc public var error: NSError?
    
    @objc init(data: Data?, status: OSStatus) {
        self.success = true
        self.status = status
        self.data = data
    }
    
    init(error: NSError, status: OSStatus) {
        self.success = false
        self.status = status
        self.error = error
    }
}

@objc(SFSDKKeychainHelper)
public class KeychainHelper: NSObject {
    
    @objc public class func readItem(identifier: String, account: String?) -> KeychainResult {
        let keychainManager = KeychainItemManager(service: identifier, account: account)
        return keychainManager.getValue()
    }
    
    @objc public class func createItemIfNotPresent(identifier: String, account: String?) -> KeychainResult {
        let keychainManager = KeychainItemManager(service: identifier, account: account)
        var keychainResult =  keychainManager.getValue()
        if !keychainResult.success && keychainResult.status == errSecItemNotFound {
            keychainResult =  keychainManager.addEmptyValue()
        }
        return keychainResult
    }
    
    @objc public class func writeItem(identifier: String, data: Data, account: String?) -> KeychainResult  {
        let keychainManager = KeychainItemManager(service: identifier, account: account)
        return keychainManager.setValue(data)
    }
    
    @objc public class func resetItem(identifier: String, account: String?) -> KeychainResult {
        let keychainManager = KeychainItemManager(service: identifier, account: account)
        var keychainResult = keychainManager.getValue()
        if keychainResult.success == true, keychainManager.removeValue().success {
            keychainResult = keychainManager.addEmptyValue()
        }
        return keychainResult
    }
    
    @objc public class func removeItem(identifier: String, account: String?) -> KeychainResult {
        let keychainManager = KeychainItemManager(service: identifier, account: account)
        var keychainResult = keychainManager.getValue()
        if keychainResult.success == true {
            keychainResult = keychainManager.removeValue()
        }
        return keychainResult
    }
}
