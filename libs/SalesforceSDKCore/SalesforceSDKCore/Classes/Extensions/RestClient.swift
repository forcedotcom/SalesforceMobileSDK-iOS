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

import Foundation
import Combine

/// Errors that can be thrown while using RestClient
public enum RestClientError: Error {
    case apiResponseIsEmpty
    case apiFailed(response: Any?, underlyingError: Error, urlResponse: URLResponse?)
    case decodingFailed(underlyingError: Error)
    case jsonSerialization(underlyingError: Error)
}

public struct RestResponse {
    private static let emptyStringResponse = ""
    private(set) var data: Data
    public private(set) var urlResponse: URLResponse
    
    /// Initializes the RestResponse with a Data object and URLResponse.
    /// - Parameter data: Raw response as Data.
    /// - Parameter urlResponse: URlResponse from endpoint.
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
            throw RestClientError.jsonSerialization(underlyingError: error)
        }
    }
    
    /// Get response as Data object. Use this for retrieving  binary objects.
    /// - Returns:
    /// Data object containing the response.
    public func asData() -> Data {
        return self.data
    }
    
    /// Parse response as String.
    /// - Returns: `String` containing the response.
    public func asString() -> String {
        let stringData = String(data: data, encoding: String.Encoding.utf8)
        return stringData ?? RestResponse.emptyStringResponse
    }
    
    /// Decode the response as  a codable.
    /// - Parameter type: The type to use for decoding.
    public func asDecodable<T: Decodable>(type: T.Type, decoder: JSONDecoder = .init()) throws -> T {
        do {
            let object = try decoder.decode(type, from: data)
            return object
        } catch let error {
            throw RestClientError.decodingFailed(underlyingError: error)
        }
    }
}

extension RestRequest {
  
  /// Calculated property to determine if this request is a data retrieval request with a SOQL or SOSL query.
  /// All such queries will return a JSON decodable QueryResponseWrapper.
  /// Implied contract is that all requests matching both properties here will be decodable via QueryResponseWrapper<Record>
  public var isQueryRequest: Bool {
    get {
      return self.method == .GET && (self.path.lowercased().hasSuffix("query") || self.path.lowercased().hasSuffix("search"))
    }
  }
  
}

extension RestClient {
  
    /// Struct represents the JSON Structure of a Salesforce Response.
    /// This struct requires a Model Object that conforms to Decodable
    /// This model object's properties need to match the Salesforce Schema
    ///   at least in part.
    public struct QueryResponse<Record: Decodable>: Decodable {
      var totalSize: Int?
      var done: Bool?
      var records: [Record]?
    }
    
