/*
 SfapApiGenerationsRequestBody.swift
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
 Models a `sfap_api` `generations` endpoint request.
 See https://developer.salesforce.com/docs/einstein/genai/references/models-api?meta=generateText
 */
struct SfapApiGenerationsRequestBody: Codable {
    
    /// The request prompt parameter value
    public let prompt: String
    
    enum CodingKeys: String, CodingKey {
        case prompt = "prompt"
    }
    
    /// Returns a JSON representation of this sfap_api generations request body.
    /// - Returns: A JSON representation of this sfap_api generations request body or nil if a value
    ///  cannot be returned for any reason.  A log entry will be output when nil is returned do to an error
    ///
    func toJson() -> String? {
        // Generate the start registration request body.
        guard let startRegistrationRequestBodyString = {
            do { return String(
                data: try JSONEncoder().encode(self),
                encoding: .utf8)
            } catch let error {
                SFSDKCoreLogger().e(
                    SfapApiClient.classForCoder(),
                    message: "Cannot JSON encode sfap_api generations request body due to an encoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return nil }
        return startRegistrationRequestBodyString
    }
}
