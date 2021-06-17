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
    }

    // MARK: Symmetric Encrypt/Decrypt
    
    /// Encrypts data with a given key
    ///
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: Data representation of symmetric key to encrypt with
    /// - Returns: Encrypted data
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encrypt(data: Data, using key: Data) throws -> Data {
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
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func decrypt(data: Data, using key: Data) throws -> Data {
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
    static var keyCache = [String: SymmetricKey]()
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
        if let key = keyCache[label] {
            return key
        } else {
            let key = try symmetricKey(for: label)
            keyCache[label] = key
            return key
        }
    }
    
    static func symmetricKey(for label: String, keySize: SymmetricKeySize = .bits256) throws -> SymmetricKey {
        let storedLabel = "\(KeyGenerator.keyStoreService).\(label)"
        if let encryptedKeyData = KeychainHelper.read(service: storedLabel, account: nil).data {
            let decryptedKeyData = try Encryptor.decrypt(data: encryptedKeyData, using: ecKeyPair(name: defaultKeyName).privateKey)
            return SymmetricKey(data: decryptedKeyData)
        } else {
            let key = SymmetricKey(size: keySize)
            let encryptedKeyData = try Encryptor.encrypt(data: key.dataRepresentation, using: ecKeyPair(name: defaultKeyName).publicKey)
            
            let result = KeychainHelper.write(service: storedLabel, data: encryptedKeyData, account: nil)
            if result.success {
                return key
            } else {
                throw KeyGeneratorError.keychainWriteError(underlyingError: result.error)
            }
        }
    }
    
    static func ecKeyPair(name: String) throws -> KeyPair {
        let privateTagString = "\(ecPrivateKeyTagPrefix).\(name)"
        let publicTagString = "\(ecPublicKeyTagPrefix).\(name)"
        
        guard let privateTag = privateTagString.data(using: .utf8),
              let publicTag = publicTagString.data(using: .utf8) else {
            throw KeyGeneratorError.tagCreationFailed
        }
        
        if let privateKey = ecKey(tag: privateTag),
           let publicKey = ecKey(tag: publicTag) {
            return KeyPair(publicKey: publicKey, privateKey: privateKey)
        }
        
        return try createECKeyPair(privateTag: privateTag, publicTag: publicTag)
    }
    
    static func ecKey(tag: Data) -> SecKey? {
        let query: [String: Any] = [
            String(kSecClass): String(kSecClassKey),
            String(kSecAttrApplicationTag): tag,
            String(kSecReturnRef): true
        ]
        var queryResult: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &queryResult)
        if let secKey = queryResult, CFGetTypeID(secKey) == SecKeyGetTypeID() {
            return (secKey as! SecKey)
        } else if status != errSecItemNotFound {
            SalesforceLogger.log(KeyGenerator.self, level: .error, message: "Error getting EC SecKey: \(status)")
        }
        return nil
    }

    static func createECKeyPair(privateTag: Data, publicTag: Data) throws -> KeyPair {
        var privateKeyAttributes: [String: Any] = [
            String(kSecAttrIsPermanent): true,
            String(kSecAttrApplicationTag): privateTag
        ]
        
        if SecureEnclave.isAvailable && !UIDevice.current.isSimulator() {
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
        
        if SecureEnclave.isAvailable && !UIDevice.current.isSimulator() {
            keyPairAttributes[String(kSecAttrTokenID)] = kSecAttrTokenIDSecureEnclave;
        }
        keyPairAttributes[String(kSecPrivateKeyAttrs)] = privateKeyAttributes;
        keyPairAttributes[String(kSecPublicKeyAttrs)] = publicKeyAttributes;
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            let error = error?.takeRetainedValue()
            throw KeyGeneratorError.keyCreationFailed(underlyingError: error)
        }
        return KeyPair(publicKey: publicKey, privateKey: privateKey)
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
