/*
 ForceAdvancedAuthTests.swift
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

/// UI tests for the `SalesforceSDKManager.forceAdvancedAuthentication` flag (GUS W-23126676),
/// which forces Advanced Authentication (browser-based OAuth via `ASWebAuthenticationSession`) to
/// be used for every interactive login regardless of whether the login server has My Domain /
/// opts into native-browser login. It **defaults to ON**.
///
/// These tests close the gap the unit tests cannot: they assert the login **modality** end to end
/// — that the flag actually flips the surface between the external browser (ON) and the legacy
/// in-app WebView (OFF) — and cover the iOS-only presentation regressions the forced path
/// introduced (spec iOS design §5), where the in-app login screen is skipped so its back button
/// and dev-menu gear had to be restored on the server-picker screen
/// (`SFSDKLoginHostListViewController`).
///
/// Modality detection (see `LoginPageObject` presentation probes):
/// - External browser — the SDK's browser chrome `TopBrowserBar` (`isShowingBrowserLogin`).
/// - In-app WebView — the username field inside the web content (`isShowingInAppLoginForm`).
///
/// Driving the flag on iOS: the flag lives on the in-app `SalesforceSDKManager` singleton, which
/// the out-of-process XCUITest runner cannot set directly. It is driven the same way the harness
/// drives `useWebServerFlow` / `useHybridFlow` — the dev-menu Auth Flow Types JSON-import hook
/// (`{"forceAdvancedAuthentication": false}`), reachable from the Login Options gear. The §5b fix
/// surfaces that gear on the server picker, so the ON path can reach Login Options even though the
/// forced path skips the in-app login screen. The flag re-defaults to ON at every process launch,
/// so — unlike Android — there is **no** process-global state to save/restore in `setUp`/`tearDown`
/// on iOS: ON cases simply `launch()`; OFF cases import `false`.
///
/// These are **live-org integration tests** requiring `shared/test/ui_test_config.json`; they run
/// in the **nightly** `AuthFlowTester` suite, not per-PR CI. The one-time `ASWebAuthenticationSession`
/// system consent alert is absorbed by the `UIInterruptionMonitor` in `BaseAuthFlowTester.setUp()`.
///
/// NB: Tests use the first user from ui_test_config.json.
///
class ForceAdvancedAuthTests: BaseAuthFlowTester {

    /// Display name of the built-in standard login server (`login.salesforce.com`) in the host
    /// list — set from `LOGIN_SERVER_PRODUCTION` by `SFSDKLoginHostStorage`. Used to make the
    /// "standard server" cases target `login.salesforce.com` explicitly rather than relying on the
    /// implicit default selection.
    private let productionHostDisplayName = "Production"

    // MARK: - Modality: flag gates external browser vs. in-app WebView

    /// Flag ON (default), standard server (`login.salesforce.com`).
    ///
    /// Headline regression — the case no existing test covers: forced Advanced Auth must launch the
    /// external browser even on a standard login server that has no My Domain / auth-config opt-in.
    /// Asserts the external browser is showing and the in-app WebView login form is not. Stops at
    /// the browser surface rather than completing a token round-trip, since the standard server may
    /// have no live test user.
    func testForceAdvancedAuth_StandardServer_LaunchesExternalBrowser() throws {
        launch()

        // Fresh launch shows the external browser (advanced auth forced on by default). Cancel it to
        // reach the host list, then select the standard server so the browser relaunches against
        // login.salesforce.com specifically.
        returnToLoginHostList(expectingBrowser: true)
        configureLoginHost(productionHostDisplayName)

        XCTAssertTrue(isShowingBrowserLogin(),
                      "Forced advanced auth on the standard server should launch the external browser")
        XCTAssertFalse(isShowingInAppLoginForm(timeout: UITestTimeouts.short),
                       "The in-app WebView login form must NOT be shown when advanced auth is forced on")
    }

    /// Flag OFF (imported explicitly), standard server.
    ///
    /// Proves the flag genuinely gates the surface: with advanced auth disabled, a standard server
    /// (no browser opt-in) falls back to the legacy in-app WebView. Asserts the WebView login form
    /// is showing and the external browser is not.
    func testForceAdvancedAuth_Disabled_StandardServer_UsesInAppWebView() throws {
        launch()

        // Reach the host list (fresh launch shows the browser), pin the standard server, then
        // import forceAdvancedAuthentication = false via the gear → Login Options JSON hook. No
        // app config override — the bootconfig.plist consumer key is an org-specific test CA that
        // may not resolve on login.salesforce.com, so we don't wait for the login page to finish
        // loading. Instead we assert that the SDK chose the in-app WebView modality (the "Log In"
        // nav bar appears as soon as SFLoginViewController is presented, before the WKWebView
        // completes the page load). Closing Login Options restarts authentication, now in WebView.
        returnToLoginHostList(expectingBrowser: true)
        configureLoginHost(productionHostDisplayName)
        returnToLoginHostList(expectingBrowser: true)
        setForceAdvancedAuthentication(false)

        XCTAssertTrue(isShowingLoginViewController(),
                      "With advanced auth disabled, the standard server should present the in-app login view controller")
        XCTAssertFalse(isShowingBrowserLogin(timeout: UITestTimeouts.short),
                       "The external browser must NOT be shown when advanced auth is disabled")
    }

    /// Flag ON (default), `regular_auth` My Domain that does NOT opt into browser login.
    ///
    /// Proves the flag overrides a host that did not opt in: the login is forced into the external
    /// browser and completes end to end (credentials + REST call validated by
    /// `launchLoginAndValidate`). Advanced auth always pairs with the web server flow, so this is a
    /// web-server-flow login.
    func testForceAdvancedAuth_MyDomainRegularHost_RemainsBrowser() throws {
        // Pass `true` to explicitly force advanced auth ON so login runs in the external browser;
        // validation asserts credentials and a REST round-trip.
        launchLoginAndValidate(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaOpaque,
            forceAdvancedAuthentication: true
        )
    }

    // MARK: - iOS presentation regressions (spec iOS design §5)

    /// §5a — Flag ON (default). With one user already logged in, adding another account under forced
    /// advanced auth reaches the server picker; the picker must present an accessible back control
    /// (the `globalheader-back-arrow`, mirrored from the in-app login screen) that returns to the
    /// existing account list without completing login.
    ///
    /// Pre-fix regression this guards: the forced path created the picker with `hidesCancelButton =
    /// YES` and no back control, stranding the add-user flow.
    func testForceAdvancedAuth_AddAdditionalUser_BackButtonAccessible() throws {
        // Log in the first user with advanced auth explicitly ON (external browser).
        launchAndLogin(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaOpaque,
            forceAdvancedAuthentication: true
        )

        // Trigger Add New Account (Switch User → New User): under forced advanced auth this launches
        // the external browser for the additional user while preserving the current user (the
        // user-management screen is dismissed before the auth window is presented). Cancel the
        // browser to land on the server picker.
        triggerAddUser()
        returnToLoginHostList(expectingBrowser: true)

        XCTAssertTrue(isShowingLoginBackButton(),
                      "Under forced advanced auth, the server picker for an added user should show an accessible back control")

        // Tapping back stops the in-flight authentication and dismisses the auth window, returning to
        // the app with the existing user still logged in — the add-user flow is abandoned without
        // completing login.
        tapLoginBackButton()
        assertMainPageLoaded()

        // The original user is still logged in; it is cleaned up by the default tearDown logout.
    }

    /// §5b — Flag ON (default), fresh launch. The server picker must expose the dev-menu gear, and
    /// its Login Options entry must open the Auth Flow Types screen.
    ///
    /// This is the guard for the harness's own flag-driving mechanism: if the gear regresses off the
    /// forced-path picker, the dev-menu flag-flip path (and therefore the OFF cases above) is dead.
    func testForceAdvancedAuth_DefaultOn_LoginOptionsReachable() throws {
        launch()

        // Fresh launch shows the browser under the default flag; cancel it to reach the picker.
        returnToLoginHostList(expectingBrowser: true)

        XCTAssertTrue(isShowingLoginSettingsGear(),
                      "Under forced advanced auth, the server picker should expose the dev-menu gear")

        openLoginOptions()
        XCTAssertTrue(isShowingAuthFlowTypesView(),
                      "The picker's Login Options entry should open the Auth Flow Types dev screen")
    }

    /// §5a/§5b parity — Flag OFF. With one user already logged in, adding another account on the
    /// legacy WebView path must show the **same** back control and dev-menu gear, proving the §5 fix
    /// is flag-independent and legacy-mode chrome did not regress. On the OFF path the add-user
    /// surface is the in-app WebView (`SFLoginViewController`) directly, so the controls are asserted
    /// there rather than on the server picker.
    func testForceAdvancedAuth_Disabled_BackAndGearStillPresent() throws {
        // Log in the first user with advanced auth disabled (legacy in-app WebView). The imported
        // flag persists for the rest of this process, so the subsequent add-user login also uses the
        // WebView.
        launchAndLogin(
            loginHost: .regularAuth,
            user: .first,
            staticAppConfigName: .ecaOpaque,
            forceAdvancedAuthentication: false
        )

        // Add New Account on the legacy path lands directly on the in-app WebView login screen.
        triggerAddUser()

        XCTAssertTrue(isShowingLoginBackButton(),
                      "On the legacy WebView path, adding a user should show the same accessible back control")
        XCTAssertTrue(isShowingLoginSettingsGear(),
                      "On the legacy WebView path, adding a user should show the same dev-menu gear")
    }
}
