//
//  KeychainManager.swift
//  SecureSDK
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
/// KeyStoreError is thrown for errors related to keychain item access.
internal enum KeyStoreError: Error {
    case keychainError(message: String)
    
    static func mapError(from status: OSStatus) -> KeyStoreError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        return .keychainError(message: message)
    }
}

/// A basic queryable interface to look for keychain items, just a bunch of key value pairs
internal protocol SecureKeyStoreItemQueryable {
    var query: [String: Any] { get }
}

/// A generic queryable interface to look for keychain items classified as kSecClassGenericPassword
internal struct GenericKeyStoreItemQueryable {
    
    let service: String
    let account: String?
    let accessGroup: String?
}

/// Adds kSecClassGenericPassword to the queryable
extension GenericKeyStoreItemQueryable: SecureKeyStoreItemQueryable {
    
    var query: [String: Any] {
        var query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                                    String(kSecAttrService): service,
                                    String(kSecMatchLimit): String(kSecMatchLimitOne),
                                    String(kSecReturnAttributes): true,
                                    String(kSecReturnData): true,
                        ];
        
        #if !targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            query[String(kSecAttrAccessGroup)] = accessGroup
        }
        #endif
        if let account = account {
            query[ String(kSecAttrAccount)] = account
        }
        
        return query
    }
}

@objc(SFSDKKeychainHelper)
public class KeychainHelper: NSObject {
    
    @objc public class func readItem(identifier: String, account: String?, accessGroup: String?) throws -> Data {
        let keychainManager = KeychainManager(service: identifier, account: account, accessGroup: accessGroup)
        return try keychainManager.getValue(for: identifier)
    }
    
    @objc public class func writeItem(identifier: String, data: Data, account: String?, accessGroup: String?) throws  {
        let keychainManager = KeychainManager(service: identifier, account: account, accessGroup: accessGroup)
        try keychainManager.setValue(data, for: identifier)
    }
    
    @objc public class func resetKeychainItem(identifier: String, account: String?, accessGroup: String?) throws {
        let keychainManager = KeychainManager(service: identifier, account: account, accessGroup: accessGroup)
        try keychainManager.removeValue(for: identifier)
    }
    
}

@objc(SFSDKKeychainManager)
public class KeychainManager: NSObject {
    let secureStoreQueryable: SecureKeyStoreItemQueryable
    
    
    /// Initializer for kSecClassGenericPassword with accessgroup. Will create a keychain manager for kSecClassGenericPassword operations
    @objc public init(service: String, account: String?, accessGroup: String?) {
        self.secureStoreQueryable = GenericKeyStoreItemQueryable(service: service, account: account, accessGroup: accessGroup)
    }
    
    /// Set a value into the keychain for a given identifier.
    /// - Parameters:
    ///   - data: Value to store
    ///   - identifer: key to use
    /// - Throws: KeyStoreError wich wraps the underlying error message
    @objc public func setValue(_ data: Data, for identifer: String) throws {
        var query = self.secureStoreQueryable.query
        query.merge([String(kSecAttrAccount): identifer]){ (current, _) in current }
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.mapError(from: status)
        }
        
        if status == errSecItemNotFound {
            query[String(kSecValueData)] = data
            status = SecItemAdd(query as CFDictionary, nil)
            
        } else {
            let attributesToUpdate: [String: Any] = [String(kSecValueData):data]
            status = SecItemUpdate(query as CFDictionary,
                                   attributesToUpdate as CFDictionary)
        }
        
        //failure to add or update
        if status != errSecSuccess {
            let error = KeyStoreError.mapError(from: status)
            throw error
        }
    }
    
    /// Get a value into the keychain for a given identifier.
    /// - Parameter identifer: Key to use
    /// - Throws: KeyStoreError wich wraps the underlying error message
    /// - Returns: Value retrieved for the givenidentifier
    @objc public func getValue(for identifer: String) throws -> Data {
        
        let additions: [String: Any] = [String(kSecMatchLimit): kSecMatchLimitOne,
                                        String(kSecReturnAttributes): kCFBooleanTrue as Any,
                                        String(kSecReturnData): kCFBooleanTrue as Any,
                                        String(kSecAttrAccount): identifer]
        
        var query = secureStoreQueryable.query
        query.merge(additions) { (current, _) in current }
        
        var queryResult: AnyObject?
        
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }
        
        guard errSecSuccess == status else {
            throw KeyStoreError.mapError(from: status)
        }
        
        guard let item = queryResult as? [String: Any],
              let resultData = item[String(kSecValueData)] as? Data else {
            let message = "Could not retrieve item from keychain"
            throw KeyStoreError.keychainError(message: message)
        }
        return resultData
        
    }
    
    /// Remove value for a given identifier.
    /// - Parameter identifier: the key to use.
    /// - Throws: KeyStoreError wich wraps the underlying error message
    @objc public func removeValue(for identifier: String) throws {
        var query = secureStoreQueryable.query
        query[String(kSecAttrAccount)] = identifier
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            let error = KeyStoreError.mapError(from: status)
            throw error
        }
    }
    
    
    /// Remove all values for a given queryable class
    /// - Throws: KeyStoreError wich wraps the underlying error message
    @objc public func removeAllValues() throws {
        let query = secureStoreQueryable.query
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            let error = KeyStoreError.mapError(from: status)
            throw error
        }
    }
}
