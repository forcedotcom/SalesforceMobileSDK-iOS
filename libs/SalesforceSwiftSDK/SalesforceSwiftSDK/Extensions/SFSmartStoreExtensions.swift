/*
 SFSmartStoreClient
 Created by Raj Rao on 01/19/18.
 
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
import SmartStore
import PromiseKit

enum SmartStoreError : Error {
    case StoreNotFoundError
    case SoupNotFoundError
    case IndicesNotFoundError
}

extension SFSmartStore {
    
    public var Promises : SFSmartStorePromises {
        return SFSmartStorePromises(api: self)
    }
    
    public class SFSmartStorePromises {
        
        weak var api: SFSmartStore?
        
        init(api: SFSmartStore) {
            self.api = api
        }
        
        public func attributes(forSoup soupName: String) -> Promise<SFSoupSpec> {
            return Promise(.pending) {  resolver in
                let soupSpec : SFSoupSpec?  = self.api!.attributes(forSoup: soupName)
                if let spec = soupSpec {
                     resolver.fulfill(spec)
                } else {
                    resolver.reject(SmartStoreError.SoupNotFoundError)
                }
            }
        }
        
        public func indices(forSoup soupName: String) -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                let indices : [Any]?  = self.api!.indices(forSoup: soupName)
                if let indices = indices {
                    resolver.fulfill(indices)
                } else {
                    resolver.reject(SmartStoreError.IndicesNotFoundError)
                }
            }
        }
        
        public func soupExists(soupName: String) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                let result  = self.api!.soupExists(soupName)
                resolver.fulfill(result)
            }
        }
        
        public func registerSoup(soupName: String, indexSpecs: [Any]) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                do {
                   try self.api!.registerSoup(soupName, withIndexSpecs: indexSpecs, error: ())
                   resolver.fulfill(true)
                } catch let error {
                    resolver.reject(error)
                }
            }
        }
        
        public func registerSoup(soupSpec: SFSoupSpec,indexSpecs: [Any]) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                do {
                    try self.api!.registerSoup(with: soupSpec, withIndexSpecs: indexSpecs)
                    resolver.fulfill(true)
                } catch  let error {
                    resolver.reject(error)
                }
            }
        }
        
        public func count(querySpec: SFQuerySpec) -> Promise<UInt> {
            return Promise(.pending) {  resolver in
                var count: UInt = 0
                var error: NSError?
                count = self.api!.count(with: querySpec, error: &error)
                if let error = error {
                    resolver.reject(error)
                }else {
                    resolver.fulfill(count)
                }
            }
        }
        
        public func query(querySpec: SFQuerySpec, pageIndex: UInt) throws -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                var result: [Any]?
                var error: NSError?
                result = self.api!.query(with: querySpec, pageIndex: pageIndex, error: &error)
                if let error = error {
                    resolver.reject(error)
                }else {
                    if let result = result {
                        resolver.fulfill(result)
                    } else {
                         resolver.fulfill([])
                    }
                }
            }
        }
        
        public func upsertEntries(entries: [Any], toSoup soupName: String) -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                var result: [Any] = []
                result = self.api!.upsertEntries(entries, toSoup: soupName)
                resolver.fulfill(result)
            }
        }
        
        public func upsertEntries(entries: [Any], soupName: String, externalIdPath: String)  -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                 var result: [Any] = []
                 var error: NSError?
                 result = self.api!.upsertEntries(entries, toSoup: soupName, withExternalIdPath: externalIdPath, error: &error)
                if let error = error {
                    resolver.reject(error)
                } else {
                    resolver.fulfill(result)
                }
            }
        }
        
        public func lookupSoupEntryId(soupName: String, fieldPath: String, fieldValue: String) throws -> Promise<NSNumber> {
            return Promise(.pending) {  resolver in
                var result: NSNumber = -1
                var error: NSError?
                result = self.api!.lookupSoupEntryId(forSoupName: soupName, forFieldPath: fieldPath, fieldValue: fieldValue, error: &error)
                if let error = error {
                    resolver.reject(error)
                } else {
                    resolver.fulfill(result)
                }
            }
        }
        
        public func removeEntries(entryIds: [Any], soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.removeEntries(entryIds, fromSoup: soupName)
                resolver.fulfill(())
            }
        }
        
        public func removeEntries(querySpec: SFQuerySpec, soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.removeEntries(byQuery: querySpec, fromSoup: soupName)
                resolver.fulfill(())
            }
        }
        
        public func clearSoup(soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.clearSoup(soupName)
                resolver.fulfill(())
            }
        }
        
        public func removeSoup(soupName: String) -> Promise<Void>{
            return Promise(.pending) {  resolver in
                self.api!.removeSoup(soupName)
                resolver.fulfill(())
            }
        }
        
        public func removeAllSoups() -> Promise<Void>{
            return Promise(.pending) {  resolver in
                self.api!.removeAllSoups()
                resolver.fulfill(())
            }
        }
    }
    
    

}

public class SFSmartStoreClient {
    
    public class func store(withName: String) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedStore(withName : withName)
            guard let _ = smartStore else {
                return resolver.reject(SmartStoreError.StoreNotFoundError)
            }
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    public class func store(withName: String,user: SFUserAccount) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedStore(withName : withName,user: user)
            guard let _ = smartStore else {
                return resolver.reject(SmartStoreError.StoreNotFoundError)
            }
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    public class func globalStore(withName: String) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedGlobalStore(withName : withName)
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    public class func removeGlobalStore(withName: String) -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeSharedGlobalStore(withName:  withName)
            resolver.fulfill(())
        }
    }
    
    public class func removeSharedStore(withName: String) -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeSharedStore(withName:  withName)
            resolver.fulfill(())
        }
    }
    
    public class func removeAllSharedStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllStores()
            resolver.fulfill(())
        }
    }
    
    public class func removeAllGlobalStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllGlobalStores()
            resolver.fulfill(())
        }
    }
}

