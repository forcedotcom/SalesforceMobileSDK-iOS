//
//  Encryptor.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 5/18/21.
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
import CryptoKit
import SalesforceSDKCommon

@objc(SFSDKEncryptor)
public class Encryptor: NSObject {
    
    enum EncryptorError: Error {
        case combinedBoxFailed
        case encryptionFailed(underlyingError: Error?)
        case decryptionFailed(underlyingError: Error?)
        case noEncryptionKey
    }

    // MARK: Symmetric Encrypt/Decrypt
    
    /// Encrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: Data representation of symmetric key to encrypt with
    /// - Returns: Encrypted data
    @objc @available(*, deprecated, renamed: "encrypt(data:key:)") @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encrypt(data: Data, using key: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return try encrypt(data: data, using: symmetricKey)
    }
    
    /// Encrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: Data representation of symmetric key to encrypt with
    /// - Returns: Encrypted data
    @objc(encryptData:key:error:) @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encrypt(data: Data, key: Data?) throws -> Data {
        guard let key = key else {
            throw EncryptorError.noEncryptionKey
        }
        let symmetricKey = SymmetricKey(data: key)
        return try encrypt(data: data, using: symmetricKey)
    }

    /// Encrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: Symmetric key to encrypt with
    /// - Returns: Encrypted data
    public static func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce())
        guard let combined = sealedBox.combined else {
            throw EncryptorError.combinedBoxFailed
        }
        return combined
    }
    
    /// Decrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to decrypt
    ///   - key: Data representation of symmetric key to decrypt with
    /// - Returns: Decrypted data
    @objc @available(*, deprecated, renamed: "decrypt(data:key:)") @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func decrypt(data: Data, using key: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return try decrypt(data: data, using: symmetricKey)
    }
    
    /// Decrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to decrypt
    ///   - key: Data representation of symmetric key to decrypt with
    /// - Returns: Decrypted data
    @objc(decryptData:key:error:) @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func decrypt(data: Data, key: Data?) throws -> Data {
        guard let key = key else {
            throw EncryptorError.noEncryptionKey
        }
        let symmetricKey = SymmetricKey(data: key)
        return try decrypt(data: data, using: symmetricKey)
    }

    /// Decrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to decrypt
    ///   - key: Symmetric key to decrypt with
    /// - Returns: Decrypted data
    public static func decrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: EC Encrypt/Decrypt
    static func encrypt(data: Data, using key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(key, .eciesEncryptionStandardX963SHA256AESGCM, data as CFData, &error) else {
            let error = error?.takeRetainedValue()
            throw EncryptorError.encryptionFailed(underlyingError: error)
        }
        return encryptedData as Data
    }
    
    static func decrypt(data: Data, using key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(key, .eciesEncryptionStandardX963SHA256AESGCM, data as CFData, &error) else {
            let error = error?.takeRetainedValue()
            throw EncryptorError.decryptionFailed(underlyingError: error)
        }
        return decryptedData as Data
    }
}

@objc(SFSDKKeyGenerator)
public class KeyGenerator: NSObject {
    static var keyCache = Cache<String, SymmetricKey>()
    static let keyStoreService = "com.salesforce.keystore"
    static let defaultKeyName = "defaultKey"
    static let ecPublicKeyTagPrefix = "com.salesforce.eckey.public"
    static let ecPrivateKeyTagPrefix = "com.salesforce.eckey.private"
    
    enum KeyGeneratorError: Error {
        case keychainWriteError(underlyingError: Error?)
        case accessControlCreationFailed
        case tagCreationFailed
        case keyCreationFailed(underlyingError: Error?)
        case keyQueryFailed(status: OSStatus)
        case invalidQueryResult
    }
    
    struct KeyPair {
        let publicKey: SecKey
        let privateKey: SecKey
    }
    
