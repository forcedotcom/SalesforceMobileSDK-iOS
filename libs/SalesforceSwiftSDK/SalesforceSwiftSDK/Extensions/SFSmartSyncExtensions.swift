/*
 SFSmartSyncExtensions
 Created by Raj Rao on 01/23/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
import SmartSync
import PromiseKit

/// SFSmartSyncError representation.
///
/// - SyncDownFailed: Thrown when the sync down fails.
/// - SyncUpFailed: Thrown when the sync up fails.
/// - ReSyncFailed: Thrown when the resync fails.
/// - CleanResyncGhostsFailed: Thrown when the cleanresyncghosts fails.
enum SFSmartSyncError : Error {
    case SyncDownFailed(syncState: SFSyncState)
    case SyncUpFailed(syncState: SFSyncState)
    case ReSyncFailed(syncState: SFSyncState)
    case CleanResyncGhostsFailed
}

/** SFSmartSyncSyncManager provides sync api(s) wrapped in promises.
```
firstly {
     let syncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(soqlQuery)
     let syncOptions    = SFSyncOptions.newSyncOptions(forSyncDown: SFSyncStateMergeMode.overwrite)
     return (self.syncManager.Promises.syncDown(target: syncDownTarget, options: syncOptions, soupName: CONTACTS_SOUP))
}
.then { syncState -> Promise<UInt> in
     let querySpec =  SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
     .queryType(value: "range")
     .build()
     return (store.Promises.count(querySpec: querySpec))!
}
.then { count -> Promise<Void>  in
     return new Promise(())
}
.done { syncStateStatus in
}
.catch { error in
}
```
 */
extension SFSmartSyncSyncManager {
    
    public var Promises : SFSmartSyncSyncManagerPromises {
        return SFSmartSyncSyncManagerPromises(api: self)
    }
    
    /// SF SmartSyncSyncManager api(s) wrapped in promises.
    public class SFSmartSyncSyncManagerPromises {

        weak var api: SFSmartSyncSyncManager?

        init(api: SFSmartSyncSyncManager) {
            self.api = api
        }

