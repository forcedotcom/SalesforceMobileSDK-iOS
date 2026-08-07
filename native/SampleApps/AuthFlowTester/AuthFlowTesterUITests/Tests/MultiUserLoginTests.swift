/*
 MultiUserLoginTests.swift
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

/// Tests for multi-user login scenarios.
/// Tests login with two users using various configurations:
/// - Static vs dynamic app configuration
/// - Same or different app types (opaque vs JWT)
/// - Same or different scopes
/// - Token revocation scenarios with multiple users
///
/// NB: Tests use the fourth and fifth user from ui_test_config.json
///
class MultiUserLoginTests: BaseAuthFlowTester {
        
    // MARK: - Both Users Static Config
    
    /// Both users use static config, same app type (opaque), same scopes (default).
    func testBothStatic_SameApp_SameScopes() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque
        )
        
        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque
        )
        
        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaOpaque,
            isMultiUser: true)

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaOpaque,
            isMultiUser: true)

        // Logout second user
        logout()
    }

    /// Both users use static config, different app types (opaque + jwt), same scopes (default).
    func testBothStatic_DifferentApps() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque
        )
        
        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaJwt
        )
        
        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaJwt, // static config overwritten
            userAppConfigName: .ecaOpaque,
            isMultiUser: true)

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaJwt,
            userAppConfigName: .ecaJwt,
            isMultiUser: true)

        // Logout second user
        logout()
    }
    
    /// Both users use static config, same app type, different scopes (first subset, second default).
    func testBothStatic_SameApp_DifferentScopes() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque,
            staticScopeSelection: .subset
        )
        
        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque
        )
        
        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque,
            staticScopeSelection: .empty,
            userAppConfigName: .ecaOpaque,
            userScopeSelection: .subset,
            isMultiUser: true
        )

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            staticScopeSelection: .empty,
            userAppConfigName: .ecaOpaque,
            userScopeSelection: .empty,
            isMultiUser: true
        )

        // Logout second user
        logout()
    }
    
    // MARK: - Mixed Static/Dynamic Config
    
    /// First user static config, second user dynamic config, different apps, same scopes (default).
    func testFirstStatic_SecondDynamic_DifferentApps() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque
        )
        
        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt
        )
        
        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaOpaque,
            isMultiUser: true
        )

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaJwt,
            isMultiUser: true
        )

        // Logout second user
        logout()
    }

    /// First user dynamic config, second user static config, different apps, same scopes (default).
    func testFirstDynamic_SecondStatic_DifferentApps() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque, // not used - but using other config for validation
            dynamicAppConfigName: .ecaJwt
        )

        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque
        )

        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaJwt,
            isMultiUser: true
        )

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            userAppConfigName: .ecaOpaque,
            isMultiUser: true
        )

        // Logout second user
        logout()
    }

    // MARK: - Both Users Dynamic Config
    
    /// Both users use dynamic config, different apps, same scopes (default).
    func testBothDynamic_DifferentApps() throws {
        // Initial user
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque, // not used - but using other config for validation
            dynamicAppConfigName: .ecaOpaque
        )
        
        // Other user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque, // not used - but using other config for validation
            dynamicAppConfigName: .ecaJwt
        )

        // Switch back to initial user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque, // not used - but using other config for validation
            userAppConfigName: .ecaOpaque,
            isMultiUser: true
        )

        // Switch back to other user
        switchToUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque, // not used - but using other config for validation
            userAppConfigName: .ecaJwt,
            isMultiUser: true
        )

        // Logout second user
        logout()
    }

    // MARK: - Beacon and Non-Beacon Multi-User

    /// Login User A with Beacon and User B with CA (non-beacon).
    /// Tests that beacon child key is properly isolated per user.
    func testBeaconAndNonBeacon_MultiUser() throws {
        // Login User A with Beacon Opaque
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .beaconOpaque
        )

        // Verify User A has beacon child key
        var userACredentials = getUserCredentials()
        XCTAssertNotEqual(userACredentials.beaconChildConsumerKey, "", "User A should have beacon child key")

        // Login User B with CA Opaque (non-beacon)
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque
        )

        // Verify User B has no beacon child key
        let userBCredentials = getUserCredentials()
        XCTAssertEqual(userBCredentials.beaconChildConsumerKey, "", "User B should not have beacon child key")

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Verify User A still has beacon child key
        userACredentials = getUserCredentials()
        XCTAssertNotEqual(userACredentials.beaconChildConsumerKey, "", "User A should still have beacon child key after switch")

        // Switch to User B
        switchToUser(loginHost: .regularAuth, user: .fifth)

        // Verify User B still has no beacon child key
        let userBCredentialsAfter = getUserCredentials()
        XCTAssertEqual(userBCredentialsAfter.beaconChildConsumerKey, "", "User B should still not have beacon child key after switch")

        // Logout second user
        logout()
    }

    // MARK: - Token Revocation Tests

    /// Revoke access for user with dynamic config and verify other user is unaffected.
    /// Tests token isolation when one user uses dynamic consumer key selection.
    func testRevokeAccessForUserWithDynamicConfig_OtherUserUnaffected() throws {
        // Login User A with static config
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque
        )

        // Get User A credentials before adding User B
        let userACredentialsBefore = getUserCredentials()

        // Login User B with dynamic config (overrides consumer key at runtime)
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt
        )

        // Revoke User B's access token
        XCTAssertTrue(revokeAccessToken(), "Failed to revoke User B's access token")

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Verify User A's access token unchanged
        let userACredentialsAfter = getUserCredentials()
        XCTAssertEqual(
            userACredentialsBefore.accessToken,
            userACredentialsAfter.accessToken,
            "User A's access token should not change when User B's token is revoked"
        )

        // Make API call for User A (should succeed without refresh)
        XCTAssertTrue(makeRestRequest(), "User A's API call should succeed")

        // Verify User A's access token still unchanged (no refresh occurred)
        let userACredentialsAfterAPI = getUserCredentials()
        XCTAssertEqual(
            userACredentialsAfter.accessToken,
            userACredentialsAfterAPI.accessToken,
            "User A's access token should not refresh (User B's revocation should not affect User A)"
        )

        // Switch back to User B
        switchToUser(loginHost: .regularAuth, user: .fifth)

        // Get User B credentials before API call
        let userBCredentialsBeforeAPI = getUserCredentials()

        // Make API call for User B (should trigger refresh and succeed)
        XCTAssertTrue(makeRestRequest(), "User B's API call should succeed after refresh")

        // Verify User B's access token changed (refresh occurred)
        let userBCredentialsAfterAPI = getUserCredentials()
        XCTAssertNotEqual(
            userBCredentialsBeforeAPI.accessToken,
            userBCredentialsAfterAPI.accessToken,
            "User B's access token should refresh after revocation"
        )

        // Logout second user
        logout()
    }

    /// Revoke access for CA user and verify ECA user is unaffected.
    /// Tests token isolation between users with different app types (CA vs ECA).
    func testDifferentAppTypes_RevokeAccessForCaUser_EcaUserUnaffected() throws {
        // Login User A with CA Opaque
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque
        )

        // Login User B with ECA Opaque
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque
        )

        // Get User B credentials before switching
        let userBCredentialsBefore = getUserCredentials()

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Revoke User A's access token
        XCTAssertTrue(revokeAccessToken(), "Failed to revoke User A's access token")

        // Switch to User B
        switchToUser(loginHost: .regularAuth, user: .fifth)

        // Verify User B's access token unchanged
        let userBCredentialsAfter = getUserCredentials()
        XCTAssertEqual(
            userBCredentialsBefore.accessToken,
            userBCredentialsAfter.accessToken,
            "User B's access token should not change when User A's token is revoked"
        )

        // Make API call for User B (should succeed without refresh)
        XCTAssertTrue(makeRestRequest(), "User B's API call should succeed")

        // Verify User B's access token still unchanged (no refresh occurred)
        let userBCredentialsAfterAPI = getUserCredentials()
        XCTAssertEqual(
            userBCredentialsAfter.accessToken,
            userBCredentialsAfterAPI.accessToken,
            "User B's access token should not refresh (User A's revocation should not affect User B)"
        )

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Get User A credentials before API call
        let userACredentialsBeforeAPI = getUserCredentials()

        // Make API call for User A (should trigger refresh and succeed)
        XCTAssertTrue(makeRestRequest(), "User A's API call should succeed after refresh")

        // Verify User A's access token changed (refresh occurred)
        let userACredentialsAfterAPI = getUserCredentials()
        XCTAssertNotEqual(
            userACredentialsBeforeAPI.accessToken,
            userACredentialsAfterAPI.accessToken,
            "User A's access token should refresh after revocation"
        )

        // Logout second user
        logout()
    }

    // MARK: - User Logout Tests

    /// Logout user with dynamic config and verify other user is unaffected.
    /// Tests that logging out one user automatically switches to the other user.
    func testLogoutUserWithDynamicConfig_OtherUserUnaffected() throws {
        // Login User A with static config
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaOpaque
        )

        // Get User A credentials
        let userACredentials = getUserCredentials()

        // Login User B with dynamic config (overrides consumer key at runtime)
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt
        )

        // Logout User B (should automatically switch to User A)
        logout()

        // Verify we're automatically on User A after User B logout
        let currentUserCredentials = getUserCredentials()
        XCTAssertEqual(
            currentUserCredentials.username,
            userACredentials.username,
            "Should automatically be on User A after User B logout"
        )

        // Verify User A's credentials are intact
        XCTAssertEqual(
            currentUserCredentials.accessToken,
            userACredentials.accessToken,
            "User A's access token should be unchanged after User B logout"
        )

        // Make API call for User A (should succeed)
        XCTAssertTrue(makeRestRequest(), "User A's API call should succeed")
    }

    // MARK: - Feature Flag Multi-User Isolation Tests

    /// Verifies A-marker and token-format flags are isolated per user.
    /// User A: web-server non-hybrid (A1) + opaque token (OT).
    /// User B: web-server hybrid (A2) + JWT (JT).
    /// A-marker leakage is undetectable when both users share A2; diverging A-markers here make it visible.
    func testFlagDiversity_NonHybridOpaqueVsHybridJwt() throws {
        // User A: A1 (web server, non-hybrid), OT, no BN
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque,
            useHybridFlow: false,
            forceAdvancedAuthentication: true
        )

        // User B: A2 (web server, hybrid), JT, no BN — multi-user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaJwt
        )

        // Switch to User A — A1 and OT must survive alongside MU
        switchToUser(loginHost: .regularAuth, user: .fourth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerNonHybrid,
            isJwt: false,
            isBeacon: false
        )

        // Switch to User B — A2 and JT must survive alongside MU
        switchToUser(loginHost: .regularAuth, user: .fifth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerHybrid,
            isJwt: true,
            isBeacon: false
        )

        // Logout User B — User A becomes active, MU must clear, A1 and OT must persist
        logout()
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: false,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerNonHybrid,
            isJwt: false,
            isBeacon: false
        )
    }

    /// Verifies A-marker, token format, and beacon flag are isolated per user simultaneously.
    /// User A: A1 (web server, non-hybrid) + JWT (JT) + beacon (BN).
    /// User B: A2 (web server, hybrid) + opaque (OT), no beacon.
    /// Three per-user flags differ, maximising leakage detectability.
    func testFlagDiversity_BeaconNonHybridJwtVsHybridOpaque() throws {
        // User A: A1, JT, BN
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .beaconJwt,
            useHybridFlow: false,
            forceAdvancedAuthentication: true
        )

        // User B: A2, OT, no BN — multi-user
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .caOpaque
        )

        // Switch to User A — A1, JT, BN must survive alongside MU
        switchToUser(loginHost: .regularAuth, user: .fourth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerNonHybrid,
            isJwt: true,
            isBeacon: true
        )

        // Switch to User B — A2, OT, no BN must survive alongside MU
        switchToUser(loginHost: .regularAuth, user: .fifth)
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: true,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerHybrid,
            isJwt: false,
            isBeacon: false
        )

        // Logout User B — User A becomes active, MU must clear, A1, JT, BN must persist
        logout()
        validateUserAgent(
            userCredentials: getUserCredentials(),
            loginHost: .regularAuth,
            expectAdvancedAuth: true,
            isMultiUser: false,
            expectedBMarker: kBrowserLoginForceFlag,
            expectedLMarker: kLoginServerMyDomain,
            expectedAMarker: kAuthTypeWebServerNonHybrid,
            isJwt: true,
            isBeacon: true
        )
    }

    // MARK: - Feature Flag User Agent Tests

    /// Verifies that the BW (browser-web) feature flag is set in the user agent for advanced auth users
    /// and absent for regular auth users. Also verifies the MU (multi-user) flag when multiple users
    /// are logged in simultaneously.
    ///
    /// NB: Uses .fourth user from regular_auth and .third user from advanced_auth (beaconOpaque app)
    ///     to avoid parallel conflicts with AdvancedAuthBeaconLoginTests which uses .second.
    ///     loginOtherUser (no validate) is used for the advanced auth user because identity data
    ///     may not be immediately available in a cross-host multi-user login.
    func testAdvancedAuthUser_HasBWFlag_RegularAuthUser_DoesNot() throws {
        // User A: regular auth — no BW.
        // Pass forceAdvancedAuthentication: false so User A logs in via the in-app WebView and does
        // NOT register the BW flag. The .regularAuth host does not opt into native browser auth via
        // its auth config, so disabling the process-global flag is sufficient to use the WebView.
        launchLoginAndValidate(loginHost: .regularAuth, user: .fourth, staticAppConfigName: .ecaOpaque, forceAdvancedAuthentication: false)

        // User B: advanced auth — has BW, both users now logged in → MU
        // Use loginOtherUser (without full credential validation) since identity data
        // may not be immediately available in cross-host multi-user scenarios.
        loginOtherUser(loginHost: .advancedAuth, user: .third, staticAppConfigName: .beaconOpaque)
        validateUserAgent(userCredentials: getUserCredentials(), loginHost: .advancedAuth, expectAdvancedAuth: true, isMultiUser: true, expectedBMarker: kBrowserLoginForceFlag, expectedLMarker: kLoginServerMyDomain, expectedAMarker: kAuthTypeWebServerHybrid, isBeacon: true)

        // Switch to User A — no BW, MU still set, no beacon
        switchToUser(loginHost: .regularAuth, user: .fourth)
        validateUserAgent(userCredentials: getUserCredentials(), loginHost: .regularAuth, isMultiUser: true, expectedLMarker: kLoginServerMyDomain, expectedAMarker: kAuthTypeWebServerHybrid)

        // Switch back to User B — BW back, MU still set, beacon
        switchToUser(loginHost: .advancedAuth, user: .third)
        validateUserAgent(userCredentials: getUserCredentials(), loginHost: .advancedAuth, expectAdvancedAuth: true, isMultiUser: true, expectedBMarker: kBrowserLoginForceFlag, expectedLMarker: kLoginServerMyDomain, expectedAMarker: kAuthTypeWebServerHybrid, isBeacon: true)

        // Logout User B — app auto-switches to User A; MU must be gone, no beacon
        logout()
        validateUserAgent(userCredentials: getUserCredentials(), loginHost: .regularAuth, isMultiUser: false, expectedLMarker: kLoginServerMyDomain, expectedAMarker: kAuthTypeWebServerHybrid)
    }

    // MARK: - DPoP + non-DPoP Multi-User (per-credential proof gating)

    /// Mixed DPoP + non-DPoP users with the process-wide DPoP flag flipped off after both are
    /// logged in. Each user's post-flip refresh + REST GET must use its own auth scheme
    /// independently — DPoP for the DPoP-bound credential, Bearer for the non-DPoP one — gated
    /// by per-credential state (tokenType or persisted key material), not the global flag.
    ///
    /// Simulates an app upgrade or config change that flips
    /// `SalesforceManager.shared.usesDPoP = false` after both users are authenticated. The flag
    /// flip is injected via the AuthFlowTester `--disableDPoPAtStart` launch argument (see
    /// `AppDelegate.init`) on relaunch, since XCUITest runs out-of-process.
    func test_dpopAndNonDPoPUsers_flagOff_maintainIndependentProofs() throws {
        // User A: DPoP ECA (useDPoP=true so /authorize gets dpop_jkt and the credential is
        // persisted with tokenType="DPoP" and a key pair in the Keychain).
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .ecaJwtDpop,
            useDPoP: true
        )

        // User B: non-DPoP ECA (Bearer) — no key material, no DPoP tokenType.
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaJwt
        )

        // Uses direct token invalidation rather than revokeAccessToken to avoid a known gap in the RestClient's use_dpop_nonce retry loop.

        // Switch to user A so A is the current account across the next relaunch.
        switchToUser(loginHost: .regularAuth, user: .fourth)
        let userACredentialsBefore = getUserCredentials()
        // Relaunch with the global DPoP flag flipped off AND user A's access token
        // invalidated in place. --disableDPoPAtStart sets SalesforceManager.shared.usesDPoP = false;
        // --invalidateCurrentUserAccessTokenAtStart corrupts the current user's access token so
        // the next REST call 401s and triggers the natural refresh path.
        restart(withLaunchArguments: ["--disableDPoPAtStart", "--invalidateCurrentUserAccessTokenAtStart"])
        XCTAssertTrue(makeRestRequest(), "User A's REST request should succeed with DPoP proof after flag flip")
        let userACredentialsAfter = getUserCredentials()
        XCTAssertNotEqual(
            userACredentialsBefore.accessToken,
            userACredentialsAfter.accessToken,
            "User A's access token should have refreshed"
        )
        XCTAssertEqual(userACredentialsAfter.dpopTokenType, "DPoP", "User A should remain DPoP-bound after global flag flipped off")
        XCTAssertNotNil(userACredentialsAfter.dpopNonce, "User A DPoP nonce should be present after refresh")
        XCTAssertFalse(userACredentialsAfter.dpopNonce?.isEmpty ?? true, "User A DPoP nonce should not be empty")

        // Switch to user B (Bearer) and repeat with the same launch args. Refresh + REST must NOT be DPoP.
        switchToUser(loginHost: .regularAuth, user: .fifth)
        let userBCredentialsBefore = getUserCredentials()
        restart(withLaunchArguments: ["--disableDPoPAtStart", "--invalidateCurrentUserAccessTokenAtStart"])
        XCTAssertTrue(makeRestRequest(), "User B's REST request should succeed as Bearer after flag flip")
        let userBCredentialsAfter = getUserCredentials()
        XCTAssertNotEqual(
            userBCredentialsBefore.accessToken,
            userBCredentialsAfter.accessToken,
            "User B's access token should have refreshed"
        )
        XCTAssertNotEqual(userBCredentialsAfter.dpopTokenType, "DPoP", "User B should remain Bearer after global flag flipped off")

        // Logout current user
        logout()
    }

    /// Logout CA user and verify ECA user is unaffected.
    /// Tests that logging out one user automatically switches to the other user with different app types.
    func testDifferentAppTypes_LogoutCaUser_EcaUserUnaffected() throws {
        // Login User A with CA Opaque
        launchAndLogin(
            loginHost: .regularAuth,
            user: .fourth,
            staticAppConfigName: .caOpaque
        )

        // Login User B with ECA Opaque
        loginOtherUserAndValidate(
            loginHost: .regularAuth,
            user: .fifth,
            staticAppConfigName: .ecaOpaque
        )

        // Get User B credentials
        let userBCredentials = getUserCredentials()

        // Switch to User A
        switchToUser(loginHost: .regularAuth, user: .fourth)

        // Logout User A (should automatically switch to User B)
        logout()

        // Verify we're automatically on User B after User A logout
        let currentUserCredentials = getUserCredentials()
        XCTAssertEqual(
            currentUserCredentials.username,
            userBCredentials.username,
            "Should automatically be on User B after User A logout"
        )

        // Verify User B's credentials are intact
        XCTAssertEqual(
            currentUserCredentials.accessToken,
            userBCredentials.accessToken,
            "User B's access token should be unchanged after User A logout"
        )

        // Make API call for User B (should succeed)
        XCTAssertTrue(makeRestRequest(), "User B's API call should succeed")
    }
}
