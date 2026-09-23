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
///  - proactive `DPoP-Nonce` harvest from token-endpoint responses (Salesforce only
///    emits nonces from the token endpoint — resource-server responses don't carry
///    `DPoP-Nonce` on 2xx or on challenges).
///  - reactive 400 / 401 challenges at the token endpoint (RFC 9449 §8).
///
/// Read semantics (`nonce(htu:scope:)`, `latest(forScope:)`) are intentionally
/// non-destructive: the cache returns the most recently observed nonce and does NOT
/// invalidate it on read. Rationale:
///  - Per RFC 9449 §9, a server-issued nonce is reusable until the server rotates it.
///    Read-and-remove would force concurrent callers to race for a single nonce.
///    The non-destructive read lets every concurrent caller use the most recently
///    harvested value.
///  - Resource-server calls reuse the latest token-endpoint nonce via
///    `latest(forScope:)`. When the access token's nonce ages out, the next refresh
///    (driven by the existing 401-on-resource → refresh-on-token → retry-resource
///    path) hits the token endpoint and harvests a fresh nonce on the way back, so
///    the retried resource-server call picks up the new value.
///  - When the server rotates the nonce mid-flight, harvest from the in-flight
///    response wins over harvest from a stale response that lost the race;
///    last-writer-wins is acceptable because both values are server-issued.
@objc(SFSDKDPoPNonceCache)
public final class DPoPNonceCache: NSObject {

    @objc public static let shared = DPoPNonceCache()

    /// A scope normally contains only the token endpoint and a small set of
    /// resource origins. Keep enough headroom for multi-origin deployments while
    /// bounding process-lifetime memory when a server returns nonces for many HTUs.
    static let maximumEntriesPerScope = 32

    private let queue = DispatchQueue(label: "com.salesforce.dpop.nonceCache", attributes: .concurrent)

    // Nonces are ephemeral by spec.
    private var storage: [String: ScopeCache] = [:]

    private struct Entry {
        let nonce: String
        let sequence: UInt64
    }

    private struct WriteRecord {
        let htu: String
        let sequence: UInt64
    }

    private struct ScopeCache {
        var entries: [String: Entry] = [:]
        var latestHTU: String?
        var nextSequence: UInt64 = 0
        var writeOrder: [WriteRecord] = []
        var writeOrderHead = 0

        var latestNonce: String? {
            guard let latestHTU else { return nil }
            return entries[latestHTU]?.nonce
        }

        mutating func setNonce(_ nonce: String, htu: String) {
            nextSequence += 1
            let sequence = nextSequence
            entries[htu] = Entry(nonce: nonce, sequence: sequence)
            latestHTU = htu
            writeOrder.append(WriteRecord(htu: htu, sequence: sequence))

            evictIfNeeded()
            compactWriteOrderIfNeeded()
        }

        private mutating func evictIfNeeded() {
            while entries.count > DPoPNonceCache.maximumEntriesPerScope,
                  writeOrderHead < writeOrder.count {
                let candidate = writeOrder[writeOrderHead]
                writeOrderHead += 1

                // Rewrites leave an older record in the FIFO. Evict only when
                // this record still identifies the entry's most recent write.
                if entries[candidate.htu]?.sequence == candidate.sequence {
                    entries.removeValue(forKey: candidate.htu)
                }
            }
        }

        private mutating func compactWriteOrderIfNeeded() {
            let liveRecordCount = writeOrder.count - writeOrderHead
            guard writeOrderHead > DPoPNonceCache.maximumEntriesPerScope
                    || liveRecordCount > DPoPNonceCache.maximumEntriesPerScope * 2 else {
                return
            }

            // This bookkeeping remains bounded even if one HTU is rewritten
            // indefinitely without ever causing an eviction.
            writeOrder = entries
                .map { WriteRecord(htu: $0.key, sequence: $0.value.sequence) }
                .sorted { $0.sequence < $1.sequence }
            writeOrderHead = 0
        }
    }

    private override init() { super.init() }

    /// Returns the most recently observed nonce for `(htu, scope)`, or `nil` if none.
    /// Non-destructive — see class doc comment for rationale.
    @objc(nonceForHtu:scope:)
    public func nonce(htu: URL, scope: String?) -> String? {
        let htuKey = DPoPURL.htu(htu)
        let scopeKey = Self.scopeKey(scope)
        return queue.sync { storage[scopeKey]?.entries[htuKey]?.nonce }
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
        let scopeKey = Self.scopeKey(scope)
        return queue.sync { storage[scopeKey]?.latestNonce }
    }

    @objc(setNonce:htu:scope:)
    public func setNonce(_ nonce: String, htu: URL, scope: String?) {
        let htuKey = DPoPURL.htu(htu)
        let scopeKey = Self.scopeKey(scope)
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.storage[scopeKey, default: ScopeCache()].setNonce(nonce, htu: htuKey)
        }
    }

    @objc(clearForScope:)
    public func clear(forScope scope: String) {
        guard !scope.isEmpty else { return }

        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeValue(forKey: scope)
        }
    }

    @objc public func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }

    // MARK: - Internal

    private static func scopeKey(_ scope: String?) -> String {
        (scope?.isEmpty == false) ? scope! : "anonymous"
    }
}
