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
import CryptoKit

/// File-based key-value storage
@objc(SFSDKKeyValueEncryptedFileStore)
public class KeyValueEncryptedFileStore: NSObject {
    @objc(storeDirectory) public let directory: URL
    @objc(storeName) public let name: String
    @objc public private(set) var storeVersion: Int
    @objc public static let maxStoreNameLength = 96

    private var legacyEncryptionKey: SFEncryptionKey?
    private let encryptionKey: SymmetricKey
    private static var globalStores = SafeMutableDictionary<NSString, KeyValueEncryptedFileStore>()
    private static var userStores = SafeMutableDictionary<NSString, SafeMutableDictionary<NSString, KeyValueEncryptedFileStore>>()
    private static let storeVersionString = "2"
    private static let storeVersionFileName = "version"
    private static let storeGCMEncryptionFileName = "gcmEncryption"
    private static let keyValueStoresDirectory = "key_value_stores"
    private static let encryptionKeyLabel = "com.salesforce.keyValueStores.encryptionKey"
    
    private enum FileType {
        case key, value
        
        var nameSuffix: String {
            let suffix: String
            switch self {
            case .key:
                suffix = "_key"
            case .value:
                suffix = "_value"
            }
            return suffix
        }
    }

    /// Creates a store.
    /// - Parameter parentDirectory: Parent directory for the store.
    /// - Parameter name: Name of the store.
    /// - Parameter encryptionKey: Encryption key for the store.
    @available(*, deprecated, renamed: "init(parentDirectory:name:)")
    @objc public convenience init?(parentDirectory: String, name: String, encryptionKey: SFEncryptionKey) {
        self.init(parentDirectory: parentDirectory, name: name)
        self.legacyEncryptionKey = encryptionKey
    }
    
    /// Creates a store.
    /// - Parameter parentDirectory: Parent directory for the store.
    /// - Parameter name: Name of the store.
    @objc public convenience init?(parentDirectory: String, name: String) {
        do {
            let encryptionKey = try KeyGenerator.encryptionKey(for: KeyValueEncryptedFileStore.encryptionKeyLabel)
            self.init(parentDirectory: parentDirectory, name: name, encryptionKey: encryptionKey)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error ensuring getting encryption key: \(error)")
            return nil
        }
    }
    
    private init?(parentDirectory: String, name: String, encryptionKey: SymmetricKey) {
        guard KeyValueEncryptedFileStore.isValidName(name) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Invalid store name")
            return nil
        }
        
        let fullPath = parentDirectory + "/\(name)"
        let isNewlyCreated = !KeyValueEncryptedFileStore.directoryExists(atPath: fullPath)
        do {
            try SFDirectoryManager.ensureDirectoryExists(fullPath)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Error ensuring directory exists: \(error)")
            return nil
        }
        
        self.name = name
        self.directory = URL(fileURLWithPath: fullPath)
        self.encryptionKey = encryptionKey
        self.storeVersion = isNewlyCreated ? 2 : 1
        super.init()
        
