//
//  SFSDKDPoPRequestDecorator.swift
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

@objc(SFSDKDPoPRequestDecorator)
public final class DPoPRequestDecorator: NSObject {

    @objc public static let dpopHeaderName = "DPoP"
    @objc public static let dpopNonceHeaderName = "DPoP-Nonce"
    @objc public static let nonceErrorCode = "use_dpop_nonce"

    /// Authorization scheme value used when the token endpoint returns
    /// `token_type: "DPoP"` (RFC 6749 §5.1 / RFC 9449 §6.1).
    @objc public static let dpopTokenType = "DPoP"

    /// Single source of truth for "does this `tokenType` denote a DPoP-bound session?".
    ///
    /// Compares case-insensitively against `dpopTokenType` (RFC 6749 §5.1 / RFC 9449 §6.1 both
    /// define `token_type` as case-insensitive). Every DPoP-vs-Bearer decision — the `/authorize`
    /// binding gate in `SFOAuthCoordinator`, the proof-attach gate below, and the migration guards
    /// in `SFUserAccountManager` — routes through this so they can never disagree on a server
    /// casing variant. `nil`/empty → `false`.
    ///
    /// Public (not internal) so it stays visible to the Objective-C callers across framework, SPM,
    /// and CocoaPods builds — an internal `@objc` member is invisible to in-module Objective-C in a
    /// framework build.
    @objc(isDPoPTokenType:)
    public static func isDPoPTokenType(_ tokenType: String?) -> Bool {
        guard let tokenType, !tokenType.isEmpty else { return false }
        return tokenType.caseInsensitiveCompare(dpopTokenType) == .orderedSame
    }

    /// Gate deciding whether to attach a DPoP proof for `scope`.
    ///
    /// An explicit `tokenType` is authoritative:
    /// - `tokenType == "DPoP"` (case-insensitive, per RFC 6749 §5.1 / RFC 9449 §6.1) → attach.
    /// - any other known type (e.g. `"Bearer"`) → do **not** attach, and short-circuit
    ///   before any Keychain I/O. This is what protects the DPoP→Bearer migration /
    ///   Bearer re-auth path: a Bearer credential that reuses a scope still holding stale
    ///   DPoP key material must never get an unexpected proof.
    ///
    /// `tokenType == nil` is the transition window between `/authorize` and `/token`
    /// (and any refresh where the persisted `tokenType` hasn't been rehydrated onto the
    /// request struct yet). Only then do we fall back to the key-material signal: a DPoP
    /// keypair already persisted for this scope in the Keychain.
    ///
    /// Empty scope always returns `false` — an empty `SFOAuthCredentials.identifier`
    /// would collide with unrelated accounts' key material.
    ///
    /// Note: this gate is deliberately independent of `SalesforceManager.shared.usesDPoP`.
    /// The global flag governs *new* logins (whether to request DPoP-bound tokens); once a
    /// credential is bound, every request for it carries a proof regardless of the flag.
    @objc(shouldAttachDPoPForScope:tokenType:)
    public static func shouldAttachDPoP(scope: String, tokenType: String?) -> Bool {
        guard !scope.isEmpty else {
            SFSDKCoreLogger.i(Self.self, message: "DPoP decorator skipped: empty scope identifier")
            return false
        }
        if let tokenType {
            return isDPoPTokenType(tokenType)
        }
        // tokenType is nil — transition window between /authorize and /token; fall back to
        // the key-material signal.
        return DPoPKeyStore.shared.hasKeyPair(forScope: scope)
    }

    /// No-op when the credential is not DPoP-bound (see `shouldAttachDPoP(scope:tokenType:)`).
    /// Otherwise builds a fresh proof JWT (with cached nonce if any) and sets it on the
    /// `DPoP` header. `scope` is typically `SFOAuthCredentials.identifier` so the keypair and
    /// nonce cache are isolated per-account, even before an `SFUserAccount` exists.
    ///
    /// Preserved for backwards compatibility. Delegates with `tokenType: nil`, so the gate
    /// falls back to the key-material signal — safe for the token-endpoint flow where the
    /// tokenType isn't yet known.
    @objc(decorateRequest:scope:error:)
    public static func decorate(_ request: NSMutableURLRequest, scope: String) throws {
        try decorate(request, scope: scope, tokenType: nil, accessToken: nil)
    }

    /// Same as `decorate(_:scope:)` but binds the proof to the given access token via the
    /// `ath` claim (RFC 9449 §4.2). Use at resource-server call sites where the SDK already
    /// holds a token; pass `nil` (or use the no-token overload) at the token endpoint.
    ///
    /// Preserved for backwards compatibility. Delegates to the 4-arg overload with
    /// `tokenType: nil`.
    @objc(decorateRequest:scope:accessToken:error:)
    public static func decorate(_ request: NSMutableURLRequest,
                                scope: String,
                                accessToken: String?) throws {
        try decorate(request, scope: scope, tokenType: nil, accessToken: accessToken)
    }

