/*
 RefreshTokenMigrationWithRestartTests.swift
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

/// Tests for verifying that migrated refresh tokens persist across app restarts.
/// These tests combine migration scenarios with app restart validation to ensure
/// that token migrations are properly saved and restored.
///
/// NB: Tests use the third and fourth user from ui_test_config.json
///
class RefreshTokenMigrationWithRestartTests: BaseAuthFlowTester {

    /// Login with CA, migrate to ECA, restart app, and verify migrated tokens persist.
    func testMigrateCAToECA_WithRestart() throws {
        // Login with CA
        launchAndLogin(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .caOpaque
        )

        // Migrate to ECA
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .ecaOpaque
        )

        // Restart and validate migration persisted
        restartAndValidate(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .ecaOpaque
        )
    }

    /// Login with CA, migrate to Beacon, restart app, and verify beacon migration persists.
    func testMigrateCAToBeacon_WithRestart() throws {
        // Login with CA
        launchAndLogin(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .caOpaque
        )

        // Migrate to Beacon
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .beaconOpaque
        )

        // Restart and validate migration persisted
        restartAndValidate(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .beaconOpaque
        )
    }

    /// Login with subset scopes, migrate to all scopes, restart, and verify scope changes persist.
    func testMigrateScopeAddition_WithRestart() throws {
        // Login with subset scopes
        launchAndLogin(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .ecaJwt,
            staticScopeSelection: .subset
        )

        // Migrate to all scopes
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .ecaJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .ecaJwt,
            migrationScopeSelection: .all
        )

        // Restart and validate scope migration persisted
        restartAndValidate(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .ecaJwt,
            userScopeSelection: .all
        )
    }

    /// Login with Beacon subset scopes, migrate to all scopes, restart, and verify beacon scope migration persists.
    func testMigrateBeaconScopeAddition_WithRestart() throws {
        // Login with subset scopes
        launchAndLogin(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .beaconJwt,
            staticScopeSelection: .subset
        )

        // Migrate to all scopes
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .beaconJwt,
            migrationScopeSelection: .all
        )

        // Restart and validate scope migration persisted
        restartAndValidate(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .beaconJwt,
            userScopeSelection: .all
        )
    }

    /// Login multiple users with migrations, restart app, and verify all users and migrations persist.
    func testMigrateMultipleUsers_WithRestart() throws {
        // Login User A with CA Opaque
        launchAndLogin(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .caOpaque
        )

        // Migrate User A to ECA Opaque
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .ecaOpaque
        )

        // Add User B with Beacon Opaque
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .beaconOpaque
        )

        // Restart app
        restart()

        // Verify main page loads
        assertMainPageLoaded()

        // Switch to User A and validate
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .caOpaque,
            userAppConfigName: .ecaOpaque,
            userScopeSelection: .empty
        )

        // Switch to User B and validate
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque,
            userAppConfigName: .beaconOpaque,
            userScopeSelection: .empty
        )

        // Logout second user
        logout()
    }
}
