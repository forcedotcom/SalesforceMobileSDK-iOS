/*
 CommunityLoginTests.swift
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

 Covers logging into a community (Experience Cloud) login server: with and without DPoP, hybrid
 and non-hybrid, across a token refresh, an app relaunch, logout/relogin, in-place DPoP
 upgrade/downgrade, multi-user isolation against a regular org user, and the alternate (in-app
 WebView) auth UI. Protects the `communityUrl > instanceUrl > domain` refresh precedence chain by
 asserting the community URL stays populated throughout.

 These tests require a `community_auth` login host (with one user) in `ui_test_config.json`; see
 `shared/test/ui_test_config.json.sample` for the expected shape. They skip cleanly when that entry
 is absent so CI stays green until a dedicated community org is provisioned.

 There is no dedicated community-only app config. The community org under evaluation reuses the
 existing regular-host apps (`eca_opaque`, `eca_jwt`, `eca_jwt_dpop`, `eca_jwt_dpop_rtr`), so every
 test below just points one of those apps at the `community_auth` login host instead. Because the
 app names already correctly encode their real properties (`issuesJwt`/`isDPoP`/
 `expectsRefreshTokenRotation`, all name-derived in `UITestConfigUtils.AppConfig`), the normal
 name-derived heavy helpers (`launchLoginAndValidate`, `switchToUserAndValidateUser`,
 `restartAndValidateUser`, `upgradeToDPoPAndValidate`, `downgradeFromDPoPAndValidate`) just work
 with no extra overrides, exactly like every other suite. The app choice for each scenario is
 centralized below so swapping to a real dedicated community app later (once one is provisioned) is
 a one-place change.

 Uses the same heavy, app-config-driven chain `DPoPLoginTests`/`RTRLoginTests` use. The one case
 that doesn't fit that chain is the logout/relogin scenario (test 8): `login()` after `logout()` is
 a lightweight primitive with no corresponding "relogin and validate" heavy helper, so that one
 scenario checks the DPoP token-type triad directly via `assertCommunitySessionIsHealthy`.
 */

import XCTest

