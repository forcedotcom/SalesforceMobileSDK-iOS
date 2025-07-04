//
//  WebSocketClient.swift
//  SalesforceSDKCore
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

import Foundation

actor TokenRefreshCoordinator {
    private var isRefreshing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    func beginRefreshIfNeeded() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }
    
    func notifyRefreshCompleted() {
        isRefreshing = false
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
    
    func waitUntilRefreshed() async {
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

public final class WebSocketClient {
    private var task: WebSocketClientTaskProtocol
    private var network: WebSocketNetworkProtocol
    private var accountManager: UserAccountManaging
    private let tokenRefreshCoordinator = TokenRefreshCoordinator()
    
    deinit { task.cancel() }
    
    init(task: WebSocketClientTaskProtocol,
         network: WebSocketNetworkProtocol = Network.sharedEphemeralInstance(),
         accountManager: UserAccountManaging = UserAccountManager.shared) {
        self.task = task
        self.network = network
        self.accountManager = accountManager
    }
    
    public func send(_ message: URLSessionWebSocketTask.Message) async throws -> Void {
        do {
            try await task.send(message)
        } catch {
            if let error = await attemptTokenRefresh(error: error) {
                throw error
            } else {
                try await send(message)
            }
        }
    }
    
    public func listen(onReceive: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        task.resume()
        Task { [weak self] in
            guard let self = self else { return }
            
            var keepListening = true
            
            while keepListening {
                do {
                    
                    let message = try await task.receive()
                    onReceive(.success(message))
                } catch {
                    keepListening = false
                    if let error = await attemptTokenRefresh(error: error) {
                        onReceive(.failure(error))
                    } else {
                        listen(onReceive: onReceive)
                    }
                }
            }
        }
    }
    
    public func cancel(with closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
        task.cancel(with: closeCode, reason: reason)
    }
    
    private func attemptTokenRefresh(error: Error) async -> Error? {
        guard task.shouldRetry(),
              let originalRequest = task.originalRequest else {
            return error
        }
        
        if await tokenRefreshCoordinator.beginRefreshIfNeeded() {
            task.cancel(with: .goingAway, reason: nil)
            do {
                try await self.refreshWebSocketToken(with: originalRequest)
                await tokenRefreshCoordinator.notifyRefreshCompleted()
                return nil
            } catch {
                await tokenRefreshCoordinator.notifyRefreshCompleted()
                return error
            }
        } else {
            await tokenRefreshCoordinator.waitUntilRefreshed()
            return nil
        }
        
    }
    
    private func refreshWebSocketToken(with request: URLRequest) async throws {
        let request = try await self.prepareWebSocketRequest(request)
        task = network.webSocketTask(with: request)
        task.resume()
    }
    
    private func prepareWebSocketRequest(_ request: URLRequest) async throws -> URLRequest {
        var mutableRequest = request
        if let account = accountManager.account() {
            try await refreshCredentials(for: account)
            if let token = account.credentials.accessToken {
                mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        return mutableRequest
    }
    
    private func refreshCredentials(for account: UserAccount) async throws {
        try await withCheckedThrowingContinuation { continuation in
            _ = accountManager.refresh(credentials: account.credentials) { result in
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
