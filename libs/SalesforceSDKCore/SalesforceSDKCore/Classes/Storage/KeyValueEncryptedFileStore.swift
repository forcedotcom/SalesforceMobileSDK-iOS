//
//  KeyValueEncryptedFileStore.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 6/23/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCommon

@objc(SFSDKKeyValueEncryptedFileStore)
public class KeyValueEncryptedFileStore: NSObject {
    @objc(storeDirectory) public let directory: URL
    @objc(storeName) public let name: String
    @objc public static let maxStoreNameLength = 96

    private var encryptionKey: SFEncryptionKey
    private static var globalStores = SafeMutableDictionary<NSString, KeyValueEncryptedFileStore>()
    private static var userStores = SafeMutableDictionary<NSString, SafeMutableDictionary<NSString, KeyValueEncryptedFileStore>>()
    private static let keyValueStoresDirectory = "key_value_stores"
    private static let encryptionKeyLabel = "com.salesforce.keyValueStores.encryptionKey"

    /// Creates a store.
    /// - Parameter parentDirectory: Parent directory for the store.
    /// - Parameter name: Name of the store.
    /// - Parameter encryptionKey: Encryption key for the store.
    @objc public init?(parentDirectory: String, name: String, encryptionKey: SFEncryptionKey) {
        guard KeyValueEncryptedFileStore.isValidName(name) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Invalid store name")
            return nil
        }
        let fullPath = parentDirectory + "/\(name)"
        do {
            try SFDirectoryManager.ensureDirectoryExists(fullPath)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error ensuring directory exists: \(error)")
            return nil
        }
        self.name = name
        self.directory = URL(fileURLWithPath: fullPath)
        self.encryptionKey = encryptionKey
    }

    // MARK: Store management

    /// Returns a shared store instance with the given name for the current user.
    /// - Parameter name: Name of the store.
    @objc(sharedStoreWithName:)
    public static func shared(withName name: String) -> KeyValueEncryptedFileStore? {
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.w(KeyValueEncryptedFileStore.self, message: "\(#function): Cannot create shared store with name '\(name)' for nil user. Did you mean to call \(String(describing: self)).sharedGlobal(withName:)?")
            return nil
        }
        return KeyValueEncryptedFileStore.shared(withName: name, forUserAccount: currentUser)
    }

    /// Returns a shared store instance with the given name for the given user.
    /// - Parameter name: Name of the store.
    /// - Parameter user: The user account associated with the store.
    @objc(sharedStoreWithName:user:)
    public static func shared(withName name: String, forUserAccount user: UserAccount) -> KeyValueEncryptedFileStore? {
        let userKey = self.userKey(forUser: user)
        if userStores[userKey] == nil {
            userStores[userKey] = SafeMutableDictionary<NSString, KeyValueEncryptedFileStore>()
        }

        if let store = userStores[userKey]?[name as NSString] {
            return store
        } else {
            guard let directory = KeyValueEncryptedFileStore.storesDirectory(forUser: user) else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): User stores directory is nil")
                return nil
            }
            guard let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name, encryptionKey: SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: encryptionKeyLabel, autoCreate: true)) else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Creating store failed")
                return nil
            }
            userStores[userKey]?[name as NSString] = store
            return store
        }
    }

    /// Returns a shared global store instance with the given name. This store will not be specific to a particular user.
    /// - Parameter name: Name of the store.
    @objc(sharedGlobalStoreWithName:)
    public static func sharedGlobal(withName name: String) -> KeyValueEncryptedFileStore? {
        if let store = globalStores[name as NSString] {
            return store
        } else {
            let directory = globalStoresDirectory()
            guard let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name, encryptionKey: SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: encryptionKeyLabel, autoCreate: true)) else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Creating store failed")
                return nil
            }
            globalStores[name as NSString] = store
            return store
        }
    }

    /// All of the store names from this app for the current user.
    @objc(allStoreNames)
    public static func allNames() -> [String] {
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.w(KeyValueEncryptedFileStore.self, message: "\(#function): Cannot get store names for nil user. Did you mean to call \(String(describing: self)).allGlobalNames?")
            return [String]()
        }
        return KeyValueEncryptedFileStore.allNames(forUserAccount: currentUser)
    }

    /// All of the store names from this app for the given user.
    /// - Parameter user: Associated user account.
    @objc(allStoreNamesForUser:)
    public static func allNames(forUserAccount user: UserAccount) -> [String] {
        let directory = storesDirectory(forUser: user)
        return contentsOfDirectory(directory, function: #function)
    }

    /// All of the global store names from this app.
    @objc(allGlobalStoreNames)
    public static func allGlobalNames() -> [String] {
        let directory = globalStoresDirectory()
        return contentsOfDirectory(directory, function: #function)
    }

    /// Completely removes a persisted shared store with the given name for the current user.
    /// - Parameter name: Name of the store.
    @objc(removeSharedStoreWithName:)
    public static func removeShared(withName name: String) {
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.w(KeyValueEncryptedFileStore.self, message: "\(#function): Cannot remove shared store with name '\(name)' for nil user. Did you mean to call \(String(describing: self)).removeSharedGlobal(withName:)?")
            return
        }
        removeShared(withName: name, forUserAccount: currentUser)
    }

    /// Completely removes a persisted shared store with the given name for the given user.
    /// - Parameter name: Name of the store.
    /// - Parameter user: The user account associated with the store.
    @objc(removeSharedStoreWithName:forUser:)
    public static func removeShared(withName name: String, forUserAccount user: UserAccount) {
        guard let storesDirectory = storesDirectory(forUser: user) else {
            return
        }

        let storeDirectory = URL(fileURLWithPath: storesDirectory).appendingPathComponent(name)
        removeFile(storeDirectory, function: #function)

        let userKey = self.userKey(forUser: user)
        userStores[userKey]?.removeObject(name as NSString)
    }

    /// Completely removes a persisted shared global store with the given name.
    /// - Parameter name: Name of the store.
    @objc(removeSharedGlobalStoreWithName:)
    public static func removeSharedGlobal(withName name: String) {
        let storesDirectory = globalStoresDirectory()
        let storeDirectory = URL(fileURLWithPath: storesDirectory).appendingPathComponent(name)
        removeFile(storeDirectory, function: #function)
        globalStores.removeObject(name as NSString)
    }

    /// Completely removes all persisted shared stores for the current user.
    @objc(removeAllStores)
    public static func removeAllForCurrentUser() {
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.w(KeyValueEncryptedFileStore.self, message: "\(#function): Cannot remove all shared stores for nil user. Did you mean to call \(String(describing: self)).removeAllGlobal()?")
            return
        }
        removeAll(forUserAccount: currentUser)
    }

    /// Completely removes all persisted shared stores for the given user.
    /// - Parameter user: The user account associated with the store.
    @objc(removeAllStoresForUser:)
    public static func removeAll(forUserAccount user: UserAccount) {
        guard let directory = storesDirectory(forUser: user) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): User stores directory is nil")
            return
        }

        let userKey = self.userKey(forUser:user)
        let storeDirectories = contentsOfDirectory(directory, function: #function)

        for store in storeDirectories {
            let storeURL = URL(fileURLWithPath: directory).appendingPathComponent(store)

            do {
                try FileManager.default.removeItem(at: storeURL)
                userStores[userKey]?.removeObject(store as NSString)
            } catch {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error removing file at path '\(storeURL.path)': \(error)")
            }
        }
    }

    /// Completely removes all persisted shared global stores.
    @objc(removeAllGlobalStores)
    public static func removeAllGlobal() {
        let directory = globalStoresDirectory()
        let storeDirectories = contentsOfDirectory(directory, function: #function)
        for store in storeDirectories {
            let storeURL = URL(fileURLWithPath: directory).appendingPathComponent(store)

            do {
                try FileManager.default.removeItem(at: storeURL)
                globalStores.removeObject(store as NSString)
            } catch {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error removing file at path '\(storeURL.path)': \(error)")
            }
        }
    }

    // MARK: Store

    /// Returns whether the given store name is valid.
    /// - Parameter name: name of the store.
    @objc(isValidStoreName:)
    public static func isValidName(_ name: String) -> Bool {
        return name.count > 0 && name.count <= maxStoreNameLength && name.range(of: "^[a-zA-Z0-9_]*$", options: .regularExpression) != nil
    }

    /// Updates the value stored for the given key, or adds a new entry if the key does not exist.
    /// - Parameter value: Value to add to the store.
    /// - Parameter key: Key associated with the value.
    /// - Returns: True on success, false on failure.
    @objc @discardableResult public func saveValue(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to convert string to data")
            return false
        }
        guard let encryptedData = encryptionKey.encryptData(data) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to encrypt data")
            return false
        }
        guard let fileURL = encodedUrl(forKey: key, function: #function) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
            return false
        }

        do {
            try encryptedData.write(to: fileURL)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error writing data to file: \(error)")
            return false
        }

        return true
    }

    /// Accesses the value associated with the given key for reading and writing.
    @objc public subscript(key: String) -> String? {
        get {
            guard let fileURL = encodedUrl(forKey: key, function: #function) else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
                return nil
            }
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }

            do {
                let encryptedData = try Data(contentsOf: fileURL)
                guard let decryptedData = encryptionKey.decryptData(encryptedData) else {
                    SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to decrypt file at path '\(fileURL.path)'")
                    return nil
                }
                return String(data: decryptedData, encoding: .utf8)
            } catch {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error reading file at path '\(fileURL.path)': \(error)")
                return nil
            }
        }

        set {
            if let newValue = newValue {
                saveValue(newValue, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }
    /// Removes entry for given key.
    /// - Parameter key: The key associated with the entry to remove.
    /// - Returns: True if the entry is successfully removed or doesn't exist, false otherwise.
    @objc @discardableResult public func removeValue(forKey key: String) -> Bool {
        guard let fileURL = encodedUrl(forKey: key, function: #function) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
            return false
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return true
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error removing file at path '\(fileURL.path)': \(error)")
            return false
        }
    }

    /// Removes all contents of the store.
    @objc public func removeAll() {
        let files = KeyValueEncryptedFileStore.contentsOfDirectory(directory.path, function: #function)
        for file in files {
            let fileURL = directory.appendingPathComponent(file)
            KeyValueEncryptedFileStore.removeFile(fileURL, function: #function)
        }
    }

    /// - Returns: The number of entries in the store.
    @objc public func count() -> Int {
        let files = KeyValueEncryptedFileStore.contentsOfDirectory(directory.path, function: #function)
        return files.count
    }

    /// - Returns: A Boolean value that indicates whether the store is empty.
    @objc public func isEmpty() -> Bool {
        return count() == 0
    }

    // MARK: Private
    private static func storesDirectory(forUser user: UserAccount) -> String? {
        return SFDirectoryManager.shared().directory(forUser: user, type: .documentDirectory, components: [keyValueStoresDirectory])
    }

    private static func globalStoresDirectory() -> String {
        return SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: [keyValueStoresDirectory])
    }

    private static func contentsOfDirectory(_ directory: String?, function: String) -> [String] {
        guard let directory = directory else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(function): Directory is nil")
            return [String]()
        }
        guard FileManager.default.fileExists(atPath: directory) else {
            return [String]()
        }

        do {
            return try FileManager.default.contentsOfDirectory(atPath: directory)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(function): Error getting contents of directory: \(error)")
            return [String]()
        }
    }

    private static func removeFile(_ fileURL: URL, function: String) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            SFSDKCoreLogger.i(KeyValueEncryptedFileStore.self, message: "\(function): Removing file at path '\(fileURL.path)'")
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(function): Error removing file at path '\(fileURL.path)': \(error)")
        }
    }

    private func encodedUrl(forKey key: String, function: String) -> URL? {
        guard key.count > 0 else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(function): Key is empty")
            return nil
        }
        guard let keyData = key.data(using: .utf8) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(function): Unable to convert key string to data")
            return nil
        }

        let encodedKey = (keyData as NSData).sha256()
        return directory.appendingPathComponent(encodedKey)
    }

    private static func userKey(forUser user: UserAccount?) -> NSString {
        if user == nil {
            return SFKeyForGlobalScope() as NSString
        } else {
            let key = SFKeyForUserAndScope(user, .community)
            if let key = key {
                return key as NSString
            } else {
                return "" as NSString
            }
        }
    }
}
