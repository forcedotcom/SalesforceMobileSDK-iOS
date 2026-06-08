//
//  SFSDKDPoPNonceCache.swift
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

/// Process-lifetime cache of `DPoP-Nonce` values, keyed by `(htu, scope)`.
/// `scope` is typically `SFOAuthCredentials.identifier`. Fed by:
///  - reactive 400 / 401 challenges (RFC 9449 §8)
///  - proactive `DPoP-Nonce` response headers on 200 OK (Salesforce backend rotation).
///
/// Read semantics (`nonce(htu:scope:)`) are intentionally non-destructive: the cache
/// returns the most recently observed nonce for a given `(htu, scope)` and does NOT
/// invalidate it on read. Rationale:
///  - The Salesforce backend rotates the nonce on every response, so a successful
///    request's response brings the next nonce via `harvestNonce(...)` — staleness
///    is bounded to "exactly one outbound request" in the steady state.
///  - The server is the authority on freshness: a stale nonce produces a
///    `use_dpop_nonce` challenge that the caller already retries once.
///  - Read-and-remove would force concurrent callers to race for a single nonce,
///    causing all-but-one to fall back to the unauthenticated path and incur an
///    extra round-trip per concurrent call.
///
/// This PR uses the cache only at the token endpoint, where requests are serial,
/// so the read-doesn't-remove choice has no observable effect today. The model
/// will be revisited when DPoP is extended to API calls in a later phase: with
/// concurrent REST calls, the right policy might be "one-use-per-write" or
/// "serialize on rotation."
@objc(SFSDKDPoPNonceCache)
public final class DPoPNonceCache: NSObject {

    @objc public static let shared = DPoPNonceCache()

    private let queue = DispatchQueue(label: "com.salesforce.dpop.nonceCache", attributes: .concurrent)

    // Nonces are ephemeral by spec.
    private var storage: [String: String] = [:]

    private override init() { super.init() }

    /// Returns the most recently observed nonce for `(htu, scope)`, or `nil` if none.
    /// Non-destructive — see class doc comment for rationale.
    // TODO: Revisit read semantics when DPoP extends to API calls. Concurrent REST callers may
    // need one-use-per-write or serialize-on-rotation to avoid all-but-one hitting use_dpop_nonce.
    @objc(nonceForHtu:scope:)
    public func nonce(htu: URL, scope: String?) -> String? {
        let key = Self.cacheKey(htu: htu, scope: scope)
        return queue.sync { storage[key] }
    }

    @objc(setNonce:htu:scope:)
    public func setNonce(_ nonce: String, htu: URL, scope: String?) {
        let key = Self.cacheKey(htu: htu, scope: scope)
        queue.async(flags: .barrier) { [weak self] in
            self?.storage[key] = nonce
        }
    }

    @objc(clearForScope:)
    public func clear(forScope scope: String) {
        guard !scope.isEmpty else { return }
        
        // The cache stores entries keyed by (htu, scope) — token-endpoint URL + which credentials
        // it belongs to. To make a single dictionary work, those two strings get joined into one composite key:
        //
        // cacheKey = "<canonicalized htu>|<scope>"
        // e.g.       "https://login.salesforce.com/services/oauth2/token|005xx0000012Q9P"
        let suffix = "|" + scope
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.storage = self.storage.filter { !$0.key.hasSuffix(suffix) }
        }
    }

    @objc public func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }

    // MARK: - Internal

    private static func cacheKey(htu: URL, scope: String?) -> String {
        let canonical = DPoPURL.htu(htu)
        let scopeKey = (scope?.isEmpty == false) ? scope! : "anonymous"
        return "\(canonical)|\(scopeKey)"
    }
}
