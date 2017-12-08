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
    
    func asJsonDictionary() -> [String: Any] {
        guard let rawData = data,data!.count > 0 else {
            return [String:Any]()
        }
        let jsonData = try! JSONSerialization.jsonObject(with: rawData, options: []) as! Dictionary<String, Any>
        return jsonData
    }
    
    func asJsonArray() -> [[String: Any]] {
        guard let rawData = data,data!.count > 0 else {
            return [[String: Any]]()
        }
        let jsonData = try! JSONSerialization.jsonObject(with: rawData, options: []) as! [Dictionary<String, Any>]
        return jsonData
    }
    
    func asString() -> String {
        guard let rawData = data,data!.count > 0 else {
            return ""
        }
        let jsonData = String(data: rawData, encoding: String.Encoding.utf8)
        return jsonData!
    }
    
    func asDecodable<T:Decodable>(type: T.Type) -> Decodable? {
        guard let rawData = data,data!.count > 0 else {
            return nil
        }
        let decoder = JSONDecoder()
        return try! decoder.decode(type, from: rawData)
    }
}

extension SFRestAPI {
    
    public var Factory: SFRestRequestFactory {
        return SFRestRequestFactory(api: self)
    }
    
    public class SFRestRequestFactory {
        
        weak var api: SFRestAPI?
        
        init(api: SFRestAPI) {
            self.api = api
        }
        
        /**
         A factory method for versions().
         ```
         SFRestRequestFactory.Factory.versions()
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
         SFRestRequestFactory.Factory.resources()
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
         SFRestRequestFactory.Factory.describe()
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
         SFRestRequestFactory.Factory.describeGlobal()
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
         SFRestRequestFactory.Factory.metadata(objectType)
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
         SFRestRequestFactory.Factory.retrieve(objectType: objectType,objectId: objectId, fieldList: "Name","LastModifiedDate")
         .then { (request) in
             restApi.send(request)
         }
         ```
         - Returns: SFRestRequest wrapped in a promise.
         */
        public func retrieve(objectType: String,objectId: String, fieldList: String... ) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(self.api!.requestForRetrieve(withObjectType: objectType, objectId: objectId, fieldList: fieldList.joined(separator: ",")))
            }
        }
        
        /**
         A factory method for create object request.
         ```
         SFRestRequestFactory.Factory.create(objectType: objectType, fieldList: ["Name": "salesforce.com", "TickerSymbol": "CRM"])
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
         SFRestRequestFactory.Factory.upsert(objectType: objectType,externalIdField:"",externalId: "1000", fieldList: {Name: "salesforce.com", TickerSymbol: "CRM"})
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
         SFRestRequestFactory.Factory.update(objectType: objectId: "1000", fieldList: fieldList,ifUnmodifiedSince:sinceDate)
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
         SFRestRequestFactory.Factory.delete(objectType: objectType, objectId: objectId)
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
         SFRestRequestFactory.Factory.query(soql: soql)
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
         SFRestRequestFactory.Factory.queryAll(soql: soql)
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
         SFRestRequestFactory.Factory.search(sosl: sosl)
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
         SFRestRequestFactory.Factory.searchScopeAndOrder()
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
         SFRestRequestFactory.Factory.searchResultLayout(objectList: "Account","Contact")
         .then { (request) in
            ...
         }
         ```
         - Returns:  SFRestRequest wrapped in a promise.
         */
        public func searchResultLayout(objectList: String...) -> Promise<SFRestRequest> {
            return  Promise(.pending) {  resolver in
                resolver.fulfill(
                    self.api!.request(forSearchResultLayout: objectList.joined(separator: ",")))
            }
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
            self.send(request, fail: { (error, urlResponse) in
                resolver.reject(error!)
            }, complete: { (data, urlResponse) in
                resolver.fulfill(SFRestResponse(data: data as? Data,response: urlResponse))
            })
        }
    }

}
