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

    /// No-op when `SalesforceSDKManager.shared.useDPoP == NO`. Otherwise builds a fresh
    /// proof JWT (with cached nonce if any) and sets it on the `DPoP` header.
    /// `scope` is typically `SFOAuthCredentials.identifier` so the keypair and nonce cache
    /// are isolated per-account, even before an `SFUserAccount` exists.
    @objc(decorateRequest:scope:error:)
    public static func decorate(_ request: NSMutableURLRequest, scope: String) throws {
        try decorate(request, scope: scope, accessToken: nil)
    }

    /// Same as `decorate(_:scope:)` but binds the proof to the given access token via the
    /// `ath` claim (RFC 9449 §4.2). Use at resource-server call sites where the SDK already
    /// holds a token; pass `nil` (or use the no-token overload) at the token endpoint.
    @objc(decorateRequest:scope:accessToken:error:)
    public static func decorate(_ request: NSMutableURLRequest,
                                scope: String,
                                accessToken: String?) throws {
        guard SalesforceManager.shared.usesDPoP else { return }
        guard !scope.isEmpty else {
            SFSDKCoreLogger.i(self, message: "DPoP decorator skipped: empty scope identifier")
            return
        }
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
    ///     by the token endpoint, RFC 6749 §5.1). Case-sensitive equality match against
    ///     `"DPoP"` is the only positive branch.
    @objc(applyAuthHeaders:scope:accessToken:tokenType:error:)
    public static func applyAuthHeaders(_ request: NSMutableURLRequest,
                                        scope: String,
                                        accessToken: String?,
                                        tokenType: String?) throws {
        guard let accessToken, !accessToken.isEmpty else { return }
        if tokenType == dpopTokenType {
            request.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
            try decorate(request, scope: scope, accessToken: accessToken)
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
