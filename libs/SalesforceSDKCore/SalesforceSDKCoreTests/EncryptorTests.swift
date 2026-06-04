//
//  EncryptorTests.swift
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
import XCTest
@testable import SalesforceSDKCore

class EncryptorTests: XCTestCase {

    private let keyName = "encryptor-tests-\(UUID().uuidString)"

    override func tearDownWithError() throws {
        _ = try? KeyGenerator.removeECKeyPair(name: keyName)
        try super.tearDownWithError()
    }

    // MARK: - signES256

    func test_givenP256KeyPair_whenSignES256_thenReturns64ByteRawSignatureThatVerifies() throws {
        let pair = try KeyGenerator.ecKeyPair(name: keyName)
        let payload = Data("hello dpop".utf8)

        let signature = try Encryptor.signES256(payload, with: pair.privateKey)
        XCTAssertEqual(signature.count, 64, "ES256 raw R||S signature must be 64 bytes")

        // Verify by converting raw R||S back to DER and asking SecKeyVerifySignature.
        let derSignature = try derEncode(rawSignature: signature)
        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(pair.publicKey,
                                             .ecdsaSignatureMessageX962SHA256,
                                             payload as CFData,
                                             derSignature as CFData,
                                             &error)
        XCTAssertTrue(verified,
                      "Signature should verify against public key. error=\(String(describing: error))")
    }

    func test_givenSamePayloadAndKey_whenSignTwice_thenSignaturesDifferButBothVerify() throws {
        let pair = try KeyGenerator.ecKeyPair(name: keyName)
        let payload = Data("hello dpop".utf8)

        let s1 = try Encryptor.signES256(payload, with: pair.privateKey)
        let s2 = try Encryptor.signES256(payload, with: pair.privateKey)

        XCTAssertEqual(s1.count, 64)
        XCTAssertEqual(s2.count, 64)
        XCTAssertNotEqual(s1, s2, "ECDSA must use a fresh nonce per signature")

        for sig in [s1, s2] {
            let der = try derEncode(rawSignature: sig)
            var error: Unmanaged<CFError>?
            let ok = SecKeyVerifySignature(pair.publicKey,
                                           .ecdsaSignatureMessageX962SHA256,
                                           payload as CFData,
                                           der as CFData,
                                           &error)
            XCTAssertTrue(ok)
        }
    }

    // MARK: - jwkP256

    func test_givenP256PublicKey_whenJwkP256_thenReturnsRfc7518FieldsWith32ByteCoordinates() throws {
        let pair = try KeyGenerator.ecKeyPair(name: keyName)

        let jwk = try Encryptor.jwkP256(from: pair.publicKey)

        XCTAssertEqual(jwk["kty"], "EC")
        XCTAssertEqual(jwk["crv"], "P-256")

        let x = try XCTUnwrap(jwk["x"])
        let y = try XCTUnwrap(jwk["y"])
        XCTAssertFalse(x.contains("="), "base64url must not include padding")
        XCTAssertFalse(y.contains("="), "base64url must not include padding")
        XCTAssertFalse(x.contains("+") || x.contains("/"), "x must use base64url charset")
        XCTAssertFalse(y.contains("+") || y.contains("/"), "y must use base64url charset")

        let xBytes = try base64UrlDecode(x)
        let yBytes = try base64UrlDecode(y)
        XCTAssertEqual(xBytes.count, 32)
        XCTAssertEqual(yBytes.count, 32)
    }

    // MARK: - removeECKeyPair(name:)

    func test_givenExistingKeyPair_whenRemoveByName_thenSubsequentLookupGeneratesFreshKey() throws {
        let pair1 = try KeyGenerator.ecKeyPair(name: keyName)
        let payload = Data("rotate me".utf8)
        let sig1 = try Encryptor.signES256(payload, with: pair1.privateKey)

        let removed = try KeyGenerator.removeECKeyPair(name: keyName)
        XCTAssertTrue(removed)

        let pair2 = try KeyGenerator.ecKeyPair(name: keyName)

        // Fresh keypair must not verify a signature produced by the rotated-out key.
        let der = try derEncode(rawSignature: sig1)
        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(pair2.publicKey,
                                             .ecdsaSignatureMessageX962SHA256,
                                             payload as CFData,
                                             der as CFData,
                                             &error)
        XCTAssertFalse(verified)
    }

    func test_givenNoKeyPair_whenRemoveByName_thenReturnsTrue() throws {
        XCTAssertTrue(try KeyGenerator.removeECKeyPair(name: "never-created-\(UUID().uuidString)"))
    }

    // MARK: - Helpers

    /// Convert a 64-byte raw R||S ES256 signature to ASN.1 DER (`SEQUENCE { INTEGER r, INTEGER s }`)
    /// for `SecKeyVerifySignature`, which expects DER for `.ecdsaSignatureMessageX962SHA256`.
    private func derEncode(rawSignature raw: Data) throws -> Data {
        guard raw.count == 64 else {
            throw NSError(domain: "EncryptorTests", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "raw signature must be 64 bytes"])
        }
        let r = derInteger(raw.prefix(32))
        let s = derInteger(raw.suffix(32))
        let inner = r + s
        var out = Data([0x30])
        out.append(contentsOf: derLength(inner.count))
        out.append(inner)
        return out
    }

    private func derInteger(_ bytes: Data) -> Data {
        var b = Array(bytes)
        while b.count > 1 && b[0] == 0x00 && (b[1] & 0x80) == 0 { b.removeFirst() }
        if (b[0] & 0x80) != 0 { b.insert(0x00, at: 0) }
        var out = Data([0x02])
        out.append(contentsOf: derLength(b.count))
        out.append(contentsOf: b)
        return out
    }

    private func derLength(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var bytes: [UInt8] = []
        var v = n
        while v > 0 { bytes.insert(UInt8(v & 0xff), at: 0); v >>= 8 }
        return [UInt8(0x80 | bytes.count)] + bytes
    }

    private func base64UrlDecode(_ s: String) throws -> Data {
        var b64 = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        b64 += String(repeating: "=", count: pad)
        guard let d = Data(base64Encoded: b64) else {
            throw NSError(domain: "EncryptorTests", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "bad base64url"])
        }
        return d
    }
}
