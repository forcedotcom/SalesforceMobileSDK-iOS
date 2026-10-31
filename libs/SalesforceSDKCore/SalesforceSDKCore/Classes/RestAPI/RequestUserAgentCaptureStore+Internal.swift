/*
 RequestUserAgentCaptureStore+Internal.swift
 SalesforceSDKCore

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list
 of conditions and the following disclaimer.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may
 be used to endorse or promote products derived from this software without
 specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

/// AuthFlowTester-only diagnostics API. SPI permits internal cross-module use without creating a supported SDK API.
/// This value type remains available in Release so UI tests can parse capture exports built in that configuration.
@_spi(Internal) public struct RequestUserAgentCaptureEntry: Identifiable, Equatable {
    public let path: String
    public let userKey: String
    public let userAgent: String
    public let sequence: Int

    public var id: Int { sequence }

    public init(path: String, userKey: String, userAgent: String, sequence: Int) {
        self.path = path
        self.userKey = userKey
        self.userAgent = userAgent
        self.sequence = sequence
    }

    public var dictionary: [String: Any] {
        ["path": path, "userKey": userKey, "userAgent": userAgent, "seq": sequence]
    }

    public init?(dictionary: [String: Any]) {
        guard let path = dictionary["path"] as? String,
              let userKey = dictionary["userKey"] as? String,
              let userAgent = dictionary["userAgent"] as? String,
              let sequence = dictionary["seq"] as? Int else {
            return nil
        }
        self.init(path: path, userKey: userKey, userAgent: userAgent, sequence: sequence)
    }
}

#if DEBUG
/// SPI controls who can access this API; DEBUG keeps capture state and behavior out of production binaries.
@_spi(Internal) public final class RequestUserAgentCaptureStore {
    public static let defaultCapacity = 200
    // Keep in sync with kSFNetworkRequestOwnerPrefix in SFNetwork.m, which writes this task metadata.
    private static let ownerPrefix = "com.salesforce.sdk.request-owner:"

    private let queue = DispatchQueue(label: "com.salesforce.sdk.requestUserAgents")
    private let capacity: Int
    private var entries: [RequestUserAgentCaptureEntry] = []
    private var retiredKeys: Set<String> = []
    private var nextSequence = 0

    public init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public var snapshot: [RequestUserAgentCaptureEntry] { queue.sync { entries } }

    public func reset(onSnapshot: ([RequestUserAgentCaptureEntry]) -> Void) {
        queue.sync {
            entries.removeAll()
            retiredKeys.removeAll()
            nextSequence = 0
            onSnapshot(entries)
        }
    }

    public func retire(_ userKey: String, onSnapshot: ([RequestUserAgentCaptureEntry]) -> Void) {
        queue.sync {
            retiredKeys.insert(userKey)
            entries.removeAll { $0.userKey == userKey }
            onSnapshot(entries)
        }
    }

    public func login(_ userKey: String) {
        queue.sync { _ = retiredKeys.remove(userKey) }
    }

    /// Bounds diagnostics memory while leaving room for the sample app's 50-request batch.
    public func capture(url: URL, taskDescription: String?, userAgent: String, onSnapshot: ([RequestUserAgentCaptureEntry]) -> Void, onTokenRequest: ((String, String) -> Void)? = nil) -> RequestUserAgentCaptureEntry? {
        queue.sync {
            let userKey = Self.ownerKey(from: taskDescription) ?? "unknown"
            guard !retiredKeys.contains(userKey) else { return nil }
            nextSequence += 1
            let entry = RequestUserAgentCaptureEntry(path: url.path, userKey: userKey, userAgent: userAgent, sequence: nextSequence)
            entries.append(entry)
            if entries.count > capacity {
                entries.removeFirst(entries.count - capacity)
            }
            if url.path.hasSuffix("/services/oauth2/token") {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.query = nil
                onTokenRequest?(userAgent, components?.string ?? "")
            }
            onSnapshot(entries)
            return entry
        }
    }

    /// Uses the final transaction request after redirects or retries, falling back to the task's original request.
    public static func selectedRequest(transactionRequests: [URLRequest?], originalRequest: URLRequest?) -> URLRequest? {
        transactionRequests.last ?? originalRequest
    }

    public static func ownerKey(from taskDescription: String?) -> String? {
        guard let taskDescription,
              taskDescription.hasPrefix(ownerPrefix) else {
            return nil
        }
        let ownerKey = String(taskDescription.dropFirst(ownerPrefix.count))
        return ownerKey.isEmpty ? nil : ownerKey
    }
}
#endif
