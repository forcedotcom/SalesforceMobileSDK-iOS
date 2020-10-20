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
    case notStarted(_ error: Error?)
    case stopped
    case failed(_ SyncState: SyncState?)
    case unknown
}

extension SyncManager {
    
    /// Runs or reruns a sync. Does not send progress updates like reSync(named, updateBlock).
    /// - Parameter named: name of sync to run
    /// - Parameter completionBlock: block invoked when sync completes or fails with Result<SyncState, MobileSyncError>)
    public func reSyncWithoutUpdates(named syncName: String, _ completionBlock: @escaping (Result<SyncState, MobileSyncError>) -> Void) {
        do {
            try self.reSync(named: syncName) { (state) in
                switch state.status {
                    case .done: completionBlock(.success(state))
                    case .stopped: completionBlock(.failure(.stopped))
                    case .failed: completionBlock(.failure(.failed(state)))
                    default: break
                }
            }
        } catch let error {
            completionBlock(.failure(.notStarted(error)))
        }
    }
    
    /// Runs a clean ghosts for the given sync.
    /// - Parameter named: name of sync
    /// - Parameter completionBlock: block invoked when clean ghosts completes or fails with Result<UInt, MobileSyncError>)
    public func cleanGhosts(named syncName: String, _ completionBlock: @escaping (Result<UInt, MobileSyncError>) -> Void) {
        do {
            try self.cleanResyncGhosts(forName: syncName) { (status, numberRecords) in
                switch status {
                    case .done: completionBlock(.success(numberRecords))
                    case .stopped: completionBlock(.failure(.stopped))
                    case .failed: completionBlock(.failure(.failed(nil)))
                    default: break
                }
            }
        } catch let error {
            completionBlock(.failure(.notStarted(error)))
        }
    }
}

extension SyncManager {
    /// Runs or reruns a sync.
    /// - Parameter named: name of sync to run
    /// - Returns: a Future<SyncState, MobileSyncError> publisher.
    public func publisher(for syncName: String) -> Future<SyncState, MobileSyncError> {
        Future<SyncState, MobileSyncError> { promise in
            self.reSyncWithoutUpdates(named: syncName) { (result) in
                switch result {
                case .success(let state):
                    promise(.success(state))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }

    /// Runs a clean ghosts.
    /// - Parameter named: name of sync
    /// - Returns: a Future<UInt, MobileSyncError> publisher.
    public func cleanGhostsPublisher(for syncName: String) -> Future<UInt, MobileSyncError> {
        Future<UInt, MobileSyncError> { promise in
            self.cleanGhosts(named: syncName) { (result) in
                switch result {
                case .success(let numberRecords):
                    promise(.success(numberRecords))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
}