class CommunityLoginTests: BaseAuthFlowTester {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            UITestConfigUtils.shared.hasLoginHost(.communityAuth),
            "No community_auth login host configured in ui_test_config.json; skipping community login tests"
        )
    }

    // MARK: - App choice (temporary — swap for a real dedicated community app once provisioned)

    /// No DPoP: an opaque, non-RTR ECA. Matches the plain login pattern in `ECALoginTests`.
    private let noDPoPAppConfig: KnownAppConfig = .ecaOpaque

    /// DPoP, non-RTR: matches the DPoP-enforced ECA `DPoPLoginTests` uses for its basic DPoP
    /// scenarios (login, restart, logout/relogin, in-app WebView).
    private let dpopAppConfig: KnownAppConfig = .ecaJwtDpop

    /// DPoP, RTR: matches the ECA `DPoPLoginTests`'/`RTRLoginTests`' refresh-token-rotation
    /// scenario uses.
    private let dpopRtrAppConfig: KnownAppConfig = .ecaJwtDpopRtr

    /// Upgrade: matches `DPoPLoginTests.test_givenBearerSession_whenUpgradeToDPoP_thenDPoPBound`,
    /// which logs in Bearer-only against this (DPoP-optional) ECA before upgrading in place.
    private let upgradeAppConfig: KnownAppConfig = .ecaJwt

    /// Downgrade: matches
    /// `DPoPLoginTests.test_givenDPoPSession_whenDowngradeFromDPoP_thenBearerUnbound`, which logs
    /// in DPoP-bound against this (DPoP-optional) ECA before downgrading in place.
    private let downgradeAppConfig: KnownAppConfig = .ecaJwt

    // MARK: - Local helper

    /// Asserts the DPoP/Bearer token-type triad and the community URL on a set of community
    /// credentials. Used for the one scenario (test 8, logout/relogin) that can't go through the
    /// heavy `validateUser`-driven chain (see file header), and as a cheap addition everywhere
    /// else, since nothing in `BaseAuthFlowTester` checks `communityUrl`.
    private func assertCommunitySessionIsHealthy(_ credentials: UserCredentialsData, expectDPoP: Bool, context: String = "") {
        let ctx = context.isEmpty ? "" : " (\(context))"
        if expectDPoP {
            XCTAssertEqual(credentials.dpopTokenType, "DPoP", "Expected DPoP-bound token_type\(ctx); got \(credentials.dpopTokenType ?? "nil")")
            XCTAssertFalse(credentials.dpopNonce?.isEmpty ?? true, "Expected a non-empty DPoP nonce\(ctx)")
        } else {
            XCTAssertNotEqual(credentials.dpopTokenType, "DPoP", "Expected a non-DPoP (Bearer) token_type\(ctx); got \(credentials.dpopTokenType ?? "nil")")
        }
        XCTAssertFalse(credentials.communityUrl.isEmpty, "Expected a non-empty community URL\(ctx)")
    }

    // MARK: - 1/2: Non-DPoP login, hybrid and non-hybrid

    /// Logging into the community server without DPoP, using the hybrid auth flow, produces a
    /// Bearer token and a working revoke/refresh cycle.
    func test_givenCommunityNoDPoPHybrid_whenLogin_thenBearerAndRefreshWorks() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: noDPoPAppConfig,
            useDPoP: false
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: false)
    }

    /// Logging into the community server without DPoP, using the non-hybrid auth flow, produces
    /// a Bearer token and a working revoke/refresh cycle.
    func test_givenCommunityNoDPoPNoHybrid_whenLogin_thenBearerAndRefreshWorks() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: noDPoPAppConfig,
            useHybridFlow: false,
            useDPoP: false
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: false)
    }

    // MARK: - 3/4: DPoP login, hybrid and non-hybrid

    /// Logging into the community server with DPoP enabled, using the hybrid auth flow, produces
    /// a DPoP-bound token and a working revoke/refresh cycle.
    func test_givenCommunityDPoPHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            useDPoP: true
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: true)
    }

    /// Logging into the community server with DPoP enabled, using the non-hybrid auth flow,
    /// produces a DPoP-bound token and a working revoke/refresh cycle.
    func test_givenCommunityDPoPNoHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            useHybridFlow: false,
            useDPoP: true
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: true)
    }

    // MARK: - 5: Refresh-token rotation

    /// A community DPoP session's refresh token rotates on refresh, and the DPoP binding holds
    /// across that rotation. `launchLoginAndValidate` already runs one revoke/refresh cycle; this
    /// test runs an explicit extra cycle dedicated to the rotation assertion, mirroring the
    /// `DPoPLoginTests`/`RTRLoginTests` RTR tests' pattern.
    func test_givenCommunityDPoP_whenRefresh_thenRefreshTokenRotatesAndDPoPBindingHolds() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopRtrAppConfig,
            useDPoP: true
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: true)

        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: true, isDPoP: true, loginHost: .communityAuth, isJwt: true)
    }

    // MARK: - 6/7: App restart

    /// A community DPoP session (and its DPoP keypair) survives an app restart: the session
    /// stays DPoP-bound, the community URL and client id are unchanged, and a revoke/refresh
    /// cycle still works afterward.
    func test_givenCommunityDPoPUser_whenAppRestart_thenSessionAndKeypairSurvive() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            useDPoP: true
        )
        let beforeRestart = getUserCredentials()
        assertCommunitySessionIsHealthy(beforeRestart, expectDPoP: true)

        // restartAndValidateUser() does not pass --resetSDKForUITesting, so the existing session
        // survives the restart.
        restartAndValidateUser(loginHost: .communityAuth, userAppConfigName: dpopAppConfig)

        let afterRestart = getUserCredentials()
        assertCommunitySessionIsHealthy(afterRestart, expectDPoP: true, context: "after restart")
        XCTAssertEqual(afterRestart.communityUrl, beforeRestart.communityUrl, "Community URL should be unchanged after restart")
        XCTAssertEqual(afterRestart.clientId, beforeRestart.clientId, "Client id should be unchanged after restart")

        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after restart")
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, loginHost: .communityAuth, isJwt: true)
    }

    /// A community non-DPoP session survives an app restart: the community URL and client id are
    /// unchanged, and a revoke/refresh cycle still works afterward.
    func test_givenCommunityNoDPoPUser_whenAppRestart_thenSessionSurvives() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: noDPoPAppConfig,
            useDPoP: false
        )
        let beforeRestart = getUserCredentials()
        assertCommunitySessionIsHealthy(beforeRestart, expectDPoP: false)

        restartAndValidateUser(loginHost: .communityAuth, userAppConfigName: noDPoPAppConfig)

        let afterRestart = getUserCredentials()
        assertCommunitySessionIsHealthy(afterRestart, expectDPoP: false, context: "after restart")
        XCTAssertEqual(afterRestart.communityUrl, beforeRestart.communityUrl, "Community URL should be unchanged after restart")
        XCTAssertEqual(afterRestart.clientId, beforeRestart.clientId, "Client id should be unchanged after restart")

        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after restart")
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: false, loginHost: .communityAuth, isJwt: false)
    }

    // MARK: - 8: Logout and relogin

    /// A community DPoP user who logs out and logs back in gets a fresh DPoP-bound session with a
    /// new refresh token (not a refresh of the previous one).
    ///
    /// `login()` after `logout()` is a lightweight primitive with no corresponding "relogin and
    /// validate" heavy helper (see file header), so this scenario checks the DPoP triad directly.
    func test_givenCommunityDPoPUser_whenLogoutAndRelogin_thenTokenTypeIsDPoP() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            useDPoP: true
        )

        let beforeLogout = getUserCredentials()
        assertCommunitySessionIsHealthy(beforeLogout, expectDPoP: true)

        logout()
        // login()'s first step always returns to the host list expecting the (default) browser
        // prompt, so it can be called directly after logout() without any extra teardown.
        login(loginHost: .communityAuth, user: .first, staticAppConfigName: dpopAppConfig, useDPoP: true)

        let afterRelogin = getUserCredentials()
        assertCommunitySessionIsHealthy(afterRelogin, expectDPoP: true, context: "after logout and relogin")
        XCTAssertNotEqual(afterRelogin.refreshToken, beforeLogout.refreshToken, "Refresh token should differ after a fresh login (not a refresh)")

        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after relogin")
    }

    // MARK: - 9/10: In-place DPoP upgrade/downgrade

    /// A community Bearer session can be upgraded to DPoP in place: the client id is unchanged,
    /// the session becomes DPoP-bound, and a revoke/refresh cycle still works afterward.
    func test_givenCommunityBearerSession_whenUpgradeToDPoP_thenDPoPBound() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: upgradeAppConfig,
            useDPoP: false
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: false)

        upgradeToDPoPAndValidate(loginHost: .communityAuth)

        let afterUpgrade = getUserCredentials()
        assertCommunitySessionIsHealthy(afterUpgrade, expectDPoP: true, context: "after upgrade to DPoP")
        XCTAssertTrue(makeRestRequest(), "REST API request should succeed with DPoP binding after upgrade")
    }

    /// A community DPoP session can be downgraded to Bearer in place: the client id is unchanged,
    /// the session is no longer DPoP-bound, and a revoke/refresh cycle still works afterward.
    func test_givenCommunityDPoPSession_whenDowngradeFromDPoP_thenBearerUnbound() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: downgradeAppConfig,
            useDPoP: true
        )
        assertCommunitySessionIsHealthy(getUserCredentials(), expectDPoP: true)

        downgradeFromDPoPAndValidate(loginHost: .communityAuth)

        let afterDowngrade = getUserCredentials()
        assertCommunitySessionIsHealthy(afterDowngrade, expectDPoP: false, context: "after downgrade from DPoP")
        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after downgrade")
    }

    // MARK: - 11: Multi-user isolation

    /// A community DPoP user and a regular org DPoP/JWT user (`eca_jwt_dpop`) stay isolated from
    /// each other across switches and refreshes: distinct access/refresh tokens, and each user's
    /// DPoP nonce persists across the switch to the other user and back.
    func test_givenCommunityDPoPUserAndRegularDPoPUser_whenSwitchAndRefresh_thenTokensAndNoncesAreIsolated() throws {
        // Community DPoP user
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            useDPoP: true
        )
        let communityBeforeSwitch = getUserCredentials()
        assertCommunitySessionIsHealthy(communityBeforeSwitch, expectDPoP: true)

        // Regular org user, on the same app config but a different (regular) login host.
        loginOtherUserAndValidate(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaJwtDpop, useDPoP: true)
        let regularCredentials = getUserCredentials()

        XCTAssertNotEqual(communityBeforeSwitch.accessToken, regularCredentials.accessToken, "Users should have different access tokens")
        XCTAssertNotEqual(communityBeforeSwitch.refreshToken, regularCredentials.refreshToken, "Users should have different refresh tokens")

        // Switch back to the community user: its DPoP nonce should have persisted, and a
        // revoke/refresh cycle should still work.
        switchToUserAndValidateUser(loginHost: .communityAuth, user: .first, userAppConfigName: dpopAppConfig, isMultiUser: true)
        let communityAfterSwitch = getUserCredentials()
        assertCommunitySessionIsHealthy(communityAfterSwitch, expectDPoP: true, context: "after switch back")
        XCTAssertEqual(communityAfterSwitch.dpopNonce, communityBeforeSwitch.dpopNonce, "Community user's DPoP nonce should persist across switch")
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, loginHost: .communityAuth, isMultiUser: true, isJwt: true)

        // Switch to the regular user: its DPoP nonce should have persisted, and a revoke/refresh
        // cycle should still work.
        switchToUserAndValidateUser(loginHost: .regularAuth, user: .first, userAppConfigName: .ecaJwtDpop, isMultiUser: true)
        let regularAfterSwitchBack = getUserCredentials()
        XCTAssertEqual(regularAfterSwitchBack.dpopNonce, regularCredentials.dpopNonce, "Regular user's DPoP nonce should persist across switch")
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, isMultiUser: true, isJwt: true)
    }

    // MARK: - 12: Alternate (in-app WebView) auth UI

    /// Logging into the community server via the in-app WebView (rather than the default advanced
    /// auth browser), with DPoP enabled, produces a DPoP-bound token and a working revoke/refresh
    /// cycle.
    func test_givenCommunityDPoP_whenLoginViaInAppWebView_thenTokenTypeIsDPoP() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: dpopAppConfig,
            forceAdvancedAuthentication: false,
            useDPoP: true
        )

        let credentials = getUserCredentials()
        assertCommunitySessionIsHealthy(credentials, expectDPoP: true)
        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after community login via the in-app WebView")

        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, loginHost: .communityAuth, expectAdvancedAuth: false, isJwt: true)
    }

    /// Logging into the community server via the in-app WebView, with DPoP disabled, produces a
    /// Bearer token and a working revoke/refresh cycle.
    func test_givenCommunityNoDPoP_whenLoginViaInAppWebView_thenTokenTypeIsBearer() throws {
        launchLoginAndValidate(
            loginHost: .communityAuth,
            staticAppConfigName: noDPoPAppConfig,
            forceAdvancedAuthentication: false,
            useDPoP: false
        )

        let credentials = getUserCredentials()
        assertCommunitySessionIsHealthy(credentials, expectDPoP: false)
        XCTAssertTrue(makeRestRequest(), "REST API request should succeed after community login via the in-app WebView")

        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: false, loginHost: .communityAuth, expectAdvancedAuth: false, isJwt: false)
    }
}
