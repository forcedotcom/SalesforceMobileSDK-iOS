/*
 SfapApiClient.swift
 SalesforceSDKCore
 
 Created by Eric C. Johnson (Johnson.Eric@Salesforce.com) on 20250108.
 
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

/**
 * Provides REST client methods for a variety of `sfap_api` endpoints.
 * - `chat-generations`
 * - `embeddings`
 * - `feedback`
 * - `generations`
 *
 * See https://developer.salesforce.com/docs/einstein/genai/guide/access-models-api-with-rest.html
 */
@objc(SFApApiClient)
public class SfapApiClient : NSObject {
    
    /// The sfap_api hostname
    private let apiHostName: String
    
    /// The sfap_api model name
    private let modelName: String?
    
    /// The REST client
    private let restClient: RestClient
    
    /**
     * Initializes a new SfapApiClient.
     * - Parameters:
     *   - apiHostName: The Salesforce `sfap_api` hostname
     *   - modelName: The model name to request from.  For possible values, see
     *   https://developer.salesforce.com/docs/einstein/genai/guide/api-names.html.
     *   Note that the `embeddings` endpoint requires an embeddings-enabled model such as
     *   `sfdc_ai__DefaultOpenAITextEmbeddingAda_002`.  Also note that submitting to the `feedback`
     *   endpoint does not require value for this parameter
     *   - restClient: The REST client to use
     */
    @objc
    public init(
        apiHostName: String,
        modelName: String? = nil,
        restClient: RestClient
    ) {
        self.apiHostName = apiHostName
        self.modelName = modelName
        self.restClient = restClient
    }
    
