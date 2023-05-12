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
//

import Foundation

@objc(SFSDKKeychainHelper)
public class KeychainHelper: NSObject {
    
    typealias KeychainOperation = (String, String?) -> KeychainResult
    
    /// Default access group, used for all operations unless otherwise specfied at the method level
    @objc public static var accessGroup: String?
    @objc public static var cacheEnabled: Bool = true
    @objc public private(set) static var accessibilityAttribute: CFString?
    
    @objc public enum CacheMode: Int {
        case unspecified
        case enabled
        case disabled
    }

    private static var keychainAccessibleAttribute: CFString {
        return accessibilityAttribute ?? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }

    private static let upgrade: Void = {
        _ = KeychainUpgradeManager.init().upgradeManagedKeys()
    }()

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
        return read(service: service, account: account, accessGroup: KeychainHelper.accessGroup, cacheMode: .unspecified)
    }

    /// Read a value from the keychain for a given access group
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - account: Account name for keychain item
    ///   - accessGroup: kSecAttrAccessGroup attribute for keychain item
    /// - Returns: KeychainResult
    @objc public class func read(service: String, account: String?, accessGroup: String? = nil, cacheMode: CacheMode) -> KeychainResult {
        self.upgradeIfRequired()
        
        let keychainRead: KeychainOperation = { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute,
                                                      accessGroup: KeychainHelper.accessGroup(accessGroup))
            return keychainManager.getValue()
        }
        
        if cacheEnabled(cacheMode) {
            return CachedWrapper.wrap(service, account, keychainFunc: keychainRead)
        } else {
            return keychainRead(service, account)
        }
        
    }

    /// Create an item in the keychain if not present.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func createIfNotPresent(service: String, account: String?) -> KeychainResult {
        return createIfNotPresent(service: service, account: account, accessGroup: accessGroup, cacheMode: .unspecified)
    }
    
    /// Create an item in the keychain if not present.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func createIfNotPresent(service: String, account: String?, accessGroup: String? = nil, cacheMode: CacheMode = .unspecified) -> KeychainResult {
        self.upgradeIfRequired()
        
        let keychainCreateIfNotPresent: KeychainOperation = { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute,
                                                      accessGroup: KeychainHelper.accessGroup(accessGroup))
            var keychainResult = keychainManager.getValue()
            if !keychainResult.success && keychainResult.status == errSecItemNotFound {
                keychainResult = keychainManager.addEmptyValue()
            }
            return keychainResult
        }
        
        if cacheEnabled(cacheMode) {
            return CachedWrapper.wrap(service, account, keychainFunc: keychainCreateIfNotPresent)
        } else {
            return keychainCreateIfNotPresent(service, account)
        }
    }

    /// Write or Update an item in the keychain if not present.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - data: Data to write
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func write(service: String, data: Data, account: String?) -> KeychainResult {
        write(service: service, data: data, account: account, accessGroup: accessGroup, cacheMode: .unspecified)
    }

    ///  Update or create an item in the keychain if not present for a given access group
    /// - Parameters:
    ///   - service: Service name for keychain item
    ///   - data:  Data to write
    ///   - account: Account name for keychain item
    ///   - accessGroup: kSecAttrAccessGroup attribute for keychain item
    /// - Returns: KeychainResult
    @objc public class func write(service: String, data: Data, account: String?, accessGroup: String? = nil, cacheMode: CacheMode = .unspecified) -> KeychainResult {
        self.upgradeIfRequired()
        
        let keychainWrite: (String, Data, String?) -> KeychainResult = { service, data, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute,
                                                      accessGroup: KeychainHelper.accessGroup(accessGroup))
            return keychainManager.setValue(data)
        }
        
        if cacheEnabled(cacheMode) {
            return CachedWrapper.wrapWrites(service, data, account, writeFunc: keychainWrite)
        } else {
            return keychainWrite(service, data, account)
        }
    }

    /// If an item is found remove it and then add an empty entry i.e. data is nil.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func reset(service: String, account: String?) -> KeychainResult {
        return reset(service: service, account: account, accessGroup: accessGroup, cacheMode: .unspecified)
    }
    
    @objc public class func reset(service: String, account: String?, accessGroup: String? = nil, cacheMode: CacheMode = .unspecified) -> KeychainResult {
        self.upgradeIfRequired()
        
        let keychainReset: KeychainOperation = { service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute,
                                                      accessGroup: KeychainHelper.accessGroup(accessGroup))
            var keychainResult = keychainManager.getValue()
            if keychainResult.success, keychainManager.removeValue().success {
                keychainResult = keychainManager.addEmptyValue()
            }
            return keychainResult
        }
        
        if cacheEnabled(cacheMode) {
            return CachedWrapper.wrapRemoves(service, account, removeFunc: keychainReset)
        } else {
            return keychainReset(service, account)
        }
    }
    

    /// Remove an item from the keychain.
    /// - Parameters:
    ///   - service: Identifier to use for keychain service key.
    ///   - account: Identifier to use for keychain account key.
    /// - Returns: KeychainResult
    @objc public class func remove(service: String, account: String?) -> KeychainResult {
        return remove(service: service, account: account, accessGroup: accessGroup, cacheMode: .unspecified)
    }
    
    @discardableResult
    @objc public class func remove(service: String, account: String?, accessGroup: String? = nil, cacheMode: CacheMode = .unspecified) -> KeychainResult {
        self.upgradeIfRequired()
        
        let keychainRemove: KeychainOperation = {service, account in
            let keychainManager = KeychainItemManager(service: service,
                                                      account: account,
                                                      accessibilityAttribute: KeychainHelper.keychainAccessibleAttribute,
                                                      accessGroup: KeychainHelper.accessGroup(accessGroup))
            var keychainResult = keychainManager.getValue()
            if keychainResult.success {
                keychainResult = keychainManager.removeValue()
            }
            return keychainResult
        }
        
        if cacheEnabled(cacheMode) {
            return CachedWrapper.wrapRemoves(service, account, removeFunc: keychainRemove)
        } else {
            return keychainRemove(service, account)
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

            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
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
    @objc @discardableResult
    public class func setAccessibleAttribute(_ secAttrAccessible: KeychainItemAccessibility) -> KeychainResult {
       
        accessibilityAttribute = secAttrAccessible.asCFString
        if accessibleAttributeMatches(secAttrAccessible) {
            return KeychainResult.init(data: Data(), status: errSecSuccess)
        }
        
        CachedWrapper.clearAllCaches()
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
    
    private class func accessGroup(_ accessGroup: String?) -> String? {
        return accessGroup ?? KeychainHelper.accessGroup
    }
    
    private class func cacheEnabled(_ cacheMode: CacheMode) -> Bool {
        switch cacheMode {
        case .enabled:
            return true
        case .disabled:
            return false
        case .unspecified:
            return KeychainHelper.cacheEnabled
        }
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
        static private(set) var cache = Dictionary<NSString, KeychainResult>()
        static private var queue = DispatchQueue(label: "com.salesforce.mobilesdk.readWriteQueue\(arc4random_uniform(32))", qos: .unspecified, attributes: [.concurrent], autoreleaseFrequency: .inherit, target: nil)

        class func key(service: String, account: String?) -> NSString {
            guard let acc = account else {
                return NSString(string: "\(service)")
            }
            return NSString(string: "\(service)_\(acc)")
        }
        
        class func wrap(_ service: String, _ account: String?, keychainFunc: (String, String?) -> KeychainResult) -> KeychainResult {
            let key = key(service: service, account: account)
            
            // Try read without barrier
            let cacheValue = queue.sync {
                cache[key]
            }
            if let cacheValue = cacheValue {
                return cacheValue
            }
            
            return queue.sync(flags: .barrier) { () -> KeychainResult in
                // Checking current value again in case anything happened between first read and this
                if let currentValue = cache[key] {
                    return currentValue
                } else {
                    let keychainResult = keychainFunc(service, account)
                    if keychainResult.success {
                        cache[key] = keychainResult
                    }
                    return keychainResult
                }
            }
        }
        
        class func wrapWrites(_ service: String, _ data: Data, _ account: String?, writeFunc: (String, Data, String?) -> KeychainResult) -> KeychainResult {
            return queue.sync(flags: .barrier) {
                if let _ = cache[key(service: service, account: account)] {
                    cache.removeValue(forKey: key(service: service, account: account))
                }
                let newKeychainResult = writeFunc(service, data, account)
                cache[key(service: service, account: account)] = newKeychainResult
                return newKeychainResult
            }
        }
        
        class func wrapRemoves(_ service: String, _ account: String?, removeFunc: (String, String?) -> KeychainResult) -> KeychainResult {
            return queue.sync(flags: .barrier) {
                if let _ = cache[key(service: service, account: account)] {
                    cache.removeValue(forKey: key(service: service, account: account))
                }
                let newKeychainResult = removeFunc(service, account)
                return newKeychainResult
            }
        }
        
        class func wrapRemoveAll(removeAllFunc: () -> KeychainResult) -> KeychainResult {
            return queue.sync(flags: .barrier) {
                cache.removeAll()
                let newKeychainResult = removeAllFunc()
                return newKeychainResult
            }
        }
        
        class func clearAllCaches() {
            queue.async(flags: .barrier) {
                cache.removeAll()
            }
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