    /// Returns an encryption key for the given label. If the key doesn't already exist, it
    /// will be created.
    ///
    /// - Parameters:
    ///   - label: Identifier for the key
    /// - Returns: Data representation of a symmetric encryption key
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encryptionKey(for label: String) throws -> Data {
        return try KeyGenerator.encryptionKey(for: label).dataRepresentation
    }
    
    /// Returns an encryption key for the given label. If the key doesn't already exist, it
    /// will be created.
    ///
    /// - Parameters:
    ///   - label: Identifier for the key
    /// - Returns: Symmetric encryption key
    public static func encryptionKey(for label: String) throws -> SymmetricKey {
        return try keyCache.getOrCreate(key: label) { label in
            return try symmetricKey(for: label)
        }
    }
    
    /// Remove the encryption key for the given label.
    ///
    /// - Parameters:
    ///   - label: Identifier for the key
    /// - Returns: If removal was successful or not
    @objc @discardableResult
    public static func removeEncryptionKey(for label: String) -> Bool {
        let storedLabel = "\(KeyGenerator.keyStoreService).\(label)"
        keyCache.removeValue(forKey: label)
        return KeychainHelper.remove(service: storedLabel, account: nil).success
    }
    
    static func symmetricKey(for label: String, keySize: SymmetricKeySize = .bits256) throws -> SymmetricKey {
        let storedLabel = "\(KeyGenerator.keyStoreService).\(label)"
        if let encryptedKeyData = KeychainHelper.read(service: storedLabel, account: nil).data {
            do {
                let privateKey = try ecKeyPair(name: defaultKeyName).privateKey
                let decryptedKeyData = try Encryptor.decrypt(data: encryptedKeyData, using: privateKey)
                return SymmetricKey(data: decryptedKeyData)
            } catch {
                SalesforceLogger.log(KeyGenerator.self, level: .info, message: "Unable to decrypt existing encryption key for \(label), generating new one. Error: \(error.localizedDescription)")
            }
        }
        // Key wasn't in keychain or couldn't be decrypted
        let key = SymmetricKey(size: keySize)
        let encryptedKeyData = try Encryptor.encrypt(data: key.dataRepresentation, using: ecKeyPair(name: defaultKeyName).publicKey)

        let result = KeychainHelper.write(service: storedLabel, data: encryptedKeyData, account: nil)
        if result.success {
            return key
        } else {
            SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Error writing \(storedLabel) to keychain: \(result.error?.localizedDescription ?? "")")
            throw KeyGeneratorError.keychainWriteError(underlyingError: result.error)
        }
    }
    
    static func ecKeyPair(name: String) throws -> KeyPair {
        let privateTag = try keyTag(name: name, prefix: ecPrivateKeyTagPrefix)
        let publicTag = try keyTag(name: name, prefix: ecPublicKeyTagPrefix)

        if let privateKey = try? ecKey(tag: privateTag),
           let publicKey = try? ecKey(tag: publicTag) {
            return KeyPair(publicKey: publicKey, privateKey: privateKey)
        }
    
        removeECKeyPair(privateTag: privateTag, publicTag: publicTag)
        return try createECKeyPair(privateTag: privateTag, publicTag: publicTag)
    }
    
    static func keyTag(name: String, prefix: String) throws -> Data {
        let tagString = "\(prefix).\(name)"
        if let tag = tagString.data(using: .utf8) {
            return tag
        } else {
            throw KeyGeneratorError.tagCreationFailed
        }
    }
    
    static func ecKey(tag: Data) throws -> SecKey? {
        let query: [String: Any] = [
            String(kSecMatchLimit): kSecMatchLimitAll,
            String(kSecClass): String(kSecClassKey),
            String(kSecAttrApplicationTag): tag,
            String(kSecReturnRef): true
        ]
        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)

