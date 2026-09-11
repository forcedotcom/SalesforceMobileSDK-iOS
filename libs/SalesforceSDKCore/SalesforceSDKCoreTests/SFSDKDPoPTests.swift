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

    func test_givenAccessTokenProvided_whenBuildProof_thenPayloadIncludesAth() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let accessToken = "00DXX0000000000!ARQAQGyAccessTokenLiteralValue"
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "GET",
                                                    htu: URL(string: "https://example.salesforce.com/services/data/v60.0/sobjects/Account")!,
                                                    nonce: nil,
                                                    accessToken: accessToken,
                                                    keyPair: pair)
        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        let ath = try XCTUnwrap(payload["ath"] as? String)

        // ath = base64url(SHA-256(access_token)) per RFC 9449 §4.2.
        let expected = (((accessToken.data(using: .utf8)! as NSData)
                            .sfsdk_sha256()!) as NSData).sfsdk_base64UrlString()
        XCTAssertEqual(ath, expected)
    }

    func test_givenNoAccessToken_whenBuildProof_thenPayloadOmitsAth() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST",
                                                    htu: tokenURL,
                                                    nonce: nil,
                                                    keyPair: pair)
        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        XCTAssertNil(payload["ath"], "Token-endpoint proofs must not include ath")
    }

    func test_givenEmptyAccessToken_whenBuildProof_thenPayloadOmitsAth() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: "GET",
                                                    htu: tokenURL,
                                                    nonce: nil,
                                                    accessToken: "",
                                                    keyPair: pair)
        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        XCTAssertNil(payload["ath"])
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

    // MARK: - JWK thumbprint (RFC 7638)

    /// Precomputed RFC 7638 thumbprint for a fixed P-256 public key.
    /// The point (X, Y) is drawn from RFC 6979 §A.2.5. The expected thumbprint
    /// is computed offline as `base64url(SHA-256(canonical_json({crv:"P-256",
    /// kty:"EC", x:<...>, y:<...>})))` where the canonical JSON has sorted keys,
    /// UTF-8 encoding, and no whitespace. Any drift in canonicalization
    /// (unsorted keys, added whitespace, wrong base64 flavor, or a bad SHA-256)
    /// will make this fixture fail.
    func test_givenFixedTestKeyPair_whenJwkThumbprint_thenMatchesPrecomputedRFC7638Value() throws {
        let publicKey = try Self.makeTestPublicKey()
        let thumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: publicKey)
        XCTAssertEqual(thumbprint, Self.expectedThumbprintForTestKey)
    }

    /// Result must be a 43-character base64url string with no padding.
    func test_givenFixedTestKeyPair_whenJwkThumbprint_thenMatchesBase64UrlShape() throws {
        let publicKey = try Self.makeTestPublicKey()
        let thumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: publicKey)
        XCTAssertEqual(thumbprint.count, 43)
        let pattern = try NSRegularExpression(pattern: "^[A-Za-z0-9_-]{43}$")
        let range = NSRange(location: 0, length: thumbprint.utf16.count)
        XCTAssertNotNil(pattern.firstMatch(in: thumbprint, options: [], range: range),
                        "thumbprint must be a 43-char base64url string")
    }

    /// Two independent key pairs must produce different thumbprints — sanity
    /// that the helper is actually reading key material, not returning a constant.
    func test_givenTwoIndependentKeyPairs_whenJwkThumbprint_thenValuesDiffer() throws {
        let scopeA = "thumbprint-a-\(UUID().uuidString)"
        let scopeB = "thumbprint-b-\(UUID().uuidString)"
        defer {
            DPoPKeyStore.shared.delete(forScope: scopeA)
            DPoPKeyStore.shared.delete(forScope: scopeB)
        }
        let pairA = try DPoPKeyStore.shared.keyPair(forScope: scopeA)
        let pairB = try DPoPKeyStore.shared.keyPair(forScope: scopeB)
        let thumbA = try DPoPProofBuilder.jwkThumbprint(publicKey: pairA.publicKey)
        let thumbB = try DPoPProofBuilder.jwkThumbprint(publicKey: pairB.publicKey)
        XCTAssertNotEqual(thumbA, thumbB)
        XCTAssertEqual(thumbA.count, 43)
        XCTAssertEqual(thumbB.count, 43)
    }

    /// The thumbprint of a key pair equals the RFC 7638
    /// thumbprint recomputed from the `jwk` claim of a DPoP proof built with
    /// the same key pair. This is the invariant that binds `/authorize` to
    /// `/token`: whatever thumbprint the SDK sends in `dpop_jkt`, the server
    /// will later independently compute from the proof's `jwk` claim and
    /// compare byte-for-byte.
    func test_givenSameKeyPair_whenJwkThumbprintAndProofJwkRehashed_thenValuesMatch() throws {
        let pair = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let thumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: pair.publicKey)

        let proof = try DPoPProofBuilder.buildProof(httpMethod: "POST",
                                                    htu: tokenURL,
                                                    nonce: nil,
                                                    keyPair: pair)
        let segments = proof.split(separator: ".")
        let header = try decodeBase64UrlJSON(String(segments[0]))
        let jwk = try XCTUnwrap(header["jwk"] as? [String: String])

        // Recompute the thumbprint from the proof's jwk claim using the same
        // RFC 7638 canonicalization (sorted keys, no whitespace, UTF-8).
        let canonicalData = try JSONSerialization.data(withJSONObject: jwk,
                                                       options: [.sortedKeys, .withoutEscapingSlashes])
        let digest = try XCTUnwrap((canonicalData as NSData).sfsdk_sha256())
        let recomputed = (digest as NSData).sfsdk_base64UrlString()
        XCTAssertEqual(thumbprint, recomputed,
                       "dpop_jkt (authorize) must equal RFC 7638 thumbprint of jwk (token proof)")
    }

    // MARK: - Key store

    func test_givenSameScope_whenKeyPairCalledTwice_thenSameKeyIsReturned() throws {
        let p1 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let p2 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        // The SecKey backing the same keychain entry should sign identically; sign+compare.
        let payload = "hello".data(using: .utf8)!
        let s1 = try Encryptor.signES256(payload, with: p1.privateKey)
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

    func test_givenPredicateSignals_whenShouldAttachDPoP_thenTokenTypeOrKeyMaterialTriggers() throws {
        // Empty scope always false — never mistake a missing identifier for a DPoP credential.
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: "", tokenType: "DPoP"))

        // No token type, no key pair on this scope: predicate false.
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: nil))
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "Bearer"))

        // Token type "DPoP" alone (before key pair minted) short-circuits to true.
        XCTAssertTrue(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "DPoP"))

        // Mint the key pair. Key material is the fallback signal only when tokenType is nil.
        _ = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        XCTAssertTrue(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: nil))
        // An explicit "Bearer" tokenType takes priority — no proof, even with key material present.
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "Bearer"))
        XCTAssertTrue(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "DPoP"))

        // Removing the key pair collapses back to the tokenType-only signal.
        DPoPKeyStore.shared.delete(forScope: testScope)
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: nil))
        XCTAssertFalse(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "Bearer"))
        XCTAssertTrue(DPoPRequestDecorator.shouldAttachDPoP(scope: testScope, tokenType: "DPoP"))
    }

    func test_givenTokenTypeVariants_whenIsDPoPTokenType_thenMatchesCaseInsensitivelyAndRejectsNilEmptyBearer() {
        // Canonical and casing variants all resolve to DPoP — token_type is case-insensitive per
        // RFC 6749 §5.1 / RFC 9449 §6.1, so the /authorize gate and the migration guards agree
        // no matter how the server cases the value.
        XCTAssertTrue(DPoPRequestDecorator.isDPoPTokenType("DPoP"))
        XCTAssertTrue(DPoPRequestDecorator.isDPoPTokenType("dpop"))
        XCTAssertTrue(DPoPRequestDecorator.isDPoPTokenType("DPOP"))

        // nil / empty / Bearer are not DPoP. nil and empty especially matter: the predicate must
        // preserve the `isEqualToString:` semantics it replaced (a bare `caseInsensitiveCompare:`
        // on a nil receiver would return NSOrderedSame and wrongly read as DPoP).
        XCTAssertFalse(DPoPRequestDecorator.isDPoPTokenType(nil))
        XCTAssertFalse(DPoPRequestDecorator.isDPoPTokenType(""))
        XCTAssertFalse(DPoPRequestDecorator.isDPoPTokenType("Bearer"))
        XCTAssertFalse(DPoPRequestDecorator.isDPoPTokenType("bearer"))
    }

    func test_givenLowercaseDPoPTokenType_whenApplyAuthHeaders_thenStampsDPoPSchemeNotBearer() throws {
        // Regression for W-24027018: server returns lowercase "dpop" in refresh responses
        // (SFOAuthCredentials.m line 492). Case-sensitive == caused applyAuthHeaders to fall
        // through to the Bearer branch on every post-refresh request.
        _ = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let request = NSMutableURLRequest(url: URL(string: "https://test.salesforce.com/services/data/v66.0/sobjects")!)
        try DPoPRequestDecorator.applyAuthHeaders(request, scope: testScope, accessToken: "test_access_token", tokenType: "dpop")
        let auth = request.value(forHTTPHeaderField: "Authorization")
        XCTAssertTrue(auth?.hasPrefix("DPoP ") == true,
                      "lowercase 'dpop' tokenType must produce 'Authorization: DPoP …', got: \(auth ?? "nil")")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"),
                        "lowercase 'dpop' tokenType must attach a DPoP proof header")
    }

    func test_givenScope_whenHasKeyPairChecked_thenReflectsKeyMaterialPresenceOnly() throws {
        // Fresh scope: no key material yet.
        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: testScope),
                       "hasKeyPair should be false before keyPair(forScope:) is ever called")

        // Minting the pair should flip the flag to true without side-effects on other scopes.
        _ = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forScope: testScope),
                      "hasKeyPair should be true after a keypair is minted for the scope")

        // Deletion should flip it back to false.
        DPoPKeyStore.shared.delete(forScope: testScope)
        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: testScope),
                       "hasKeyPair should be false after the keypair is deleted")

        // Empty scope must be rejected — never treat "" as a valid credential.
        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: ""),
                       "hasKeyPair should be false for an empty scope")
    }

    func test_givenScopedKey_whenDeleted_thenSubsequentLookupGeneratesFreshKey() throws {
        let pair1 = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let payload = "hello".data(using: .utf8)!
        let sig1 = try Encryptor.signES256(payload, with: pair1.privateKey)

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

    func test_givenSameScope_whenKeyPairRequestedConcurrently_thenAllReturnTheSameKey() throws {
        let iterations = 50
        var pairs: [DPoPKeyPair?] = Array(repeating: nil, count: iterations)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if let pair = try? DPoPKeyStore.shared.keyPair(forScope: testScope) {
                lock.lock()
                pairs[i] = pair
                lock.unlock()
            }
        }

        let resolved = pairs.compactMap { $0 }
        XCTAssertEqual(resolved.count, iterations, "every concurrent caller should get a keypair")

        // All concurrent callers must resolve to the same underlying keychain entry.
        // Verify by signing with one and validating with every other.
        let payload = "concurrent".data(using: .utf8)!
        let sig = try Encryptor.signES256(payload, with: resolved[0].privateKey)
        let der = try derEncodeRawECSignature(sig)
        for pair in resolved {
            var error: Unmanaged<CFError>?
            let ok = SecKeyVerifySignature(pair.publicKey,
                                           .ecdsaSignatureMessageX962SHA256,
                                           payload as CFData,
                                           der as CFData,
                                           &error)
            XCTAssertTrue(ok, "all concurrent callers should yield the same keypair (no double-create)")
        }
    }

    func test_givenDifferentScopes_whenKeyPairRequestedConcurrently_thenEachScopeGetsItsOwnKey() throws {
        let iterations = 20
        let scopes = (0..<iterations).map { "concurrent-scope-\(UUID().uuidString)-\($0)" }
        defer { scopes.forEach { DPoPKeyStore.shared.delete(forScope: $0) } }

        var publicKeys: [SecKey?] = Array(repeating: nil, count: iterations)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if let pair = try? DPoPKeyStore.shared.keyPair(forScope: scopes[i]) {
                lock.lock()
                publicKeys[i] = pair.publicKey
                lock.unlock()
            }
        }

        let resolved = publicKeys.compactMap { $0 }
        XCTAssertEqual(resolved.count, iterations)

        // Each per-scope public key should be distinct: a signature from one scope's key
        // must not verify against another scope's public key.
        let payload = "scope-isolation".data(using: .utf8)!
        let firstScopePair = try DPoPKeyStore.shared.keyPair(forScope: scopes[0])
        let sig = try Encryptor.signES256(payload, with: firstScopePair.privateKey)
        let der = try derEncodeRawECSignature(sig)
        for (i, key) in resolved.enumerated() where i != 0 {
            var error: Unmanaged<CFError>?
            let ok = SecKeyVerifySignature(key,
                                           .ecdsaSignatureMessageX962SHA256,
                                           payload as CFData,
                                           der as CFData,
                                           &error)
            XCTAssertFalse(ok, "scope \(i)'s key should not verify scope 0's signature")
        }
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

    func test_givenConcurrentReadsAndWrites_whenNonceCacheAccessed_thenStateRemainsConsistent() {
        let iterations = 200
        let urls = (0..<10).map { URL(string: "https://login.salesforce.com/services/oauth2/token?path=\($0)")! }
        let scopes = (0..<5).map { "concurrent-nonce-scope-\($0)" }
        defer { scopes.forEach { DPoPNonceCache.shared.clear(forScope: $0) } }

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let url = urls[i % urls.count]
            let scope = scopes[i % scopes.count]
            switch i % 3 {
            case 0:
                DPoPNonceCache.shared.setNonce("nonce-\(i)", htu: url, scope: scope)
            case 1:
                _ = DPoPNonceCache.shared.nonce(htu: url, scope: scope)
            default:
                DPoPNonceCache.shared.clear(forScope: scope)
            }
        }

        // After the storm, write a known value and verify it round-trips. The point of
        // this test is to surface data races / crashes under TSan; the final assertion
        // is just a liveness check.
        let url = urls[0]
        let scope = scopes[0]
        DPoPNonceCache.shared.setNonce("final", htu: url, scope: scope)
        XCTAssertEqual(DPoPNonceCache.shared.nonce(htu: url, scope: scope), "final")
    }

    // MARK: - Decorator gating + nonce challenge detection

    func test_givenNoTokenTypeAndNoKeyMaterial_whenDecorate_thenNoHeaderAttached() throws {
        // Fresh scope: no key material, no tokenType. Both predicate signals off → skip.
        // Global usesDPoP is intentionally ignored — the gate is per-credential state now.
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "POST"
        try DPoPRequestDecorator.decorate(req, scope: testScope)
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenKeyMaterialPresent_whenDecorate_thenDPoPHeaderAttached() throws {
        // Simulates the fresh-login flow after `/authorize` (which mints the key pair via
        // dpop_jkt) but before `/token` returns a tokenType. Presence of key material alone
        // is sufficient to gate proof attachment.
        _ = try DPoPKeyStore.shared.keyPair(forScope: testScope)
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "POST"
        try DPoPRequestDecorator.decorate(req, scope: testScope)
        let header = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(header.split(separator: ".").count, 3)
    }

    func test_givenTokenTypeDPoP_whenDecorate_thenDPoPHeaderAttachedRegardlessOfGlobalFlag() throws {
        // Simulates the refresh flow after a DPoP-bound credential has been persisted.
        // Global flag is off, but the credential's tokenType is "DPoP" → proof still attached.
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = false
        defer { SalesforceManager.shared.usesDPoP = prior }
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "POST"
        try DPoPRequestDecorator.decorate(req, scope: testScope, tokenType: "DPoP", accessToken: nil)
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

    // MARK: - applyAuthHeaders

    func test_givenDPoPTokenType_whenApplyAuthHeaders_thenDPoPSchemeAndProofAttached() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }

        let req = NSMutableURLRequest(url: URL(string: "https://example.salesforce.com/services/data/v60.0/sobjects/Account")!)
        req.httpMethod = "GET"
        let token = "00DXX0000000000!ARQAQGyAccessTokenLiteralValue"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: token,
                                                  tokenType: "DPoP")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "DPoP \(token)")
        let proof = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(proof.split(separator: ".").count, 3)

        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        let ath = try XCTUnwrap(payload["ath"] as? String)
        let expected = (((token.data(using: .utf8)! as NSData)
                            .sfsdk_sha256()!) as NSData).sfsdk_base64UrlString()
        XCTAssertEqual(ath, expected)
    }

    func test_givenBearerTokenType_whenApplyAuthHeaders_thenBearerSchemeNoProof() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: "tok-abc",
                                                  tokenType: "Bearer")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer tok-abc")
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenNilTokenType_whenApplyAuthHeaders_thenBearerSchemeNoProof() throws {
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: "tok-abc",
                                                  tokenType: nil)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer tok-abc")
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenEmptyAccessToken_whenApplyAuthHeaders_thenNoHeadersStamped() throws {
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: "",
                                                  tokenType: "DPoP")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenNilAccessToken_whenApplyAuthHeaders_thenNoHeadersStamped() throws {
        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: nil,
                                                  tokenType: "DPoP")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    // MARK: - applyAuthHeaders(_:credentials:)

    func test_givenDPoPCredentials_whenApplyAuthHeadersWithCredentials_thenBothHeadersSet() throws {
        let scope = "creds-dpop-\(UUID().uuidString)"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = "00DXX0000000000!ARQ.dpop.access.token"
        creds.tokenType = "DPoP"
        _ = try DPoPKeyStore.shared.keyPair(forScope: scope)

        let req = NSMutableURLRequest(url: URL(string: "https://example.salesforce.com/services/data/v60.0/sobjects/Account")!)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req, credentials: creds)

        let auth = try XCTUnwrap(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(auth.hasPrefix("DPoP "))
        let proof = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(proof.split(separator: ".").count, 3)
    }

    func test_givenBearerCredentials_whenApplyAuthHeadersWithCredentials_thenOnlyAuthorizationHeader() throws {
        let scope = "creds-bearer-\(UUID().uuidString)"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = "bearer-only-access-token"
        creds.tokenType = "Bearer"

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req, credentials: creds)

        let auth = try XCTUnwrap(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(auth.hasPrefix("Bearer "))
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenDPoPCredentials_usesDPoPFalse_whenApplyAuthHeadersWithCredentials_thenProofStillAttached() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = false
        defer { SalesforceManager.shared.usesDPoP = prior }

        let scope = "creds-dpop-flagoff-\(UUID().uuidString)"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = "00DXX0000000000!ARQ.dpop.access.token"
        creds.tokenType = "DPoP"
        _ = try DPoPKeyStore.shared.keyPair(forScope: scope)

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req, credentials: creds)

        XCTAssertNotNil(req.value(forHTTPHeaderField: "DPoP"),
                        "Proof gating is per-credential, not the global usesDPoP flag")
    }

    func test_givenNilTokenType_withKeypair_whenApplyAuthHeadersWithCredentials_thenProofAttached() throws {
        let scope = "creds-niltype-keypair-\(UUID().uuidString)"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = "00DXX0000000000!ARQ.dpop.access.token"
        // tokenType left nil.
        _ = try DPoPKeyStore.shared.keyPair(forScope: scope)

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req, credentials: creds)

        XCTAssertNotNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    func test_givenNilTokenType_noKeypair_whenApplyAuthHeadersWithCredentials_thenBearerOnly() throws {
        let scope = "creds-niltype-nokeypair-\(UUID().uuidString)"
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = "bearer-only-access-token"
        // tokenType left nil, no keypair seeded.

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req, credentials: creds)

        let auth = try XCTUnwrap(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(auth.hasPrefix("Bearer "))
        XCTAssertNil(req.value(forHTTPHeaderField: "DPoP"))
    }

    // MARK: - Identity service loop-prevention

    /// Loop regression: under DPoP-bound credentials, an identity request must go out
    /// stamped `Authorization: DPoP <token>` with a valid `ath` claim — the same outbound
    /// shape any other DPoP-aware site uses. The loop happened previously when the
    /// identity site stamped `Bearer <dpop-bound-token>` instead, and the server returned
    /// 401, the SDK refreshed, retried with `Bearer` again, and looped.
    func test_givenDPoPCredentials_whenIdentityRequestStamped_thenAuthorizationIsDPoPAndAthMatches() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }

        let scope = "sc3-\(UUID().uuidString)"
        let token = "00DXX0000000000!ARQAQGyAccessTokenLiteralValue"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }

        let identityURL = URL(string: "https://login.salesforce.com/id/00D000000000000/005000000000000")!
        let req = NSMutableURLRequest(url: identityURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: scope,
                                                  accessToken: token,
                                                  tokenType: "DPoP")

        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "DPoP \(token)",
                       "Identity must use DPoP scheme under a DPoP-bound token; Bearer here is what produced the original loop.")
        let proof = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        let ath = try XCTUnwrap(payload["ath"] as? String)
        let expected = (((token.data(using: .utf8)! as NSData)
                            .sfsdk_sha256()!) as NSData).sfsdk_base64UrlString()
        XCTAssertEqual(ath, expected)
    }

    func test_givenGlobalFlagOffButTokenTypeDPoP_whenApplyAuthHeaders_thenProofStillAttached() throws {
        // With the credential-state gate in place, the proof follows the tokenType — a
        // DPoP-bound credential always gets a proof, even if the process-wide usesDPoP
        // switch was flipped off (e.g. after an app upgrade / config change).
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = false
        defer { SalesforceManager.shared.usesDPoP = prior }

        let req = NSMutableURLRequest(url: tokenURL)
        req.httpMethod = "GET"
        try DPoPRequestDecorator.applyAuthHeaders(req,
                                                  scope: testScope,
                                                  accessToken: "tok-abc",
                                                  tokenType: "DPoP")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "DPoP tok-abc")
        let proof = try XCTUnwrap(req.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(proof.split(separator: ".").count, 3,
                       "Proof must be attached whenever tokenType == DPoP, regardless of global flag")
    }

    // MARK: - SFRestRequest end-to-end

    func test_givenDPoPCredentials_whenPrepareRestRequest_thenAuthorizationIsDPoPAndProofAttached() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }

        let scope = "rest-dpop-\(UUID().uuidString)"
        let creds = OAuthCredentials(identifier: scope,
                                     clientId: "CLIENT_ID",
                                     encrypted: false)!
        creds.accessToken = "00DXX0000000000!ARQ.dpop.access.token"
        creds.tokenType = "DPoP"
        creds.instanceUrl = URL(string: "https://example.salesforce.com")
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }

        let account = UserAccount(credentials: creds)
        let request = RestRequest(method: .GET,
                                  path: "/services/data/v60.0/sobjects/Account",
                                  queryParams: nil)
        let urlRequest = try XCTUnwrap(request.prepare(forSend: account))

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"),
                       "DPoP \(creds.accessToken!)")
        let proof = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "DPoP"))
        XCTAssertEqual(proof.split(separator: ".").count, 3)
        let payload = try decodeBase64UrlJSON(String(proof.split(separator: ".")[1]))
        let ath = try XCTUnwrap(payload["ath"] as? String)
        let expected = (((creds.accessToken!.data(using: .utf8)! as NSData)
                            .sfsdk_sha256()!) as NSData).sfsdk_base64UrlString()
        XCTAssertEqual(ath, expected)
    }

    func test_givenBearerCredentials_whenPrepareRestRequest_thenAuthorizationIsBearerNoProof() throws {
        let creds = OAuthCredentials(identifier: "rest-bearer-\(UUID().uuidString)",
                                     clientId: "CLIENT_ID",
                                     encrypted: false)!
        creds.accessToken = "bearer-only-access-token"
        // tokenType left nil — the Bearer baseline.
        creds.instanceUrl = URL(string: "https://example.salesforce.com")
        creds.userId = "USERID"
        creds.organizationId = "ORGID"

        let account = UserAccount(credentials: creds)
        let request = RestRequest(method: .GET,
                                  path: "/services/data/v60.0/sobjects/Account",
                                  queryParams: nil)
        let urlRequest = try XCTUnwrap(request.prepare(forSend: account))

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"),
                       "Bearer \(creds.accessToken!)")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "DPoP"),
                     "Bearer credentials must not attach a DPoP header")
    }

    // A DPoP-bound credential MUST attach a proof on the outbound REST request even
    // when the process-wide `usesDPoP` flag has been flipped OFF. Locks in the fix — the
    // gate is per-credential state, not the global flag.
    func test_givenGlobalFlagOffAndDPoPCredential_whenPrepareRestRequest_thenAuthorizationIsDPoPAndProofAttached() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = false
        defer { SalesforceManager.shared.usesDPoP = prior }

        let scope = "rest-dpop-flagoff-\(UUID().uuidString)"
        let creds = OAuthCredentials(identifier: scope,
                                     clientId: "CLIENT_ID",
                                     encrypted: false)!
        creds.accessToken = "00DXX0000000000!ARQ.dpop.access.token"
        creds.tokenType = "DPoP"
        creds.instanceUrl = URL(string: "https://example.salesforce.com")
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }

        let account = UserAccount(credentials: creds)
        let request = RestRequest(method: .GET,
                                  path: "/services/data/v60.0/sobjects/Account",
                                  queryParams: nil)
        let urlRequest = try XCTUnwrap(request.prepare(forSend: account))

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"),
                       "DPoP \(creds.accessToken!)",
                       "Authorization scheme must follow credentials.tokenType even when the global usesDPoP flag is off")
        let proof = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "DPoP"),
                                  "DPoP proof header must be attached for a DPoP-bound credential even with global usesDPoP flag off")
        XCTAssertEqual(proof.split(separator: ".").count, 3)
    }

    // A Bearer credential MUST NOT get a DPoP header regardless of the global flag.
    func test_givenBearerCredential_whenPrepareRestRequest_thenNoDPoPHeaderRegardlessOfGlobalFlag() throws {
        let prior = SalesforceManager.shared.usesDPoP
        defer { SalesforceManager.shared.usesDPoP = prior }

        for flag in [true, false] {
            SalesforceManager.shared.usesDPoP = flag
            let creds = OAuthCredentials(identifier: "rest-bearer-matrix-\(UUID().uuidString)",
                                         clientId: "CLIENT_ID",
                                         encrypted: false)!
            creds.accessToken = "bearer-only-access-token"
            // tokenType left nil, no keyPair seeded — Bearer baseline.
            creds.instanceUrl = URL(string: "https://example.salesforce.com")
            creds.userId = "USERID"
            creds.organizationId = "ORGID"

            let account = UserAccount(credentials: creds)
            let request = RestRequest(method: .GET,
                                      path: "/services/data/v60.0/sobjects/Account",
                                      queryParams: nil)
            let urlRequest = try XCTUnwrap(request.prepare(forSend: account), "flag=\(flag)")

            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"),
                           "Bearer \(creds.accessToken!)",
                           "Bearer credential must yield `Authorization: Bearer <token>` (flag=\(flag))")
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "DPoP"),
                         "Bearer credential must not attach a DPoP header (flag=\(flag))")
        }
    }

    // MARK: - Log redaction

    /// Captures every line submitted to `SFSDKCoreLogger` during the four-site DPoP flow
    /// and asserts none contain the access token, the proof JWT, the embedded JWK
    /// (`jwk`/`jkt`/coordinate `x`/`y`), or the `ath` thumbprint. Per CLAUDE.md the SDK must
    /// never log credentials.
    func test_givenDPoPBoundFlow_whenAllSitesStampHeaders_thenLoggerCapturesNoSecrets() throws {
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer {
            SalesforceManager.shared.usesDPoP = prior
            // SFLogger caches per-component loggers; swapping the factory alone won't
            // re-route messages from already-cached components. Flush so the recorder
            // installed by this test stops receiving messages emitted by sibling tests.
            SalesforceLogger.setLogReceiverFactory(NoOpLogReceiverFactory())
            SalesforceLogger.clearAllComponents()
        }

        let recorder = RecordingLogReceiver()
        let factory = RecordingLogReceiverFactory(receiver: recorder)
        SalesforceLogger.setLogReceiverFactory(factory)
        // Force cached per-component loggers to re-bind to the recording factory above.
        // Without this flush, components that logged earlier in the run would keep
        // their old receiver and the recorder would silently observe nothing.
        SalesforceLogger.clearAllComponents()

        let scope = "redaction-\(UUID().uuidString)"
        let token = "00DXX0000000000!ARQ.redactionTestSecret.AccessTokenLiteralValue"
        defer { DPoPKeyStore.shared.delete(forScope: scope) }

        // Site 1 — REST (SFRestRequest.prepare)
        let creds = OAuthCredentials(identifier: scope, clientId: "CLIENT_ID", encrypted: false)!
        creds.accessToken = token
        creds.tokenType = "DPoP"
        creds.instanceUrl = URL(string: "https://example.salesforce.com")
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        let account = UserAccount(credentials: creds)
        let restRequest = RestRequest(method: .GET,
                                      path: "/services/data/v60.0/sobjects/Account",
                                      queryParams: nil)
        let restURLRequest = try XCTUnwrap(restRequest.prepare(forSend: account))
        let restProof = try XCTUnwrap(restURLRequest.value(forHTTPHeaderField: "DPoP"))

        // Sites 2, 3, 4 — Identity / photo / userinfo all funnel through applyAuthHeaders.
        // Run the helper directly to exercise the same code path the production sites use.
        for path in ["/id/00D000000000000/005000000000000",
                     "/profilephoto/Q3a000000000000/F",
                     "/services/oauth2/userinfo"] {
            let req = NSMutableURLRequest(url: URL(string: "https://example.salesforce.com\(path)")!)
            req.httpMethod = "GET"
            try DPoPRequestDecorator.applyAuthHeaders(req,
                                                     scope: scope,
                                                     accessToken: token,
                                                     tokenType: "DPoP")
        }

        let proofSegments = restProof.split(separator: ".")
        XCTAssertEqual(proofSegments.count, 3)
        let header = try decodeBase64UrlJSON(String(proofSegments[0]))
        let payload = try decodeBase64UrlJSON(String(proofSegments[1]))
        let jwk = try XCTUnwrap(header["jwk"] as? [String: String])
        let jwkX = try XCTUnwrap(jwk["x"])
        let jwkY = try XCTUnwrap(jwk["y"])
        let ath = try XCTUnwrap(payload["ath"] as? String)

        // Forbidden substrings: the access token, the full proof, and the JWK material that
        // (when hashed) becomes the `jkt` thumbprint binding the token.
        let forbidden: [(String, String)] = [
            ("access token", token),
            ("DPoP proof JWS", restProof),
            ("ath claim", ath),
            ("JWK x coordinate", jwkX),
            ("JWK y coordinate", jwkY),
        ]
        let allLines = recorder.snapshot()
        for line in allLines {
            for (label, secret) in forbidden {
                XCTAssertFalse(line.contains(secret),
                               "\(label) leaked into log line: \(line)")
            }
        }
    }

    func test_givenBearerCredentialsAndPhotoResponseWithStrayNonceHeader_whenRetrieveUserPhoto_thenCacheStaysEmpty() throws {
        // The user-photo path harvests DPoP-Nonce headers from responses. Under a Bearer
        // login it must NOT touch the DPoP nonce cache, even if the photo CDN happens to
        // emit a stray DPoP-Nonce header — the cache is DPoP-scoped state that Bearer
        // sessions must leave untouched (Bearer-path backward compatibility).
        let prior = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        defer { SalesforceManager.shared.usesDPoP = prior }

        let scope = "photo-bearer-\(UUID().uuidString)"
        defer { DPoPNonceCache.shared.clear(forScope: scope) }
        let photoURL = URL(string: "https://example.salesforce.com/profilephoto/T/F/abc/200")!

        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self] + (config.protocolClasses ?? [])
        ScriptedURLProtocol.installScripts([
            .init(statusCode: 200,
                  headers: ["DPoP-Nonce": "should-not-cache"],
                  body: Data())
        ], identifier: identifier)
        Network.setSessionConfiguration(config, identifier: identifier)
        defer {
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
        }

        let creds = OAuthCredentials(identifier: scope,
                                     clientId: "CLIENT_ID",
                                     encrypted: false)!
        creds.accessToken = "bearer-photo-token"
        // tokenType left nil — the Bearer baseline.
        creds.instanceUrl = URL(string: "https://example.salesforce.com")
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.identityUrl = URL(string: "https://login.salesforce.com/id/ORGID/USERID")

        let account = UserAccount(credentials: creds)
        account.idData = IdentityData(jsonDict: [
            "user_id": "USERID",
            "organization_id": "ORGID",
            "photos": [
                "thumbnail": photoURL.absoluteString
            ]
        ])

        let manager = UserAccountManager.shared
        manager.perform(NSSelectorFromString("retrieveUserPhotoIfNeeded:"), with: account)

        // The photo path is fire-and-forget (no completion block to await). The bug, if
        // present, manifests as a synchronous cache write inside the dataResponseBlock —
        // so we poll the cache with a predicate expectation that flips to true on a leak.
        // If the gate is in place, the predicate never flips and the wait times out
        // (the negative outcome we want), at which point we assert the cache is still nil.
        let leakDetected = XCTNSPredicateExpectation(predicate: NSPredicate(block: { _, _ in
            DPoPNonceCache.shared.nonce(htu: photoURL, scope: scope) != nil
        }), object: nil)
        leakDetected.isInverted = true
        wait(for: [leakDetected], timeout: 2.0)

        XCTAssertEqual(ScriptedURLProtocol.requestCount(identifier: identifier), 1,
                       "photo request must have been issued exactly once")
        XCTAssertNil(DPoPNonceCache.shared.nonce(htu: photoURL, scope: scope),
                     "Bearer photo response must not write to the DPoP nonce cache")
    }

    // MARK: - Test key fixture (RFC 6979 §A.2.5 P-256 point)

    /// P-256 public key point (X, Y) from RFC 6979 §A.2.5. Fixed across all
    /// runs, so tests derived from it can compare against a precomputed
    /// RFC 7638 thumbprint fixture below.
    private static let testKeyXHex =
        "60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6"
    private static let testKeyYHex =
        "7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299"

    /// Precomputed offline (Python: base64url(SHA-256(canonical_json(jwk)))) using
    /// the RFC 7638 canonical form `{"crv":"P-256","kty":"EC","x":"…","y":"…"}`.
    /// If this value ever changes without a corresponding RFC 7638 spec change,
    /// something canonicalization-related has drifted in the implementation.
    private static let expectedThumbprintForTestKey =
        "DOvxvJiAdIqVWIkFt5hDtCunXLF0BV4-JGv4f-ALSm0"

    /// Builds a P-256 `SecKey` public key from the fixed test point above,
    /// using the uncompressed SEC1 encoding `0x04 || X(32) || Y(32)`.
    private static func makeTestPublicKey() throws -> SecKey {
        let xBytes = try hexToBytes(testKeyXHex)
        let yBytes = try hexToBytes(testKeyYHex)
        var raw = Data([0x04])
        raw.append(xBytes)
        raw.append(yBytes)
        let attrs: [String: Any] = [
            String(kSecAttrKeyType): kSecAttrKeyTypeECSECPrimeRandom,
            String(kSecAttrKeyClass): kSecAttrKeyClassPublic,
            String(kSecAttrKeySizeInBits): 256
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(raw as CFData, attrs as CFDictionary, &error) else {
            throw NSError(domain: "DPoPTest",
                          code: -3,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "SecKeyCreateWithData failed: \(String(describing: error?.takeRetainedValue()))"])
        }
        return key
    }

    private static func hexToBytes(_ hex: String) throws -> Data {
        guard hex.count % 2 == 0 else {
            throw NSError(domain: "DPoPTest", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "odd-length hex"])
        }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw NSError(domain: "DPoPTest", code: -5,
                              userInfo: [NSLocalizedDescriptionKey: "bad hex byte"])
            }
            data.append(byte)
            index = next
        }
        return data
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

