/*
 NativeLoginTests.swift
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


/*
 Covers Native Login (the SDK's debug Native Login form, selected by the Authentication Mode of the
 SDK Login Options screen) against the community login host, for the two headless ECAs:

   - `eca_jwt_headless`      accepts, but does not require, DPoP
   - `eca_jwt_dpop_headless` requires DPoP (`/authorize` without `dpop_jkt` is rejected)

 The four-case matrix (ECA x client DPoP choice) has explicit expectations: Bearer, DPoP, rejected
 (no account created), DPoP. Every test launches the app in Native mode with its configuration
 (`--nativeLoginConfig=<json>`); tests that switch apps or DPoP mid-run use the Login Options import.
 The browser fallback test covers the hand-off to web authentication.

 The suite needs a `nativeLogin` entry in `ui_test_config.json` (see
 `shared/test/ui_test_config.json.sample`) naming the login host and both apps. It skips cleanly
 when the entry is absent. A present but malformed entry fails `testNativeLoginConfigIsValid` and
 every other test (never a silent skip).
 */

import XCTest

class NativeLoginTests: BaseAuthFlowTester {

    private var setup: NativeLoginSetup!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            UITestConfigUtils.shared.hasNativeLoginConfig,
            "No nativeLogin entry in ui_test_config.json; skipping Native Login tests"
        )
        setup = try UITestConfigUtils.shared.nativeLoginSetup()
        // Record the last token request so refreshes can be checked against the community host.
        extraLaunchArguments = ["--captureTokenRequestUserAgent"]
    }

    // MARK: - Config

    /// Validates the `nativeLogin` entry (references resolve, keys set, HTTPS redirect URIs).
    /// `setUpWithError` already throws for a malformed entry; this names the check explicitly.
    func testNativeLoginConfigIsValid() throws {
        let setup = try UITestConfigUtils.shared.nativeLoginSetup()
        XCTAssertFalse(setup.user.username.isEmpty)
        XCTAssertTrue(setup.communityUrl.lowercased().hasPrefix("https://"))
        XCTAssertNotEqual(setup.optionalDPoPAppConfig.consumerKey, setup.requiredDPoPAppConfig.consumerKey)
    }

    // MARK: - Matrix

    /// Optional ECA, DPoP off: Bearer.
    func test_givenOptionalEca_whenDPoPOff_thenBearer() throws {
        let app = setup.optionalDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: false, expectation: .bearer)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: false)
        restartNativeAndValidate(setup: setup, app: app, expectDPoP: false)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: false)
    }

    /// Optional ECA, DPoP on: DPoP-bound.
    func test_givenOptionalEca_whenDPoPOn_thenDPoP() throws {
        let app = setup.optionalDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: true, expectation: .dpop)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: true)
        restartNativeAndValidate(setup: setup, app: app, expectDPoP: true)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: true)
    }

    /// Required ECA, DPoP off: the server rejects the unbound request; no account is created.
    func test_givenRequiredEca_whenDPoPOff_thenRejectedNoAccount() throws {
        loginNativeAndValidate(setup: setup, app: setup.requiredDPoPApp, useDPoP: false, expectation: .rejected)
    }

    /// Required ECA, DPoP on: DPoP-bound.
    func test_givenRequiredEca_whenDPoPOn_thenDPoP() throws {
        let app = setup.requiredDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: true, expectation: .dpop)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: true)
        restartNativeAndValidate(setup: setup, app: app, expectDPoP: true)
        assertNativeRevokeAndRefresh(app: app, expectDPoP: true)
    }

    /// After a rejection the form is usable again: fixing the DPoP choice then succeeds.
    func test_givenRejection_whenRetryWithDPoP_thenSucceeds() throws {
        let app = setup.requiredDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: false, expectation: .rejected)
        configureNative(setup: setup, app: app, useDPoP: true)
        submitNativeCredentials(setup: setup)
        seedNativeRTRState(setup: setup, app: app)
        validateNativeSession(setup: setup, app: app, expectDPoP: true)
    }

    // MARK: - Cancellation, fallback, reauth, lifecycle

    /// Cancel is offered only when an account already exists; cancelling add-user keeps the account.
    func test_givenLoggedInUser_whenCancelAddUserForm_thenStaysLoggedIn() throws {
        let app = setup.optionalDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: false, expectation: .bearer)
        triggerAddUser()
        XCTAssertTrue(nativeLoginPage.isShowingForm(), "Native form should appear for add-user")
        XCTAssertTrue(nativeLoginPage.isShowingCancelButton(), "Cancel should be offered when an account exists")
        nativeLoginPage.tapCancel()
        validateNativeSession(setup: setup, app: app, expectDPoP: false)
    }

    /// With no account there is nothing to return to, so Cancel is not offered.
    func test_givenNoUser_whenNativeFormShown_thenNoCancelButton() throws {
        launchNative(setup: setup, app: setup.optionalDPoPApp, useDPoP: false)
        XCTAssertFalse(nativeLoginPage.isShowingCancelButton(), "Cancel must not be offered without an account")
    }

    /// The browser fallback hands off to web authentication.
    func test_givenNativeForm_whenBrowserFallback_thenWebLoginShown() throws {
        launchNative(setup: setup, app: setup.optionalDPoPApp, useDPoP: false)
        nativeLoginPage.tapBrowserFallback()
        XCTAssertTrue(isShowingAnyWebLogin(), "Web authentication should be showing after the browser fallback")
    }

    /// Same user, DPoP login then logout then Bearer login: no DPoP carry-over.
    func test_givenSameUser_whenDPoPThenBearerReauth_thenBearerWithoutDPoPMarker() throws {
        let app = setup.optionalDPoPApp
        loginNativeAndValidate(setup: setup, app: app, useDPoP: true, expectation: .dpop)
        logout()
        XCTAssertTrue(nativeLoginPage.isShowingForm(), "Native form should return after logout")
        configureNative(setup: setup, app: app, useDPoP: false)
        submitNativeCredentials(setup: setup)
        seedNativeRTRState(setup: setup, app: app)
        validateNativeSession(setup: setup, app: app, expectDPoP: false)
        restartNativeAndValidate(setup: setup, app: app, expectDPoP: false)
    }

    /// Backgrounding and reactivating mid-form keeps the form usable.
    func test_givenNativeForm_whenBackgroundedAndReactivated_thenLoginStillWorks() throws {
        let app = setup.optionalDPoPApp
        launchNative(setup: setup, app: setup.requiredDPoPApp, useDPoP: true)
        // Switch apps through the Login Options import, then background mid-form.
        configureNative(setup: setup, app: app, useDPoP: false)
        sendAppToBackgroundAndBack()
        XCTAssertTrue(nativeLoginPage.isShowingForm(), "Native form should survive backgrounding")
        submitNativeCredentials(setup: setup)
        seedNativeRTRState(setup: setup, app: app)
        validateNativeSession(setup: setup, app: app, expectDPoP: false)
    }

    // MARK: - Diagnostics

    /// Diagnostics name the rejected authorize stage and carry no secrets.
    func test_givenFailedLogin_whenDiagnosticsShown_thenRedacted() throws {
        loginNativeAndValidate(setup: setup, app: setup.requiredDPoPApp, useDPoP: false, expectation: .rejected)
        let diagnostics = nativeLoginPage.diagnostics()
        XCTAssertTrue(diagnostics.contains("authorize"), "Diagnostics should name the authorize stage; got: \(diagnostics)")
        assertNativeDiagnosticsAreRedacted()
    }
}