        /**
         Get sync status given sync id.
         
         ```
         syncManager.Promises.getSyncStatus()
         .then { syncStatus in
         ..
         }
         ```
         - parameter syncId: Id for sync.
         - Returns: SFSyncState wrapped in a promise.
         */
        public func getSyncStatus(syncId: UInt) -> Promise<SFSyncState?> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.getSyncStatus(NSNumber(value: syncId)))
            }
        }

        /**
         Get sync status given sync name.
         
         ```
         syncManager.Promises.getSyncStatus()
         .then { syncStatus in
         ..
         }
         ```
         - parameter name: Name of sync.
         - Returns: SFSyncState wrapped in a promise.
         */
        public func getSyncStatus(name: String) -> Promise<SFSyncState?> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.getSyncStatus(byName: name))
            }
        }

        /**
         Check to see of Sync exists
         
         ```
         syncManager.Promises.hasSync(name: syncName)
         .then { result in
         ..
         }
         ```
         - parameter name: Name of sync.
         - Returns: Boolean result wrapped in a promise.
         */
        public func hasSync(name: String) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.hasSync(withName: name))
            }
        }
        
        /**
         Delete a sync
         
         ```
         syncManager.Promises.deleteSync(syncId:  id)
         .then {
         ..
         }
         ```
         - parameter name: Name of sync.
         */
        public func deleteSync(syncId: UInt) -> Promise<Void>  {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.deleteSync(byId: NSNumber(value: syncId)))
            }
        }

        /**
         Delete a sync
         
         ```
         syncManager.Promises.deleteSync(name:  name)
         .then {
         ..
         }
         ```
         - parameter name: Name of sync.
         */
        public func deleteSync(name: String) -> Promise<Void>  {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.deleteSync(byName:name))
            }
        }

        /**
         Create a sync down
         
         ```
         syncManager.Promises.createSyncDown(target: target, options: options, soupName: soupName, syncName: syncName)
         .then {
         ..
         }
         ```
         - parameters:
            - target: SFSyncDownTarget target
            - options: SFSyncOptions
             - soupName: Soup Name
             - syncName: Sync Name
         - Returns: SFSyncState wrapped in a promise.
         */
        public func createSyncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill( self.api!.createSyncDown(target, options: options, soupName: soupName, syncName: syncName))
            }
        }

        /**
         Sync Down
         
         ```
         syncManager.Promises.syncDown(target: target, soupName: soupName)
         .then {
         ..
         }
         .catch SFSmartSync.SyncDownFailed {
         
         }
         ```
         - parameters:
             - target: SFSyncDownTarget target
             - soupName: Soup Name
         - Returns: SFSmartStore wrapped in a promise.
         */
        public func syncDown(target: SFSyncDownTarget, soupName: String) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncDown(with: target, soupName: soupName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncDownFailed(syncState: syncState))
                    }
                })
            }
        }
        
        /**
         Sync Down
         
         ```
         syncManager.Promises.syncDown(target: target, options: options,soupName: soupName)
         .then {
         ..
         }
         .catch SFSmartSync.SyncDownFailed {
         
         }
         ```
         - parameters:
         - target: SFSyncDownTarget target
         - soupName: Soup Name
         - Returns: SFSmartStore wrapped in a promise.
         */
        public func syncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncDown(with: target, options: options, soupName: soupName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncDownFailed(syncState: syncState))
                    }
                })
            }
        }

        /**
         Sync Down
         
         ```
         syncManager.Promises.syncDown(target: target, options: options,soupName: soupName)
         .then {
         ..
         }
         .catch SFSmartSync.SyncDownFailed {
         
         }
         ```
         - parameters:
         - target: SFSyncDownTarget target
         - soupName: Soup Name
         - Returns: SFSmartStore wrapped in a promise.
         */
        public func syncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncDown(with: target, options: options, soupName: soupName, syncName: syncName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncDownFailed(syncState: syncState))
                    }
                })
            }
        }

        /**
         ReSync

         ```
         syncManager.Promises.reSync(syncId: syncId)
         .then { syncState in
         ..
         }
         .catch SFSmartSync.ReSyncFailed {
         
         }
         ```
         - parameters:
             - syncId: NSNumber
         - Returns: SFSyncState wrapped in a promise.
         */

        public func reSync(syncId: UInt) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.reSync(NSNumber(value: syncId), update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.ReSyncFailed(syncState: syncState))
                    }
                })
            }
        }

        /**
         ReSync

         ```
         syncManager.Promises.reSync(syncId: syncName)
         .then {
         ..
         }
         .catch SFSmartSync.ReSyncFailed {
         
         }
         ```
         - parameters:
             - syncName: Soup Name
         - Returns: SFSyncState wrapped in a promise.
         */
        public func reSync(syncName: String) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.reSync(byName: syncName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                         resolver.reject(SFSmartSyncError.ReSyncFailed(syncState: syncState))
                    }
                })
            }
        }
       
        /**
         Create a sync up without running it.
         ```
         syncManager.Promises.createSyncUp(target: target, options: options, soupName: soupName, syncName: syncName)
         .then {
         ..
         }
         ```
         - parameters:
            - target: The sync up target that will manage the sync up process.
            - options: The options associated with this sync up.
            - soupName: The soup name where the local entries are stored.
            - syncName: The name for this sync.
         - Returns: SFSyncState wrapped in a promise.
         */
        public func createSyncUp(target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.createSyncUp(target, options: options, soupName: soupName, syncName: syncName))
            }
        }
        
        /** Creates and runs a sync up with the default SFSyncUpTarget.
         ```
         syncManager.Promises.syncUp(options: options, soupName: soupName)
         .then { syncState in
         ..
         }
         .catch SFSmartSync.SyncUpFailed {
         
         }
         ```
         - parameters:
             - options: The options associated with this sync up.
             - soupName: The soup name where the local entries are stored.
         - Returns: SFSyncState wrapped in a promise.
         */
        public func syncUp(options: SFSyncOptions, soupName: String) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncUp(with: options, soupName: soupName) { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncUpFailed(syncState: syncState))
                    }
                }
            }
        }
        
        
        /**
         Creates and runs a sync up with the configured SFSyncUpTarget.
         ```
         syncManager.Promises.syncUp(target:target, options: options, soupName: soupName)
         .then { syncState in
         ..
         }
         .catch SFSmartSync.SyncUpFailed  {
         
         }
         ```
         - parameters:
             - target: The options associated with this sync up.
             - options: The options associated with this sync up.
             - soupName: The soup name where the local entries are stored.
         - Returns: The sync state associated with this sync up.
         */
        public func syncUp(target: SFSyncUpTarget, options: SFSyncOptions, soupName: String) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncUp(with: target, options: options, soupName: soupName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncUpFailed(syncState: syncState))
                    }
                })
            }
        }
        
        /** Creates and runs a named sync up.
         ```
         syncManager.Promises.syncUp(target:target, options: options, soupName: soupName,syncName: syncName)
         .then { syncState in
         ..
         }
         .catch SFSmartSync.SyncUpFailed {
         
         }
         ```
         - parameters:
             - target: The options associated with this sync up.
             - options: The options associated with this sync up.
             - soupName: The soup name where the local entries are stored.
             - syncName: The name for this sync.
        - Returns: The SFSyncState wrapped in a promise
         */
        public func syncUp(with target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                self.api!.syncUp(with: target, options: options, soupName: soupName,syncName: syncName, update: { (syncState) in
                    if syncState.status == .done  {
                        resolver.fulfill(syncState)
                    } else if syncState.status == .failed {
                        resolver.reject(SFSmartSyncError.SyncUpFailed(syncState: syncState))
                    }
                })
            }
        }
        
        /** Removes local copies of records that have been deleted on the server or do not match the query results on the server anymore.
         ```
         syncManager.Promises.cleanResyncGhosts(syncId: syncId)
         .then { syncStatus in
         ..
         }
         .catch SFSmartSync.CleanResyncGhostsFailed {
         
         }
         ```
         - parameter syncId: Sync ID.
         - Returns: The SFSyncState wrapped in a promise
         */
        public func cleanResyncGhosts(syncId: UInt) -> Promise<SFSyncStateStatus> {
            return Promise(.pending) {  resolver in
                self.api!.cleanResyncGhosts(NSNumber(value: syncId), completionStatusBlock: { (syncStatus) in
                    if syncStatus == .done  {
                        resolver.fulfill(syncStatus)
                    } else if syncStatus == .failed {
                        resolver.reject(SFSmartSyncError.CleanResyncGhostsFailed)
                    }
                })
            }
        }
    }
    
}
