/*
 EmbeddingsResponseBody.swift
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
 * Models a `sfap_api` `embeddings` endpoint response.
 */
@objc(SFEmbeddingsResponseBody)
public class EmbeddingsResponseBody : NSObject, Codable {
    public let embeddings: Array<Embedding>?
    public let parameters: Parameters?
    
    public struct Embedding : Codable {
        public let embedding: Array<Double>?
        public let index: Int?
    }
    
    public struct Parameters : Codable {
        public let model: String?
        public let `object`: String?
        public let usage: Usage?
        
        public struct Usage : Codable {
            public let promptTokens: Int?
            public let totalTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    /** The original JSON used to initialize this response body */
    internal(set) public var sourceJson: String?
}
