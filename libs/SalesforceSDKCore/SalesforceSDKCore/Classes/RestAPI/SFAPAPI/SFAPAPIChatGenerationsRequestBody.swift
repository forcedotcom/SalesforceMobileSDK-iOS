/*
 SFAPAPIChatGenerationsRequestBody.swift
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
 * Models a `sfap_api` `chat-generations` endpoint request.
 * See https://developer.salesforce.com/docs/einstein/genai/references/models-api?meta=generateChat
 *
 * The endpoint accepts a `tags` object.  To provide `tags`, subclass and introduce a
 * new parameter of any object type named `tags`.  Also, the subclass will need to conform to
 * `Codable` and provide handling for the custom `tags` object's encoding and decoding as in
 * the following sample code.
 *   required init(from decoder: any Decoder) throws {
 *     let container = try decoder.container(keyedBy: CodingKeys.self)
 *     self.tags = try container.decode(Tags.self, forKey: .tags)
 *     try super.init(from: decoder)
 *   }
 *
 *   public init(
 *       // Provide superclass parameters
 *     tags: Tags
 *   ) {
 *     self.tags = tags
 *      super.init( // Provide superclass parameters)
 *   }
 *
 *   public override func encode(to encoder: any Encoder) throws {
 *     var container = encoder.container(keyedBy: CodingKeys.self)
 *     try container.encode(tags, forKey: .tag`)
 *     try super.encode(to: encoder)
 *   }
 */
@objc
open class SFAPAPIChatGenerationsRequestBody : NSObject, Codable {
    
    /// The request messages parameter value
    public let messages: Array<Message>
    
    /// The request localization parameter value
    public let localization: Localization
    
    public init(
        messages: Array<Message>,
        localization: Localization
    ) {
        self.messages = messages
        self.localization = localization
    }
    
    public struct Message : Codable {
        public let role: String
        public let content: String
        
        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }
    
    public struct Localization : Codable {
        public let defaultLocale: String
        public let inputLocales: Array<Locale>
        public let expectedLocales: Array<String>
        
        public init(
            defaultLocale: String,
            inputLocales: Array<Locale>,
            expectedLocales: Array<String>
        ) {
            self.defaultLocale = defaultLocale
            self.inputLocales = inputLocales
            self.expectedLocales = expectedLocales
        }
    }
    
    public struct Locale : Codable {
        public let locale: String
        public let probability: Double
        
        public init(
            locale: String,
            probability: Double
        ) {
            self.locale = locale
            self.probability = probability
        }
    }
}
