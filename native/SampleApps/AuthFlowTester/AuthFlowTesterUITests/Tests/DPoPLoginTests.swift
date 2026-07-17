/*
 DPoPLoginTests.swift
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

/// Tests for login flows using External Client App (ECA) configurations with DPoP token binding.
///
/// NB: Tests use users from ui_test_config.json across multiple scenarios
///
class DPoPLoginTests: BaseAuthFlowTester {

    // MARK: - ECA JWT DPoP Tests

    /// Login with ECA JWT DPoP using hybrid flow and verify DPoP token binding.
    func test_givenDPoPHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpop, forceAdvancedAuthentication: false, useDPoP: true)
        // Two revoke/refresh cycles verify DPoP binding survives a second nonce rotation
        // (parity with Android's `testECAJwtDPoP_Hybrid`).
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true)
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true)
    }

    /// Login with ECA JWT DPoP without hybrid flow and verify DPoP token binding.
    func test_givenDPoPNoHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpop, useHybridFlow: false, forceAdvancedAuthentication: false, useDPoP: true)
        // Two revoke/refresh cycles verify DPoP binding survives a second nonce rotation
        // (parity with Android's `testECAJwtDPoP_NoHybrid`).
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true)
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true)
    }

    // MARK: - ECA JWT DPoP+RTR Tests

    /// Login with ECA JWT DPoP+RTR using hybrid flow (pending server fix for Named JWTs + hybrid + RTR).
    // TODO: Re-enable when server enables Named JWTs for Hybrid Flows (Salesforce server bug — see internal tracker).
    func test_givenDPoPRtrHybrid_whenLogin_pendingServerFix() throws {
        throw XCTSkip("TODO: W-22512846 — Pending server fix for Named JWTs + RTR + hybrid flow")
    }

    /// Login with ECA JWT DPoP+RTR without hybrid flow and verify refresh token rotation and DPoP binding.
    func test_givenDPoPRtrNoHybrid_whenLogin_thenRefreshTokenRotatesAndDPoPBindingHolds() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpopRtr, useHybridFlow: false, forceAdvancedAuthentication: false, useDPoP: true)
        assertRevokeAndRefreshWorks(isRtr: true, isDPoP: true)
    }

    // MARK: - Multi-User

    /// Login two DPoP users and verify token and nonce isolation across user switch.
    func test_givenTwoDPoPUsers_whenSwitchAndRefresh_thenTokensAndNoncesAreIsolated() throws {
        // Login first user
        launchLoginAndValidate(user: .first, staticAppConfigName: .ecaJwtDpop, forceAdvancedAuthentication: false, useDPoP: true)
        let userACredentialsBeforeSwitch = getUserCredentials()
        let userANonceBeforeSwitch = userACredentialsBeforeSwitch.dpopNonce

        // Login second user
        loginOtherUserAndValidate(loginHost: .regularAuth, user: .second, staticAppConfigName: .ecaJwtDpop, forceAdvancedAuthentication: false, useDPoP: true)
        let userBCredentials = getUserCredentials()
        let userBNonce = userBCredentials.dpopNonce

        // Verify users have different tokens
        XCTAssertNotEqual(userACredentialsBeforeSwitch.accessToken, userBCredentials.accessToken, "Users should have different access tokens")
        XCTAssertNotEqual(userACredentialsBeforeSwitch.refreshToken, userBCredentials.refreshToken, "Users should have different refresh tokens")

        // Switch back to user A and verify nonce persisted
        switchToUserAndValidateUser(loginHost: .regularAuth, user: .first, userAppConfigName: .ecaJwtDpop, isMultiUser: true)
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true, isMultiUser: true)
        let userACredentialsAfterSwitch = getUserCredentials()
        XCTAssertEqual(userACredentialsAfterSwitch.dpopNonce, userANonceBeforeSwitch, "User A nonce should persist across switch")

        // Switch to user B and verify nonce persisted
        switchToUserAndValidateUser(loginHost: .regularAuth, user: .second, userAppConfigName: .ecaJwtDpop, isMultiUser: true)
        assertRevokeAndRefreshWorks(isRtr: false, isDPoP: true, isMultiUser: true)
        let userBCredentialsAfterRefresh = getUserCredentials()
        XCTAssertEqual(userBCredentialsAfterRefresh.dpopNonce, userBNonce, "User B nonce should persist across switch and refresh")
    }

    // MARK: - Migration

    /// Migrate from subset scopes to all scopes and verify DPoP binding is preserved.
    func test_givenDPoPUserWithSubsetScopes_whenMigrateToAllScopes_thenDPoPBindingPreserved() throws {
        // Login with subset scopes
        launchLoginAndValidate(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaJwtDpop, staticScopeSelection: .subset, forceAdvancedAuthentication: false, useDPoP: true)

        // Migrate to all scopes
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .ecaJwtDpop,
            staticScopeSelection: .subset,
            migrationAppConfigName: .ecaJwtDpop,
            migrationScopeSelection: .all,
            useDPoP: true
        )

        // Verify API call succeeds with DPoP binding
        XCTAssert(makeRestRequest(), "REST API request should succeed with DPoP binding after migration")
    }

    /// Migrate from DPoP to DPoP+RTR and verify refresh token rotation is enabled with hybrid flow disabled.
    func test_givenDPoPUser_whenMigrateToDPoPRtr_thenRefreshTokenRotationEnabled() throws {
        // Login with DPoP (non-RTR) without hybrid flow
        launchLoginAndValidate(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaJwtDpop, useHybridFlow: false, forceAdvancedAuthentication: false, useDPoP: true)

        // Migrate to DPoP+RTR without hybrid flow (workaround for server limitation per Wolf)
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .ecaJwtDpop,
            migrationAppConfigName: .ecaJwtDpopRtr,
            migrationUseHybridFlow: false,
            useDPoP: true
        )

        // Verify RTR is enabled post-migration
        assertRevokeAndRefreshWorks(isRtr: true, isDPoP: true)
    }

    // MARK: - Restart

    /// Restart app after DPoP login and verify session and keypair persist.
    func test_givenDPoPUser_whenAppRestart_thenSessionAndKeypairSurvive() throws {
        // Login with DPoP
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpop, forceAdvancedAuthentication: false, useDPoP: true)
        let credentialsBeforeRestart = getUserCredentials()

        // Restart app
        restartAndValidateUser(userAppConfigName: .ecaJwtDpop)

        // Verify session persists (restart-specific asserts — the DPoP triad is checked in the
        // base class's `validateUser()` via `restartAndValidateUser`).
        let credentialsAfterRestart = getUserCredentials()
        XCTAssertEqual(credentialsAfterRestart.userId, credentialsBeforeRestart.userId, "User ID should match after restart")
        XCTAssertEqual(credentialsAfterRestart.accessToken, credentialsBeforeRestart.accessToken, "Access token should match after restart")

        // Verify API call succeeds (validates keypair survived restart)
        XCTAssert(makeRestRequest(), "REST API request should succeed after restart, proving keypair persisted")
    }

    // MARK: - Admin Login

    /// Login with DPoP via Login for Admin (browser-based) and verify DPoP binding.
    func test_givenDPoPECA_whenAdminLogin_thenDPoPBindingWorksThroughSafariVC() throws {
        // Login via Login for Admin with DPoP enabled (the DPoP triad is checked in the
        // base class's `validateUser()` via `launchLoginAndValidate`).
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaJwtDpop,
            forceAdvancedAuthentication: false,
            loginForAdmin: true,
            useDPoP: true
        )

        // Verify API call succeeds with DPoP binding through browser-based auth
        XCTAssert(makeRestRequest(), "REST API request should succeed with DPoP binding after admin login")
    }
}
