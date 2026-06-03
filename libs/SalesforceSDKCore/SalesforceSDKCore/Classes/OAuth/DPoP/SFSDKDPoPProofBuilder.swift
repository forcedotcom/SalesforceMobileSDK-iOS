//
//  SFSDKDPoPProofBuilder.swift
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

@objc(SFSDKDPoPProofBuilderError)
public enum DPoPProofBuilderError: Int, Error {
    case jwkExportFailed = 1
    case serializationFailed = 2
    case signingFailed = 3
}

/// Builds an RFC 9449 §4 DPoP proof JWS for a single token-endpoint request.
@objc(SFSDKDPoPProofBuilder)
public final class DPoPProofBuilder: NSObject {

    /// Build a compact-serialized JWS suitable for the `DPoP` HTTP header.
    /// - Parameters:
    ///   - httpMethod: HTTP verb (`"POST"` for token endpoint).
    ///   - htu: Full request URL with no query and no fragment, per RFC 9449 §4.2.
    ///   - nonce: Optional `nonce` claim from a prior `DPoP-Nonce` server hint.
    ///   - keyPair: Public key is embedded in the JWS header `jwk`; private key signs.
    ///   - now: Injected clock for deterministic tests; defaults to `Date()`.
    @objc public static func buildProof(httpMethod: String,
                                        htu: URL,
                                        nonce: String?,
                                        keyPair: DPoPKeyPair,
                                        now: Date = Date()) throws -> String {
        guard let jwk = SFSDKCryptoUtils.jwkExport(fromPublicKeyRef: keyPair.publicKey) else {
            throw DPoPProofBuilderError.jwkExportFailed
        }
        let header: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": jwk
        ]
        var payload: [String: Any] = [
            "htm": httpMethod.uppercased(),
            "htu": canonicalize(htu),
            "iat": Int(now.timeIntervalSince1970),
            "jti": newJti()
        ]
        if let nonce = nonce, !nonce.isEmpty {
            payload["nonce"] = nonce
        }
        guard let headerSegment = encode(json: header),
              let payloadSegment = encode(json: payload) else {
            throw DPoPProofBuilderError.serializationFailed
        }
        let signingInput = "\(headerSegment).\(payloadSegment)"
        guard let signingData = signingInput.data(using: .utf8),
              let signature = SFSDKCryptoUtils.signDataES256(signingData, withKeyRef: keyPair.privateKey) else {
            throw DPoPProofBuilderError.signingFailed
        }
        let signatureSegment = (signature as NSData).sfsdk_base64UrlString()
        return "\(signingInput).\(signatureSegment)"
    }

    // MARK: - Helpers

    /// `htu` MUST be the request URL without query or fragment (RFC 9449 §4.2).
    private static func canonicalize(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url?.absoluteString ?? url.absoluteString
    }

    /// 96 bits (12 bytes) of random entropy, per backend design doc.
    private static func newJti() -> String {
        let raw = SFSDKCryptoUtils.randomByteData(withLength: 12)
        return (raw as NSData).sfsdk_base64UrlString()
    }

    private static func encode(json: [String: Any]) -> String? {
        // .sortedKeys keeps output stable so unit tests can snapshot byte-for-byte.
        guard let data = try? JSONSerialization.data(withJSONObject: json,
                                                     options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        return (data as NSData).sfsdk_base64UrlString()
    }
}
