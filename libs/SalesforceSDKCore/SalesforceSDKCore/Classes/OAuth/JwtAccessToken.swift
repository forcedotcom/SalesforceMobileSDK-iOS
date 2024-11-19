//
//  JwtAccessToken.swift
//  SalesforceSDKCore
//
//  Created by Wolfgang Mathurin on 11/18/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
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

/// Struct representing a JWT Header
public struct JwtHeader: Codable {
    let algorithm: String?
    let type: String?
    let keyId: String?
    let tokenType: String?
    let tenantKey: String?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case algorithm = "alg"
        case type = "typ"
        case keyId = "kid"
        case tokenType = "tty"
        case tenantKey = "tnk"
        case version = "ver"
    }
}

/// Struct representing a JWT Payload
public struct JwtPayload: Codable {
    let audience: [String]?
    let expirationTime: Int?
    let issuer: String?
    let notBeforeTime: Int?
    let subject: String?
    let scopes: String?
    let clientId: String?

    enum CodingKeys: String, CodingKey {
        case audience = "aud"
        case expirationTime = "exp"
        case issuer = "iss"
        case notBeforeTime = "nbf"
        case subject = "sub"
        case scopes = "scp"
        case clientId = "client_id"
    }
}

/// Class representing a JWT Access Token
public class JwtAccessToken {
    let rawJwt: String
    let header: JwtHeader
    let payload: JwtPayload

    /// Initializer to parse and decode the JWT string
    init(jwt: String) throws {
        self.rawJwt = jwt
        self.header = try JwtAccessToken.parseJwtHeader(jwt: jwt)
        self.payload = try JwtAccessToken.parseJwtPayload(jwt: jwt)
    }

    /// Helper method to decode the JWT Header
    private static func parseJwtHeader(jwt: String) throws -> JwtHeader {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw JwtError.invalidFormat
        }

        let headerJson = try decodeBase64Url(String(parts[0]))
        let data = Data(headerJson.utf8)
        return try JSONDecoder().decode(JwtHeader.self, from: data)
    }

    /// Helper method to decode the JWT Payload
    private static func parseJwtPayload(jwt: String) throws -> JwtPayload {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw JwtError.invalidFormat
        }

        let payloadJson = try decodeBase64Url(String(parts[1]))
        let data = Data(payloadJson.utf8)
        return try JSONDecoder().decode(JwtPayload.self, from: data)
    }

    /// Helper method to decode Base64 URL-encoded strings
    private static func decodeBase64Url(_ string: String) throws -> String {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }

        guard let data = Data(base64Encoded: base64),
              let decodedString = String(data: data, encoding: .utf8) else {
            throw JwtError.invalidBase64
        }
        return decodedString
    }

    /// Custom errors for JWT decoding
    enum JwtError: Error {
        case invalidFormat
        case invalidBase64
    }
}
