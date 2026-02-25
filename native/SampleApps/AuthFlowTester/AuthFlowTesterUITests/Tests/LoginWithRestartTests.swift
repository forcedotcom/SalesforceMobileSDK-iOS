/*
 LoginWithRestartTests.swift
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

/// Tests for verifying that user sessions persist across app restarts.
/// Includes tests for CA, ECA, and Beacon configurations with both static and dynamic settings.
///
/// NB: Tests use the second, third, fourth, and fifth users from ui_test_config.json
///
class LoginWithRestartTests: BaseAuthFlowTester {

    // MARK: - Legacy Login Persistence

    /// Login with CA, restart app, and verify session persists.
    func testCAOpaque_DefaultScopes_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .caOpaque
        )

        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .caOpaque
        )
    }

    // MARK: - ECA Login Persistence

    /// Login with ECA, restart app, and verify session persists.
    func testECAOpaque_DefaultScopes_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .ecaOpaque
        )

        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .ecaOpaque
        )
    }

    // MARK: - Beacon Login Persistence

    /// Login with Beacon, restart app, and verify session and child key persist.
    func testBeaconOpaque_DefaultScopes_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .beaconOpaque
        )

        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .beaconOpaque
        )
    }

    // MARK: - ECA Dynamic Configuration

    /// Login with ECA JWT using default scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            user: .second,
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt
        )
        restartAndValidateUser(
            user: .second,
            userAppConfigName: .ecaJwt
        )
    }

    /// Login with ECA JWT using subset of scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            user: .second,
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt,
            dynamicScopeSelection: .subset
        )
        
        restartAndValidateUser(
            user: .second,
            userAppConfigName: .ecaJwt,
            userScopeSelection: .subset
        )
    }

    // MARK: - Beacon Dynamic Configuration

    /// Login with Beacon JWT using default scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .second,
            staticAppConfigName: .beaconOpaque,
            dynamicAppConfigName: .beaconJwt
        )
        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .second,
            userAppConfigName: .beaconJwt
        )
    }

    /// Login with Beacon JWT using subset of scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .second,
            staticAppConfigName: .beaconOpaque,
            dynamicAppConfigName: .beaconJwt,
            dynamicScopeSelection: .subset
        )
        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .second,
            userAppConfigName: .beaconJwt,
            userScopeSelection: .subset
        )
    }

    // MARK: - Multi-User Restart

    /// Login multiple users with dynamic config, restart app, and verify all users persist correctly.
    func testMultiUserRestart() throws {
        // Login User A with dynamic config (ECA-Opaque)
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque,
            dynamicAppConfigName: .ecaOpaque
        )

        // Login User B with static config (ECA-JWT)
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaJwt
        )

        // Restart app
        restart()

        // Verify main page loads
        assertMainPageLoaded()

        // Verify and switch to User A
        switchToUserAndValidateUser(
            loginHost: .regularAuth,
            user: .fourth,
            userAppConfigName: .ecaOpaque,
            userScopeSelection: .empty
        )

        // Test API call for User A
        XCTAssertTrue(makeRestRequest(), "User A API should work after restart")

        // Verify and switch to User B
        switchToUserAndValidateUser(
            loginHost: .regularAuth,
            user: .fifth,
            userAppConfigName: .ecaJwt,
            userScopeSelection: .empty
        )

        // Test API call for User B
        XCTAssertTrue(makeRestRequest(), "User B API should work after restart")

        // Logout second user
        logout()
    }
}
