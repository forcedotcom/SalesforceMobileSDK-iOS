//
//  NativeLoginDiagnostics.swift
//  AuthFlowTester
//
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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
//

import Foundation
import os
import SalesforceSDKCore

/// Redacted, structured record of the Native Login network stages (`authorize`, `token`, `identity`).
///
/// Fed by `Network.metricsCollectedAction`, so it sees only URLs, status codes and header presence:
/// never a nonce, proof, code, verifier, token or password. `NativeLoginResult` carries no HTTP
/// status, so this is how a rejection (e.g. HTTP 400 on `/authorize`) is observable to the app.
final class NativeLoginDiagnostics: ObservableObject {
    static let shared = NativeLoginDiagnostics()

    private static let maxLines = 20
    private let logger = Logger(subsystem: "com.salesforce.AuthFlowTester", category: "native-login")
    private var nonceChallenges = 0
    private var retries = 0
    private var previousStage: String?
    private var challengePending = false

    @Published private(set) var lines: [String] = []

    var text: String { lines.isEmpty ? "(none)" : lines.joined(separator: "\n") }

    /// Starts recording. Wraps any metrics handler already installed (e.g. the user-agent capture).
    func install() {
        let previous = Network.metricsCollectedAction
        Network.metricsCollectedAction = { [weak self] session, task, metrics in
            previous?(session, task, metrics)
            self?.record(task: task)
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.lines = []
            self.nonceChallenges = 0
            self.retries = 0
            self.previousStage = nil
            self.challengePending = false
        }
    }

    private func record(task: URLSessionTask) {
        guard let request = task.originalRequest, let url = request.url else { return }
        let stage: String
        if url.path.hasSuffix("/services/oauth2/authorize") {
            stage = "authorize"
        } else if url.path.hasSuffix("/services/oauth2/token") {
            stage = "token"
        } else if url.path.hasSuffix("/id") || url.path.contains("/id/") {
            stage = "identity"
        } else {
            stage = "other(\(url.lastPathComponent))"
        }
        let response = task.response as? HTTPURLResponse
        let status = response?.statusCode ?? -1
        let hasProof = request.value(forHTTPHeaderField: "DPoP") != nil
        let nonceInResponse = response?.value(forHTTPHeaderField: "DPoP-Nonce") != nil
        DispatchQueue.main.async {
            // A repeat of the same stage right after a nonce-bearing 400/401 is a nonce retry.
            if self.previousStage == stage, self.challengePending {
                self.retries += 1
            }
            self.challengePending = nonceInResponse && (status == 400 || status == 401)
            if self.challengePending { self.nonceChallenges += 1 }
            self.previousStage = stage
            let line = "\(stage) dpop=\(hasProof) nonceInResponse=\(nonceInResponse) nonceChallenges=\(self.nonceChallenges) retries=\(self.retries) status=\(status)"
            self.logger.info("\(line, privacy: .public)")
            self.lines.append(line)
            if self.lines.count > Self.maxLines { self.lines.removeFirst(self.lines.count - Self.maxLines) }
        }
    }
}
