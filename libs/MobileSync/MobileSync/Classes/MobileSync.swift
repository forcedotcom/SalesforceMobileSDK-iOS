import Foundation

/*
 MobileSync.swift
 MobileSync Swift Extensions
 
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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


import Combine

/// Errors that can be thrown using MobileSync
public enum MobileSyncError: Error {
    case error(_ error: Error?)
    case unknown
}

extension SyncManager {
    
    /// Runs or reruns a sync.
    /// - Parameter named: name of sync to run
    /// - Parameter completionBlock: block invoked with Result<Bool, MobileSyncError>)
    /// Note: boolean indicates completion/failure, error is only returned if the sync could not be started (e.g. invalid name)
    public func runSync(named syncName: String, _ completionBlock: @escaping (Result<Bool, MobileSyncError>) -> Void) {
        do {
            try self.reSync(named: syncName) { (state) in
                if state.isDone() {
                    completionBlock(.success(true))
                } else if state.hasFailed() {
                    completionBlock(.success(false))
                }
            }
        } catch let error {
            completionBlock(.failure(.error(error)))
        }
    }
}

@available(iOS 13.0, watchOS 6.0, *)
extension SyncManager {
    /// Runs or reruns a sync.
    /// - Parameter named: name of sync to run
    /// - Returns: a Future<Bool, MobileSyncError> publisher.
    /// Note: boolean indicates completion/failure, error is only returned if the sync could not be started (e.g. invalid name)
    public func publisher(for syncName: String) -> Future<Bool, Error> {
        Future<Bool, Error> { promise in
            self.runSync(named: syncName) { (result) in
                switch result {
                case .success(let val):
                    promise(.success(val))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
}
