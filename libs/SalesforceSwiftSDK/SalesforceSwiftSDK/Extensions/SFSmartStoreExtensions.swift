/*
 SFSmartStoreExtensions
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

extension SFQuerySpec {
    
    /**
     Builder class to build a querySpec
     
     ```
      var querySpec =  SFQuerySpec.Builder().
                                 .queryType()
                                 .smartSql()
                                 .pageSize()
                                 .soupName()
                                 .selectedPaths()
                                 ....
                                 .build()
     ```
     */
    public class Builder {
        var queryDict: Dictionary<String,Any> = [[]]
        
        public required init() {
        }
        
        public func queryType(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = value
            return self
        }
        
        public func smartSql(value: String) -> Self {
            queryDict[kQuerySpecParamSmartSql] = value
            return self
        }
        
        public func pageSize(value: UInt) -> Self {
             queryDict[kQuerySpecParamPageSize] = value
            return self
        }
        
        public func soupName(value: String) -> Self {
            queryDict[kQuerySpecParamSmartSql] = value
            return self
        }
        
        public func selectedPaths(value: [Any]) -> Self {
            queryDict[kQuerySpecParamSelectPaths] = value
            return self
        }
        
        public func path(value: String) -> Self {
             queryDict[kQuerySpecParamIndexPath] = value
            return self
        }
        
        public func beginKey(value: String) -> Self {
            queryDict[kQuerySpecParamBeginKey] = value
            return self
        }
        
        public func endKey(value: String) -> Self {
             queryDict[kQuerySpecParamEndKey] = value
            return self
        }
        
        public func likeKey(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = kQuerySpecTypeLike
            queryDict[kQuerySpecParamLikeKey] = value
            return self
        }
        
        public func matchKey(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = kQuerySpecTypeMatch
            queryDict[kQuerySpecParamMatchKey] = value
            return self
        }
        
        public func orderPath(value: String) -> Self {
             queryDict[kQuerySpecParamOrderPath] = value
            return self
        }
        
        public func order(value: SFSoupQuerySortOrder) ->Self {
            queryDict[kQuerySpecParamOrder] = value
            return self
        }
        
        public func build() -> SFSoupSpec {
          return SFQuerySpec(self.queryDict)
        }
    }
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
        
        /**
         Get attributes given soupName
         
         ```
         store.Promises.attributes(soupName)
         .then { (soupSpec) in
            ..
         }
         ```
         - parameter soupName: The Name of the soup
         - Returns: SFSoupSpec wrapped in a promise.
         */
        public func attributes(soupName: String) -> Promise<SFSoupSpec> {
            return Promise(.pending) {  resolver in
                let soupSpec : SFSoupSpec?  = self.api!.attributes(forSoup: soupName)
                if let spec = soupSpec {
                     resolver.fulfill(spec)
                } else {
                    resolver.reject(SmartStoreError.SoupNotFoundError)
                }
            }
        }
        
        /**
         Get indices given soupName
         
         ```
         store.Promises.indices(soupName)
         .then { (indices) in
         ..
         }
         ```
         - parameter soupName: The name of the soup
         - Returns: [Any] of indices wrapped in a promise.
         */
        public func indices(soupName: String) -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                let indices : [Any]?  = self.api!.indices(forSoup: soupName)
                if let indices = indices {
                    resolver.fulfill(indices)
                } else {
                    resolver.reject(SmartStoreError.IndicesNotFoundError)
                }
            }
        }
        
        /**
        Check if a soup exists
         
         ```
         store.Promises.soupExists(soupName)
         .then { (result) in
            ..
         }
         ```
         - parameter soupName: The name of the soup
         - Returns: Boolean wrapped in a promise indicating existence of soup.
         */
        public func soupExists(soupName: String) -> Promise<Bool> {
            return Promise(.pending) {  resolver in
                let result  = self.api!.soupExists(soupName)
                resolver.fulfill(result)
            }
        }
        
        /**
         Create a soup
         
         ```
         store.Promises.registerSoup(soupName,indexSpecs: specs)
         .then { (result) in
         ..
         }
         ```
         - parameters:
            - soupName: The name of the soup
            - indexSpecs: Array of Index specs
         - Returns: Boolean wrapped in a promise indicating success.
         */
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
        
        /**
         Create a soup
         
         ```
         store.Promises.registerSoup(soupName,indexSpecs: specs)
         .then { (result) in
         ..
         }
         ```
         - parameters:
             - soupSpec: SFSoupSpec Specification of the Soup
             - indexSpecs: Array of Index specs
         - Returns: Boolean wrapped in a promise indicating success.
         */
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
        
        /**
         Create a soup
         
         ```
         store.Promises.count(querySpec: spec)
         .then { (numberOfRecords) in
            ..
         }
         ```
         - parameter soupSpec: SFSoupSpec Specification of the Soup
         - Returns: Integer wrapped in a promise indicating count.
         */
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
        
        /**
         Perform a Query
         
         ```
         store.Promises.query(querySpec: spec,pageIndex: 0)
         .then { (results) in
            ..
         }
         ```
         - parameters:
            - querySpec: SFSoupSpec Specification of the Soup
            - pageIndex: Page number for records.
         - Returns: Integer wrapped in a promise indicating count.
         */
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
        
        /**
         Update or insert entries into the soup.
         
         ```
         store.Promises.upsertEntries(entries: entries,soupName: soupName)
         .then { (results) in
         ..
         }
         ```
         - parameters:
             - entries: Entries to upsert in the soup
             - soupName: Nameof Soup.
         - Returns: Upserted entries wrapped in a promise.
         */
        public func upsertEntries(entries: [Any],soupName: String) -> Promise<[Any]> {
            return Promise(.pending) {  resolver in
                var result: [Any] = []
                result = self.api!.upsertEntries(entries, toSoup: soupName)
                resolver.fulfill(result)
            }
        }
        
        /**
         Update or insert entries into the soup.
         
         ```
         store.Promises.upsertEntries(entries: entries,soupName: soupName,externalIdPath: externalIdPath)
         .then { (results) in
         ..
         }
         ```
         - parameters:
             - entries: Entries to upsert in the soup
             - soupName: Nameof Soup.
             - externalIdPath: External ID Path
         - Returns: Upserted entries wrapped in a promise.
         */
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
        
        /**
         Lookup the soup entry Id
         
         ```
         store.Promises.lookupSoupEntryId(soupName: soupName, fieldPath: path, fieldValue: fieldValue)
         .then { (entryId) in
         ..
         }
         ```
         - parameters:
             - entries: Entries to upsert in the soup
             - soupName: Nameof Soup.
             - fieldPath: Field Path
             - fieldValue: Value for the field.
         - Returns: EntryId wrapped in promise
         */
        public func lookupSoupEntryId(soupName: String, fieldPath: String, fieldValue: String) -> Promise<NSNumber> {
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
        
        /**
         Lookup the soup entry Id
         
         ```
         store.Promises.removeEntries(entryIds: entries, soupName: soupName)
         .then {
         ..
         }
         ```
         - parameters:
             - entryIds: Entries to upsert in the soup
             - soupName: Name of soup.
         */
        public func removeEntries(entryIds: [Any], soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.removeEntries(entryIds, fromSoup: soupName)
                resolver.fulfill(())
            }
        }
        
        /**
         Lookup the soup entry Id
         
         ```
         store.Promises.removeEntries(querySpec: querySpec, soupName: soupName)
         .then {
         ..
         }
         ```
         - parameters:
             - querySpec: SFQuerySoupSpec for the soup
             - soupName: Name of soup.
         */
        public func removeEntries(querySpec: SFQuerySpec, soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.removeEntries(byQuery: querySpec, fromSoup: soupName)
                resolver.fulfill(())
            }
        }
        
        /**
         Clear a soup
         
         ```
         store.Promises.clearSoup(soupName: soupName)
         .then {
         ..
         }
         ```
         - parameters:
         - querySpec: SFQuerySoupSpec for the soup
         - soupName: Name of soup.
         */
        public func clearSoup(soupName: String) -> Promise<Void> {
            return Promise(.pending) {  resolver in
                self.api!.clearSoup(soupName)
                resolver.fulfill(())
            }
        }
        
        /**
         Remove a soup
         
         ```
         store.Promises.removeSoup(soupName: soupName)
         .then {
         ..
         }
         ```
         - parameters soupName: Name of soup.
         */
        public func removeSoup(soupName: String) -> Promise<Void>{
            return Promise(.pending) {  resolver in
                self.api!.removeSoup(soupName)
                resolver.fulfill(())
            }
        }
        
        /**
         Remove a soup
         
         ```
         store.Promises.removeAllSoups()
         .then {
         ..
         }
         ```
         - parameters soupName: Name of soup.
         */
        public func removeAllSoups() -> Promise<Void>{
            return Promise(.pending) {  resolver in
                self.api!.removeAllSoups()
                resolver.fulfill(())
            }
        }
    }
 
}