        // Store version must be determined, otherwise initialiazation fails by returning nil.
        // A new created store is automatic v2, but version file must be succesfully written.
        let versionFileURL = directory.appendingPathComponent(KeyValueEncryptedFileStore.storeVersionFileName)
        if isNewlyCreated {
            let versionFileCreated = writeFile(versionFileURL, content: KeyValueEncryptedFileStore.storeVersionString)
            let encryptionFileURL = directory.appendingPathComponent(KeyValueEncryptedFileStore.storeGCMEncryptionFileName)
            let encryptionFileCreated = FileManager.default.createFile(atPath: encryptionFileURL.path, contents: nil, attributes: nil)
            if !versionFileCreated || !encryptionFileCreated {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Failed to create version file or encryption file for store")
                return nil
            }
        } else {
            if let version = readVersion(versionFileURL) {
                self.storeVersion = version
            } else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Failed to read version for store")
                return nil
            }
        }
    }
    
    /// Upgrades the encryption of a store created with SFEncryptionKey to a new key provided by Mobile SDK. Only use this if the store was originally created
    /// by initializing KeyValueEncyptedFileStore directly rather than using the shared store methods.
    /// - Parameter parentDirectory: Parent directory for the store.
    /// - Parameter name: Name of the store.
    /// - Parameter legacyKey: SFEncryptionKey store was originally created with.
    @objc static func updateEncryption(parentDirectory: String, name: String, legacyKey: SFEncryptionKey) {
        guard KeyValueEncryptedFileStore.isValidName(name) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Invalid store name")
            return
        }
        
        let storeDirectory = URL(fileURLWithPath: parentDirectory + "/\(name)")
        let encryptionFile = storeDirectory.appendingPathComponent(KeyValueEncryptedFileStore.storeGCMEncryptionFileName)
        guard !FileManager.default.fileExists(atPath: encryptionFile.path),
              let encryptionKey = try? KeyGenerator.encryptionKey(for: KeyValueEncryptedFileStore.encryptionKeyLabel),
              let fileURLs = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in fileURLs {
            do {
                let encryptedData = try Data(contentsOf: fileURL)
                guard let decryptedData = legacyKey.decryptData(encryptedData) else {
                    SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "Unable to decrypt file at path '\(fileURL.path)'")
                    return
                }
                let reencryptedData = try Encryptor.encrypt(data: decryptedData, using: encryptionKey)
                try reencryptedData.write(to: fileURL)
            } catch {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "Error updating encryption for '\(fileURL.path)': \(error)")
            }
        }
        FileManager.default.createFile(atPath: encryptionFile.path, contents: nil, attributes: nil)
    }

    // MARK: - Store management

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
        let userKey = KeyValueEncryptedFileStore.userKey(forUser: user)
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
            if let legacyKey = SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: encryptionKeyLabel, autoCreate: false) {
                KeyValueEncryptedFileStore.updateEncryption(parentDirectory: directory, name: name, legacyKey: legacyKey)
            }
            guard
                let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name) else {
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
        }
        if let directory = globalStoresDirectory(), let encryptionKey = try? KeyGenerator.encryptionKey(for: encryptionKeyLabel) {
            if let legacyKey = SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: encryptionKeyLabel, autoCreate: false) {
                KeyValueEncryptedFileStore.updateEncryption(parentDirectory: directory, name: name, legacyKey: legacyKey)
            }
            if let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name, encryptionKey: encryptionKey) {
                globalStores[name as NSString] = store
                return store
            }
        }
        
        SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Creating store failed")
        return nil
    }

    /// All of the store names from this app for the current user.
    @objc(allStoreNames)
    public static func allNames() -> [String] {
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.w(KeyValueEncryptedFileStore.self, message: "\(#function): Cannot get store names for nil user. Did you mean to call \(String(describing: self)).allGlobalNames?")
            return []
        }
        return KeyValueEncryptedFileStore.allNames(forUserAccount: currentUser)
    }

    /// All of the store names from this app for the given user.
    /// - Parameter user: Associated user account.
    @objc(allStoreNamesForUser:)
    public static func allNames(forUserAccount user: UserAccount) -> [String] {
        let directory = storesDirectory(forUser: user)
        return contentsOfDirectory(directory)
    }

    /// All of the global store names from this app.
    @objc(allGlobalStoreNames)
    public static func allGlobalNames() -> [String] {
        let directory = globalStoresDirectory()
        return contentsOfDirectory(directory)
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
        removeFile(storeDirectory)

        let userKey = KeyValueEncryptedFileStore.userKey(forUser: user)
        userStores[userKey]?.removeObject(name as NSString)
    }

    /// Completely removes a persisted shared global store with the given name.
    /// - Parameter name: Name of the store.
    @objc(removeSharedGlobalStoreWithName:)
    public static func removeSharedGlobal(withName name: String) {
        guard let storesDirectory = globalStoresDirectory() else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Global stores directory is nil")
            return
        }
        let storeDirectory = URL(fileURLWithPath: storesDirectory).appendingPathComponent(name)
        removeFile(storeDirectory)
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

        let userKey = KeyValueEncryptedFileStore.userKey(forUser:user)
        let storeDirectories = contentsOfDirectory(directory)

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
        guard let directory = globalStoresDirectory() else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Global stores directory is nil")
            return
        }
        
        let storeDirectories = contentsOfDirectory(directory)
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
    
    // Internal for testing
    static func clearGlobalCache() {
        KeyValueEncryptedFileStore.globalStores.removeAllObjects()
    }

    // MARK: - Store operations

    /// Returns whether the given store name is valid.
    /// - Parameter name: name of the store.
    @objc(isValidStoreName:)
    public static func isValidName(_ name: String) -> Bool {
        return !name.isEmpty && name.count <= maxStoreNameLength && name.range(of: "^[a-zA-Z0-9_]*$", options: .regularExpression) != nil
    }

    /// Updates the value stored for the given key, or adds a new entry if the key does not exist.
    /// - Parameters:
    ///   - value: Value to add to the store.
    ///   - key: Key associated with the value.
    /// - Returns: True on success, false on failure.
    @objc @discardableResult public func saveValue(_ value: String, forKey key: String) -> Bool {
        return saveData(Data(value.utf8), forKey: key)
    }
    
    /// Updates the data stored for the given key, or adds a new entry if the key does not exist.
    /// - Parameters:
    ///   - data: Data to add to the store.
    ///   - key: Key associated with the data.
    /// - Returns: True on success, false on failure.
    @objc @discardableResult public func saveData(_ data: Data, forKey key: String) -> Bool {
        guard let fileURL = encodedURL(forKey: key, fileType: .value) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
            return false
        }
        
        if storeVersion < 2 {
            return writeDataToFile(fileURL, data: data)
        }
        
        let valueFileWriteSuccess = writeDataToFile(fileURL, data: data)
        if valueFileWriteSuccess {
            if let keyFileURL = encodedURL(forKey: key, fileType: .key) {
                writeFile(keyFileURL, content: key)
            } else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct key file URL")
            }
        }
        return valueFileWriteSuccess
    }

    /// Accesses the value associated with the given key for reading and writing.
    @objc public subscript(key: String) -> String? {
        get {
            guard let fileURL = encodedURL(forKey: key, fileType: .value) else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
                return nil
            }
            return readFile(fileURL)
        }

        set {
            if let newValue = newValue {
                saveValue(newValue, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }
    
    /// Accesses the data associated with the given key.
    @objc public func readData(key: String) -> Data? {
        guard let fileURL = encodedURL(forKey: key, fileType: .value) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
            return nil
        }
        return readDataFromFile(fileURL)
    }
    
    /// Removes entry for given key.
    /// - Parameter key: The key associated with the entry to remove.
    /// - Returns: True if the entry is successfully removed or doesn't exist, false otherwise.
    @objc @discardableResult public func removeValue(forKey key: String) -> Bool {
        guard let fileURL = encodedURL(forKey: key, fileType: .value) else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct file URL")
            return false
        }
        
        if storeVersion < 2 {
            return KeyValueEncryptedFileStore.removeFile(fileURL)
        }
        
        let valueFileDeletionSuccess = KeyValueEncryptedFileStore.removeFile(fileURL)
        if valueFileDeletionSuccess {
            if let keyFileURL = encodedURL(forKey: key, fileType: .key) {
                KeyValueEncryptedFileStore.removeFile(keyFileURL)
            } else {
                SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(#function): Unable to construct key file URL")
            }
        }
        return valueFileDeletionSuccess
    }

    /// Removes all contents of the store.
    @objc public func removeAll() {
        let files = KeyValueEncryptedFileStore.contentsOfDirectory(directory.path)
        for file in files {
            if !KeyValueEncryptedFileStore.isReservedFile(file) {
                let fileURL = directory.appendingPathComponent(file)
                KeyValueEncryptedFileStore.removeFile(fileURL)
            }
        }
    }
    
    /// All keys in the store
    /// - Returns: all keys of stored values in a v2 store, nil if it's a v1 store
    @objc public func allKeys() -> [String]? {
        guard storeVersion >= 2 else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "This store does not have this capability!")
            return nil
        }
        
        return KeyValueEncryptedFileStore.contentsOfDirectory(directory.path)
            .filter { (file) -> Bool in
                return file.hasSuffix(FileType.key.nameSuffix)
            }
            .compactMap { (file) -> String? in
                let fileURL = directory.appendingPathComponent(file)
                return readFile(fileURL)
            }
    }

    /// - Returns: The number of entries in the store.
    @objc public func count() -> Int {
        if storeVersion < 2 {
            return KeyValueEncryptedFileStore.contentsOfDirectory(directory.path)
                .filter{ (file) -> Bool in
                    return file != KeyValueEncryptedFileStore.storeGCMEncryptionFileName
                }.count
        } else {
            return KeyValueEncryptedFileStore.contentsOfDirectory(directory.path)
                .filter { (file) -> Bool in
                    return file.hasSuffix(FileType.key.nameSuffix)
                }.count
        }
    }

    /// - Returns: A Boolean value that indicates whether the store is empty.
    @objc public func isEmpty() -> Bool {
        return count() == 0
    }

    // MARK: - Private
    private static func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    private static func storesDirectory(forUser user: UserAccount) -> String? {
        return SFDirectoryManager.shared().directory(forUser: user, type: .documentDirectory, components: [keyValueStoresDirectory])
    }

    static func globalStoresDirectory() -> String? {
        return SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: [keyValueStoresDirectory])
    }

    private static func contentsOfDirectory(_ directory: String?, callingFunction: String = #function) -> [String] {
        guard let directory = directory else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Directory is nil")
            return []
        }
        guard FileManager.default.fileExists(atPath: directory) else {
            return []
        }

        do {
            return try FileManager.default.contentsOfDirectory(atPath: directory)
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Error getting contents of directory: \(error)")
            return []
        }
    }

    @discardableResult
    private func writeFile(_ fileURL: URL, content: String, callingFunction: String = #function) -> Bool {
        return writeDataToFile(fileURL, data: Data(content.utf8), callingFunction: callingFunction)
    }
    
    private func writeDataToFile(_ fileURL: URL, data: Data, callingFunction: String = #function) -> Bool {
        do {
            let encryptedData = try Encryptor.encrypt(data: data, using: encryptionKey)
            try encryptedData.write(to: fileURL)
            return true
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Error writing encrypted data to file: \(error)")
            return false
        }
    }
    
    private func readFile(_ fileURL: URL, callingFunction: String = #function) -> String? {
        let decryptedData = readDataFromFile(fileURL, callingFunction: callingFunction)
        return decryptedData != nil ? String(data: decryptedData!, encoding:.utf8) : nil
    }
    
    private func readDataFromFile(_ fileURL: URL, callingFunction: String = #function) -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let encryptedData = try Data(contentsOf: fileURL)
            let decryptedData = try Encryptor.decrypt(data: encryptedData, using: encryptionKey)
            return decryptedData
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Error reading or decrypting file at path '\(fileURL.path)': \(error)")
            return nil
        }
    }
    
    @discardableResult
    private static func removeFile(_ fileURL: URL, callingFunction: String = #function) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return true
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            SFSDKCoreLogger.i(KeyValueEncryptedFileStore.self, message: "\(callingFunction): File removed at path '\(fileURL.path)'")
            return true
        } catch {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Error removing file at path '\(fileURL.path)': \(error)")
            return false
        }
    }
    
    private static func isReservedFile(_ file: String) -> Bool {
        return file == KeyValueEncryptedFileStore.storeVersionFileName || file == KeyValueEncryptedFileStore.storeGCMEncryptionFileName
    }
    
    private func readVersion(_ fileURL: URL) -> Int? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return 1
        }
        
        if let versionString = readFile(fileURL), let versionNumber = Int(versionString) {
            return versionNumber
        } else {
            return nil
        }
    }
    
    private func encodedURL(forKey key: String, fileType: FileType, callingFunction: String = #function) -> URL? {
        guard !key.isEmpty else {
            SFSDKCoreLogger.e(KeyValueEncryptedFileStore.self, message: "\(callingFunction): Key is empty")
            return nil
        }
        
        let keyData = Data(key.utf8) as NSData
        let encodedKey = keyData.sha256() + "\(storeVersion >= 2 ? fileType.nameSuffix : "")"
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
