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
    case invalidRequest(String)
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
    
    /// Sends a URLRequest
    /// - Parameter urlRequest: The URLRequest to send
    /// - Parameter networkServiceType: Specify a service type or use the default.
    /// - Parameter requiresAuthentication: Specify requires auth, default to true.
    /// - Returns: A RestResponse containing the response data and metadata
    /// - Throws: A RestClientError if the request fails
    @objc(sendURLRequest:networkServiceType:requiresAuthentication:completion:)
    public func send(urlRequest: URLRequest,
                     networkServiceType: RestRequest.NetWorkServiceType = RestRequest.NetWorkServiceType.SFNetworkServiceTypeDefault,
                     requiresAuthentication: Bool = true) async throws -> (Data, URLResponse) {
        guard let restRequest = urlRequest.toRestRequest(networkServiceType, requiresAuthentication) else {
            throw RestClientError.invalidRequest("Request is not a valid MSDK REST request.")
        }
        let response = try await send(request: restRequest)
        return (response.data, response.urlResponse)
    }
    
    /// Execute a prebuilt request.
    /// - Parameter request: The `RestRequest` object containing the request details.
    /// - Returns: A `RestResponse` object containing the response data and metadata.
    /// - Throws: A `RestClientError` if the request fails.
    public func send(request: RestRequest) async throws -> RestResponse {
        request.parseResponse = false
        
        return try await withCheckedThrowingContinuation { continuation in
            send(request,
                 failureBlock: { rawResponse, error, urlResponse in
                let apiError = RestClientError.apiFailed(
                    response: rawResponse,
                    underlyingError: error ?? RestClientError.apiResponseIsEmpty,
                    urlResponse: urlResponse
                )
                continuation.resume(throwing: apiError)
            },
                 successBlock: { rawResponse, urlResponse in
                if let data = rawResponse as? Data,
                   let urlResponse = urlResponse {
                    let result = RestResponse(data: data, urlResponse: urlResponse)
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: RestClientError.apiResponseIsEmpty)
                }
            })
        }
    }
    
    public func send(compositeRequest: CompositeRequest) async throws -> CompositeResponse {
        compositeRequest.parseResponse = false
        
        return try await withCheckedThrowingContinuation { continuation in
            sendCompositeRequest(compositeRequest, failureBlock: { (response, error, urlResponse) in
                let apiError = RestClientError.apiFailed(response: response, underlyingError: error ?? RestClientError.apiResponseIsEmpty, urlResponse: urlResponse)
                continuation.resume(throwing: apiError)
            }, successBlock: { (response, _) in
                continuation.resume(returning: response)
            })
        }
        
    }
    
    /// Execute a prebuilt batch of requests.
    /// - Parameter batchRequest: `BatchRequest` object containing the array of subrequests to execute.
    /// - Returns: A `BatchResponse` object containing the responses for the batch requests.
    /// - Throws: A `RestClientError` if the request fails.
    /// - See   [Batch](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_batch.htm).
    public func send(batchRequest: BatchRequest) async throws -> BatchResponse {
        batchRequest.parseResponse = false
        
        return try await withCheckedThrowingContinuation { continuation in
            sendBatchRequest(batchRequest,
                             failureBlock: { response, error, urlResponse in
                let apiError = RestClientError.apiFailed(
                    response: response,
                    underlyingError: error ?? RestClientError.apiResponseIsEmpty,
                    urlResponse: urlResponse
                )
                continuation.resume(throwing: apiError)
            }, successBlock: { response, _ in
                continuation.resume(returning: response)
            })
        }
    }
    
    // MARK: Record Convience API - Pure Swift 4+
    
    /// Fetches records of a specific model type using the provided request.
    /// - Parameters:
    ///   - modelType: The type of the model to decode the records into.
    ///   - request: The `RestRequest` object representing the query.
    ///   - decoder: The `JSONDecoder` used to decode the response. Defaults to `.init()`.
    /// - Returns: A `QueryResponse` object containing the query results.
    /// - Throws: A `RestClientError` if the request fails or the response cannot be decoded.
    public func fetchRecords<Record: Decodable>(ofModelType modelType: Record.Type,
                                                forRequest request: RestRequest,
                                                withDecoder decoder: JSONDecoder = .init()
    ) async throws -> QueryResponse<Record> {
        guard request.isQueryRequest else {
            throw RestClientError.invalidRequest("Request is not a query request.")
        }
        
        do {
            let response = try await RestClient.shared.send(request: request)
            return try response.asDecodable(type: QueryResponse<Record>.self, decoder: decoder)
        } catch _ as RestClientError {
            return QueryResponse<Record>(totalSize: 0, done: true, records: [])
        } catch {
            throw error
        }
    }
    
    /// Fetches records of a specific model type using the provided query.
    /// - Parameters:
    ///   - modelType: The type of the model to decode the records into.
    ///   - query: The SOQL query string to execute.
    ///   - version: The API version to use. Defaults to `SFRestDefaultAPIVersion`.
    ///   - decoder: The `JSONDecoder` used to decode the response. Defaults to `.init()`.
    /// - Returns: A `QueryResponse` object containing the query results.
    /// - Throws: A `RestClientError` if the request fails or the response cannot be decoded.
    public func fetchRecords<Record: Decodable>(
        ofModelType modelType: Record.Type,
        forQuery query: String,
        withApiVersion version: String = SFRestDefaultAPIVersion,
        withDecoder decoder: JSONDecoder = .init()
    ) async throws -> QueryResponse<Record> {
        let request = RestClient.shared.request(forQuery: query, apiVersion: version)
        return try await fetchRecords(ofModelType: modelType, forRequest: request, withDecoder: decoder)
    }
    
}

extension RestClient {
    
    public func publisher(for request: RestRequest) -> Future<RestResponse, RestClientError> {
        return Future<RestResponse, RestClientError> { promise in
            Task {
                do {
                    let response = try await self.send(request: request)
                    promise(.success(response))
                } catch let error as RestClientError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(RestClientError.apiFailed(response: nil, underlyingError: error, urlResponse: nil)))
                }
            }
        }
    }
    
    public func publisher(for request: CompositeRequest) -> Future<CompositeResponse, RestClientError> {
        return Future<CompositeResponse, RestClientError> { promise in
            Task {
                do {
                    let response = try await self.send(compositeRequest: request)
                    promise(.success(response))
                } catch let error as RestClientError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.apiFailed(response: nil, underlyingError: error, urlResponse: nil)))
                }
            }
        }
    }
    
    public func publisher(for request: BatchRequest) -> Future<BatchResponse, RestClientError> {
        return Future<BatchResponse, RestClientError> { promise in
            Task {
                do {
                    let response = try await self.send(batchRequest: request)
                    promise(.success(response))
                } catch let error as RestClientError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(RestClientError.apiFailed(response: nil, underlyingError: error, urlResponse: nil)))
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
