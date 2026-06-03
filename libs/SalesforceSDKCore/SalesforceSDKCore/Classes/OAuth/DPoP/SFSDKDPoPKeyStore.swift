//
//  SFSDKDPoPKeyStore.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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
import Security

@objc(SFSDKDPoPKeyPair)
public final class SFSDKDPoPKeyPair: NSObject {
    @objc public let publicKey: SecKey
    @objc public let privateKey: SecKey

    init(publicKey: SecKey, privateKey: SecKey) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

@objc(SFSDKDPoPKeyStoreError)
public enum SFSDKDPoPKeyStoreError: Int, Error {
    case missingScopeIdentifier = 1
    case keyGenerationFailed = 2
    case keyLookupFailed = 3
}

/// Per-credentials DPoP keypair lifecycle, scoped on `SFOAuthCredentials.identifier`
/// (stable from before the first token-endpoint call, since the auth-code exchange
/// happens before an `SFUserAccount` exists). Persisted in the iOS Keychain and
/// uses the Secure Enclave when available; otherwise falls back to software-backed
/// keychain storage.
@objc(SFSDKDPoPKeyStore)
public final class SFSDKDPoPKeyStore: NSObject {

    @objc public static let shared = SFSDKDPoPKeyStore()

    private let queue = DispatchQueue(label: "com.salesforce.dpop.keystore", attributes: .concurrent)

    private override init() { super.init() }

    /// Returns the keypair bound to the given scope identifier, generating it on first call.
    @objc(keyPairForScope:error:)
    public func keyPair(forScope scope: String) throws -> SFSDKDPoPKeyPair {
        guard !scope.isEmpty else {
            throw SFSDKDPoPKeyStoreError.missingScopeIdentifier
        }
        let name = Self.keyName(for: scope)
        return try queue.sync(flags: .barrier) {
            try self.fetchOrCreate(name: name)
        }
    }

    /// Convenience: scope on `credentials.identifier`.
    @objc(keyPairForCredentials:error:)
    public func keyPair(forCredentials credentials: SFOAuthCredentials) throws -> SFSDKDPoPKeyPair {
        return try keyPair(forScope: credentials.identifier)
    }

    /// Removes any existing keypair for the scope. Idempotent.
    @objc(deleteForScope:)
    public func delete(forScope scope: String) {
        guard !scope.isEmpty else { return }
        let name = Self.keyName(for: scope)
        queue.sync(flags: .barrier) {
            _ = SFSDKCryptoUtils.deleteECKeyPair(withName: name)
        }
    }

    @objc(deleteForCredentials:)
    public func delete(forCredentials credentials: SFOAuthCredentials) {
        delete(forScope: credentials.identifier)
    }

    // MARK: - Internal helpers

    static func keyName(for scope: String) -> String {
        return "dpop_" + scope
    }

    private func fetchOrCreate(name: String) throws -> SFSDKDPoPKeyPair {
        if let pair = lookup(name: name) {
            return pair
        }
        let useSecureEnclave = SFSDKCryptoUtils.isSecureEnclaveAvailable()
        if !useSecureEnclave {
            SFSDKCoreLogger.i(Self.self, message: "DPoP keypair using software-backed storage; Secure Enclave unavailable")
        }
        let created = SFSDKCryptoUtils.createECKeyPair(withName: name,
                                                      accessibleAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                      useSecureEnclave: useSecureEnclave)
        if !created {
            // Secure Enclave generation can fail on policy-locked devices. Try software-backed
            // as a one-time recovery before surfacing the failure.
            if useSecureEnclave {
                let retry = SFSDKCryptoUtils.createECKeyPair(withName: name,
                                                             accessibleAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                             useSecureEnclave: false)
                if !retry {
                    throw SFSDKDPoPKeyStoreError.keyGenerationFailed
                }
            } else {
                throw SFSDKDPoPKeyStoreError.keyGenerationFailed
            }
        }
        guard let pair = lookup(name: name) else {
            throw SFSDKDPoPKeyStoreError.keyLookupFailed
        }
        return pair
    }

    private func lookup(name: String) -> SFSDKDPoPKeyPair? {
        guard let priv = SFSDKCryptoUtils.getECPrivateKeyRef(withName: name)?.takeRetainedValue() else {
            return nil
        }
        if let pub = SFSDKCryptoUtils.getECPublicKeyRef(withName: name)?.takeRetainedValue() {
            return SFSDKDPoPKeyPair(publicKey: pub, privateKey: priv)
        }
        // Public key entry can be missing on Secure-Enclave-backed pairs; derive from private.
        if let derived = SecKeyCopyPublicKey(priv) {
            return SFSDKDPoPKeyPair(publicKey: derived, privateKey: priv)
        }
        return nil
    }
}
