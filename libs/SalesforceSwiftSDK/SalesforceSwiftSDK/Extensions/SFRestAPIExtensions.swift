/*
 SFRestAPIExtensions
 Created by Raj Rao on 11/27/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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
import PromiseKit
import SalesforceSDKCore

public struct SFRestResponse {
    
    private (set) var data : Data?
    private (set) var urlResponse : URLResponse?
    
    init(data: Data?,response: URLResponse?) {
        self.data = data
        self.urlResponse = response
    }
    
    public func asJsonDictionary() -> [String: Any] {
        guard let rawData = data,data!.count > 0 else {
            return [String:Any]()
        }
        let jsonData = try! JSONSerialization.jsonObject(with: rawData, options: []) as! Dictionary<String, Any>
        return jsonData
    }
    
    public func asJsonArray() -> [[String: Any]] {
        guard let rawData = data,data!.count > 0 else {
            return [[String: Any]]()
        }
        let jsonData = try! JSONSerialization.jsonObject(with: rawData, options: []) as! [Dictionary<String, Any>]
        return jsonData
    }
    
    public func asData() -> Data? {
       return self.data
    }
    
    public func asString() -> String {
        guard let rawData = data,data!.count > 0 else {
            return ""
        }
        let jsonData = String(data: rawData, encoding: String.Encoding.utf8)
        return jsonData!
    }
    
    public func asDecodable<T:Decodable>(type: T.Type) -> Decodable? {
        guard let rawData = data,data!.count > 0 else {
            return nil
        }
        let decoder = JSONDecoder()
        return try! decoder.decode(type, from: rawData)
    }
}

extension SFRestAPI {
    
    public var Promises : SFRestAPIPromises {
        return SFRestAPIPromises(api: self)
    }
    
    public class SFRestAPIPromises {
        
        weak var api: SFRestAPI?
        
        init(api: SFRestAPI) {
            self.api = api
        }
        
        /**
         A factory method for versions().
         ```
         restApi.Promises.versions()
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func versions() -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForVersions())
            }
        }
        
        /**
         A factory method for resources().
         ```
         restApi.Promises.resources()
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func resources() -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForResources())
            }
        }
        
        /**
         A factory method for describe object request.
         ```
         restApi.Promises.describe()
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func describe(objectType:String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForDescribe(withObjectType: objectType))
            }
        }
        
        /**
         A factory method for describe global request.
         ```
         restApi.Promises.describeGlobal()
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func describeGlobal() -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForDescribeGlobal())
            }
        }
        
        /**
         A factory method for metadata object request.
         ```
         restApi.Promises.metadata(objectType)
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func metadata(objectType: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForMetadata(withObjectType: objectType))
            }
        }
        
        /**
         A factory method for retrieve object request.
         ```
         restApi.Promises.retrieve(objectType: objectType,objectId: objectId, fieldList: "Name","LastModifiedDate")
         .then { (request) in
             restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func retrieve(objectType: String,objectId: String, fieldList: String... ) -> Promise<SFRestRequest> {
            return  self.retrieve(objectType: objectType, objectId: objectId, fieldList: fieldList)
        }
        
        public func retrieve(objectType: String,objectId: String, fieldList: [String] ) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForRetrieve(withObjectType: objectType, objectId: objectId, fieldList: fieldList.joined(separator: ",")))
            }
        }
        
        /**
         A factory method for create object request.
         ```
         restApi.Promises.create(objectType: objectType, fieldList: ["Name": "salesforce.com", "TickerSymbol": "CRM"])
         .then { (request) in
            restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func create(objectType: String, fields: [String:String]) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!
                    .requestForCreate(withObjectType: objectType, fields: fields))
            }
        }
        
        /**
         A factory method for upsert object request.
         ```
         restApi.Promises.upsert(objectType: objectType,externalIdField:"",externalId: "1000", fieldList: {Name: "salesforce.com", TickerSymbol: "CRM"})
         .then { (request) in
            restApi.send(request)
         }
         
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func upsert(objectType: String,externalIdField: String, externalId: String, fieldList: Dictionary<String,String>?) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!
                    .requestForUpsert(withObjectType: objectType, externalIdField: externalId, externalId: externalId, fields: fieldList!))
            }
        }
        
        /**
         A factory method for update object request.
         ```
         restApi.Promises.update(objectType: objectId: "1000", fieldList: fieldList,ifUnmodifiedSince:sinceDate)
         .then { (request) in
            restApi.send(request)
         }
         
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func update(objectType: String,objectId: String,fieldList: [String: Any]?,ifUnmodifiedSince: Date?) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForUpdate(withObjectType: objectType, objectId: objectId, fields: fieldList, ifUnmodifiedSince: ifUnmodifiedSince))
            }
        }
        
        /**
         A factory method for delete object request.
         ```
         restApi.Promises.delete(objectType: objectType, objectId: objectId)
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func delete(objectType: String, objectId: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForDelete(withObjectType: objectType, objectId: objectId))
            }
        }
        
        /**
         A factory method for query object request.
         ```
         restApi.Promises.query(soql: soql)
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func query(soql: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.request(forQuery: soql))
            }
        }
        
        /**
         A factory method for queryAll object request.
         ```
         restApi.Promises.queryAll(soql: soql)
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func queryAll(soql: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.request(forQueryAll: soql))
            }
        }
        
        /**
         A factory method for sosl object request.
         ```
          restApi.Promises.search(sosl: sosl)
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func search(sosl: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.request(forSearch: sosl))
            }
        }
        
        /**
         A factory method for Search Scope And Order request.
         ```
         restApi.Promises.searchScopeAndOrder()
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func searchScopeAndOrder() -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForSearchScopeAndOrder())
            }
        }
        
        /**
         A factory method for Search Result Layout request.
         ```
         restApi.Promises.searchResultLayout(objectList: "Account","Contact")
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func searchResultLayout(objectList: String...) -> Promise<SFRestRequest> {
            return self.searchResultLayout(objectList: objectList)
        }
        
        /**
         A factory method for Search Result Layout request.
         ```
         restApi.Promises.searchResultLayout(objectList: ["Account","Contact"])
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func searchResultLayout(objectList: [String]) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forSearchResultLayout: objectList.joined(separator: ",")))
            }
        }
        
        /**
         A factory method for Batch request.
         ```
         restApi.Promises.batch(requests: request1,request2, haltOnError: Bool = false)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func batch(requests: SFRestRequest..., haltOnError: Bool = false) -> Promise<SFRestRequest> {
            return self.batch(requests: requests,haltOnError: haltOnError)
        }
        
        /**
         A factory method for Batch request.
         ```
         restApi.Promises.batch(requests: [request1,request2], haltOnError: true )
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func batch(requests: [SFRestRequest], haltOnError: Bool) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.batchRequest(requests, haltOnError: haltOnError))
            }
        }
        
        /**
         A factory method for a Composite request.
         ```
         restApi.Promises.composite(requests: [request1,request2],  refIds:["id1","id2], allOrNone: Bool)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func composite(requests: [SFRestRequest], refIds: [String], allOrNone: Bool) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.compositeRequest(requests, refIds: refIds, allOrNone: allOrNone) )
            }
        }
        
        /**
         A factory method for a SObjectTree request.
         ```
         restApi.sObjectTree(requests: "Account", objectTrees: sObjectTree1,sObjectTree2)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        func sObjectTree(objectType: String, objectTrees: SFSObjectTree...) -> Promise<SFRestRequest> {
            return self.sObjectTree(objectType: objectType, objectTrees: objectTrees)
        }
        
        /**
         A factory method for SObjectTree request.
         ```
         restApi.sObjectTree(requests: "Account", objectTrees: [sObjectTree1,sObjectTree2])
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        func sObjectTree(objectType: String, objectTrees: [SFSObjectTree]) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forSObjectTree: objectType, objectTrees: objectTrees))
            }
        }
        
        /**
         A factory method for users files request.
         ```
         restApi.filesOwned(userId: "", page: 0)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func filesOwned(userId: String?, page: UInt = 0) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forOwnedFilesList: userId, page: page))
            }
        }
        
        /**
          A factory method to retrieve files in users groups.
         ```
         restApi.filesInUsersGroups(userId: "", page: 0)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func filesInUsersGroups(userId: String?, page: UInt = 0) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.requestForFiles(inUsersGroups: userId, page: page))
            }
        }
        
        /**
         A factory method to create a retrieve files shared with user.
         ```
         restApi.filesShared(userId: "", page: 0)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func filesShared(userId: String, page: UInt = 0) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.requestForFilesShared(withUser: userId, page: page))
            }
        }
        
        /**
         A factory method to create a retrieve file details request.
         ```
         restApi.fileDetails(sfdcFileId: "", version: "")
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func fileDetails(sfdcFileId: String, version: String?) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forFileDetails: sfdcFileId, forVersion: version))
            }
        }
        
        /**
         A factory method to create a retrieve batch file details request
         ```
         restApi.batchDetails(sfdcFileIds: "fileId1","fileId2")
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func batchDetails(sfdcFileIds: String...) -> Promise<SFRestRequest> {
            return self.batchDetails(sfdcFileIds:sfdcFileIds)
        }
        
        /**
         A factory method to create a retrieve batch file details request
         ```
         restApi.batchDetails(sfdcFileIds: ["fileId1","fileId2"])
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func batchDetails(sfdcFileIds: [String] ) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forBatchFileDetails: sfdcFileIds))
            }
        }
        
        /**
          A factory method to create a  retrieve preview/rendition of a particular page of the file (and version) request.
         ```
         restApi.fileRendition(sfdcFileId: "id", version: nil, renditionType: "PDF", page: UInt = 0)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func fileRendition(sfdcFileId: String, version: String?, renditionType: String, page: UInt = 0) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forFileRendition: sfdcFileId, version: version, renditionType: renditionType, page: page))
            }
        }
        
        /**
         A factory method to create a retrieve contents of  file (and version) request
         ```
         restApi.fileContents(sfdcId: "10", version: nil)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func fileContents(sfdcId: String, version: String?) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forFileContents: sfdcId, version: version))
            }
        }
        
        /**
         A factory method to create a retrieve file shares request
         ```
         restApi.fileShares(sfdcId: "10", version: nil)
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func fileShares(sfdcId: String, page: UInt? = 0) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forFileShares: sfdcId, page: page!))
            }
        }
        
        /**
         A factory method to create a add file shares request
         ```
         restApi.addFileShare(fileId: "id", entityId: "someotheruserid", shareType: "V")
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func addFileShare(fileId: String, entityId: String, shareType: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) { resolver in
                resolver.fulfill(
                    self.api!.request(forAddFileShare: fileId, entityId: entityId, shareType: shareType))
            }
        }
        
        /**
         A factory method to create a delete file share request
         ```
         restApi.deleteFileShare(shareId: "id")
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func deleteFileShare(shareId: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forDeleteFileShare: shareId))
            }
        }
        
        /**
         A factory method to create a upload file request.
         ```
         restApi.uploadFile(data: Data, name: "AFileName", description: "A File Description", mimeType: "text/plain")
         .then { (request) in
         ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        
        public func uploadFile(data: Data, name: String, description: String, mimeType: String) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forUploadFile: data, name: name, description: description, mimeType: mimeType))
            }
        }
        
        /**
         Send api wrapped in a promise.
         
         ```
         let restApi = SFRestAPI.sharedInstance()
         restApi.Factory.describe(objectType: "Account")
         .then { request in
         restApi.send(request: request)
         }
         .done { sfRestResponse in
         var restResonse = sfRestResponse.asJsonDictionary()
         ...
         }
         .catch { error in
         restError = error
         }
         ```
         
         ```
         let restApi = SFRestAPI.sharedInstance()
         restApi.Factory.describe(objectType: "Account")
         .then { request in
         restApi.send(request: request)
         }
         .done { sfRestResponse in
         var restResonse = sfRestResponse.asDecodable(Account.Type)
         ...
         }
         .catch { error in
         restError = error
         }
         ```
         - Returns: The instance of Promise<SFRestResponse>.
         */
        public func send(request :SFRestRequest) -> Promise<SFRestResponse> {
            return Promise(.pending) {  resolver in
                request.parseResponse = false
                self.api!.send(request, fail: { (error, urlResponse) in
                    resolver.reject(error!)
                }, complete: { (data, urlResponse) in
                    resolver.fulfill(SFRestResponse(data: data as? Data,response: urlResponse))
                })
            }
        }
        
    }
    
}