public class SFSmartStoreClient {
    
    /**
     Retrieve a store instance for a store name.
     
     ```
     SFSmartStoreClient.store(withName: storeName)
     .then { (store) in
     ..
     }
     ```
     - parameter storeName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    
    public class func store(withName: String) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedStore(withName : withName)
            guard let _ = smartStore else {
                return resolver.reject(SmartStoreError.StoreNotFoundError)
            }
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    /**
     Retrieve a store instance for a store name.
     
     ```
     SFSmartStoreClient.store(withName: storeName, user: user)
     .then { (store) in
     ..
     }
     ```
     - parameters:
        -storeName: Name of Store.
        -user: User associated with the store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func store(withName: String,user: SFUserAccount) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedStore(withName : withName,user: user)
            guard let _ = smartStore else {
                return resolver.reject(SmartStoreError.StoreNotFoundError)
            }
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    /**
     Retrieve a global store instance for a store name.
     
     ```
     SFSmartStoreClient.globalStore(withName: storeName)
     .then { (store) in
     ..
     }
     ```
     - parameter withName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func globalStore(withName: String) -> Promise<SFSmartStore> {
        return Promise(.pending) { resolver in
            let smartStore = SFSmartStore.sharedGlobalStore(withName : withName)
            resolver.fulfill(smartStore as! SFSmartStore)
        }
    }
    
    /**
     Remove a global store instance for a store name.
     
     ```
     SFSmartStoreClient.removeGlobalStore(withName: storeName)
     .then { (store) in
     ..
     }
     ```
     - parameter withName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func removeGlobalStore(withName: String) -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeSharedGlobalStore(withName:  withName)
            resolver.fulfill(())
        }
    }
    
    /**
     Remove a shared store instance for a store name.
     
     ```
     SFSmartStoreClient.removeSharedStore(withName: storeName)
     .then { (store) in
     ..
     }
     ```
     - parameter withName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func removeSharedStore(withName: String) -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeSharedStore(withName:  withName)
            resolver.fulfill(())
        }
    }
    
    /**
     Remove all shared store instances for current user.
     
     ```
     SFSmartStoreClient.removeAllSharedStores()
     .then { 
     ..
     }
     ```
     - parameter withName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func removeAllSharedStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllStores()
            resolver.fulfill(())
        }
    }
    
    /**
     Remove all shared store instances for current user.
     
     ```
     SFSmartStoreClient.removeAllGlobalStores()
     .then {
     ..
     }
     ```
     - parameter withName: Name of Store.
     - Returns: SFSmartStore wrapped in a promise.
     */
    public class func removeAllGlobalStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllGlobalStores()
            resolver.fulfill(())
        }
    }
}

