/*
 SfapApiGenerationsResponseBody.swift
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

/// Models a `sfap_api` "generations" endpoint response.
/// See https://developer.salesforce.com/docs/einstein/genai/references/models-api?meta=generateText
@objc
public class SfapApiGenerationsResponseBody: NSObject, Codable {
    public let id: String?
    public let generation: Generation?
    public let moreGenerations: String?
    public let parameters: Parameters?
    public let prompt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case generation = "generation"
        case moreGenerations = "moreGenerations"
        case parameters = "parameters"
        case prompt = "prompt"
    }
    
    /// The original JSON used to initialize this response body
    public var sourceJson: String?
    
    public struct Generation: Codable {
        public let id: String?
        public let contentQuality: ContentQuality?
        public let generatedText: String?
        public let parameters: Parameters?
        
        enum CodingKeys: String, CodingKey {
            case id = "id"
            case contentQuality = "contentQuality"
            case generatedText = "generatedText"
            case parameters = "parameters"
        }
        
        public struct Parameters : Codable {
            public let finishReason: String?
            public let refusal: String?
            public let index: Int?
            public let logprobs: String?
            
            enum CodingKeys: String, CodingKey {
                case finishReason = "finish_reason"
                case refusal = "refusal"
                case index = "index"
                case logprobs = "logprobs"
            }
        }
        
        public struct ContentQuality: Codable {
            public let scanToxicity: ScanToxicity?
            
            enum CodingKeys: String, CodingKey {
                case scanToxicity = "scanToxicity"
            }
            
            public struct ScanToxicity: Codable {
                public let isDetected: Bool?
                public let categories: Array<Category>?
                
                enum CodingKeys: String, CodingKey {
                    case isDetected = "isDetected"
                    case categories = "categories"
                }
                
                public struct Category : Codable {
                    public let categoryName: String?
                    public let score: Double?
                    
                    enum CodingKeys: String, CodingKey {
                        case categoryName = "categoryName"
                        case score = "score"
                    }
                }
            }
        }
    }
    
    public struct Parameters : Codable {
        public let created: Int?
        public let model: String?
        public let `object`: String?
        public let systemFingerprint: String?
        public let usage: Usage?
        
        enum CodingKeys: String, CodingKey {
            case created = "created"
            case model = "model"
            case object = "object"
            case systemFingerprint = "system_fingerprint"
            case usage = "usage"
        }
        
        public struct Usage : Codable {
            public let completionTokens: Int?
            public let completionTokensDetails: CompletionTokensDetails?
            public let promptTokens: Int?
            public let promptTokensDetails: PromptTokensDetails?
            public let totalTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case completionTokens = "completion_tokens"
                case completionTokensDetails = "completion_tokens_details"
                case promptTokens = "prompt_tokens"
                case promptTokensDetails = "prompt_tokens_details"
                case totalTokens = "total_tokens"
            }
            
            public struct CompletionTokensDetails : Codable {
                public let reasoningTokens: Int = 0
                public let audioTokens: Int = 0
                public let acceptedPredictionTokens: Int = 0
                public let rejectedPredictionTokens: Int = 0
                
                enum CodingKeys: String, CodingKey {
                    case reasoningTokens = "reasoning_tokens"
                    case audioTokens = "audio_tokens"
                    case acceptedPredictionTokens = "accepted_prediction_tokens"
                    case rejectedPredictionTokens = "rejected_prediction_tokens"
                }
            }
            
            public struct PromptTokensDetails : Codable {
                public let cachedTokens: Int = 0
                public let audioTokens: Int = 0
                
                enum CodingKeys: String, CodingKey {
                    case cachedTokens = "cached_tokens"
                    case audioTokens = "audio_tokens"
                }
            }
        }
    }
    
    /// Returns an `sfap_api` "generations" endpoint response from the JSON text.
    /// - Parameters:
    /// - json The JSON text
    /// - Return: The `sfap_api` "generations" endpoint response body or nil if a value cannot be
    ///  returned for any reason.  A log entry will be output when nil is returned do to an error
    static func fromJson(json: String) -> SfapApiGenerationsResponseBody? {
        guard let result: SfapApiGenerationsResponseBody? = {
            do {
                if let data = json.data(using: .utf8) {
                    return try JSONDecoder.init().decode(SfapApiGenerationsResponseBody.self, from: data)
                } else { return nil }
            } catch let error {
                SFSDKCoreLogger().e(
                    SfapApiClient.classForCoder(),
                    message: "Cannot JSON decode sfap_api generations request body due to a decoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return nil }
        result?.sourceJson = json
        return result
    }
}