    /// Execute a prebuilt request.
    /// - Parameter request: `RestRequest` object.
    /// - Parameter completionBlock: `Result` block that handles the server's response.
    public func send(request: RestRequest, _ completionBlock: @escaping (Result<RestResponse, RestClientError>) -> Void) {
        request.parseResponse = false
        __send(request, failureBlock: { (rawResponse, error, urlResponse) in
            let apiError = RestClientError.apiFailed(response: rawResponse, underlyingError: error ?? RestClientError.apiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }, successBlock: { (rawResponse, urlResponse) in
            if let data = rawResponse as? Data,
                let urlResponse = urlResponse {
                let result = RestResponse(data: data, urlResponse: urlResponse)
                completionBlock(Result.success(result))
            } else {
                completionBlock(Result.failure(.apiResponseIsEmpty))
            }
        })
    }
    
    /// Execute a prebuilt composite request.
    /// - Parameter compositeRequest: `CompositeRequest` object containing the array of subrequests to execute.
    /// - Parameter completionBlock: `Result` block that handles the server's response.
    /// - See   [Composite](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm).
    public func send(compositeRequest: CompositeRequest, _ completionBlock: @escaping (Result<CompositeResponse, RestClientError>) -> Void) {
        compositeRequest.parseResponse = false
        __send(compositeRequest, failureBlock: { (response, error, urlResponse) in
            let apiError = RestClientError.apiFailed(response: response, underlyingError: error ?? RestClientError.apiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }, successBlock: { (response, _) in
            completionBlock(Result.success(response))
        })
    }
    
    /// Execute a prebuilt batch of requests.
    /// - Parameter batchRequest: `BatchRequest` object containing the array of subrequests to execute.
    /// - Parameter completionBlock: `Result` block that handles the server's response.
    /// - See   [Batch](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_batch.htm).
    public func send(batchRequest: BatchRequest, _ completionBlock: @escaping (Result<BatchResponse, RestClientError>) -> Void ) {
        batchRequest.parseResponse = false
        __send(batchRequest, failureBlock: { (response, error, urlResponse) in
            let apiError = RestClientError.apiFailed(response: response, underlyingError: error ?? RestClientError.apiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }, successBlock: { (response, _) in
            completionBlock(Result.success(response))
        })
    }
  
    // MARK: Record Convience API - Pure Swift 4+
    
    /// This method provides a reusuable, generic pipeline for retrieving records
    ///   from Salesforce. It relys on Swift Generics, and type inference to determine what
    ///  models to create.
    ///
    /// Given a model object - Contact, you can use this method like this:
    ///   RestClient.shared.fetchRecords(ofModelType: ModelName.self, forRequest: request) { result in
    ///       switch result {
    ///       case .success(let records):
    ///           do something with your array of model objects
    ///       case .failure(let error):
    ///           print(error)
    ///       }
    ///     }
    ///
    /// This method relies on the passed parameter ofModelType to infer the generic Record's
    /// concrete type.
    public func fetchRecords<Record: Decodable>(ofModelType modelType: Record.Type,
                                         forRequest request: RestRequest,
                                         withDecoder decoder: JSONDecoder = .init(),
                                       _ completionBlock: @escaping (Result<QueryResponse<Record>, RestClientError>) -> Void) {
      guard request.isQueryRequest else { return }
      RestClient.shared.send(request: request) { result in
          switch result {
              case .success(let response):
                do {
                  let wrapper = try response.asDecodable(type: QueryResponse<Record>.self, decoder: decoder)
                  completionBlock(.success(wrapper))
                } catch {
                  completionBlock(.success(QueryResponse<Record>(totalSize: 0, done: true, records: [])))
              }
              case .failure(let err):
                  completionBlock(.failure(err))
          }
        }
    }
  
    /// This method provides a reusuable, generic pipeline for retrieving records
    ///   from Salesforce. It relys on Swift Generics, and type inference to determine what
    ///  models to create.
    ///
    /// Given a model object - Account, you can use this method like this:
    ///   RestClient.shared.fetchRecords(ofModelType: Account.self,
    ///                                  forQuery: "select id from account"
    ///                                  withApiVersion: "v48.0") { result in
    ///       switch result {
    ///       case .success(let records):
    ///           do something with your array of model objects
    ///       case .failure(let error):
    ///           print(error)
    ///       }
    ///     }
    ///
    /// This method relies on the passed parameter ofModelType to infer the generic Record's
    /// concrete type.
    public func fetchRecords<Record: Decodable>(ofModelType modelType: Record.Type,
                                         forQuery query: String,
                                         withApiVersion version: String = SFRestDefaultAPIVersion,
                                         withDecoder decoder: JSONDecoder = .init(),
                                         _ completionBlock: @escaping (Result<QueryResponse<Record>, RestClientError>) -> Void) {
        let request = RestClient.shared.request(forQuery: query, apiVersion: version)
        guard request.isQueryRequest else { return }
        return self.fetchRecords(ofModelType: modelType, forRequest: request, withDecoder: decoder, completionBlock)
    }
  
}

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
    
    public func publisher(for request: CompositeRequest) -> Future<CompositeResponse, RestClientError> {
        return Future<CompositeResponse, RestClientError> { promise in
            self.send(compositeRequest: request) { (result) in
                switch result {
                case .success(let response):
                    promise(.success(response))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    public func publisher(for request: BatchRequest) -> Future<BatchResponse, RestClientError> {
        return Future<BatchResponse, RestClientError> { promise in
            self.send(batchRequest: request) { (result) in
                switch result {
                case .success(let response):
                    promise(.success(response))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
  
    // MARK: Record Convience API - Swift & Combine

  
    /// This method provides a reusuable, generic Combine pipeline for retrieving records
    ///   from Salesforce. It relys on Swift Generics, and type inference to determine what
    ///  models to create.
    ///
    /// Given a model object - Contact, you can use this pipeline like this:
    /// contactsForCancellable = RestClient.shared.records(forRequest: request)
    ///   .receive(on: RunLoop.main)
    ///   .assign(to: \.contacts, on: self)
    ///
    /// This pipeline infers it's return type from the variable in the assign subscriber.
    public func records<Record: Decodable>(forRequest request: RestRequest,
                                    withDecoder decoder: JSONDecoder = .init()) -> AnyPublisher<QueryResponse<Record>, Never> {
      guard request.isQueryRequest else {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
      }
      return RestClient.shared.publisher(for: request)
        .tryMap({ (response) -> Data in
          response.asData()
        })
        .decode(type: QueryResponse<Record>.self, decoder: decoder)
        .catch({ _ in
          Just(QueryResponse<Record>(totalSize: 0, done: true, records: []))
        })
        .eraseToAnyPublisher()
    }
  
    /// Reusable, generic Combine Pipeline returning an array of records of a local
    /// model object that conforms to Decodable. This method accepts a query string and defers
    /// to records<Record:Decodable>(forRequest request: RestRequest) -> AnyPublisher<[Record], Never>
    public func records<Record: Decodable>(forQuery query: String,
                                    withApiVersion version: String = SFRestDefaultAPIVersion,
                                    withDecoder decoder: JSONDecoder = .init()) -> AnyPublisher<QueryResponse<Record>, Never> {
        let request = RestClient.shared.request(forQuery: query, apiVersion: version)
        return self.records(forRequest: request, withDecoder: decoder)
    }
}
