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
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpop, useDPoP: true)
        // Two revoke/refresh cycles verify DPoP binding survives a second nonce rotation
        // (parity with Android's `testECAJwtDPoP_Hybrid`).
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, isJwt: true)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, isJwt: true)
    }

    /// Login with ECA JWT DPoP without hybrid flow and verify DPoP token binding.
    func test_givenDPoPNoHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpop, useHybridFlow: false, useDPoP: true)
        // Two revoke/refresh cycles verify DPoP binding survives a second nonce rotation
        // (parity with Android's `testECAJwtDPoP_NoHybrid`).
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, useHybridFlow: false, isJwt: true)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, useHybridFlow: false, isJwt: true)
    }

    // MARK: - ECA JWT DPoP+RTR Tests

    /// Login with ECA JWT DPoP+RTR using hybrid flow (pending server fix for Named JWTs + hybrid + RTR).
    // TODO: Re-enable when server enables Named JWTs for Hybrid Flows (Salesforce server bug — see internal tracker).
    func test_givenDPoPRtrHybrid_whenLogin_pendingServerFix() throws {
        throw XCTSkip("TODO: Pending server fix for Named JWTs + RTR + hybrid flow")
    }

    /// Login with ECA JWT DPoP+RTR without hybrid flow and verify refresh token rotation and DPoP binding.
    func test_givenDPoPRtrNoHybrid_whenLogin_thenRefreshTokenRotatesAndDPoPBindingHolds() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtDpopRtr, useHybridFlow: false, useDPoP: true)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, isDPoP: true, useHybridFlow: false, isJwt: true)
    }

    // MARK: - Multi-User

    /// Login two DPoP users and verify token and nonce isolation across user switch.
    func test_givenTwoDPoPUsers_whenSwitchAndRefresh_thenTokensAndNoncesAreIsolated() throws {
        // Login first user
        launchLoginAndValidate(user: .first, staticAppConfigName: .ecaJwtDpop, useDPoP: true)
        let userACredentialsBeforeSwitch = getUserCredentials()
        let userANonceBeforeSwitch = userACredentialsBeforeSwitch.dpopNonce

        // Login second user
        loginOtherUserAndValidate(loginHost: .regularAuth, user: .second, staticAppConfigName: .ecaJwtDpop, useDPoP: true)
        let userBCredentials = getUserCredentials()
        let userBNonce = userBCredentials.dpopNonce

        // Verify users have different tokens
        XCTAssertNotEqual(userACredentialsBeforeSwitch.accessToken, userBCredentials.accessToken, "Users should have different access tokens")
        XCTAssertNotEqual(userACredentialsBeforeSwitch.refreshToken, userBCredentials.refreshToken, "Users should have different refresh tokens")

        // Switch back to user A and verify nonce persisted
        switchToUserAndValidateUser(loginHost: .regularAuth, user: .first, userAppConfigName: .ecaJwtDpop, isMultiUser: true)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, isMultiUser: true, isJwt: true)
        let userACredentialsAfterSwitch = getUserCredentials()
        XCTAssertEqual(userACredentialsAfterSwitch.dpopNonce, userANonceBeforeSwitch, "User A nonce should persist across switch")

        // Switch to user B and verify nonce persisted
        switchToUserAndValidateUser(loginHost: .regularAuth, user: .second, userAppConfigName: .ecaJwtDpop, isMultiUser: true)
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, isMultiUser: true, isJwt: true)
        let userBCredentialsAfterRefresh = getUserCredentials()
        XCTAssertEqual(userBCredentialsAfterRefresh.dpopNonce, userBNonce, "User B nonce should persist across switch and refresh")
    }

    // MARK: - Migration

    /// Migrate from subset scopes to all scopes and verify DPoP binding is preserved.
    func test_givenDPoPUserWithSubsetScopes_whenMigrateToAllScopes_thenDPoPBindingPreserved() throws {
        // Login with subset scopes
        launchLoginAndValidate(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaJwtDpop, staticScopeSelection: .subset, useDPoP: true)

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
        launchLoginAndValidate(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaJwtDpop, useHybridFlow: false, useDPoP: true)

        // Migrate to DPoP+RTR without hybrid flow (workaround for server limitation per Wolf)
        migrateAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .ecaJwtDpop,
            migrationAppConfigName: .ecaJwtDpopRtr,
            migrationUseHybridFlow: false,
            useDPoP: true
        )

        // Verify RTR is enabled post-migration
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, isDPoP: true, expectAdvancedAuth: true, useHybridFlow: false, wasMigrated: true, isJwt: true)
    }

    // MARK: - Enforcement

    /// Attempt to log in against a DPoP-enforced ECA with the "Use DPoP" toggle off and verify the
    /// login is rejected: the enforced ECA requires a dpop_jkt on /authorize to bind the
    /// authorization code, so an unbound login never reaches the post-login credentials view.
    func testLogin_DPoP_ECA_Without_DPoP_Fails() throws {
        launchAndAttemptLoginExpectingFailure(loginHost: .regularAuth, staticAppConfigName: .ecaJwtDpop, useDPoP: false)
    }

    // MARK: - Upgrade

    /// Login with a Bearer (non-DPoP) session against the global "Use DPoP" flag off, then use
    /// `UserAccountManager.upgradeToDPoP` to re-authenticate the same connected app in place and
    /// verify the session becomes DPoP-bound without changing the consumer key.
    func test_givenBearerSession_whenUpgradeToDPoP_thenDPoPBound() throws {
        // Login with a plain Bearer (non-DPoP) ECA, global "Use DPoP" flag off.
        launchLoginAndValidate(staticAppConfigName: .ecaJwt, useDPoP: false)

        // Upgrade the current session to DPoP in place and validate the result.
        upgradeToDPoPAndValidate()
    }

    // MARK: - Downgrade

    /// Login with a DPoP-bound session, then use `UserAccountManager.downgradeFromDPoP` to
    /// re-authenticate the same connected app in place and verify the session becomes an unbound
    /// Bearer session without changing the consumer key.
    ///
    /// Uses the DPoP-optional `.ecaJwt` ECA rather than the DPoP-enforced `.ecaJwtDpop`: an
    /// enforced ECA rejects the downgrade's unbound `/authorize` request outright, so downgrading
    /// only makes sense starting from an ECA that accepts DPoP without requiring it.
    func test_givenDPoPSession_whenDowngradeFromDPoP_thenBearerUnbound() throws {
        // Login with a DPoP-bound session against a DPoP-optional ECA.
        launchLoginAndValidate(staticAppConfigName: .ecaJwt, useDPoP: true)

        // Downgrade the current session from DPoP in place and validate the result.
        downgradeFromDPoPAndValidate()
    }

    // MARK: - Restart

    /// Restart app after DPoP login; verify the EC keypair and session survive, and that
    /// revoke+refresh works despite the in-memory nonce cache being empty after restart.
    ///
    /// After restart the nonce cache is cold. The first revoke call sends a nonce-less DPoP
    /// proof; the server returns HTTP 400 `use_dpop_nonce`. `SFRestAPI.enqueueRequest` now
    /// detects this, harvests the server-issued nonce from the response header, and retries
    /// the request once with the updated proof (W-23501382).
    func test_givenDPoPUser_whenAppRestart_thenSessionAndKeypairSurvive() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .third,
            staticAppConfigName: .ecaJwtDpop,
            useHybridFlow: false,
            useDPoP: true
        )

        restartAndValidateUser(
            loginHost: .regularAuth,
            user: .third,
            userAppConfigName: .ecaJwtDpop,
            useHybridFlow: false
        )
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, useHybridFlow: false, isJwt: true)
    }

    // MARK: - Pool Server Login

    /// Login via the pool server with DPoP enabled and verify that dpop_jkt was accepted
    /// and DPoP binding holds after a revoke+refresh. The pool server routes through
    /// production login infrastructure, so the user agent carries L1 (production), not L4.
    func test_givenDPoP_whenLoginViaPoolServer_thenTokenTypeIsDPoP() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaJwtDpop,
            useHybridFlow: false,
            useDPoP: true,
            useLoginPoolHost: true
        )
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, useHybridFlow: false, isJwt: true, useLoginPoolHost: true)
    }

    /// Login via the pool server with DPoP + RTR and verify the refresh token survives the identity
    /// fetch after login. Safety net for the RTR-unsafe credential-refresh pattern in
    /// SFIdentityCoordinator: if the identity fetch were to consume the refresh token (by
    /// triggering a credential refresh to resolve a routing error), assertRevokeAndRefreshWorks
    /// below would fail because the refresh token would already be spent. W-23991713 tracks the fix.
    func test_givenDPoPRtr_whenLoginViaPoolServer_thenRefreshTokenSurvivesIdentityFetch() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaJwtDpopRtr,
            useHybridFlow: false,
            useDPoP: true,
            useLoginPoolHost: true
        )
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, isDPoP: true, useHybridFlow: false, isJwt: true, useLoginPoolHost: true)
    }

    // MARK: - Admin Login

    /// Login with DPoP via Login for Admin (browser-based) and verify DPoP binding.
    func test_givenDPoPECA_whenAdminLogin_thenDPoPBindingWorksThroughBrowser() throws {
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
