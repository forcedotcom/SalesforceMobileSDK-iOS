/*
 RTRLoginTests.swift
 AuthFlowTesterUITests

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

/// Tests for login flows using External Client App (ECA) configurations with Refresh Token Rotation (RTR).
///
/// NB: Tests use the first user from ui_test_config.json
///
class RTRLoginTests: BaseAuthFlowTester {

    // MARK: - ECA JWT RTR Tests

    /// Login with ECA JWT RTR using hybrid flow.
    func testECAJwtRtr_Hybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
    }

    /// Login with ECA JWT RTR using hybrid flow, restart app, and verify session persists.
    func testECAJwtRtr_Hybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
        restartAndValidateUser(userAppConfigName: .ecaJwtRtr)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, isJwt: true)
    }

    /// Login with ECA JWT RTR without hybrid flow.
    func testECAJwtRtr_NoHybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr, useHybridFlow: false)
    }

    /// Login with ECA JWT RTR without hybrid flow, restart app, and verify session persists.
    func testECAJwtRtr_NoHybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr, useHybridFlow: false)
        restartAndValidateUser(userAppConfigName: .ecaJwtRtr, useHybridFlow: false)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, useHybridFlow: false, isJwt: true)
    }

    // MARK: - ECA Opaque RTR Tests

    /// Login with ECA Opaque RTR using hybrid flow.
    func testECAOpaqueRtr_Hybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr)
    }

    /// Login with ECA Opaque RTR using hybrid flow, restart app, and verify session persists.
    func testECAOpaqueRtr_Hybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr)
        restartAndValidateUser(userAppConfigName: .ecaOpaqueRtr)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true)
    }

    /// Login with ECA Opaque RTR without hybrid flow.
    func testECAOpaqueRtr_NoHybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
    }

    /// Login with ECA Opaque RTR without hybrid flow, restart app, and verify session persists.
    func testECAOpaqueRtr_NoHybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
        restartAndValidateUser(userAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, useHybridFlow: false)
    }

    /// After RTR has been observed, the first token refresh in a new app process must send the
    /// persisted RT marker on the wire. This intentionally validates the captured token-request
    /// header rather than the user agent recomputed after the refresh response.
    func test_givenRTRObserved_whenColdRestartForcesRefresh_thenTokenRequestUserAgentContainsRT() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr)
        let credentialsBeforeRestart = getUserCredentials()

        // Expire the server-side session before terminating so the first REST call in the new
        // process takes the natural 401 -> token refresh -> replay path.
        XCTAssertTrue(revokeAccessToken(), "Access-token revoke should succeed before restart")
        restart(withLaunchArguments: ["--captureTokenRequestUserAgent"])

        XCTAssertTrue(makeRestRequest(), "REST request should succeed after the cold-start refresh")
        let credentialsAfterRefresh = getUserCredentials()
        XCTAssertNotEqual(credentialsBeforeRestart.accessToken, credentialsAfterRefresh.accessToken,
                          "Access token should change during the first post-restart refresh")
        XCTAssertNotEqual(credentialsBeforeRestart.refreshToken, credentialsAfterRefresh.refreshToken,
                          "RTR refresh token should rotate during the first post-restart refresh")

        let capturedUserAgent = credentialsAfterRefresh.lastTokenRequestUserAgent
        XCTAssertFalse(capturedUserAgent.isEmpty,
                       "AuthFlowTester should capture the outbound token-request User-Agent")
        let flags = featureMarkers(in: capturedUserAgent)
        XCTAssertTrue(flags.contains("RT"),
                      "First post-restart token request should contain persisted RT; flags: \(flags), ua: \(capturedUserAgent)")
        XCTAssertTrue(flags.contains("A2"),
                      "Token request should contain the credential owner's hybrid-flow marker; flags: \(flags), ua: \(capturedUserAgent)")
        XCTAssertTrue(flags.contains("OT"),
                      "Token request should contain the credential owner's opaque-token marker; flags: \(flags), ua: \(capturedUserAgent)")
        XCTAssertTrue(flags.contains("UA"),
                      "Token request should contain the always-registered UA global marker; flags: \(flags), ua: \(capturedUserAgent)")
    }

    /// Revoke once requests overlap, then verify coordinated replay and RTR recovery.
    func test_givenRTRRequestsInFlight_whenRevoked_thenBatchSettlesAndFollowUpSucceeds() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
        let credentialsBefore = getUserCredentials()

        startManyRestRequests(interruption: .revoke)
        XCTAssertTrue(waitForManyRequestsInterruptionRequested(), "Revoke should be requested after requests enter flight")
        XCTAssertTrue(waitForManyRequestsInterruptionCompleted(), "Revoke should complete")
        let result = try XCTUnwrap(waitForManyRequestsToComplete(expectedCount: 20))
        XCTAssertEqual(result.completed, 20)
        XCTAssertEqual(result.succeeded + result.failed, 20)
        XCTAssertEqual(result.queued, 0)
        XCTAssertEqual(result.inFlight, 0)

        XCTAssertTrue(makeRestRequest(), "A follow-up request should deterministically exercise recovery")
        let credentialsAfter = getUserCredentials()
        XCTAssertNotEqual(credentialsAfter.accessToken, credentialsBefore.accessToken)
        XCTAssertNotEqual(credentialsAfter.refreshToken, credentialsBefore.refreshToken)
    }

    private func featureMarkers(in userAgent: String) -> Set<String> {
        guard let range = userAgent.range(of: "ftr_") else { return [] }
        let markerString = String(userAgent[range.upperBound...]).components(separatedBy: " ").first ?? ""
        return Set(markerString.components(separatedBy: ".").filter { !$0.isEmpty })
    }
}
