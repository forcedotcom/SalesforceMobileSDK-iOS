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
    private let testRawJwt = "eyJ0bmsiOiJjb3JlL2ZhbGNvbnRlc3QxLWNvcmU0c2RiNi8wMERTRzAwMDAwOUZZVmQyQU8iLCJ2ZXIiOiIxLjAiLCJraWQiOiJDT1JFX0FUSldULjAwRFNHMDAwMDA5RllWZC4xNzI1NTc5NDIwMTI1IiwidHR5Ijoic2ZkYy1jb3JlLXRva2VuIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYifQ.eyJzY3AiOiJyZWZyZXNoX3Rva2VuIHdlYiBhcGkiLCJhdWQiOlsiaHR0cHM6Ly9tb2JpbGVzZGthdHNkYjYudGVzdDEubXkucGMtcm5kLnNhbGVzZm9yY2UuY29tIl0sInN1YiI6InVpZDowMDVTRzAwMDAwOGVpQWJZQUkiLCJuYmYiOjE3MzAzODY2MjAsIm10eSI6Im9hdXRoIiwic2ZpIjoiYTZjZjk1MjY2NjYzM2Q4ZDUxMDUzNjkzNDcwZDczYzVhOTY4ZTA4NmQ1OGQ2NzlmYTVjMzY1ZmNhMGZiZjhkYyIsInJvbGVzIjpbXSwiaXNzIjoiaHR0cHM6Ly9tb2JpbGVzZGthdHNkYjYudGVzdDEubXkucGMtcm5kLnNhbGVzZm9yY2UuY29tIiwiaHNjIjpmYWxzZSwiZXhwIjoxNzMwMzg2Njk1LCJpYXQiOjE3MzAzODY2MzUsImNsaWVudF9pZCI6IjNNVkc5LkFnd3RvSXZFUlNkOGk4bGVQcnFmczdDYXpSeDJsbGJMOHViTm9HNlIzSHNZb21RRlJwYmF5YU1INEh0ekgzemowTkRFbUMwUElvaHcwUGYifQ.R8RDUDlRD-6LIzV2epi8y7m1_zWBwfvmTAhUiGOjg1fDWGxsX48hSi95WITHtZ-D-gDQEjVl1GBGKsIe7jEBdGkhoFhbUuYFEnd15bcYlmLBIpmRdSbSvImusaeGVBx2hLhv4Icl7md_BuNoiz6BpuV-T_0a0QxRkpo97sGN1MghO6m9ItzXY9ldR7m5_pOORy3eZ1q4JZ1aj49pphom_O_ZQAeWYX7Gp9dZjhxlLFYgk0XrarC689LOhfSAyBhJO-OvtgKrvUY1XiWEaZR3A2FAk-AK1ZrNenKB_76JGEppuODCpRyqiUUlLmFkzcx897KeTQGoC_QDrdn0y4speA"

    func testDecodeValidJwtAndParseHeader() {
        do {
            let decodedJwt = try JwtAccessToken(jwt: testRawJwt)
            XCTAssertNotNil(decodedJwt)

            let jwtHeader = decodedJwt.header
            XCTAssertNotNil(jwtHeader)

            XCTAssertEqual(jwtHeader.algorithm, "RS256")
            XCTAssertEqual(jwtHeader.type, "JWT")
            XCTAssertEqual(jwtHeader.keyId, "CORE_ATJWT.00DSG000009FYVd.1725579420125")
            XCTAssertEqual(jwtHeader.tokenType, "sfdc-core-token")
            XCTAssertEqual(jwtHeader.tenantKey, "core/falcontest1-core4sdb6/00DSG000009FYVd2AO")
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
            XCTAssertEqual(jwtPayload.subject, "uid:005SG000008eiAbYAI")
            XCTAssertEqual(jwtPayload.scopes, "refresh_token web api")
            XCTAssertEqual(jwtPayload.clientId, "3MVG9.AgwtoIvERSd8i8lePrqfs7CazRx2llbL8ubNoG6R3HsYomQFRpbayaMH4HtzH3zj0NDEmC0PIohw0Pf")
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