// MARK: - Log capture support

/// Thread-safe accumulator for log lines emitted during a test.
private final class RecordingLogReceiver: NSObject, SalesforceLogReceiver {
    private let lock = NSLock()
    private var lines: [String] = []

    func receive(level: SalesforceLogger.Level,
                 cls: AnyClass,
                 component: String,
                 message: String) {
        lock.lock()
        lines.append("[\(component)] \(NSStringFromClass(cls)): \(message)")
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}

private final class RecordingLogReceiverFactory: NSObject, SalesforceLogReceiverFactory {
    private let receiver: RecordingLogReceiver
    init(receiver: RecordingLogReceiver) { self.receiver = receiver }
    func create(componentName: String) -> SalesforceLogReceiver { receiver }
}

/// Discards everything; used to detach the recorder after the test runs.
private final class NoOpLogReceiverFactory: NSObject, SalesforceLogReceiverFactory {
    private let sink = NoOpLogReceiver()
    func create(componentName: String) -> SalesforceLogReceiver { sink }
}

private final class NoOpLogReceiver: NSObject, SalesforceLogReceiver {
    func receive(level: SalesforceLogger.Level,
                 cls: AnyClass,
                 component: String,
                 message: String) {}
}

// MARK: - ScriptedURLProtocol

/// `URLProtocol` subclass that delivers a queue of canned responses keyed by
/// per-test identifier. Each test installs its own script list and pulls results
/// off the head as requests arrive. Captures the outbound `URLRequest`s so the
/// test can assert on retry-time `DPoP` proofs (nonce claim, fresh `jti`, etc.).
final class ScriptedURLProtocol: URLProtocol {

