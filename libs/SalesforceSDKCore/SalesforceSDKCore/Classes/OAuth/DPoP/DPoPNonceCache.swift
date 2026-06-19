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
///  - proactive `DPoP-Nonce` response headers on 2xx responses (RFC 9449 §9 rotation).
///
/// Read semantics (`nonce(htu:scope:)`) are intentionally non-destructive: the cache
/// returns the most recently observed nonce for a given `(htu, scope)` and does NOT
/// invalidate it on read. Rationale:
///  - Per RFC 9449 §9, a server-issued nonce is reusable until the server rotates it.
///    Read-and-remove would force concurrent callers to race for a single nonce,
///    making all-but-one fall through to a `use_dpop_nonce` challenge and pay an
///    extra round-trip per concurrent call. The non-destructive read lets every
///    concurrent caller use the most recently harvested value.
///  - The server is the authority on freshness: a stale nonce simply produces a
///    `use_dpop_nonce` challenge that `DPoPRequestDecorator.sendWithNonceRetry`
///    handles transparently with one retry. With proactive harvest on every 2xx,
///    steady-state staleness is bounded to a single outbound request.
///  - When the server rotates the nonce mid-flight, harvest from the in-flight
///    response wins over harvest from the challenge response that lost the race;
///    last-writer-wins is acceptable because both values are server-issued and
///    the next request just picks up whichever landed last.
@objc(SFSDKDPoPNonceCache)
public final class DPoPNonceCache: NSObject {

    @objc public static let shared = DPoPNonceCache()

    private let queue = DispatchQueue(label: "com.salesforce.dpop.nonceCache", attributes: .concurrent)

    // Nonces are ephemeral by spec.
    private var storage: [String: String] = [:]

    private override init() { super.init() }

    /// Returns the most recently observed nonce for `(htu, scope)`, or `nil` if none.
    /// Non-destructive — see class doc comment for rationale.
    @objc(nonceForHtu:scope:)
    public func nonce(htu: URL, scope: String?) -> String? {
        let key = Self.cacheKey(htu: htu, scope: scope)
        return queue.sync { storage[key] }
    }

    /// Returns the most recently observed nonce for `scope`, regardless of `htu`.
    ///
    /// RFC 9449 §8/§9 leaves it to the authorization server to decide whether resource
    /// servers also emit `DPoP-Nonce`. Salesforce's deployment seeds the nonce only on
    /// token-endpoint responses; resource-server responses do not refresh it. Clients
    /// are expected to reuse that token-endpoint nonce on every DPoP-protected call for
    /// the lifetime of the DPoP session, and re-authenticate (which mints a fresh nonce)
    /// when the session expires or the server replies with `use_dpop_nonce`.
    ///
    /// `nonce(htu:scope:)` is the spec-correct per-resource lookup. This method is the
    /// fall-through used by `DPoPRequestDecorator` when the per-`htu` slot is empty —
    /// in practice the only populated slot for a given scope is the token endpoint, and
    /// returning it lets the proof carry the server-issued nonce on resource-server
    /// calls without an unnecessary `use_dpop_nonce` round-trip.
    @objc(latestForScope:)
    public func latest(forScope scope: String?) -> String? {
        let scopeKey = (scope?.isEmpty == false) ? scope! : "anonymous"
        let suffix = "|" + scopeKey
        return queue.sync {
            for (key, value) in storage where key.hasSuffix(suffix) {
                return value
            }
            return nil
        }
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
