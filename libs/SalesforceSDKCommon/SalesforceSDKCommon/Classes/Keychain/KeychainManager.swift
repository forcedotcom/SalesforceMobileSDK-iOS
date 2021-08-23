//
//  KeychainHelper.swift
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
                                    String(kSecAttrService): service]

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
    static let tag = "com.salesforce.mobilesdk"

    let accessibleAttribute: CFString
    
    /// Initializer for kSecClassGenericPassword with accessgroup. Will create a keychain item manager
    /// for kSecClassGenericPassword operations
    convenience init(service: String, account: String?) {
        self.init(service: service, account: account, accessibilityAttribute: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    /// Initializer for kSecClassGenericPassword with accessgroup. Will create a keychain item manager
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - account: Account name for keychain item
    ///   - accessibilityAttribute: kSecAttrAccessible Attribute for keychain
    init(service: String, account: String?, accessibilityAttribute: CFString) {
        self.secureStoreQueryable = GenericPasswordItemQuery(service: service,
                                                             account: account,
                                                             accessGroup: nil)
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

    fileprivate static func mapError(from status: OSStatus) -> NSError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        let error = NSError(domain: KeychainItemManager.errorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message, "com.salesforce.security.keychainException.errorCode": status])
        return error
    }

    fileprivate static func mapError(message: String) -> NSError {
        let error = NSError(domain: KeychainItemManager.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        return error
    }
}

@objc(SFSDKKeychainResult)
public class KeychainResult: NSObject {
    @objc public let success: Bool
    @objc public let status: OSStatus
    @objc public let data: Data?
    @objc public let error: NSError?

    internal init(data: Data?, status: OSStatus) {
        self.success = true
        self.status = status
        self.data = data
        self.error = nil
    }

    internal init(error: NSError, status: OSStatus) {
        self.success = false
        self.status = status
        self.data = nil
        self.error = error
    }
}

/// KeychainItemAccessibility  used as the kSecAttrAccessible Value Constants
@objc public enum KeychainItemAccessibility: Int {

    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly

    var asCFString: CFString {
        switch self {
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked

        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock

        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }

    var asString: String {
        return String(self.asCFString)
    }
}

@objc(SFSDKKeychainHelper)
public class KeychainHelper: NSObject {

    private static let upgrade: Void = {
        _ = KeychainUpgradeManager.init().upgradeManagedKeys()
    }()

    private static var keychainAccessibleAttribute: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    //pre 9.1 keys are updated to have the creator tag.
    private static func upgradeIfRequired() {
        self.upgrade
    }

    /// Read a value from the keychain.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func read(service: String, account: String?) -> KeychainResult {
        self.upgradeIfRequired()
        return CachedWrapper.wrap(service, account) { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute)
            return keychainManager.getValue()
        }
       
    }

    /// Create an item in the keychain if not present.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func createIfNotPresent(service: String, account: String?) -> KeychainResult {
        self.upgradeIfRequired()
        
        return CachedWrapper.wrap(service, account) { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute)
            var keychainResult = keychainManager.getValue()
            if !keychainResult.success && keychainResult.status == errSecItemNotFound {
                keychainResult = keychainManager.addEmptyValue()
            }
            
            return keychainResult
        }
       
    }

    /// Write or Update an item in the keychain if not present.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - data: Data to write
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func write(service: String, data: Data, account: String?) -> KeychainResult {
        self.upgradeIfRequired()
        
        return CachedWrapper.wrapWrites(service, data, account) { service, data, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute)
            return keychainManager.setValue(data)
        }
        
    }

    /// If an item is found remove it and then add an empty entry i.e. data is nil.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func reset(service: String, account: String?) -> KeychainResult {
        self.upgradeIfRequired()
        
        return CachedWrapper.wrapRemoves(service, account) { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute)
            var keychainResult = keychainManager.getValue()
            if keychainResult.success, keychainManager.removeValue().success {
                keychainResult = keychainManager.addEmptyValue()
            }
            return keychainResult
        }
    }

    /// Remove an item from the keychain.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func remove(service: String, account: String?) -> KeychainResult {
        self.upgradeIfRequired()
        
        return CachedWrapper.wrapRemoves(service, account) { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute)
            var keychainResult = keychainManager.getValue()
            if keychainResult.success {
                keychainResult = keychainManager.removeValue()
            }
            return keychainResult
        }
       
    }

    /// Remove all keychain items created by the mobile sdk.
    /// - Returns: KeychainResult
    @objc public class func removeAll() -> KeychainResult {
        self.upgradeIfRequired()
        return CachedWrapper.wrapRemoveAll {
            let deleteQuery: [String: Any] = [
                String(kSecClass): kSecClassGenericPassword,
                String(kSecAttrCreator): String(KeychainItemManager.tag)]

            let deleteStatus =  SecItemDelete(deleteQuery as CFDictionary)
            if deleteStatus == errSecSuccess {
                return KeychainResult(data: nil, status: deleteStatus)
            }

            if deleteStatus == errSecItemNotFound {
                return KeychainResult(error: KeychainItemManager.mapError(from: deleteStatus), status: deleteStatus)
            }
            return KeychainResult(data: nil, status: deleteStatus)
        }
    }

    /// Use this to relax or change the accessibility attribute for keychain items.
    /// - Parameter secAttrAccessible: Should be the accessibility attribute as defined by
    /// - Returns: KeychainResult
    @objc public class func setAccessibleAttribute(_ secAttrAccessible: KeychainItemAccessibility) -> KeychainResult {
       
        if accessibleAttributeMatches(secAttrAccessible) {
            return KeychainResult.init(data: Data(), status: errSecSuccess)
        }
        
        CachedWrapper.clearAllCaches()
        let accessibleAttribute = secAttrAccessible.asCFString
        if accessibleAttribute == keychainAccessibleAttribute {
            SalesforceLogger.log(KeychainHelper.self,level: .debug, message: "Attempting to update accessibility attribute for mobilesdk keychain items to the same level, will result in a noop")
            return KeychainResult(data: nil, status: errSecSuccess)
        }
        keychainAccessibleAttribute = accessibleAttribute
        self.upgradeIfRequired()
        let query: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecMatchLimit): kSecMatchLimitAll,
            String(kSecReturnAttributes): kCFBooleanTrue!]

        let updateQuery: [String: Any] = [
            String(kSecClass): kSecClassGenericPassword]

        var queryResult: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)

        if status == errSecItemNotFound {
            SalesforceLogger.log(KeychainHelper.self,level: .debug, message: "Attempt to update accessibility attribute for mobilesdk items, no items found")
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }

        if status != errSecSuccess {
            SalesforceLogger.log(KeychainHelper.self,level: .error, message: "Attempt to update accessibility attribute for mobilesdk items failed!")
            return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)
        }


        if (queryResult as? [[String : Any]]) != nil {
            SalesforceLogger.log(KeychainHelper.self,level: .info, message: "Retrieved keychain items, will now update!")
            let kAttributes: [String: Any] = [String(kSecAttrAccessible): keychainAccessibleAttribute]
            let status = SecItemUpdate(updateQuery as CFDictionary,
                                       kAttributes as CFDictionary)

            if status != errSecSuccess {
                SalesforceLogger.log(KeychainHelper.self,level: .error, message: "Attempt to update accessibility attribute for mobilesdk items failed!")
                return KeychainResult(error: KeychainItemManager.mapError(from: status), status: status)

            }
            SalesforceLogger.log(KeychainHelper.self,level: .info, message: "Attempt to update accessibility attribute for mobilesdk items succeeded!")
        }

        var queryUpdateResult: AnyObject?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &queryUpdateResult)
        if readStatus != errSecSuccess {
            SalesforceLogger.log(KeychainHelper.self,level: .error, message: "Attempt to update accessibility attribute for mobilesdk items failed!")
            return KeychainResult(error: KeychainItemManager.mapError(from: readStatus), status: readStatus)
        }
        return KeychainResult(data: nil, status: readStatus)
    }
    
    /// Use this call to clear caches.
    @objc public class func clearCaches() {
        CachedWrapper.clearAllCaches()
    }
    
    private class func accessibleAttributeMatches(_ secAttrAccessible: KeychainItemAccessibility) -> Bool {
        let query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                        String(kSecAttrService): KeychainUpgradeManager.baseAppIdentifierKey,
                        String(kSecMatchLimit): kSecMatchLimitOne,
                        String(kSecReturnAttributes): kCFBooleanTrue as Any]


        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)

        guard errSecSuccess == status else {
            return false
        }
        guard let item = queryResult as? [String: Any],
              let accessibleAttr = item[String(kSecAttrAccessible)] as? String else {
            return false
        }

        return secAttrAccessible.asString ==  accessibleAttr
    }
    
    internal class CachedWrapper {
        
        static var cache: SafeMutableDictionary<NSString, KeychainResult> = SafeMutableDictionary<NSString, KeychainResult>()
        
        class func key(service: String, account: String?) -> NSString {
            guard let acc = account else {
                return NSString(string: "\(service)")
            }
            return NSString(string: "\(service)_\(acc)")
        }
        
        class func wrap(_ service: String, _ account: String?, readFunc: (String, String?) -> KeychainResult ) -> KeychainResult {
            guard let result = cache[key(service: service, account: account)]  else{
                let keychainResult =  readFunc(service, account)
                if keychainResult.success {
                    cache[key(service: service, account: account)]  = keychainResult
                }
                return keychainResult
            }
            return result
        }
        
        class func wrapWrites(_ service: String, _ data: Data, _ account: String?, writeFunc: (String, Data, String?) -> KeychainResult ) -> KeychainResult {
            if let _ = cache[key(service: service, account: account)] {
                cache.removeObject(key(service: service, account: account))
            }
            let newKeychainResult = writeFunc(service, data, account)
            cache[key(service: service, account: account)] = newKeychainResult
            return newKeychainResult
        }
        
        class func wrapRemoves(_ service: String, _ account: String?, removeFunc: (String, String?) -> KeychainResult ) -> KeychainResult {
            if let _ = cache[key(service: service, account: account)] {
                cache.removeObject(key(service: service, account: account))
            }
            let newKeychainResult = removeFunc(service, account)
            return newKeychainResult
        }
        
        class func wrapRemoveAll(removeAllFunc: () -> KeychainResult) -> KeychainResult {
            cache.removeAllObjects()
            let newKeychainResult = removeAllFunc()
            return newKeychainResult
        }
        
        class func clearAllCaches() {
            self.cache.removeAllObjects()
        }
       
    }

    
    //Pre 9.1 Upgrade Handling
    internal class KeychainUpgradeManager {

        static let baseAppIdentifierKey = "com.salesforce.security.baseappid"
        let managedKeys = ["com.salesforce.security.passcode",
                           "com.salesforce.security.IV",
                           baseAppIdentifierKey,
                           "com.salesforce.security.baseappid.sim",
                           "com.salesforce.oauth.access",
                           "com.salesforce.oauth.refresh",
                           "com.salesforce.security.lockoutTime",
                           "com.salesforce.security.isLocked",
                           "com.salesforce.security.passcode.pbkdf2.verify"]
        let dynamicKeys = [ "com.salesforce.keystore.generatedKeystoreKeychainId",
        "com.salesforce.keystore.generatedKeystoreEncryptionKeyId"]

        var baseAppIdentifierValue: String?

        func upgradeManagedKeys() -> Bool {
            var result = true
            SalesforceLogger.log(KeychainUpgradeManager.self, level: .info, message: "Attempting to upgrade keychain keys.")
            managedKeys.forEach { result = self.upgradeManagedKey(identifier: $0) && result  }
            if result {
                SalesforceLogger.log(KeychainUpgradeManager.self, level: .info,
                                     message: "Attempting to upgrade keychain keys succeeded.")
            } else {
                SalesforceLogger.log(KeychainUpgradeManager.self, level: .error,
                                     message: "Attempting to upgrade keychain keys failed.")
            }

            if let baseAppIdentifier = getBaseIdentifierValue() {
                SalesforceLogger.log(KeychainUpgradeManager.self, level: .info,
                                     message: "Base app identifer retrieved, upgrading dynamic keys.")
                let keys = dynamicKeys.map { "\($0)_\(baseAppIdentifier)" }
                keys.forEach {  result = self.upgradeManagedKey(identifier: $0) && result }
            }

            return result
        }

        func upgradeManagedKey(identifier: String) -> Bool {
            let query: [String: Any] = [String(kSecMatchLimit): kSecMatchLimitAll,
                                        String(kSecReturnAttributes): kCFBooleanTrue!,
                                        String(kSecClass): String(kSecClassGenericPassword),
                                        String(kSecAttrService): identifier]

            var queryResult: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &queryResult)
            var result = true
            switch status {
            case errSecSuccess:
                if let items = queryResult as? [[String: Any]] {
                    items.forEach {
                        result = self.updateKeyAttributeWithCreator(attributes: $0, identifier: identifier) && result
                    }
                }
            default: ()
            }
            return result
        }

        //add the creator tag into the attributes for pre 9.1 keychain items
        func updateKeyAttributeWithCreator(attributes: [String: Any], identifier: String) -> Bool {
            if attributes[String(kSecAttrCreator)] != nil {
                //NOOP if the tag already exists
                return true
            }
            var query: [String: Any] = [
                String(kSecClass): String(kSecClassGenericPassword),
                String(kSecAttrService): identifier]
            if let account = attributes[String(kSecAttrAccount)] as? String, account.count > 0 {
                query[String(kSecAttrAccount)] = account
            }

            let kAttributes: [String: Any] = [String(kSecAttrCreator): KeychainItemManager.tag]
            let status = SecItemUpdate(query as CFDictionary,
                                       kAttributes as CFDictionary)

            if status != errSecSuccess {
                SalesforceLogger.log(KeychainUpgradeManager.self, level: .error, message: "Attempt to upgrade keychain key \(identifier) failed!")
                return false
            }
            return true
        }

        func  getBaseIdentifierValue() -> String? {

            let query: [String: Any] = [String(kSecClass): String(kSecClassGenericPassword),
                            String(kSecAttrService): KeychainUpgradeManager.baseAppIdentifierKey,
                            String(kSecMatchLimit): kSecMatchLimitOne,
                            String(kSecReturnAttributes): kCFBooleanTrue as Any,
                            String(kSecReturnData): kCFBooleanTrue as Any]


            var queryResult: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &queryResult)


            guard errSecSuccess == status else {
                return nil
            }
            guard let item = queryResult as? [String: Any],
                  let resultData = item[String(kSecValueData)] as? Data,
                  let resultString = String(data: resultData, encoding: .utf8 ) else {
                return nil
            }

            return resultString

        }
    }
}