    struct ScriptedResponse {
        let statusCode: Int
        let headers: [String: String]?
        let body: Data?
    }

    private static let lock = NSLock()
    private static var scripts: [String: [ScriptedResponse]] = [:]
    private static var captured: [String: [URLRequest]] = [:]
    private static var counts: [String: Int] = [:]

    static func installScripts(_ list: [ScriptedResponse], identifier: String) {
        lock.lock(); defer { lock.unlock() }
        scripts[identifier] = list
        captured[identifier] = []
        counts[identifier] = 0
    }

    static func removeScripts(identifier: String) {
        lock.lock(); defer { lock.unlock() }
        scripts.removeValue(forKey: identifier)
        captured.removeValue(forKey: identifier)
        counts.removeValue(forKey: identifier)
    }

    static func requestCount(identifier: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return counts[identifier] ?? 0
    }

    static func capturedRequests(identifier: String) -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return captured[identifier] ?? []
    }

    private static func resolveIdentifier(for request: URLRequest) -> String? {
        // The URL session is per-identifier; we tag the protocol by inspecting the
        // currently-installed scripts. With one script set per test, the lookup is
        // unambiguous. If a test's URLs clash with another, the test isolates by
        // creating a per-test SFNetwork instance which has its own session.
        lock.lock(); defer { lock.unlock() }
        // Find the identifier whose script list still has unconsumed entries OR
        // is the only one installed. In practice tests run isolated and only one
        // identifier is in flight per session, so first key wins.
        return scripts.keys.first
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canInit(with task: URLSessionTask) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let req = self.request
        let id: String? = ScriptedURLProtocol.lock.withLock {
            ScriptedURLProtocol.scripts.keys.first
        }
        guard let identifier = id else {
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: "ScriptedURLProtocol",
                                                          code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "no scripts installed"]))
            return
        }

        let response: ScriptedResponse?
        ScriptedURLProtocol.lock.lock()
        var list = ScriptedURLProtocol.scripts[identifier] ?? []
        ScriptedURLProtocol.captured[identifier, default: []].append(req)
        ScriptedURLProtocol.counts[identifier, default: 0] += 1
        if list.isEmpty {
            response = nil
        } else {
            response = list.removeFirst()
            ScriptedURLProtocol.scripts[identifier] = list
        }
        ScriptedURLProtocol.lock.unlock()

        guard let resp = response else {
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: "ScriptedURLProtocol",
                                                          code: -2,
                                                          userInfo: [NSLocalizedDescriptionKey: "ran out of scripted responses"]))
            return
        }

        let url = req.url ?? URL(string: "https://example.invalid")!
        let httpResponse = HTTPURLResponse(url: url,
                                           statusCode: resp.statusCode,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: resp.headers)!
        client?.urlProtocol(self,
                            didReceive: httpResponse,
                            cacheStoragePolicy: .notAllowed)
        if let body = resp.body {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // No async work to cancel.
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock(); defer { self.unlock() }
        return body()
    }
}
