/*
 LoginPageObject.swift
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

import Foundation
import XCTest
import SalesforceSDKCore

/// Page object for interacting with the Salesforce login screen during UI tests.
/// Provides methods to configure login servers, login options and perform user authentication.
class LoginPageObject {
    let app: XCUIApplication

    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return loginNavigationBar().waitForExistence(timeout: UITestTimeouts.network)
    }
    
    func hasFilledUsernameField(username: String) -> Bool {
        return app.staticTexts[username].waitForExistence(timeout: UITestTimeouts.long)
    }
    
    func isShowingAdvancedAuth() -> Bool {
        return advancedAuthCloseButton().waitForExistence(timeout: UITestTimeouts.short)
    }
    
    func isShowingInvalidClientIdError() -> Bool {
        return invalidClientIdText().waitForExistence(timeout: UITestTimeouts.long)
    }

    func isShowingUnexpectedOauthError() -> Bool {
        return unexpectedOauthErrorText().waitForExistence(timeout: UITestTimeouts.long)
    }
    
    /// Returns to the login host list ("Change Server") — the landing screen under forced
    /// advanced authentication and the screen from which the login host and login options are
    /// configured.
    ///
    /// - If already on the host list, does nothing.
    /// - When `expectingBrowser` is true (forced advanced auth, the default), the external browser
    ///   (`ASWebAuthenticationSession`) is showing; cancelling it makes the SDK present the host
    ///   list (`oauthCoordinatorDidCancelBrowserAuthentication:`).
    /// - When `expectingBrowser` is false (flag imported OFF), the legacy in-app WebView is
    ///   showing; open the host list from its Settings gear → "Change Server".
    ///
    /// - Parameter expectingBrowser: whether the external browser (rather than the in-app WebView)
    ///   is the surface currently showing. Defaults to `true` since advanced auth is forced on by
    ///   default. Callers that have imported `forceAdvancedAuthentication = false` pass `false`.
    func returnToHostList(expectingBrowser: Bool = true) -> Void {
        if (changeServerNavigationBar().waitForExistence(timeout: UITestTimeouts.short)) {
            return
        }

        if (expectingBrowser) {
            // Forced advanced auth: cancelling the browser lands on the host list.
            if (advancedAuthCloseButton().waitForExistence(timeout: UITestTimeouts.network)) {
                tap(advancedAuthCloseButton())
            }
        } else {
            // Legacy WebView (flag OFF): reach the host list via the Settings gear.
            if (loginNavigationBar().waitForExistence(timeout: UITestTimeouts.network)) {
                tap(settingsButton())
                tap(changeServerButton())
            }
        }

        _ = changeServerNavigationBar().waitForExistence(timeout: UITestTimeouts.network)
    }

    /// Selects (or adds) the given login host. Assumes the host list ("Change Server") is already
    /// showing — call `returnToHostList()` first. Selecting or adding a host causes the SDK to
    /// restart authentication (relaunching the browser under forced advanced auth, or reloading
    /// the in-app WebView when the flag is off).
    func configureLoginHost(host: String) -> Void {
        if (hasHost(host: host)) {
            // Select host if it exists already
            tap(hostRow(host: host))
        } else {
            // Add host if it does not exist
            tap(addConnectionButton())
            setTextField(hostInputField(), value: host)
            tap(doneOnAddConnectionButton())
        }
    }
    
    /// Enters credentials on the active login surface.
    ///
    /// - Parameter advancedAuth: when true the surface is the external browser
    ///   (`ASWebAuthenticationSession`) — the default under forced advanced auth — where fields are
    ///   submitted by pressing return. When false the surface is the in-app WebView, where the
    ///   on-page "Log In" button is tapped instead. Defaults to `true` to match the SDK's default of
    ///   forcing advanced authentication.
    func performLogin(username: String, password: String, advancedAuth: Bool = true) {
        waitForLoginFormReady()
        setTextField(usernameField(), value: username)
        if advancedAuth {
            usernameField().typeText(XCUIKeyboardKey.return.rawValue)
        } else {
            dismissKeyboardAfterTyping()
            tap(loginButton(), timeout: UITestTimeouts.network)
        }
        setTextField(passwordField(), value: password)
        if advancedAuth {
            passwordField().typeText(XCUIKeyboardKey.return.rawValue)
        } else {
            dismissKeyboardAfterTyping()
            tap(loginButton(), timeout: UITestTimeouts.network)
        }
        tapIfPresent(allowButton(), timeout: UITestTimeouts.network)
    }

    /// Performs login via the "Login for Admin" flow.
    /// Taps Settings → "Login for Admin" which triggers ASWebAuthenticationSession (native browser),
    /// then completes authentication in the browser.
    func performLoginForAdmin(username: String, password: String) {
        tap(settingsButton())
        tap(loginForAdminButton())

        // Wait for ASWebAuthenticationSession browser to appear
        let topBar = app.otherElements["TopBrowserBar"]
        _ = topBar.waitForExistence(timeout: UITestTimeouts.long)

        performLogin(username: username, password: password, advancedAuth: true)
    }

    func performWelcomeLogin(password: String, advancedAuth: Bool = false) {
        tap(loginButton(), timeout: UITestTimeouts.network)
        setTextField(passwordField(), value: password)
        if advancedAuth {
            passwordField().typeText(XCUIKeyboardKey.return.rawValue)
        } else {
            dismissKeyboardAfterTyping()
            tap(loginButton(), timeout: UITestTimeouts.network)
        }
        tapIfPresent(allowButton(), timeout: UITestTimeouts.network)
    }
    
    func configureLoginOptions(
        staticAppConfig: AppConfig?,
        staticScopes: String,
        dynamicAppConfig: AppConfig?,
        dynamicScopes: String,
        useWebServerFlow: Bool,
        useHybridFlow: Bool,
        forceAdvancedAuthentication: Bool? = nil,
        discoveryLoginHost: String,
        discoveryUsername: String,
    ) -> Void {
        tap(settingsButton())
        tap(loginOptionsButton())
        let loginOptionsPage = LoginOptionsPageObject(testApp: app)
        loginOptionsPage.configure(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            discoveryLoginHost: discoveryLoginHost,
            discoveryUsername: discoveryUsername
        )
    }

    // MARK: - Presentation Probes

    /// True when the external browser (`ASWebAuthenticationSession`) login surface is showing,
    /// detected by the SDK's browser chrome ("TopBrowserBar"). For the positive assertion keep the
    /// default (`long`) timeout, since selecting a host relaunches the browser and it takes a moment
    /// to appear; for the negative "no external browser" assertion pass `short`.
    func isShowingBrowserLogin(timeout: TimeInterval = UITestTimeouts.long) -> Bool {
        return advancedAuthCloseButton().waitForExistence(timeout: timeout)
    }

    /// True when the legacy in-app WebView login form is showing, detected by the username text
    /// field inside the web content. Non-asserting sibling of `waitForLoginFormReady()`. Pass a
    /// short timeout for the negative "no in-app WebView" assertion; keep the network default for
    /// the positive case, which must wait for the real login page to load.
    func isShowingInAppLoginForm(timeout: TimeInterval = UITestTimeouts.network) -> Bool {
        return app.webViews.webViews.webViews.textFields.firstMatch.waitForExistence(timeout: timeout)
    }

    /// True when the Settings gear is present on the current login nav bar. Under forced advanced
    /// auth the gear lives on the host list; on the legacy path it lives on the in-app WebView
    /// ("Log In"). Both expose the same accessibility identifier "settings".
    func isShowingSettingsGear() -> Bool {
        return settingsButton().waitForExistence(timeout: UITestTimeouts.long)
    }

    /// Opens the Login Options screen from the Settings gear (gear → "Login Options").
    func openLoginOptions() {
        tap(settingsButton())
        tap(loginOptionsButton())
    }

    /// True when the Authentication Flow Types dev screen — the harness's own flag-driving surface —
    /// is showing, identified by its title and the force-advanced-auth toggle.
    func isShowingAuthFlowTypesView() -> Bool {
        let title = SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_AUTH_FLOW_TYPES_TITLE")
        let titleShown = app.staticTexts[title].waitForExistence(timeout: UITestTimeouts.long)
        let toggleShown = forceAdvancedAuthToggle().waitForExistence(timeout: UITestTimeouts.short)
        return titleShown && toggleShown
    }

    /// True when an accessible back control is present on the current login nav bar — the host list
    /// under forced advanced auth (surfaced by the browser-cancel path) or the in-app WebView. Both
    /// screens use the same image-only `globalheader-back-arrow` bar button, which carries no
    /// accessibility identifier, so it is matched positionally as the leftmost nav-bar button and
    /// disambiguated from the Cancel button (pre-fix left item) and the gear.
    func isShowingBackButton() -> Bool {
        let button = backButton()
        guard button.waitForExistence(timeout: UITestTimeouts.long), button.isHittable else {
            return false
        }
        return button.label != "Cancel" && button.identifier != "settings"
    }

    /// Taps the nav-bar back control (see `isShowingBackButton()`), which stops the in-flight
    /// authentication and returns to the existing account list without completing login.
    func tapBackButton() {
        tap(backButton())
    }

    // MARK: - Login Form Readiness

    /// Waits for the login form (external browser or in-app WKWebView) to be fully loaded and
    /// interactive. After a login host change or an auth restart the surface navigates to a new
    /// URL and the form elements are not immediately available. This waits for the username text
    /// field inside the web content to appear, which signals the login form has fully rendered.
    private func waitForLoginFormReady() {
        let webViewTextField = app.webViews.webViews.webViews.textFields.firstMatch
        let formReady = webViewTextField.waitForExistence(timeout: UITestTimeouts.network)
        XCTAssertTrue(formReady, "Login form did not load within \(UITestTimeouts.network)s — WebView may not have finished loading the login page")
    }

    // MARK: - UI Element Accessors

    private func loginNavigationBar() -> XCUIElement {
        return app.navigationBars["Log In"]
    }
    
    /// The Settings gear. Both the in-app WebView screen (`SFLoginViewController`, nav bar "Log In")
    /// and the forced-advanced-auth host list (`SFSDKLoginHostListViewController`, nav bar
    /// "Change Server") expose it with the same accessibility identifier "settings", so matching by
    /// identifier across nav bars finds whichever screen is currently showing. The menu contents
    /// differ per screen (the host-list gear exposes only "Login Options"; the WebView gear also
    /// exposes Change Server / Clear Cookies / Reload / "Login for Admin").
    private func settingsButton() -> XCUIElement {
        return app.navigationBars.buttons["settings"]
    }
    
    private func changeServerButton() -> XCUIElement {
        return app.buttons["Change Server"]
    }
    
    private func loginOptionsButton() -> XCUIElement {
        return app.buttons["Login Options"]
    }

    private func loginForAdminButton() -> XCUIElement {
        return app.buttons["Login for Admin"]
    }

    /// The force-advanced-auth toggle on the Authentication Flow Types dev screen. Used only to
    /// confirm that screen is showing after opening Login Options — not to drive the flag (the
    /// harness imports the flag via `AuthFlowTypesPageObject`).
    private func forceAdvancedAuthToggle() -> XCUIElement {
        return app.switches["forceAdvancedAuthToggle"]
    }

    /// The image-only back control on the current login nav bar. Both the host list
    /// (`SFSDKLoginHostListViewController`, forced advanced auth) and the in-app WebView
    /// (`SFLoginViewController`, flag off) render it from `globalheader-back-arrow` with no
    /// accessibility identifier, so it is matched positionally as the leftmost nav-bar button.
    /// Callers must disambiguate it from the pre-fix Cancel button and the gear (see
    /// `isShowingBackButton()`).
    private func backButton() -> XCUIElement {
        return app.navigationBars.buttons.element(boundBy: 0)
    }

    private func changeServerNavigationBar() -> XCUIElement {
        return app.navigationBars["Change Server"]
    }
    
    private func addConnectionButton() -> XCUIElement {
        return changeServerNavigationBar().buttons["Add"]
    }
    
    private func addConnectionNavigationBar() -> XCUIElement {
        return app.navigationBars["Add Connection"]
    }
    
    private func hostInputField() -> XCUIElement {
        return app.textFields["addconn_hostInput"]
    }
    
    private func doneOnAddConnectionButton() -> XCUIElement {
        return addConnectionNavigationBar().buttons["Done"]
    }
    
    private func hostRow(host: String) -> XCUIElement {
        return app.staticTexts[host].firstMatch
    }
    
    /// Dismisses the keyboard after typing in a field. Tries the toolbar "Done" button first;
    /// if not found (e.g. on some simulators it is exposed as a Key, not Button), taps the
    /// password label or username label to dismiss.
    private func dismissKeyboardAfterTyping() {
        if !tapIfPresent(toolbarDoneButton()) {
            let passwordLabel = passwordFieldLabel()
            if passwordLabel.exists {
                passwordLabel.tap()
            } else {
                tap(usernameFieldLabel())
            }
        }
    }

    private func toolbarDoneButton() -> XCUIElement {
        return app.toolbars["Toolbar"].buttons["Done"]
    }
    
    private func invalidClientIdText() -> XCUIElement {
        return app.staticTexts["error=invalid_client_id&error_description=client%20identifier%20invalid"]
    }
    
    private func unexpectedOauthErrorText() -> XCUIElement {
        return app.staticTexts["OAUTH_APPROVAL_ERROR_GENERIC : An unexpected error has occurred during authentication. Please try again."]
    }

    private func usernameFieldLabel() -> XCUIElement {
        return app.staticTexts["Username"]
    }
    
    private func usernameField() -> XCUIElement {
        return app.descendants(matching: .textField).element
    }
    
    private func passwordFieldLabel() -> XCUIElement {
        return app.staticTexts["Password"]
    }
    
    private func passwordField() -> XCUIElement {
        return app.descendants(matching: .secureTextField).element
    }
    
    private func loginButton() -> XCUIElement {
        return app.webViews.webViews.webViews.buttons["Log In"]
    }
    
    private func allowButton() -> XCUIElement {
        let buttons = app.webViews.webViews.webViews.buttons
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Allow'")
        return buttons.matching(predicate).firstMatch
    }

    private func advancedAuthCloseButton() -> XCUIElement {
        let topBar = app.otherElements["TopBrowserBar"]
        let closeButton = topBar.buttons["Close"]
        if closeButton.exists {
            return closeButton
        }
        // Earlier iOS versions use "Cancel"
        return topBar.buttons["Cancel"]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement, timeout: TimeInterval = UITestTimeouts.long, file: StaticString = #file, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element.debugDescription) did not appear within \(timeout)s", file: file, line: line)
        element.tap()
    }

    @discardableResult
    private func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval = UITestTimeouts.long) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
    
    private func setTextField(_ textField: XCUIElement, value: String) {
        tap(textField)
        
        // Return if the value is already set
        if textField.value as? String == value {
            return
        }

        // Clear any existing text
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            tap(textField) // second tap should bring up menu
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: UITestTimeouts.short) {
                selectAll.tap()
                textField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
        
        textField.typeText(value)
    }
    
    // MARK: - Other
    
    private func hasHost(host: String) -> Bool {
        let row = hostRow(host: host)
        return row.waitForExistence(timeout: UITestTimeouts.long)
    }
}