    /**
     * Submit a request to the `sfap_api` `embeddings` endpoint.
     * - Parameters:
     *   - requestBody: The `embeddings` request body
     * - Returns: The endpoint's response
     */
    @objc
    public func fetchGeneratedEmbeddings(
        requestBody: SfapApiEmbeddingsRequestBody
    ) async throws -> SfapApiEmbeddingsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapApiError(message: "Cannot fetch generated embeddings without specifying a model name.")
        }
        
        // Generate the sfap_api embeddings request body.
        let sfapApiEmbeddingsRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "embeddings request")
        
        // Create the sfap_api embeddings request.
        let sfapApiEmbeddingsRequest = restRequestWithBodyString(
            sfapApiEmbeddingsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/embeddings"
        )
        
        // Submit the sfap_api embeddings request and fetch the response.
        let sfapApiEmbeddingsResponse = await withCheckedContinuation { continuation in
            restClient.send(
                request: sfapApiEmbeddingsRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the sfap_api embeddings response.
        switch sfapApiEmbeddingsResponse {
            
        case .success(let sfapApiEmbeddingsResponse):
            // Decode the sfap_api embeddings response.
            let sfapApiEmbeddingsResponseBody = try sfapApiEmbeddingsResponse.asDecodable(
                type: SfapApiEmbeddingsResponseBody.self
            )
            sfapApiEmbeddingsResponseBody.sourceJson = sfapApiEmbeddingsResponse.asString()
            return sfapApiEmbeddingsResponseBody
            
        case .failure(let error):
            throw try errorForRestClientError(error, requestName: "generate embeddings request")
        }
    }
    
    /**
     * Fetches generated chat responses from the `sfap_api` `chat-generations` endpoint.
     * - Parameters:
     *   - requestBody: The `chat-generations` request body
     * - Returns: The endpoint's response
     */
    @objc
    public func fetchGeneratedChat(
        requestBody: SfapApiChatGenerationsRequestBody
    ) async throws -> SfapApiChatGenerationsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapApiError(message: "Cannot fetch generated chat responses without specifying a model name.")
        }
        
        // Generate the sfap_api generate chat request body.
        let sfapApiChatGenerationsRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "chat generations request")
        
        // Create the sfap_api chat generations request.
        let sfapApiChatGenerationsRequest = restRequestWithBodyString(
            sfapApiChatGenerationsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/chat-generations"
        )
        
        // Submit the sfap_api chat generations request and fetch the response.
        let sfapApiChatGenerationsResponse = await withCheckedContinuation { continuation in
            restClient.send(
                request: sfapApiChatGenerationsRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the sfap_api chat generations response.
        switch sfapApiChatGenerationsResponse {
            
        case .success(let sfapApiChatGenerationsResponse):
            // Decode the sfap_api chat generations response.
            let sfapApiChatGenerationsResponseBody = try sfapApiChatGenerationsResponse.asDecodable(
                type: SfapApiChatGenerationsResponseBody.self
            )
            sfapApiChatGenerationsResponseBody.sourceJson = sfapApiChatGenerationsResponse.asString()
            return sfapApiChatGenerationsResponseBody
            
        case .failure(let error):
            throw try errorForRestClientError(error, requestName: "chat generations request")
        }
    }
    
    /**
     * Fetches generated text from the `sfap_api` "generations" endpoint.
     * - Parameters:
     *   -  prompt: The prompt request parameter value
     * - Returns: The endpoint's response
     */
    @objc
    public func fetchGeneratedText(
        _ prompt: String
    ) async throws -> SfapApiGenerationsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapApiError(message: "Cannot fetch generated text without specifying a model name.")
        }
        
        // Generate the sfap_api generations request body.
        let sfapApiGenerationsRequestBodyString = try requestBodyStringFromRequest(
            SfapApiGenerationsRequestBody(prompt: prompt),
            named: "generations request")
        
        // Create the sfap_api generations request.
        let sfapApiGenerationsRequest = restRequestWithBodyString(
            sfapApiGenerationsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/generations"
        )
        
        // Submit the sfap_api generations request and fetch the response.
        let sfapApiGenerationsResponse = await withCheckedContinuation { continuation in
            restClient.send(
                request: sfapApiGenerationsRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the sfap_api generations response.
        switch sfapApiGenerationsResponse {
            
        case .success(let sfapApiGenerationsResponse):
            // Decode the sfap_api generations response.
            let sfapApiGenerationsResponseBody = try sfapApiGenerationsResponse.asDecodable(
                type: SfapApiGenerationsResponseBody.self
            )
            sfapApiGenerationsResponseBody.sourceJson = sfapApiGenerationsResponse.asString()
            return sfapApiGenerationsResponseBody
            
        case .failure(let error):
            throw try errorForRestClientError(error, requestName: "generations request")
        }
    }
    
    /**
     * Submits feedback for previously generated text from the `sfap_api` endpoints to the `sfap_api`
     * `feedback` endpoint.
     * - Parameters:
     *   - requestBody: The `feedback` request body
     * - Returns: The endpoint's response
     */
    @objc
    public func submitGeneratedTextFeedback(
        requestBody: SfapApiFeedbackRequestBody
    ) async throws -> SfapApiFeedbackResponseBody {
        
        // Generate the sfap_api feedback request body.
        let sfapApiFeedbackRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "feedback request")
        
        // Create the sfap_api feedback request.
        let sfapApiFeedbackRequest = restRequestWithBodyString(
            sfapApiFeedbackRequestBodyString,
            path: "einstein/platform/v1/feedback"
        )
        
        // Submit the sfap_api feedback request and fetch the response.
        let sfapApiFeedbackResponse = await withCheckedContinuation { continuation in
            restClient.send(
                request: sfapApiFeedbackRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the sfap_api feedback response.
        switch sfapApiFeedbackResponse {
            
        case .success(let sfapApiFeedbackResponse):
            // Decode the sfap_api feedback response.
            let sfapApiFeedbackResponseBody = try sfapApiFeedbackResponse.asDecodable(
                type: SfapApiFeedbackResponseBody.self
            )
            sfapApiFeedbackResponseBody.sourceJson = sfapApiFeedbackResponse.asString()
            return sfapApiFeedbackResponseBody
            
        case .failure(let error):
            throw try errorForRestClientError(error, requestName: "feedback request")
        }
    }
    
    private func generateSfapApiHeaders() -> NSMutableDictionary {
        return [
            "x-sfdc-app-context" : "EinsteinGPT",
            "x-client-feature-id" : "ai-platform-models-connected-app"
        ]
    }
    
    private func requestBodyStringFromRequest(
        _ requestBody: Codable,
        named: String
    ) throws -> String {
        guard let requestBodyString = try {
            do { return String(
                data: try JSONEncoder().encode(requestBody),
                encoding: .utf8)
            } catch let error {
                throw sfapApiError(message: "Cannot JSON encode sfap_api \(named) body due to an encoding error with description '\(error.localizedDescription)'.")
            }}() else {
                throw sfapApiError(message: "Cannot JSON encode sfap_api \(named) body.")
            }
        return requestBodyString
    }
    
    private func restRequestWithBodyString(
        _ requestBodyString: String,
        path: String
    ) -> RestRequest {
        let restRequest = RestRequest(
            method: .POST,
            baseURL: "https://\(apiHostName)/",
            path: path,
            queryParams: nil)
        restRequest.customHeaders = generateSfapApiHeaders()
        restRequest.endpoint = ""
        restRequest.requiresAuthentication = true
        restRequest.setCustomRequestBodyString(
            requestBodyString,
            contentType: "application/json; charset=utf-8"
        )
        return restRequest
    }
    
    private func errorForRestClientError(_ restClientError: RestClientError, requestName: String) throws -> Error {
        switch restClientError {
            
        case .apiFailed(
            response: let response,
            underlyingError: _,
            urlResponse: _
        ): if let errorResponseData = response as? Data {
            let sfapApiErrorResponseBody = try JSONDecoder().decode(SfapApiErrorResponseBody.self, from: errorResponseData)
            return sfapApiError(
                errorCode: sfapApiErrorResponseBody.errorCode,
                message: "sfap_api \(requestName) failure with description: '\(restClientError.localizedDescription)', message: '\(String(describing: sfapApiErrorResponseBody.message))'.",
                messageCode: sfapApiErrorResponseBody.messageCode,
                source: String(data: errorResponseData, encoding: .utf8))
        } else { return restClientError }
            
        default: return restClientError
        }
    }
    
    private func sfapApiError(
        errorCode: String? = nil,
        message: String,
        messageCode: String? = nil,
        source: String? = nil) -> SfapApiError
    {
        SFSDKCoreLogger().e(classForCoder, message: message)
        
        return SfapApiError(
            errorCode: errorCode,
            message: message,
            messageCode: messageCode,
            source: source)
    }
}
