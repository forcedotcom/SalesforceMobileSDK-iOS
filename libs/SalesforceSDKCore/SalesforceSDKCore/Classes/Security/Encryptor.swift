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
    }

    // MARK: Symmetric Encrypt/Decrypt
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encrypt(data: Data, using key: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return try encrypt(data: data, using: symmetricKey)
    }

    public static func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce())
        if let combined = sealedBox.combined {
            return combined
        } else {
            throw EncryptorError.combinedBoxFailed
        }
    }
    
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func decrypt(data: Data, using key: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return try decrypt(data: data, using: symmetricKey)
    }

    public static func decrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: EC Encrypt/Decrypt
    static func encrypt(data: Data, privateKey: Data) throws -> Data {
        let key = try derivedKey(from: privateKey)
        return try encrypt(data: data, using: key)
    }
    
    static func decrypt(data: Data, privateKey: Data) throws -> Data {
        let key = try derivedKey(from: privateKey)
        return try decrypt(data: data, using: key)
    }
    
    static func derivedKey(from privateKey: Data) throws -> SymmetricKey {
        var sharedSecret: SharedSecret
        if SecureEnclave.isAvailable && !UIDevice.current.isSimulator() {
            let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: privateKey)
            sharedSecret = try key.sharedSecretFromKeyAgreement(with: key.publicKey)
        } else {
            let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            sharedSecret = try key.sharedSecretFromKeyAgreement(with: key.publicKey)
        }
        return sharedSecret.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 32)
    }
}

@objc(SFSDKKeyGenerator)
public class KeyGenerator: NSObject {
    static var keyCache = [String: SymmetricKey]()
    static let keyStoreService = "com.salesforce.keystore.keyStore"
    static let keyStoreKeyService = "com.salesforce.keystore.keyStoreKey"
    
    enum KeyGeneratorError: Error {
        case keychainWriteError(underlyingError: Error?)
        case accessControlCreateFailed
    }
    
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public static func encryptionKey(for label: String) throws -> Data {
        return try KeyGenerator.encryptionKey(for: label).dataRepresentation
    }
    
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
        let result = KeychainHelper.read(service: storedLabel, account: nil)
        if let encryptedKeyData = result.data {
            let decryptedKeyData = try Encryptor.decrypt(data: encryptedKeyData, privateKey: storedEcKey())
            return SymmetricKey(data: decryptedKeyData)
        } else {
            let key = SymmetricKey(size: keySize)
            let encryptedKeyData = try Encryptor.encrypt(data: key.dataRepresentation, privateKey: storedEcKey())
            
            let result = KeychainHelper.write(service: storedLabel, data: encryptedKeyData, account: nil)
            if result.success {
                return key
            } else {
                throw KeyGeneratorError.keychainWriteError(underlyingError: result.error)
            }
        }
    }
    
    static func storedEcKey() throws -> Data {
        let storedKey = KeychainHelper.read(service: KeyGenerator.keyStoreKeyService, account: nil)
        
        if let keyData = storedKey.data {
            return keyData
        } else {
            let key = try KeyGenerator.createEcKey()
           
            let result = KeychainHelper.write(service: KeyGenerator.keyStoreKeyService, data: key, account: nil)
            if result.success {
                return key
            } else {
                throw KeyGeneratorError.keychainWriteError(underlyingError: result.error)
            }
        }
    }
    
    /// Returns private key as data
    static func createEcKey() throws -> Data {
        if SecureEnclave.isAvailable && !UIDevice.current.isSimulator() {
            var error: Unmanaged<CFError>?
            if let accessControl = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, [.privateKeyUsage], &error) {
                let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: accessControl)
                return privateKey.dataRepresentation
            } else if let error = error?.takeUnretainedValue() {
                throw error
            } else {
                throw KeyGeneratorError.accessControlCreateFailed
            }
        } else {
            let privateKey = P256.KeyAgreement.PrivateKey()
            return privateKey.rawRepresentation
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
