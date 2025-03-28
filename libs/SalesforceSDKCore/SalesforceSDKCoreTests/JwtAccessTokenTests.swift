//
//  JwtAccessTokenTests.swift
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


import XCTest
@testable import SalesforceSDKCore

class JwtAccessTokenTests: XCTestCase {
    let header = "{\"tnk\":\"some-tnk\",\"ver\":\"1.0\",\"kid\":\"some-kid\",\"tty\":\"sfdc-core-token\",\"typ\":\"JWT\",\"alg\":\"RS256\"}"
    let payload = "{\"scp\":\"refresh_token web api\",\"aud\":[\"https://mobilesdkatsdb6.test1.my.pc-rnd.salesforce.com\"],\"sub\":\"uid:some-uid\",\"nbf\":1730386620,\"mty\":\"oauth\",\"sfi\":\"some-sfi\",\"roles\":[],\"iss\":\"https://mobilesdkatsdb6.test1.my.pc-rnd.salesforce.com\",\"hsc\":false,\"exp\":1730386695,\"iat\":1730386635,\"client_id\":\"some-client-id\"}"
    let signature = "FAKE_SIGNATURE"

    var testRawJwt: String {
        let base64Header = Data(header.utf8).base64EncodedString()
        let base64Payload = Data(payload.utf8).base64EncodedString()
        let base64Signature = Data(signature.utf8).base64EncodedString()
        
        return [base64Header, base64Payload, base64Signature].joined(separator: ".")
    }
    
    func testDecodeValidJwtAndParseHeader() {
        do {
            let decodedJwt = try JwtAccessToken(jwt: testRawJwt)
            XCTAssertNotNil(decodedJwt)

            let jwtHeader = decodedJwt.header
            XCTAssertNotNil(jwtHeader)

            XCTAssertEqual(jwtHeader.algorithm, "RS256")
            XCTAssertEqual(jwtHeader.type, "JWT")
            XCTAssertEqual(jwtHeader.keyId, "some-kid")
            XCTAssertEqual(jwtHeader.tokenType, "sfdc-core-token")
            XCTAssertEqual(jwtHeader.tenantKey, "some-tnk")
            XCTAssertEqual(jwtHeader.version, "1.0")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDecodeValidJwtAndParsePayload() {
        do {
            let decodedJwt = try JwtAccessToken(jwt: testRawJwt)
            XCTAssertNotNil(decodedJwt)

            let jwtPayload = decodedJwt.payload
            XCTAssertNotNil(jwtPayload)

            XCTAssertEqual(jwtPayload.audience, ["https://mobilesdkatsdb6.test1.my.pc-rnd.salesforce.com"])
            XCTAssertEqual(jwtPayload.expirationTime, 1730386695)
            XCTAssertEqual(jwtPayload.issuer, "https://mobilesdkatsdb6.test1.my.pc-rnd.salesforce.com")
            XCTAssertEqual(jwtPayload.notBeforeTime, 1730386620)
            XCTAssertEqual(jwtPayload.subject, "uid:some-uid")
            XCTAssertEqual(jwtPayload.scopes, "refresh_token web api")
            XCTAssertEqual(jwtPayload.clientId, "some-client-id")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidJwt() {
        let invalidRawJwt = "invalid-jwt-string"
        XCTAssertThrowsError(try JwtAccessToken(jwt: invalidRawJwt)) { error in
            XCTAssertEqual(error as? JwtAccessToken.JwtError, JwtAccessToken.JwtError.invalidFormat)
        }
    }
}
