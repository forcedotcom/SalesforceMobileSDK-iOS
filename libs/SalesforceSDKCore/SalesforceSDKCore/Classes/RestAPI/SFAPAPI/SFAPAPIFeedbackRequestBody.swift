/*
 SFAPAPIFeedbackRequestBody.swift
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
 * Models a `sfap_api` `feedback` endpoint request.
 * See https://developer.salesforce.com/docs/einstein/genai/references/models-api?meta=generateText
 *
 * The endpoint accepts a `appFeedback` object.  To provide `appFeedback`, subclass and introduce a
 * new parameter of any object type named `appFeedback`.  Also, the subclass will need to conform to
 * `Codable` and provide handling for the custom `appFeedback` object's encoding and decoding as in
 * the following sample code.
 *   required init(from decoder: any Decoder) throws {
 *     let container = try decoder.container(keyedBy: CodingKeys.self)
 *     self.appFeedback = try container.decode(AppFeedback.self, forKey: .appFeedback)
 *     try super.init(from: decoder)
 *   }
 *
 *   public init(
 *       // Provide superclass parameters
 *     appFeedback: AppFeedback
 *   ) {
 *     self.appFeedback = appFeedback
 *      super.init( // Provide superclass parameters)
 *   }
 *
 *   public override func encode(to encoder: any Encoder) throws {
 *     var container = encoder.container(keyedBy: CodingKeys.self)
 *     try container.encode(appFeedback, forKey: .appFeedback)
 *     try super.encode(to: encoder)
 *   }
 */
@objc
public class SFAPAPIFeedbackRequestBody : NSObject, Codable {
    public let id: String?
    public let appGeneration: String?
    public let appGenerationId: String?
    public let feedback: String?
    public let feedbackText: String?
    public let generationId: String?
    public let source: String?
    
    public required init(
        id: String? = nil,
        appGeneration: String? = nil,
        appGenerationId: String? = nil,
        feedback: String?,
        feedbackText: String? = nil,
        generationId: String?,
        source: String? = nil
    ) {
        self.id = id
        self.appGeneration = appGeneration
        self.appGenerationId = appGenerationId
        self.feedback = feedback
        self.feedbackText = feedbackText
        self.generationId = generationId
        self.source = source
    }
}
