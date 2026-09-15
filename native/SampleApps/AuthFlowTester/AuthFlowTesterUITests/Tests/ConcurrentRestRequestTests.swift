/*
 ConcurrentRestRequestTests.swift
 AuthFlowTesterUITests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
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

/// Shared UI and lifecycle coverage for the concurrent REST stress surface.
class ConcurrentRestRequestTests: BaseAuthFlowTester {

    func test_givenValidRTRSession_whenMakingTwentyMixedRequests_thenAllSucceed() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
        let credentialsBeforeBatch = getUserCredentials()

        startManyRestRequests()
        let result = try XCTUnwrap(waitForManyRequestsToComplete(expectedCount: 20))

        assertSuccessfulBatch(result)
        XCTAssertTrue(manyRequestType(at: 1).contains("API Resources"))
        XCTAssertTrue(manyRequestType(at: 2).contains("API Resources"))
        XCTAssertTrue(manyRequestType(at: 3).contains("Describe Global"))
        XCTAssertNotEqual(manyRequestType(at: 1), manyRequestType(at: 3))
        let credentialsAfterBatch = getUserCredentials()
        XCTAssertEqual(credentialsAfterBatch.accessToken, credentialsBeforeBatch.accessToken)
        XCTAssertEqual(credentialsAfterBatch.refreshToken, credentialsBeforeBatch.refreshToken)
    }

    func test_givenDeterministicRequestFailure_whenTappingRedSquare_thenDetailsAreShown() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
        restart(withLaunchArguments: ["--failManyRequestAtIndex=3"])

        startManyRestRequests(count: 5)
        let result = try XCTUnwrap(waitForManyRequestsToComplete(expectedCount: 5))

        XCTAssertEqual(result.completed, 5)
        XCTAssertEqual(result.succeeded, 4)
        XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(result.queued, 0)
        XCTAssertEqual(result.inFlight, 0)
        XCTAssertEqual(manyRequestState(at: 3), "Failed")

        tapFailedManyRequest(at: 3)
        XCTAssertTrue(isShowingManyRequestErrorDetails())
        XCTAssertEqual(manyRequestErrorDetail(identifier: "manyRequestErrorNumber"), "3")
        XCTAssertEqual(manyRequestErrorDetail(identifier: "manyRequestErrorType"), "Intentional Failure")
        XCTAssertTrue(manyRequestErrorDetail(identifier: "manyRequestErrorEndpoint").contains("auth-flow-tester-intentional-failure"))
        XCTAssertNotEqual(manyRequestErrorDetail(identifier: "manyRequestErrorStatus"), "Unavailable")
        XCTAssertFalse(manyRequestErrorDetail(identifier: "manyRequestErrorMessage").isEmpty)
        XCTAssertTrue(hasManyRequestErrorCopyAction())
    }

    func test_givenRTRRequestsInFlight_whenLoggingOut_thenColdRelaunchStaysLoggedOut() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)

        startManyRestRequests(interruption: .logout)
        XCTAssertTrue(waitForLoggedOut(), "Logout under load should return to an unauthenticated login surface")

        restart()
        XCTAssertTrue(waitForLoggedOut(), "A cold relaunch must not resurrect the logged-out user")
    }

    private func assertSuccessfulBatch(_ result: ManyRequestsResult, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.total, 20, file: file, line: line)
        XCTAssertEqual(result.completed, result.total, file: file, line: line)
        XCTAssertEqual(result.succeeded, result.total, file: file, line: line)
        XCTAssertEqual(result.failed, 0, file: file, line: line)
        XCTAssertEqual(result.queued, 0, file: file, line: line)
        XCTAssertEqual(result.inFlight, 0, file: file, line: line)
        XCTAssertGreaterThan(result.peakInFlight, 1, "The requests should overlap", file: file, line: line)
    }
}