    /// Full-signature entry point. Uses `shouldAttachDPoP(scope:tokenType:)` as the gate.
    /// `tokenType` is the persisted `SFOAuthCredentials.tokenType` for the in-flight
    /// account; pass `nil` when the caller doesn't have it (e.g. the token-endpoint
    /// exchange itself), in which case the gate falls back to the key-material signal.
    @objc(decorateRequest:scope:tokenType:accessToken:error:)
    public static func decorate(_ request: NSMutableURLRequest,
                                scope: String,
                                tokenType: String?,
                                accessToken: String?) throws {
        guard Self.shouldAttachDPoP(scope: scope, tokenType: tokenType) else { return }
        guard let url = request.url else { return }
        let method = request.httpMethod

        let keyPair = try DPoPKeyStore.shared.keyPair(forScope: scope)
        // Salesforce seeds DPoP-Nonce only on token-endpoint responses; resource-server
        // responses don't refresh it. RFC 9449 §8/§9 permits this. Look up the per-htu
        // entry first (spec-correct), then fall back to the latest nonce for the same
        // scope so resource-server calls reuse the token-endpoint nonce instead of
        // paying a `use_dpop_nonce` round-trip.
        let nonce = DPoPNonceCache.shared.nonce(htu: url, scope: scope)
            ?? DPoPNonceCache.shared.latest(forScope: scope)
        let proof = try DPoPProofBuilder.buildProof(httpMethod: method,
                                                    htu: url,
                                                    nonce: nonce,
                                                    accessToken: accessToken,
                                                    keyPair: keyPair)
        request.setValue(proof, forHTTPHeaderField: dpopHeaderName)
    }

    /// Central helper for stamping the Authorization header on authenticated outbound
    /// requests. Decides scheme from `tokenType`:
    ///
    /// - `"DPoP"` → `Authorization: DPoP <token>` and a fresh DPoP proof header bound
    ///   to `accessToken` via the `ath` claim.
    /// - anything else (including `nil` / `"Bearer"`) → `Authorization: Bearer <token>`,
    ///   no DPoP header.
    ///
    /// No-op when `accessToken` is empty — preserves the existing "no token, skip stamp"
    /// behavior of the four call sites.
    ///
    /// - Parameters:
    ///   - request: the request to mutate. Existing `Authorization`/`DPoP` headers are
    ///     overwritten by this method (callers should guard against double-stamping
    ///     via their own checks).
    ///   - scope: per-account isolation key, typically `SFOAuthCredentials.identifier`.
    ///   - accessToken: the access token string sent in the Authorization header.
    ///   - tokenType: `SFOAuthCredentials.tokenType` (the OAuth `token_type` returned
    ///     by the token endpoint, RFC 6749 §5.1). Matched case-insensitively per RFC 6749 §5.1 —
    ///     servers may return `"dpop"`, `"DPoP"`, or any casing variant.
    @objc(applyAuthHeaders:scope:accessToken:tokenType:error:)
    public static func applyAuthHeaders(_ request: NSMutableURLRequest,
                                        scope: String,
                                        accessToken: String?,
                                        tokenType: String?) throws {
        guard let accessToken, !accessToken.isEmpty else { return }
        if isDPoPTokenType(tokenType) {
            request.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
            try decorate(request, scope: scope, tokenType: tokenType, accessToken: accessToken)
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Convenience overload for app-built requests. Extracts `scope`, `accessToken`,
    /// and `tokenType` from `credentials`, then stamps the same headers as
    /// `applyAuthHeaders(_:scope:accessToken:tokenType:)`.
    ///
    /// Use this when you hold an `OAuthCredentials` object and want to stamp the
    /// correct `Authorization` (and, if the credential is DPoP-bound, `DPoP` proof)
    /// headers on an `NSMutableURLRequest` you constructed yourself — outside the
    /// SDK's `RestClient`.
    ///
    /// Unlike the four-argument overload (which keys the scheme off `tokenType ==
    /// "DPoP"`), this gates via `shouldAttachDPoP(scope:tokenType:)`, so a credential
    /// still in the `/authorize`→`/token` transition window (nil `tokenType` but with
    /// persisted key material) also gets a proof. Gating is per-credential, not the
    /// global `SalesforceManager.shared.usesDPoP` flag: a DPoP-bound credential carries
    /// proofs regardless of that flag.
    @objc(applyAuthHeaders:credentials:error:)
    public static func applyAuthHeaders(_ request: NSMutableURLRequest,
                                        credentials: OAuthCredentials) throws {
        guard let accessToken = credentials.accessToken, !accessToken.isEmpty else { return }
        let scope = credentials.identifier
        let tokenType = credentials.tokenType
        if shouldAttachDPoP(scope: scope, tokenType: tokenType) {
            request.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
            try decorate(request, scope: scope, tokenType: tokenType, accessToken: accessToken)
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Reads `DPoP-Nonce` from a response and stores it in the cache for the next outbound
    /// request to the same `htu`. Per RFC 9449 §8/§9, harvest from both 2xx responses
    /// (proactive rotation) and 400/401 nonce challenges (reactive). Safe to call on every
    /// response — a missing or empty header is a no-op.
    @objc(harvestNonceFromResponse:requestURL:scope:)
    public static func harvestNonce(from response: URLResponse?,
                                    requestURL: URL?,
                                    scope: String?) {
        guard let http = response as? HTTPURLResponse,
              let url = requestURL,
              let nonce = http.value(forHTTPHeaderField: dpopNonceHeaderName),
              !nonce.isEmpty else {
            return
        }
        DPoPNonceCache.shared.setNonce(nonce, htu: url, scope: scope)
    }

    /// Returns true if the response is a DPoP nonce challenge per RFC 9449 §8 — either a 401
    /// with a `DPoP-Nonce` header, or a 400 whose body contains `error=use_dpop_nonce`.
    @objc(isNonceChallengeWithStatusCode:body:response:)
    public static func isNonceChallenge(statusCode: Int,
                                        body: Data?,
                                        response: URLResponse?) -> Bool {
        guard statusCode == 400 || statusCode == 401 else { return false }
        if statusCode == 401 {
            if let http = response as? HTTPURLResponse,
               let nonce = http.value(forHTTPHeaderField: dpopNonceHeaderName),
               !nonce.isEmpty {
                return true
            }
        }
        if let body = body, let str = String(data: body, encoding: .utf8) {
            return str.contains(nonceErrorCode)
        }
        return false
    }
}
