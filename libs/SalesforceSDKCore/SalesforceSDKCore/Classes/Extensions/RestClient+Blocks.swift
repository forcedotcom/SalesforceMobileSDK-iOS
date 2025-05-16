//
//  RestClient+Blocks.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 5/6/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

// MARK: - Swift Block Definitions (for clarity in Swift)
public typealias SFRestRequestFailBlock = (_ response: Any?, _ error: Error?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDictionaryResponseBlock = (_ dict: [String: Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestArrayResponseBlock = (_ array: [Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDataResponseBlock = (_ data: Data?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestResponseBlock = (_ response: Any?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestCompositeResponseBlock = (_ response: CompositeResponse, _ rawResponse: URLResponse?) -> Void
public typealias SFRestBatchResponseBlock = (_ response: BatchResponse, _ rawResponse: URLResponse?) -> Void

// MARK: - RestClient Extension
@objc
extension RestClient {

    /** Creates an error object with the given description.
     @param description Description
     */
    @objc(errorWithDescription:)
    public static func error(withDescription description: String) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: description,
            NSFilePathErrorKey: ""
        ]
        return NSError(domain: "API Error", code: 42, userInfo: userInfo)
    }

    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request SFRestRequest to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendRequest:failureBlock:successBlock:)
    public func sendRequest(_ request: RestRequest,
                            failureBlock: @escaping SFRestRequestFailBlock,
                            successBlock: @escaping SFRestResponseBlock) {
        self.send(request, failureBlock: failureBlock, successBlock: successBlock)
    }


    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request Composite request to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendCompositeRequest:failureBlock:successBlock:)
    public func sendCompositeRequest(_ request: CompositeRequest,
                                     failureBlock: @escaping SFRestRequestFailBlock,
                                     successBlock: @escaping SFRestCompositeResponseBlock) {
        self.sendRequest(request, failureBlock: failureBlock) { response, rawResponse in
            do {
                guard let dict = response as? [AnyHashable: Any] else {
                    let errFunc: (String) -> NSError = RestClient.error(withDescription:)
                    throw errFunc("CompositeResponse format invalid")
                }
                let compositeResponse = CompositeResponse(dict)
                successBlock(compositeResponse, rawResponse)
            } catch {
                failureBlock(response, error, rawResponse)
            }
        }
    }

    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request Batch request to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendBatchRequest:failureBlock:successBlock:)
    public func sendBatchRequest(_ request: BatchRequest,
                                 failureBlock: @escaping SFRestRequestFailBlock,
                                 successBlock: @escaping SFRestBatchResponseBlock) {
        self.sendRequest(request, failureBlock: failureBlock) { response, rawResponse in
            do {
                guard let dict = response as? [AnyHashable: Any] else {
                    let errFunc: (String) -> NSError = RestClient.error(withDescription:)
                    throw errFunc("BatchResponse format invalid")
                }
                let batchResponse = BatchResponse(dict)
                successBlock(batchResponse, rawResponse)
            } catch {
                failureBlock(response, error, rawResponse)
            }
        }
    }
}

extension RestClient {
    /// Execute a prebuilt request.
    /// - Parameter request: `RestRequest` object.
    /// - Parameter completionBlock: `Result` block that handles the server's response.
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.0 and will be removed in Salesforce Mobile SDK 14.0. Use the async/await version of `send(request:)` instead.")
    public func send(request: RestRequest, _ completionBlock: @escaping (Result<RestResponse, RestClientError>) -> Void) {
        request.parseResponse = false
        send(request, failureBlock: { (rawResponse, error, urlResponse) in
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
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.0 and will be removed in Salesforce Mobile SDK 14.0. Use the async/await version of `send(compositeRequest:)` instead.")
    public func send(compositeRequest: CompositeRequest, _ completionBlock: @escaping (Result<CompositeResponse, RestClientError>) -> Void) {
        compositeRequest.parseResponse = false
        sendCompositeRequest(compositeRequest, failureBlock: { (response, error, urlResponse) in
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
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.0 and will be removed in Salesforce Mobile SDK 14.0. Use the async/await version of `send(batchRequest:)` instead.")
    public func send(batchRequest: BatchRequest, _ completionBlock: @escaping (Result<BatchResponse, RestClientError>) -> Void) {
        batchRequest.parseResponse = false
        sendBatchRequest(batchRequest,
                         failureBlock: { (response, error, urlResponse) in
            let apiError = RestClientError.apiFailed(
                response: response,
                underlyingError: error ?? RestClientError.apiResponseIsEmpty,
                urlResponse: urlResponse
            )
            completionBlock(.failure(apiError))
        },
                         successBlock: { (response, _) in
            completionBlock(.success(response))
        })
    }
    
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
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.0 and will be removed in Salesforce Mobile SDK 14.0. Use the async/await version of `fetchRecords(ofModelType:forRequest:withDecoder:)` instead.")
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
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.0 and will be removed in Salesforce Mobile SDK 14.0. Use the async/await version of `fetchRecords(ofModelType:forQuery:withApiVersion:withDecoder:)` instead.")
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
