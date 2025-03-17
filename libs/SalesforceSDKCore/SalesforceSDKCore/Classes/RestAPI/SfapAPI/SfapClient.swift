/*
 SfapClient.swift
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
@objc(SFSfapClient)
public class SfapClient : NSObject {
    
    /// The sfap_api hostname
    private let apiHostName: String
    
    /// The sfap_api model name
    private let modelName: String?
    
    /// The REST client
    private let restClient: RestClient
    
    /**
     * Initializes a new SFapClient.
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
        requestBody: EmbeddingsRequestBody
    ) async throws -> EmbeddingsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapError(message: "Cannot fetch generated embeddings without specifying a model name.")
        }
        
        // Generate the sfap_api embeddings request body.
        let embeddingsRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "embeddings request")
        
        // Create the sfap_api embeddings request.
        let embeddingsRequest = restRequestWithBodyString(
            embeddingsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/embeddings"
        )
        
        let embeddingsResponse = try await restClient.send(request: embeddingsRequest)
        let embeddingsResponseBody = try embeddingsResponse.asDecodable(
            type: EmbeddingsResponseBody.self
        )
        embeddingsResponseBody.sourceJson = embeddingsResponse.asString()
        return embeddingsResponseBody
    }
    
    /**
     * Fetches generated chat responses from the `sfap_api` `chat-generations` endpoint.
     * - Parameters:
     *   - requestBody: The `chat-generations` request body
     * - Returns: The endpoint's response
     */
    @objc
    public func fetchGeneratedChat(
        requestBody: ChatGenerationsRequestBody
    ) async throws -> ChatGenerationsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapError(message: "Cannot fetch generated chat responses without specifying a model name.")
        }
        
        // Generate the sfap_api generate chat request body.
        let chatGenerationsRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "chat generations request")
        
        // Create the sfap_api chat generations request.
        let chatGenerationsRequest = restRequestWithBodyString(
            chatGenerationsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/chat-generations"
        )
        
        let chatGenerationsResponse = try await restClient.send(request: chatGenerationsRequest)
        let chatGenerationsResponseBody = try chatGenerationsResponse.asDecodable(
            type: ChatGenerationsResponseBody.self
        )
        chatGenerationsResponseBody.sourceJson = chatGenerationsResponse.asString()
        return chatGenerationsResponseBody
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
    ) async throws -> GenerationsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapError(message: "Cannot fetch generated text without specifying a model name.")
        }
        
        // Generate the sfap_api generations request body.
        let generationsRequestBodyString = try requestBodyStringFromRequest(
            GenerationsRequestBody(prompt: prompt),
            named: "generations request")
        
        // Create the sfap_api generations request.
        let generationsRequest = restRequestWithBodyString(
            generationsRequestBodyString,
            path: "einstein/platform/v1/models/\(modelName)/generations"
        )
        
        let generationsResponse = try await restClient.send(request: generationsRequest)
        let generationsResponseBody = try generationsResponse.asDecodable(
            type: GenerationsResponseBody.self
        )
        generationsResponseBody.sourceJson = generationsResponse.asString()
        return generationsResponseBody
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
        requestBody: FeedbackRequestBody
    ) async throws -> FeedbackResponseBody {
        
        // Generate the sfap_api feedback request body.
        let feedbackRequestBodyString = try requestBodyStringFromRequest(
            requestBody,
            named: "feedback request")
        
        // Create the sfap_api feedback request.
        let feedbackRequest = restRequestWithBodyString(
            feedbackRequestBodyString,
            path: "einstein/platform/v1/feedback"
        )
        
        let feedbackResponse = try await restClient.send(request: feedbackRequest)
        let feedbackResponseBody = try feedbackResponse.asDecodable(
            type: FeedbackResponseBody.self
        )
        feedbackResponseBody.sourceJson = feedbackResponse.asString()
        return feedbackResponseBody
    }
    
    private func generateHeaders() -> NSMutableDictionary {
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
                throw sfapError(message: "Cannot JSON encode sfap_api \(named) body due to an encoding error with description '\(error.localizedDescription)'.")
            }}() else {
                throw sfapError(message: "Cannot JSON encode sfap_api \(named) body.")
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
        restRequest.customHeaders = generateHeaders()
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
            let errorResponseBody = try JSONDecoder().decode(SfapErrorResponseBody.self, from: errorResponseData)
            return sfapError(
                errorCode: errorResponseBody.errorCode,
                message: "sfap_api \(requestName) failure with description: '\(restClientError.localizedDescription)', message: '\(String(describing: errorResponseBody.message))'.",
                messageCode: errorResponseBody.messageCode,
                source: String(data: errorResponseData, encoding: .utf8))
        } else { return restClientError }
            
        default: return restClientError
        }
    }
    
    private func sfapError(
        errorCode: String? = nil,
        message: String,
        messageCode: String? = nil,
        source: String? = nil) -> SfapError
    {
        SFSDKCoreLogger().e(classForCoder, message: message)
        
        return SfapError(
            errorCode: errorCode,
            message: message,
            messageCode: messageCode,
            source: source)
    }
}
