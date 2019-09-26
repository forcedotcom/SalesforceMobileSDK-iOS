import Foundation

/*
 RestClient.swift
 SalesforceSDKCore
 
 Created by Raj Rao on 9/24/19.
 
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
/// Errors that can be thrown while using RestClient
public enum RestClientError: Error {
    case ApiResponseIsEmpty
    case ApiInvocationFailed(underlyingError: Error, urlResponse: URLResponse?)
    case DecodingFailed(underlyingError: Error)
    case JsonSerialization(underlyingError: Error)
}

public struct RestResponse {
    
    private static let emptyJsonDictionaryArrayResponse = [String:Any]()
    private static let emptyJsonArrayResponse = [[String:Any]]()
    private static let emptyStringResponse = ""
    
    private (set) var data: Data
    private (set) var urlResponse: URLResponse
    
    /// Initializes the RestResponse with a Data object and URLResponse
    /// - Parameter data: Response as raw Data
    /// - Parameter urlResponse: URlResponse from endpoint
    public init(data: Data, urlResponse: URLResponse) {
        self.data = data
        self.urlResponse = urlResponse
    }
    
    /// Parse the response as a Json Dictionary.
    public func asJson() throws -> Any {
        do {
            let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
            return jsonData
        } catch let error {
            throw RestClientError.JsonSerialization(underlyingError: error)
        }
    }
    
    /// Get response as Data object. Use this for retrieving  binary objects
    public func asData() -> Data {
        return self.data
    }
    
    /// Parse response as String
    public func asString() -> String {
        let stringData = String(data: data, encoding: String.Encoding.utf8)
        return stringData ?? RestResponse.emptyStringResponse
    }
    
    /// Decode the response as  a codable
    /// - Parameter type: The type to use for decoding.
    public func asDecodable<T:Decodable>(type: T.Type) throws -> Decodable?  {
        let decoder = JSONDecoder()
        do{
            let object = try decoder.decode(type, from: data)
            return object
        } catch let error {
            throw RestClientError.DecodingFailed(underlyingError: error)
        }
    }
}

extension RestClient {
    
    /// Execute a request.
    /// - Parameter request: RestRequest object
    /// - Parameter completionBlock: The completion block to invoke.
    public func send(request: RestRequest, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) {
        request.parseResponse = false
        __send(request, fail: { (error, urlResponse) in
            let apiError = RestClientError.ApiInvocationFailed(underlyingError: error ?? RestClientError.ApiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }) { (rawResponse, urlResponse) in
            if let data = rawResponse as? Data,
                let urlResponse = urlResponse {
                let result = RestResponse(data: data, urlResponse: urlResponse)
                completionBlock(Result.success(result))
            } else {
                completionBlock(Result.failure(.ApiResponseIsEmpty))
            }
        }
    }
    
    /// Execute a SOQL query
    /// - Parameter request: RestRequest object
    /// - Parameter completionBlock: The completion block to invoke.
    
    public func query(_ soql: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forQuery: soql, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    
    /// Execute a SOQL queryAll
    /// - Parameter soql: A soql String
    /// - Parameter completionBlock: The completion block to invoke.
    public func queryAll(_ soql: String,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forQueryAll: soql, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a SOSL search
    /// - Parameter sosl: A sosl string
    /// - Parameter completionBlock: The completion block to invoke.
    public func search(_ sosl: String,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forSearch: sosl, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a describe for Global objects
    /// - Parameter sosl:  A sosl string
    /// - Parameter completionBlock: The completion block to invoke.
    public func describeGlobal(_ sosl: String,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forDescribeGlobal: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a describe for  object type
    /// - Parameter objectType: An object type.
    /// - Parameter completionBlock: The completion block to invoke.
    public func describe(_ objectType: String,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForDescribe(withObjectType: objectType, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute metadata request
    /// - Parameter objectType: An object type.
    /// - Parameter completionBlock: The completion block to invoke.
    public func metadata(_ objectType: String,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForMetadata(withObjectType: objectType, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    
    /// Execute a retreive.
    /// - Parameter objectType: An object type.
    /// - Parameter objectId: An object  identifier.
    /// - Parameter fieldList: CSV of fields
    /// - Parameter completionBlock: The completion block to invoke.
    func retrieve(_ objectType: String, objectId: String, fieldList: [String], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForRetrieve(withObjectType: objectType, objectId: objectId, fieldList: fieldList.joined(separator: ","), apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute an update.
    /// - Parameter objectType: An object type.
    /// - Parameter objectId: An object  identifier.
    /// - Parameter fieldList: CSV of fields.
    /// - Parameter completionBlock: The completion block to invoke.
    func update(_ objectType: String, objectId: String, fieldList: [String: Any], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForUpdate(withObjectType: objectType, objectId: objectId, fields: fieldList, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute am upsert.
    /// - Parameter objectType: An object type.
    /// - Parameter externalIdField: External field identifier.
    /// - Parameter externalId: Exeternal identifier.
    /// - Parameter fieldList: Dictionary of fields.
    /// - Parameter completionBlock: The completion block to invoke.
    func upsert(_ objectType: String, externalIdField: String, externalId: String, fieldList: [String: Any], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForUpsert(withObjectType: objectType, externalIdField: externalIdField, externalId: externalId, fields: fieldList, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a delete.
    /// - Parameter objectType: An object type.
    /// - Parameter objectId: An object  identifier.
    /// - Parameter completionBlock: The completion block to invoke.
    func delete(_ objectType: String, objectId: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForDelete(withObjectType: objectType, objectId: objectId, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a create.
    /// - Parameter objectType: An object type.
    /// - Parameter fields: Dictionary of fields
    /// - Parameter completionBlock: The completion block to invoke.
    func create(_ objectType: String, fields: [String:Any], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForCreate(withObjectType: objectType, fields: fields, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute resources request
    /// - Parameter completionBlock: The completion block to invoke.
    func resources(_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forResources: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute versions request
    /// - Parameter completionBlock: The completion block to invoke.
    func apiVersions(_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForVersions()
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a searchScopeAndOrder request
    /// - Parameter completionBlock: The completion block to invoke.
    func searchScopeAndOrder(_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forSearchScopeAndOrder: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a searchResultLayout
    /// - Parameter objectList: Array of objects.
    /// - Parameter completionBlock: The completion block to invoke.
    func searchResultLayout(_ objectList:[String], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forSearchResultLayout: objectList.joined(separator: ","), apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
     
    /// Execute a Composite request
    /// - Parameter requests: Array of RestRequewst
    /// - Parameter referenceIds: String array of reference identifiers.
    /// - Parameter allOrNone: Boolean to indicate whether to set allOrNone.
    /// - Parameter completionBlock: The completion block to invoke.
    func composite(_ requests:[RestRequest], referenceIds: [String], allOrNone: Bool, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.compositeRequest(requests, refIds: referenceIds, allOrNone: allOrNone,apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a batch request
    /// - Parameter requests: Array of RestRequewst
    /// - Parameter haltOnError: Boolean to indicate whether to stop or continue when error occurs in any request.
    /// - Parameter completionBlock: The completion block to invoke.
    func batch(_ requests:[RestRequest], haltOnError: Bool, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.batchRequest(requests, haltOnError: haltOnError, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute a SObjectTree request
    /// - Parameter objectType: An object type.
    /// - Parameter objectTrees: Array of SObjectTree
    /// - Parameter completionBlock: The completion block to invoke.
    func sObjectTree(_ objectType: String, objectTrees: [SObjectTree], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forSObjectTree: objectType, objectTrees: objectTrees, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Owned Files request
    /// - Parameter userId: User identifier.
    /// - Parameter page: Page number.
    /// - Parameter completionBlock: The completion block to invoke.
    func ownedFiles(_ userId: String?, page: Int, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
       let request = self.request(forOwnedFilesList: userId, page: UInt(page), apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       return request
    }
    
    /// Get files in users groups
    /// - Parameter userId: User identifier.
    /// - Parameter page: Page number.
    /// - Parameter completionBlock: The completion block to invoke.
    func filesInUsersGroups(_ userId: String?, page: Int, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForFiles(inUsersGroups: userId, page: UInt(page), apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Files shared with user.
    /// - Parameter userId: User Identifier
    /// - Parameter page: Page number
    /// - Parameter completionBlock: The completion block to invoke.
    func filesSharedWithUser(_ userId: String?, page: Int, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.requestForFilesShared(withUser: userId, page: UInt(page), apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// File Details request
    /// - Parameter sfdcId: identifier for file.
    /// - Parameter version: Version of file.
    /// - Parameter completionBlock: The completion block to invoke.
    func fileDetails(_ sfdcId: String, version: String?,_ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forFileDetails: sfdcId, forVersion: version, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Batch files details request.
    /// - Parameter sfdcIds: Identifiers for shares.
    /// - Parameter completionBlock: The completion block to invoke.
    func batchFileDetails(_ sfdcIds: [String], _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forBatchFileDetails: sfdcIds, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute fileRendition request
    /// - Parameter fileId: An sfdc file identifier.
    /// - Parameter version: A file version.
    /// - Parameter type: File type.
    /// - Parameter page: Page number.
    /// - Parameter completionBlock: The completion block to invoke.
    func fileRendition(_ fileId: String, version: String, type: String, page: Int, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forFileRendition: fileId, version: version, renditionType: type, page: UInt(page), apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Execute fileRendition request
    /// - Parameter fileId: An sfdc file identifier.
    /// - Parameter version: A file version.
    /// - Parameter type: File type.
    /// - Parameter page: Page number.
    /// - Parameter completionBlock: The completion block to invoke.
    func fileContents(_ fileId: String, version: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forFileContents: fileId, version: version, apiVersion: self.apiVersion)
        self.send(request: request, completionBlock)
        return request
    }
    
    /// Get File Shares request
    /// - Parameter sfdcId: Identifier for shares.
    /// - Parameter page: Page number.
    /// - Parameter completionBlock: The completion block to invoke.
    func fileShares(_ sfdcId: String, page: Int, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
       let request = self.request(forFileShares: sfdcId, page: UInt(page), apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       return request
    }
    
    /// Add a File Share
    /// - Parameter fileId: File identifier.
    /// - Parameter entityId: Entity identifier
    /// - Parameter shareType: The type of Share.
    /// - Parameter completionBlock: The completion block to invoke.
    func addFileShare(_ fileId: String, entityId: String, shareType: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
       let request = self.request(forAddFileShare: fileId, entityId: entityId, shareType: shareType, apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       return request
    }
    
    /// Delete a file share.
    /// - Parameter shareId: Share identtifier.
    /// - Parameter completionBlock: The completion block to invoke.
    func deleteFileShare(_ shareId: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
       let request = self.request(forDeleteFileShare: shareId, apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       return request
    }
    
    /// Upload a File.
    /// - Parameter data: Data contents.
    /// - Parameter name: Name for the file
    /// - Parameter description: Description for file.
    /// - Parameter mimeType: The mime type.
    /// - Parameter completionBlock: The completion block to invoke.
    func uploadFileShare(_ data: Data, name: String, description: String, mimeType: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forUploadFile: data, name: name, description: description, mimeType: mimeType, apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       return request
    }
    
    /// Upload a photo.
    /// - Parameter data: Data contents.
    /// - Parameter name: Name for the file
    /// - Parameter description: Description for file.
    /// - Parameter mimeType: The mime type.
    /// - Parameter userId: Identifier for user.
    /// - Parameter completionBlock: The completion block to invoke.
    func uploadProfilePhoto(_ data: Data, name: String, description: String, mimeType: String, userId: String, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) -> RestRequest {
        let request = self.request(forProfilePhotoUpload: data, fileName: name, mimeType: mimeType, userId: userId, apiVersion: self.apiVersion)
       self.send(request: request, completionBlock)
       
       return request
    }
 
}

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension RestClient {
    public func publisher(for request: RestRequest) -> Future<RestResponse, RestClientError> {
        return Future<RestResponse, RestClientError> { promise in
            self.send(request: request) { (result) in
                switch result {
                    case .success(let response):
                        promise(.success(response))
                    case .failure(let error):
                        promise(.failure(error))
                }
            }
        }
    }
}
