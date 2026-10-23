/*
 NativeLoginDiagnostics.swift
 SalesforceSDKCore

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

/// One Native Login network attempt, redacted: no nonce, proof, code, verifier, token or password.
struct NativeLoginDiagnosticEvent: Equatable {
    /// `authorize` or `token`.
    let stage: String
    /// HTTP status, or nil when no response arrived.
    let status: Int?
    /// OAuth `error` code of a failure response.
    let error: String?
    /// OAuth `error_description` of a failure response, truncated.
    let errorDescription: String?
    /// True when the request carried a DPoP proof.
    let dpop: Bool
    /// True when the response carried a `DPoP-Nonce` header (the value is never kept).
    let nonce: Bool
    /// 0 for the first attempt, 1 for the retry after a nonce challenge.
    let retry: Int

    /// `stage=<s> status=<n> [error=<code>] dpop=<b> nonce=<b> retry=<i> [description="..."]`
    var summary: String {
        var parts = ["stage=\(stage)", "status=\(status.map(String.init) ?? "none")"]
        if let error { parts.append("error=\(error)") }
        parts.append(contentsOf: ["dpop=\(dpop)", "nonce=\(nonce)", "retry=\(retry)"])
        if let errorDescription { parts.append("description=\"\(errorDescription)\"") }
        return parts.joined(separator: " ")
    }

    /// `HTTP <status> <error>: <description>` for a failed attempt, nil for a successful one.
    var failure: String? {
        guard error != nil || (status ?? 0) >= 400 || status == nil else { return nil }
        var text = "HTTP \(status.map(String.init) ?? "none")"
        if let error { text += " \(error)" }
        if let errorDescription { text += ": \(errorDescription)" }
        return text
    }
}

/// Records Native Login network attempts for the SDK's debug Native Login form and the
/// SDK log (debug level). Records only when developer support is enabled.
final class NativeLoginDiagnostics {
    static let shared = NativeLoginDiagnostics()

    static let maxDescriptionLength = 200

    private let lock = NSLock()
    private var recorded: [NativeLoginDiagnosticEvent] = []
    private let isEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool = { SalesforceManager.shared.isDevSupportEnabled }) {
        self.isEnabled = isEnabled
    }

    var events: [NativeLoginDiagnosticEvent] {
        lock.withLock { recorded }
    }

    /// The events, one summary per line.
    var summary: String {
        events.map(\.summary).joined(separator: "\n")
    }

    /// The last failed attempt, as `HTTP <status> <error>: <description>`.
    var lastFailure: String? {
        events.last(where: { $0.failure != nil })?.failure
    }

    func reset() {
        lock.withLock { recorded.removeAll() }
    }

    func record(_ event: NativeLoginDiagnosticEvent) {
        guard isEnabled() else { return }
        lock.withLock { recorded.append(event) }
        SFSDKCoreLogger().d(NativeLoginDiagnostics.self, message: "Native Login: \(event.summary)")
    }

    /// Records an attempt from the request path, the DPoP header choice and the response.
    func record(path: String, dpop: Bool, retry: Int, urlResponse: URLResponse?, body: Any?) {
        let http = urlResponse as? HTTPURLResponse
        let status = http?.statusCode
        var error: String?
        var description: String?
        if let status, status >= 400, let data = body as? Data,
           let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            error = payload["error"] as? String
            description = (payload["error_description"] as? String).map { String($0.prefix(Self.maxDescriptionLength)) }
        }
        let nonce = http?.value(forHTTPHeaderField: DPoPRequestDecorator.dpopNonceHeaderName)?.isEmpty == false
        record(NativeLoginDiagnosticEvent(stage: Self.stage(forPath: path), status: status, error: error,
                                          errorDescription: description, dpop: dpop, nonce: nonce, retry: retry))
    }

    static func stage(forPath path: String) -> String {
        if path.hasSuffix(kSFOAuthEndPointAuthorize) { return "authorize" }
        if path.hasSuffix(kSFOAuthEndPointToken) { return "token" }
        return "other"
    }
}
