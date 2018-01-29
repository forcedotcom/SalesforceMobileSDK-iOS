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

extension SFSmartSyncSyncManager {
    
    public var Promises : SFSmartSyncSyncManagerPromises {
        return SFSmartStorePromises(api: self)
    }
    
    public class SFSmartSyncSyncManagerPromises {

        weak var api: SFSmartSyncSyncManager?

        init(api: SFSmartSyncManager) {
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
        func getSyncStatus(syncId: NSNumber) -> Promise<SFSyncState?> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.getSyncStatus(syncId))
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
        func getSyncStatus(name: String) -> Promise<SFSyncState?> {
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
        func hasSync(name: String) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.hasSync(withName: name))
            }
        }
        
        /**
         Delete a sync
         
         ```
         syncManager.Promises.deleteSync(id:  id)
         .then {
         ..
         }
         ```
         - parameter name: Name of sync.
         */
        func deleteSync(id: NSNumber) -> Promise<Void>  {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.deleteSync(byId: id))
            }
        }

        /**
         Delete a sync
         
         ```
         syncManager.Promises.deleteSync(id:  id)
         .then {
         ..
         }
         ```
         - parameter name: Name of sync.
         */
        func deleteSync(name: String) -> Promise<Void>  {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.deleteSync(byName:name))
            }
        }

        /**
         Delete a sync
         
         ```
         syncManager.Promises.createSyncDown(target: target, options: options, soupName: soupName, syncName: syncName)
         .then {
         ..
         }
         ```
         - parameters
            - target: SFSyncDownTarget target
            - options: SFSyncOptions
             - soupName: Soup Name
             - syncName: Sync Name
         - Returns: SFSyncState wrapped in a promise.
         */
        func createSyncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill( self.api!.createSyncDown(target, options: options, soupName: soupName, syncName: syncName)
            }
        }

        /**
         Sync Down
         
         ```
         syncManager.Promises.deleteSync(id:  id)
         .then {
         ..
         }
         ```
         - parameters
             - target: SFSyncDownTarget target
             - soupName: Soup Name
             - updateBlock: Block to invoke
         - Returns: SFSmartStore wrapped in a promise.
         */
        func syncDown(target: SFSyncDownTarget, soupName: String, updateBlock: SFSyncSyncManagerUpdateBlock) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.syncDown(with: target, soupName: soupName, update: updateBlock))
            }
        }
        
        /**
         Sync Down
         
         ```
         syncManager.Promises.deleteSync(id:  id)
         .then {
         ..
         }
         ```
         - parameters
             - target: SFSyncDownTarget target
             - options: SFSyncOptions
             - soupName: Soup Name
             - updateBlock: Block to invoke
         - Returns: SFSmartStore wrapped in a promise.
         */
        func syncDown(with target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, updateBlock: SFSyncSyncManagerUpdateBlock) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.syncDown(with: target,options: options, soupName: soupName, update: updateBlock))
            }
        }

        /**
         Sync Down
         
         ```
         syncManager.Promises.deleteSync(id:  id)
         .then {
         ..
         }
         ```
         - parameters
         - target: SFSyncDownTarget target
         - options: SFSyncOptions
         - soupName: Soup Name
         - updateBlock: Block to invoke
         - Returns: SFSmartStore wrapped in a promise.
         */
        func syncDown(with target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?, updateBlock: SFSyncSyncManagerUpdateBlock) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.syncDown(with: target,options: options, soupName: soupName,syncName: syncName, update: updateBlock))
            }
        }
        
        /**
         ReSync
         
         ```
         syncManager.Promises.reSync(syncId: syncId, updateBlock: {})
         .then {
         ..
         }
         ```
         - parameters
         - syncId: NSNumber
         - updateBlock: Block to invoke
         - Returns: SFSyncState wrapped in a promise.
         */

        func reSync(syncId: NSNumber, updateBlock: SFSyncSyncManagerUpdateBlock) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.reSync(syncId, update: updateBlock)))
            }
        }

        /**
         ReSync
         
         ```
         syncManager.Promises.reSync(syncId: syncId, updateBlock: {})
         .then {
         ..
         }
         ```
         - parameters
             - syncName: Soup Name
             - updateBlock: Block to invoke
         - Returns: SFSyncState wrapped in a promise.
         */
        func reSync(syncName: String, updateBlock: SFSyncSyncManagerUpdateBlock) -> Promise<SFSyncState> {
            return Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.reSync(syncName, update: updateBlock)))
            }
        }
    }
    
}
