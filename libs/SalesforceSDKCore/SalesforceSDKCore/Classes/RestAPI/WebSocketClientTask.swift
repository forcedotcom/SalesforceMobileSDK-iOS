//
//  WebSocketClientTask.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 6/5/25.
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

import Foundation

enum WebSocketAuthError: Error {
    case tokenExpired
    case unrecoverable(Error)
}

func isAuthError(_ error: Error) -> Bool {
    let nsError = error as NSError
    return (
        nsError.localizedDescription.contains("403") ||
        nsError.localizedDescription.contains("Bad_OAuth_Token") ||
        nsError.localizedDescription.contains("401")
    )
}

public final class WebSocketClientTask {
    private var task: URLSessionWebSocketTask
    
    private var shouldRetry = true

    deinit { task.cancel() }
    
    init(task: URLSessionWebSocketTask) {
        self.task = task
    }
    
    public func send(_ message: URLSessionWebSocketTask.Message, completion: ((Error?) -> Void)? = nil) {
        task.send(message) { error in
            completion?(error)
        }
    }
    
    public func listen(onReceive: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        task.receive { [self] result in
            switch result {
                
            case .failure(let error):
                if shouldRetry(for: error) {
                    guard let originalRequest = self.task.originalRequest else {
                        onReceive(.failure(error))
                        return
                    }
                    self.task.cancel(with: .goingAway, reason: nil)
                    shouldRetry = false // Only want to retry once
                    Task {
                        do {
                            try await self.refreshWebSocketToken(with: originalRequest)
                            self.listen(onReceive: onReceive)
                        } catch {
                            onReceive(.failure(error))
                        }
                    }
                } else {
                    onReceive(.failure(error))
                }
                
            case .success(_):
                onReceive(result)
                self.listen(onReceive: onReceive)
            }
        }
        task.resume()
    }

    public func cancel(with closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
        task.cancel(with: closeCode, reason: reason)
    }
    
    private func shouldRetry(for error: Error) -> Bool {
        return shouldRetry && isAuthError(error)
    }
    
    private func refreshWebSocketToken(with request: URLRequest) async throws {
        let request = try await self.prepareWebSocketRequest(request)
        let network = Network.sharedEphemeralInstance()
        task = network.activeSession.webSocketTask(with: request)
    }
    
    private func prepareWebSocketRequest(_ request: URLRequest) async throws -> URLRequest {
        var mutableRequest = request
        if let account = UserAccountManager.shared.currentUserAccount {
            try await refreshCredentials(for: account)
            if let token = account.credentials.accessToken {
                mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        return mutableRequest
    }
    
    private func refreshCredentials(for account: UserAccount) async throws {
        try await withCheckedThrowingContinuation { continuation in
            _ = UserAccountManager.shared.refresh(credentials: account.credentials) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
