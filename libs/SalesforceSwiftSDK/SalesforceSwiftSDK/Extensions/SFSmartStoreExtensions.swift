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

/// SmartStoreError types
///
/// - StoreNotFoundError: Thrown when store is not found
/// - SoupNotFoundError:  Thrown when the soup int the is not found
/// - IndicesNotFoundError: Thrown when the indices are not found
enum SmartStoreError : Error {
    case StoreNotFoundError
    case SoupNotFoundError
    case IndicesNotFoundError
}

/** Extension of SFQuerySpec with a Builder.
 
 ```
     var querySpec =  SFQuerySpec.Builder(soupName: "chickensoup")
     .queryType(value: "match")
     .path(value: "wings")
     .orderPath(value: "wings")
     .order(value: "ascending")
     .matchKey(value: "2")
     .pageSize(value: 1)
     .build()
 ```
 */
extension SFQuerySpec {
    
    /// Builder class
    public class Builder {
        var queryDict: Dictionary<String,Any> = Dictionary<String,Any>()
        let soupName: String
        
        /// create instance with soup name
        /// - Parameter soupName: Name of the soup
        public required init(soupName: String) {
            self.soupName = soupName
        }
        
        /// Set the query type
        /// - Parameter value: type of query
        /// - Returns: SFQuerySpec.Builder instance
        public func queryType(value: SFSoupQueryType) -> Self {
            queryDict[kQuerySpecParamQueryType] = SFQuerySpec.queryType(fromEnum:value)
            return self
        }
        
        /// The smart sql
        /// - Parameter value: smart sql string
        /// - Returns: SFQuerySpec.Builder instance
        public func smartSql(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = kQuerySpecTypeSmart
            queryDict[kQuerySpecParamSmartSql] = value
            return self
        }
        
        /// Page Size for the query
        /// - Parameter value:  page size
        /// - Returns: SFQuerySpec.Builder instance
        public func pageSize(value: UInt) -> Self {
             queryDict[kQuerySpecParamPageSize] = value
            return self
        }
        
        
        /// Selected Paths for the smart sql query
        /// - Parameter value: Array of selected paths
        /// - Returns: SFQuerySpec.Builder instance
        public func selectedPaths(value: [String]) -> Self {
            queryDict[kQuerySpecParamSelectPaths] = value
            return self
        }
        
        /// Path for the smart sql query
        /// - Parameter value: path
        /// - Returns: SFQuerySpec.Builder instance
        public func path(value: String) -> Self {
             queryDict[kQuerySpecParamIndexPath] = value
            return self
        }
        
        /// Begin Key for the smart sql query
        /// - Parameter value: begin Key
        /// - Returns: SFQuerySpec.Builder instance
        public func beginKey(value: String) -> Self {
            queryDict[kQuerySpecParamBeginKey] = value
            return self
        }
       
        /// End Key for the smart sql query
        /// - Parameter value: end Key
        /// - Returns: SFQuerySpec.Builder instance
        public func endKey(value: String) -> Self {
             queryDict[kQuerySpecParamEndKey] = value
            return self
        }
        
        /// Like Key for the smart sql query
        /// - Parameter value: like Key
        /// - Returns: SFQuerySpec.Builder instance
        public func likeKey(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = kQuerySpecTypeLike
            queryDict[kQuerySpecParamLikeKey] = value
            return self
        }
        
        /// Match Key for the smart sql query
        /// - Parameter value: match Key
        /// - Returns: SFQuerySpec.Builder instance
        public func matchKey(value: String) -> Self {
            queryDict[kQuerySpecParamQueryType] = kQuerySpecTypeMatch
            queryDict[kQuerySpecParamMatchKey] = value
            return self
        }
        
        /// Order Path for the smart sql query
        /// - Parameter value: order path
        /// - Returns: SFQuerySpec.Builder instance
        public func orderPath(value: String) -> Self {
             queryDict[kQuerySpecParamOrderPath] = value
            return self
        }
        