        if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
            SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Error getting EC SecKey: \(status)")
            throw KeyGeneratorError.keyQueryFailed(status: status)
        }
        
        let keys = queryResult as? Array<SecKey>
        if let key = keys?.first, keys?.count == 1 {
            return key
        }
        SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Key query result could not be read or more than one key was returned, key count: \(keys?.count ?? 0)")
        throw KeyGeneratorError.invalidQueryResult
    }
    
    static func removeKey(tag: Data) -> Bool {
        let query: [String : Any] = [
            String(kSecClass): String(kSecClassKey),
            String(kSecAttrApplicationTag): tag
        ]

        var status = SecItemDelete(query as CFDictionary)
        while (status == errSecDuplicateItem) {
            status = SecItemDelete(query as CFDictionary)
        }
        
        if (status != errSecSuccess && status != errSecItemNotFound) {
            SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Error deleting EC SecKey: \(status)")
            return false
        }
        
        return true
    }
    
    @discardableResult
    static func removeECKeyPair(privateTag: Data, publicTag: Data) -> Bool {
        let privateKeyDeleted = removeKey(tag: privateTag)
        let publicKeyDeleted = removeKey(tag: publicTag)
        return privateKeyDeleted && publicKeyDeleted
    }

    static func createECKeyPair(privateTag: Data, publicTag: Data) throws -> KeyPair {
        var privateKeyAttributes: [String: Any] = [
            String(kSecAttrIsPermanent): true,
            String(kSecAttrApplicationTag): privateTag
        ]
        
        if SecureEnclave.isAvailable && !UIDevice.current.sfsdk_isSimulator() {
            if let privateAccess = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, [.privateKeyUsage], nil) {
                privateKeyAttributes[String(kSecAttrAccessControl)] = privateAccess
            }
        } else {
            privateKeyAttributes[String(kSecAttrAccessible)] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        
        let publicKeyAttributes: [String: Any] = [
            String(kSecAttrIsPermanent): true,
            String(kSecAttrApplicationTag): publicTag,
            String(kSecAttrAccessible): kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        
        var keyPairAttributes: [String: Any] = [
            String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
            String(kSecAttrKeySizeInBits): 256
        ]
        
        if SecureEnclave.isAvailable && !UIDevice.current.sfsdk_isSimulator() {
            keyPairAttributes[String(kSecAttrTokenID)] = kSecAttrTokenIDSecureEnclave;
        }
        keyPairAttributes[String(kSecPrivateKeyAttrs)] = privateKeyAttributes;
        keyPairAttributes[String(kSecPublicKeyAttrs)] = publicKeyAttributes;
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            let error = error?.takeRetainedValue()
            SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Error creating EC key pair: \(error?.localizedDescription ?? "")")
            throw KeyGeneratorError.keyCreationFailed(underlyingError: error)
        }
        return KeyPair(publicKey: publicKey, privateKey: privateKey)
    }
}

class Cache<Key: Hashable, Value> {
    private(set) var cache = Dictionary<Key, Value>()
    private var queue = DispatchQueue(label: "com.salesforce.mobilesdk.readWriteQueue\(arc4random_uniform(32))", qos: .unspecified, attributes: [.concurrent], autoreleaseFrequency: .inherit, target: nil)
    
    func getOrCreate(key: Key, createBlock: (Key) throws -> (Value)) throws -> Value {
        // Try read without barrier
        let currentValue = queue.sync {
            cache[key]
        }
        
        if let currentValue = currentValue {
            return currentValue
        }
        
        // Key isn't present so queue again with barrier for possible write
        return try queue.sync(flags: .barrier) { () -> Value in
            let currentValue = cache[key]

            // Checking current value again in case anything happened between first read and this
            if let currentValue = currentValue {
                return currentValue
            } else {
                let newValue = try createBlock(key)
                cache[key] = newValue
                return newValue
            }
        }
    }
    
    func removeValue(forKey key: Key) {
        queue.async(group: nil, qos: .unspecified, flags: .barrier) { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }
}

// From Apple sample code (https://developer.apple.com/documentation/cryptokit/storing_cryptokit_keys_in_the_keychain)
extension ContiguousBytes {
    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count, kCFAllocatorNull)
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}
