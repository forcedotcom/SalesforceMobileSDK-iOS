/*
 SFOAuthErrorCodeTests.swift
 SalesforceSDKCoreTests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

import XCTest
@testable import SalesforceSDKCore

class SFOAuthErrorCodeTests: XCTestCase {

    func testFrom_knownAppAttestFailedValue_returnsAppAttestationFailed() {
        XCTAssertEqual(SFOAuthErrorCode.from("app_attest_failed"), .appAttestationFailed)
    }

    func testFrom_knownAppAttestFailedRetryValue_returnsAppAttestationFailedRetry() {
        XCTAssertEqual(SFOAuthErrorCode.from("app_attest_failed_retry"), .appAttestationFailedRetry)
    }

    func testFrom_knownUnsupportedGrantType_returnsUnsupportedGrantType() {
        XCTAssertEqual(SFOAuthErrorCode.from("unsupported_grant_type"), .unsupportedGrantType)
    }

    func testFrom_unknownValue_returnsUnknown() {
        XCTAssertEqual(SFOAuthErrorCode.from("not_a_real_error"), .unknown)
    }

    func testFrom_nil_returnsUnknown() {
        XCTAssertEqual(SFOAuthErrorCode.from(nil), .unknown)
    }

    func testFrom_emptyString_returnsUnknown() {
        XCTAssertEqual(SFOAuthErrorCode.from(""), .unknown)
    }

    func testFrom_invalidDpopProof_returnsInvalidDpopProof() {
        XCTAssertEqual(SFOAuthErrorCode.from("invalid_dpop_proof"), .invalidDpopProof)
    }

    func testFrom_useDpopNonce_returnsUseDpopNonce() {
        XCTAssertEqual(SFOAuthErrorCode.from("use_dpop_nonce"), .useDpopNonce)
    }

    func testFrom_allKnownValues_roundTrip() {
        let knownCases = SFOAuthErrorCode.allCases.filter { $0 != .unknown }
        for code in knownCases {
            guard let wire = code.wireValue else {
                XCTFail("Non-unknown case \(code) has nil wireValue")
                continue
            }
            XCTAssertEqual(SFOAuthErrorCode.from(wire), code,
                           "Round-trip failed for \(code) (wire: \(wire))")
        }
    }
}
