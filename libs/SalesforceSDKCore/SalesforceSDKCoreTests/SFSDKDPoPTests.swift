//
//  SFSDKDPoPTests.swift
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

class SFSDKDPoPTests: XCTestCase {

    private let testScope = "test-credentials-id-\(UUID().uuidString)"
    private let tokenURL = URL(string: "https://login.salesforce.com/services/oauth2/token")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        DPoPKeyStore.shared.delete(forScope: testScope)
        DPoPNonceCache.shared.clear(forScope: testScope)
    }

    override func tearDownWithError() throws {
        DPoPKeyStore.shared.delete(forScope: testScope)
        DPoPNonceCache.shared.clear(forScope: testScope)
        try super.tearDownWithError()
    }

    // MARK: - Proof builder

    func test_givenValidKeyPair_whenBuildProof_thenJwsHasThreeSegmentsAndValidHeader() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST",
                                                         htu: tokenURL,
                                                         nonce: nil,
                                                         keyPair: pair,
                                                         now: Date(timeIntervalSince1970: 1_700_000_000))
        let segments = proof.split(separator: ".")
        XCTAssertEqual(segments.count, 3)
        let header = try decodeBase64UrlJSON(String(segments[0]))
        XCTAssertEqual(header["typ"] as? String, "dpop+jwt")
        XCTAssertEqual(header["alg"] as? String, "ES256")
        let jwk = try XCTUnwrap(header["jwk"] as? [String: Any])
        XCTAssertEqual(jwk["kty"] as? String, "EC")
        XCTAssertEqual(jwk["crv"] as? String, "P-256")
        XCTAssertNotNil(jwk["x"] as? String)
        XCTAssertNotNil(jwk["y"] as? String)
    }

    func test_givenNonceProvided_whenBuildProof_thenPayloadIncludesNonce() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST",
                                                         htu: tokenURL,
                                                         nonce: "abc123",
                                                         keyPair: pair)
        let segments = proof.split(separator: ".")
        let payload = try decodeBase64UrlJSON(String(segments[1]))
        XCTAssertEqual(payload["nonce"] as? String, "abc123")
        XCTAssertEqual(payload["htm"] as? String, "POST")
        XCTAssertEqual(payload["htu"] as? String, tokenURL.absoluteString)
        XCTAssertNotNil(payload["jti"] as? String)
        XCTAssertNotNil(payload["iat"] as? Int)
    }

    func test_givenURLWithQueryAndFragment_whenBuildProof_thenHtuIsCanonicalized() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let messy = URL(string: "https://login.salesforce.com/services/oauth2/token?foo=bar#frag")!
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST",
                                                         htu: messy,
                                                         nonce: nil,
                                                         keyPair: pair)
        let segments = proof.split(separator: ".")
        let payload = try decodeBase64UrlJSON(String(segments[1]))
        XCTAssertEqual(payload["htu"] as? String, "https://login.salesforce.com/services/oauth2/token")
    }

    func test_givenSamePair_whenBuildProofTwice_thenJtisDiffer() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let p1 = try DPoPProofBuilder.buildProof(httpMethod: "POST", htu: tokenURL, nonce: nil, keyPair: pair)
        let p2 = try DPoPProofBuilder.buildProof(httpMethod: "POST", htu: tokenURL, nonce: nil, keyPair: pair)
        let jti1 = try decodeBase64UrlJSON(String(p1.split(separator: ".")[1]))["jti"] as? String
        let jti2 = try decodeBase64UrlJSON(String(p2.split(separator: ".")[1]))["jti"] as? String
        XCTAssertNotNil(jti1)
        XCTAssertNotNil(jti2)
        XCTAssertNotEqual(jti1, jti2)
    }

    func test_givenProof_whenSignatureIsVerified_thenItValidatesAgainstPublicKey() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST", htu: tokenURL, nonce: nil, keyPair: pair)
        let segments = proof.split(separator: ".")
        let signingInput = "\(segments[0]).\(segments[1])"
        let inputData = signingInput.data(using: .utf8)!
        let rawSig = try base64UrlDecode(String(segments[2]))
        XCTAssertEqual(rawSig.count, 64)
        let derSig = try derEncodeRawECSignature(rawSig)
        var error: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(pair.publicKey,
                                       .ecdsaSignatureMessageX962SHA256,
                                       inputData as CFData,
                                       derSig as CFData,
                                       &error)
        XCTAssertTrue(ok, "Signature should verify against public key. error=\(String(describing: error))")
    }

    // MARK: - Key store

    func test_givenSameScope_whenKeyPairCalledTwice_thenSameKeyIsReturned() throws {
        let p1 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let p2 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        // The SecKey backing the same keychain entry should sign identically; sign+compare.
        let payload = "hello".data(using: .utf8)!
        let s1 = try XCTUnwrap(SFSDKCryptoUtils.signDataES256(payload, withKeyRef: p1.privateKey))
        XCTAssertEqual(s1.count, 64)
        // verify with p2's public key (must be the same pair)
        let der = try derEncodeRawECSignature(s1)
        var error: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(p2.publicKey,
                                       .ecdsaSignatureMessageX962SHA256,
                                       payload as CFData,
                                       der as CFData,
                                       &error)
        XCTAssertTrue(ok)
    }

    func test_givenEmptyScope_whenKeyPairRequested_thenThrowsMissingScopeIdentifier() {
        XCTAssertThrowsError(try DPoPKeyStore.shared.keyPair(forScope: "")) { error in
            XCTAssertEqual(error as? DPoPKeyStoreError, .missingScopeIdentifier)
        }
    }

    func test_givenScopedKey_whenDeleted_thenSubsequentLookupGeneratesFreshKey() throws {
        let pair1 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let payload = "hello".data(using: .utf8)!
        let sig1 = try XCTUnwrap(SFSDKCryptoUtils.signDataES256(payload, withKeyRef: pair1.privateKey))

        DPoPKeyStore.shared.delete(forScope: testScope)

        let pair2 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        // pair2's public key should NOT verify signatures from pair1.
        let der = try derEncodeRawECSignature(sig1)
        var error: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(pair2.publicKey,
                                       .ecdsaSignatureMessageX962SHA256,
                                       payload as CFData,
                                       der as CFData,
                                       &error)
        XCTAssertFalse(ok, "Fresh keypair should not verify signatures from rotated-out key.")
    }

    // MARK: - Nonce cache

    func test_givenScopedNonce_whenSameUrlSameScope_thenReturnsCachedValue() {
        DPoPNonceCache.shared.setNonce("nonceA", htu: tokenURL, scope: testScope)
        XCTAssertEqual(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: testScope), "nonceA")
    }

    func test_givenScopedNonce_whenDifferentScope_thenReturnsNil() {
        DPoPNonceCache.shared.setNonce("nonceA", htu: tokenURL, scope: testScope)
        XCTAssertNil(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: "other-scope"))
    }

    func test_givenNonceForUrlWithQuery_whenLookedUpByCleanUrl_thenMatches() {
        let messy = URL(string: tokenURL.absoluteString + "?foo=bar")!
        DPoPNonceCache.shared.setNonce("nonceB", htu: messy, scope: testScope)
        XCTAssertEqual(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: testScope), "nonceB")
    }

    func test_givenNoncesAcrossScopes_whenClearForScope_thenOnlyMatchingScopeIsRemoved() {
        DPoPNonceCache.shared.setNonce("nA", htu: tokenURL, scope: testScope)
        DPoPNonceCache.shared.setNonce("nB", htu: tokenURL, scope: "other-scope")
        DPoPNonceCache.shared.clear(forScope: testScope)
        XCTAssertNil(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: testScope))
        XCTAssertEqual(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: "other-scope"), "nB")
        DPoPNonceCache.shared.clear(forScope: "other-scope")
    }

    // MARK: - Decorator gating + nonce challenge detection

    func test_givenUseDPoPDisabled_whenDecorate_thenNoHeaderAttached() throws {
        SalesforceManager.shared.usesDPoP = false
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "POST"
        try DPoPRequestDecorator.decorate(req, scope: testScope)
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenUseDPoPEnabled_whenDecorate_thenDPoPHeaderAttached() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "POST"
        try DPoPRequestDecorator.decorate(req, scope: testScope)
        let header = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(header.split(separator: ".").count, 3)
    }

    func test_given401WithDPoPNonceHeader_whenIsNonceChallenge_thenTrue() {
        let resp = HTTPURLResponse(url: tokenURL,
                                   statusCode: 401,
                                   httpVersion: nil,
                                   headerFields: ["DPoP-Nonce": "fresh-nonce"])
        XCTAssertTrue(DPoPRequestDecorator.isNonceChallenge(statusCode: 401, body: nil, response: resp))
    }

    func test_given400WithUseDPoPNonceErrorBody_whenIsNonceChallenge_thenTrue() {
        let body = "{\"error\":\"use_dpop_nonce\"}".data(using: .utf8)
        let resp = HTTPURLResponse(url: tokenURL, statusCode: 400, httpVersion: nil, headerFields: nil)
        XCTAssertTrue(DPoPRequestDecorator.isNonceChallenge(statusCode: 400, body: body, response: resp))
    }

    func test_given200OK_whenIsNonceChallenge_thenFalse() {
        let resp = HTTPURLResponse(url: tokenURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        XCTAssertFalse(DPoPRequestDecorator.isNonceChallenge(statusCode: 200, body: nil, response: resp))
    }

    func test_givenResponseWithDPoPNonce_whenHarvest_thenCacheUpdated() {
        let resp = HTTPURLResponse(url: tokenURL,
                                   statusCode: 200,
                                   httpVersion: nil,
                                   headerFields: ["DPoP-Nonce": "harvested-nonce"])
        DPoPRequestDecorator.harvestNonce(from: resp, requestURL: tokenURL, scope: testScope)
        XCTAssertEqual(DPoPNonceCache.shared.nonce(htu: tokenURL, scope: testScope), "harvested-nonce")
    }

    // MARK: - Helpers

    private func decodeBase64UrlJSON(_ segment: String) throws -> [String: Any] {
        let data = try base64UrlDecode(segment)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(obj as? [String: Any])
    }

    private func base64UrlDecode(_ s: String) throws -> Data {
        var b64 = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        b64 += String(repeating: "=", count: pad)
        guard let d = Data(base64Encoded: b64) else {
            throw NSError(domain: "DPoPTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "bad base64url"])
        }
        return d
    }

    /// Convert a 64-byte raw R||S signature back into ASN.1 DER for `SecKeyVerifySignature`,
    /// which expects `ecdsaSignatureMessageX962SHA256` to receive DER.
    private func derEncodeRawECSignature(_ raw: Data) throws -> Data {
        guard raw.count == 64 else {
            throw NSError(domain: "DPoPTest", code: -2, userInfo: [NSLocalizedDescriptionKey: "raw signature must be 64 bytes"])
        }
        let r = raw.prefix(32)
        let s = raw.suffix(32)
        let rDER = derInteger(r)
        let sDER = derInteger(s)
        var seq = Data()
        seq.append(0x30)
        let inner = rDER + sDER
        seq.append(contentsOf: derLength(inner.count))
        seq.append(inner)
        return seq
    }

    private func derInteger(_ bytes: Data) -> Data {
        var b = Array(bytes)
        while b.count > 1 && b[0] == 0x00 && (b[1] & 0x80) == 0 { b.removeFirst() }
        if (b[0] & 0x80) != 0 { b.insert(0x00, at: 0) }
        var out = Data()
        out.append(0x02)
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
}
