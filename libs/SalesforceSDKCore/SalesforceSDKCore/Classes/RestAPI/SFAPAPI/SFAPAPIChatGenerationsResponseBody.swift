/*
 SFAPAPIChatGenerationsResponseBody.swift
 SalesforceSDKCore
 
 Created by Eric C. Johnson (Johnson.Eric@Salesforce.com) on 20250114.
 
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
 * Models a `sfap_api` "chat-generations" endpoint response.
 */
@objc
public class SFAPAPIChatGenerationsResponseBody : NSObject, Codable {
    public let id: String?
    public let generationDetails: GenerationDetails?
    
    /** The original JSON used to initialize this response body */
    internal(set) public var sourceJson: String?
    
    public struct GenerationDetails : Codable {
        public let generations: Array<Generation>?
        public let parameters: Parameters?
        
        public struct Generation : Codable {
            public let id: String?
            public let content: String?
            public let contentQuality: ContentQuality?
            public let parameters: Parameters?
            public let role: String?
            public let timestamp: Int64?
            
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
            
            public struct ContentQuality : Codable {
                public let scanToxicity: ScanToxicity?
                
                public struct ScanToxicity : Codable {
                    public let isDetected: Bool?
                    public let categories: Array<Category>?
                    
                    public struct Category : Codable {
                        public let categoryName: String?
                        public let score: Double?
                    }
                }
            }
        }
    }
    
    public struct Parameters : Codable {
        public let created: Int?
        public let model: String?
        public let object: String?
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
}
