/*
 RefreshTokenMigrationTests.swift
 AuthFlowTesterUITests

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

import XCTest

/// Tests for migrating refresh tokens between different app configurations.
/// These tests verify that users can seamlessly transition between app types
/// (CA, ECA, Beacon) and token formats (opaque, JWT) without re-authentication.
///
/// NB: Tests use the second user from ui_test_config.json
///
class RefreshTokenMigrationTests: BaseAuthFlowTester {
    
    // MARK: - Migration within same app (scope upgrade)
    
    /// Migrate within same CA (scope upgrade).
    func testMigrateCA_AddMoreScopes() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caJwt,
            staticScopeSelection: .subset
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .caJwt,
            migrationScopeSelection: .all
        )
    }
    
    /// Migrate within same ECA (scope upgrade).
    func testMigrateECA_AddMoreScopes() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .ecaJwt,
            staticScopeSelection: .subset
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .ecaJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .ecaJwt,
            migrationScopeSelection: .all
        )
    }
    
    /// Migrate within same Beacon (scope upgrade).
    func testMigrateBeacon_AddMoreScopes() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .beaconJwt,
            staticScopeSelection: .subset
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .beaconJwt,
            migrationScopeSelection: .all
        )
    }
    
    // MARK: - Migration to or from beacon
    
    // Migrate from CA to Beacon
    func testMigrateCAToBeacon() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .beaconOpaque
        )
    }
    
    // Migrate from Beacon to CA
    func testMigrateBeaconToCA() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .beaconOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconOpaque,
            migrationAppConfigName: .caOpaque
        )
    }
    
    // MARK: - Migration with auth flow type change (user agent to web server flow)

    // The initial login in these tests uses the user agent flow, which is incompatible with forced
    // advanced authentication (advanced auth always uses the web server flow), so the initial login
    // disables advanced auth to exercise the legacy in-app WebView path. The migration step is a
    // refresh-token exchange (no interactive browser login), so the flag is irrelevant to it and the
    // migration keeps its default web server flow.

    // Migrate from CA (user agent) to ECA (web server)
    func testMigrateCAUserAgentToECAWebServer() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caOpaque,
            useWebServerFlow: false,
            forceAdvancedAuthentication: false
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .ecaOpaque,
            migrationUseWebServerFlow: true,
            forceAdvancedAuthentication: false
        )
    }

    // Migrate from CA (user agent) to Beacon (web server)
    func testMigrateCAUserAgentToBeaconWebServer() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caOpaque,
            useWebServerFlow: false,
            forceAdvancedAuthentication: false
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .beaconOpaque,
            migrationUseWebServerFlow: true,
            forceAdvancedAuthentication: false
        )
    }
    
    // MARK: - Cross-App Migrations with rollbacks
    
    /// Migrate from CA to ECA and back to CA
    func testMigrateCAToECA() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .ecaOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque, // should not have changed
            migrationAppConfigName: .caOpaque
        )
    }
    
    // Migrate from CA to Beacon and back to CA
    func testMigrateCAToBeaconAndBack() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .caOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .beaconOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque, // should not have changed
            migrationAppConfigName: .caOpaque
        )
    }
    
    /// Migrate from Beacon opaque to Beacon JWT and back to Beacon opaque
    func testMigrateBeaconOpaqueToJWTAndBack() throws {
        launchAndLogin(
            loginHost: .regularAuth,
            user:.second,
            staticAppConfigName: .beaconOpaque
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconOpaque,
            migrationAppConfigName: .beaconJwt
        )
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconOpaque, // should not have changed
            migrationAppConfigName: .beaconOpaque
        )
    }

    // MARK: - Multi-User Migration Scenarios

    /// After migration User A has TM+JT+BN (A2 preserved from initial login, TM set).
    /// User B logs in fresh with A1+OT, no TM. Four per-user flags differ simultaneously,
    /// making leakage between migrated and non-migrated users fully detectable.
    func testFlagDiversity_MigratedBeaconJwtVsNonHybridOpaque() throws {
        // User A: initial login with CA Opaque (A2, OT)
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque
        )

        // Migrate User A to Beacon JWT → A2 preserved, TM set, JT set, BN set
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            staticScopeSelection: .empty,
            migrationAppConfigName: .beaconJwt,
            migrationScopeSelection: .empty
        )

        // User B: fresh login with CA Opaque, non-hybrid → A1, OT, no TM, no BN
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque,
            useHybridFlow: false,
            forceAdvancedAuthentication: true
        )

        // Switch to User A — TM, JT, BN, A2, MU must all be present
        switchToUser(loginHost: .regularAuth, user: .fourth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerHybrid,
            wasMigrated: true,
            isJwt: true,
            isBeacon: true
        )

        // Switch to User B — A1, OT, no TM, no BN, MU must be present
        switchToUser(loginHost: .regularAuth, user: .fifth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerNonHybrid,
            wasMigrated: false,
            isJwt: false,
            isBeacon: false
        )

        // Logout User B — User A active again, MU must clear
        logout()
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: false,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerHybrid,
            wasMigrated: true,
            isJwt: true,
            isBeacon: true
        )
    }

    /// Migrate User A while User B remains unchanged.
    /// Tests that migrating one user does not affect other logged-in users.
    func testMigrateOneUserOnly() throws {
        // Login User A with CA Opaque
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque
        )

        // Login User B with CA Opaque
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque
        )

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Migrate User A to ECA Opaque (User B is still logged in)
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .caOpaque,
            migrationAppConfigName: .ecaOpaque,
            isMultiUser: true
        )

        // Switch to User B and verify unchanged (still CA Opaque)
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque,
            userAppConfigName: .caOpaque,
            isMultiUser: true
        )

        // Switch back to User A and verify migration persisted (ECA Opaque, with TM flag)
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque,
            userAppConfigName: .ecaOpaque,
            isMultiUser: true,
            wasMigrated: true
        )

        // Test API calls for both users
        XCTAssertTrue(makeRestRequest(), "User A API should work")

        switchToUser(loginHost: .regularAuth, user: .fifth)
        XCTAssertTrue(makeRestRequest(), "User B API should work")

        // Logout second user
        logout()
    }
}