        /// Order by for the smart sql query
        /// - Parameter value: query sort order
        /// - Returns: SFQuerySpec.Builder instance
        public func order(value: SFSoupQuerySortOrder) -> Self {
            queryDict[kQuerySpecParamOrder] = SFQuerySpec.sortOrder(fromEnum: value)
            return self
        }
        
        public func build() -> SFQuerySpec {
            return SFQuerySpec(dictionary: self.queryDict,withSoupName: soupName)
        }
    }
}

/// Extension of SFSmartStore.
extension SFSmartStore {
    
    public var Promises : SFSmartStorePromises {
        return SFSmartStorePromises(api: self)
    }
    
    /// Smart Store api(s) wrapped in promises.
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
         - Returns: Array of indices wrapped in a promise.
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
         Return a count based on querySpec
         
         ```
         store.Promises.count(querySpec: spec)
         .then { (numberOfRecords) in
            ..
         }
         ```
         - parameter querySpec: SFQuerySpec query specification
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
            - querySpec: SFQuerySpec query specification
            - pageIndex: Page number for records.
         - Returns: Array wrapped in a promise with query results.
         */
        public func query(querySpec: SFQuerySpec, pageIndex: UInt)  -> Promise<[Any]> {
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
             - soupName: Name of soup.
         - Returns: Upserted entries wrapped in a promise.
         */
        public func upsertEntries(entries: [Any],soupName: String) -> Promise<[[String:Any]]> {
            return Promise(.pending) {  resolver in
                var result: [Any] = []
                result = self.api!.upsertEntries(entries, toSoup: soupName)
                resolver.fulfill(result as! [[String:Any]])
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
             - soupName: Name of soup.
             - externalIdPath: External ID Path
         - Returns: Upserted entries wrapped in a promise.
         */
        public func upsertEntries(entries: [Any], soupName: String, externalIdPath: String)  -> Promise<[[String:Any]]> {
            return Promise(.pending) {  resolver in
                 var result: [Any] = []
                 var error: NSError?
                 result = self.api!.upsertEntries(entries, toSoup: soupName, withExternalIdPath: externalIdPath, error: &error)
                if let error = error {
                    resolver.reject(error)
                } else {
                    resolver.fulfill(result as! [[String:Any]])
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
             - soupName: Name of soup.
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
         Remove entries from the soup
         
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
        Remove entries from a soup based on query spec.
         
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
         Remove all soups
         
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
/** SFSmartStoreClient provides store api(s) wrapped in promises.
 ```
 SFSmartStoreClient.store(withName: lclStoreName)
 .then { localStore -> Promise<SFSmartStore> in
    return Promise(value: localStore)
 }
 .then { store -> Promise<(Bool,SFSmartStore)>  in
     let result  = store.soupExists(soupName)
     return Promise(value:(result,store))
 }
 .then { (result,store) -> Promise<Void> in
     if (result==true) {
        .. //perform operations on store
     }
 }
 .done {
    ...
 }
 .catch { error in
    //handle Error
 }
 ```
 */
public class SFSmartStoreClient {
    
    /**
     Retrieve a store instance for a store name.
     
     ```
     SFSmartStoreClient.store(withName: storeName)
     .then { (store) in
     ..
     }
     ```
     - parameter withName: Name of Store.
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
        - withName: Name of Store.
        - user: User associated with the store.
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
     - Returns:  A Void Promise
     */
    public class func removeAllSharedStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllStores()
            resolver.fulfill(())
        }
    }
    
    /**
     Remove all global stores.
     
     ```
     SFSmartStoreClient.removeAllGlobalStores()
     .then {
     ..
     }
     ```
     - Returns:  A Void Promise
     */
    public class func removeAllGlobalStores() -> Promise<Void> {
        return Promise(.pending) { resolver in
            SFSmartStore.removeAllGlobalStores()
            resolver.fulfill(())
        }
    }
}

