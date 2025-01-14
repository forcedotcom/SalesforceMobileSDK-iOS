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

@objc(SFApApiClient)
public class SfapApiClient : NSObject {
    
    /// The sfap_api hostname
    private let apiHostName: String
    
    /// The sfap_api model name
    private let modelName: String?
    
    /// The REST client
    private let restClient: RestClient
    
    @objc
    public init(
        apiHostName: String,
        modelName: String? = nil,
        restClient: RestClient) {
            self.apiHostName = apiHostName
            self.modelName = modelName
            self.restClient = restClient
        }
    
    /// Fetches generated text from the `sfap_api` "generations" endpoint.
    /// - Parameters:
    ///   -  prompt: The prompt request parameter value
    /// - Returns: The endpoint's response
    @objc
    public func fetchGeneratedText(
        _ prompt: String
    ) async throws -> SfapApiGenerationsResponseBody {
        
        // Guards.
        guard let modelName = modelName else {
            throw sfapApiError(message: "Cannot fetch generated embeddings without specifying a model name.")
        }
        
        // Generate the sfap_api generations request body.
        guard let sfapApiGenerationsRequestBodyString = try {
            do { return String(
                data: try JSONEncoder().encode(
                    SfapApiGenerationsRequestBody(prompt: prompt)
                ),
                encoding: .utf8)
            } catch let error {
                throw sfapApiError(message: "Cannot JSON encode sfap_api generations request body due to an encoding error with description '\(error.localizedDescription)'.")
            }}() else {
                throw sfapApiError(message: "Cannot JSON encode sfap_api generations request body.")
            }
        
        // Create the sfap_api generations request.
        let sfapApiGenerationsRequest = RestRequest(
            method: .POST,
            baseURL: "https://\(apiHostName)/",
            path: "einstein/platform/v1/models/\(modelName)/generations",
            queryParams: nil)
        sfapApiGenerationsRequest.customHeaders = [
            "x-sfdc-app-context" : "EinsteinGPT",
            "x-client-feature-id" : "ai-platform-models-connected-app"
        ]
        sfapApiGenerationsRequest.endpoint = ""
        sfapApiGenerationsRequest.requiresAuthentication = true
        sfapApiGenerationsRequest.setCustomRequestBodyString(
            sfapApiGenerationsRequestBodyString,
            contentType: "application/json; charset=utf-8"
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
            return sfapApiGenerationsResponseBody
            
        case .failure(let error):
            switch error {
                
            case .apiFailed(
                response: let response,
                underlyingError: _,
                urlResponse: _
            ): if let errorResponseData = response as? Data {
                let sfapApiErrorResponseBody = try JSONDecoder().decode(SfapApiErrorResponseBody.self, from: errorResponseData)
                throw sfapApiError(
                    errorCode: sfapApiErrorResponseBody.errorCode,
                    message: "sfap_api generations request failure with description: '\(error.localizedDescription)', message: '\(String(describing: sfapApiErrorResponseBody.message))'.",
                    messageCode: sfapApiErrorResponseBody.messageCode,
                    source: String(data: errorResponseData, encoding: .utf8))
            } else { throw error }
                
            default: throw error
            }
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
