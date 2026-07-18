/*
 BaseAuthFlowTester.swift
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

class BaseAuthFlowTester: XCTestCase {
    // App object
    private var app: XCUIApplication!

    // App Pages
    private var loginPage: LoginPageObject!
    private var mainPage: AuthFlowTesterMainPageObject!
    private var logoutAtTearDown: Bool = true

    // Test configuration
    private let testConfig = UITestConfigUtils.shared

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            let dominated = ["Allow", "OK", "Continue", "Allow While Using App",
                             "Don\u{2019}t Allow", "Allow Paste"]
            for label in dominated {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }
    
    override func tearDown() {
        if (logoutAtTearDown) {
            logout()
        }
        // Reset DPoP toggle to default (off) state for the next test
        resetDPoPToggle()
        super.tearDown()
    }

    /// Resets the DPoP toggle to off by opening Login Options and disabling it if currently on.
    /// This prevents DPoP state from leaking between tests.
    private func resetDPoPToggle() {
        // If not logged out, we can't reach the Login Options sheet from where the test stopped
        // (it lives behind the login screen's Settings gear). Skip the UI-driven reset: the next
        // test's `launch()` calls `XCUIApplication.launch()`, which per Apple's documentation
        // terminates any running instance and starts a fresh process, so the in-memory
        // `SalesforceManager.shared.usesDPoP` singleton is reset to its default (off) before the
        // next test observes it. `configureLoginOptions` also unconditionally toggles the DPoP
        // switch to match the incoming `useDPoP` value, so even a hypothetically leaked singleton
        // would be force-set correctly on the very next login.
        if !logoutAtTearDown {
            return
        }

        // Navigate to login options to reset toggle
        if let loginPage = loginPage, let app = app {
            // Check if we're on the main screen by looking for a known element
            if !app.navigationBars["AuthFlowTester"].waitForExistence(timeout: 1.0) {
                // Not on main screen, can't reliably navigate to login options
                return
            }

            // Go to login options and disable DPoP
            if app.buttons["Settings"].waitForExistence(timeout: 1.0) {
                app.buttons["Settings"].tap()
                if app.buttons["Login Options"].waitForExistence(timeout: 1.0) {
                    app.buttons["Login Options"].tap()
                    LoginOptionsPageObject(testApp: app).disableDPoP()
                    app.buttons["loginOptionsCloseButton"].tap()
                }
            }
        }
    }
    
    // MARK: - Public API for Subclasses
    
    /// Launches the application and ensures it starts in a logged-out state on a known login server.
    ///
    /// Initializes the app and page objects, launches the app, and logs out if a user is already
    /// logged in. Then resets the login server to `login.salesforce.com`: the login host persists
    /// across tests, so a prior test that selected a discovery or advanced-auth org would otherwise
    /// strand the next test (its `login()` assumes the browser is showing on entry). Leaves the app
    /// on the external browser surface (the default, advanced auth forced on) against the standard
    /// server, which is exactly the state `login()` expects on entry.
    func launch() {
        app = XCUIApplication()

        // Set environment variable to indicate we're running UI tests
        // This is used to show/hide certain UI elements like DiscoveryResultEditor
        app.launchEnvironment["IS_UI_TESTING"] = "1"

        loginPage = LoginPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
        app.launch()

        // Tap the app to trigger any pending system alert interruption handlers.
        // On CI, system alerts (tracking permission, paste confirmation) can block
        // the UI if not dismissed before interacting with app elements.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Start logged out
        if (mainPage.isShowing()) {
            logout()
        }

        // Reset to a known login server so a discovery or advanced-auth host leaked by a prior test
        // cannot strand this one. A fresh launch re-defaults advanced auth on, so the external
        // browser is normally showing; a leaked discovery host instead runs discovery in the in-app
        // WebView. Reach the host list from whichever surface is up — the browser is the common case
        // (probe it with the generous default timeout), the in-app WebView the fallback — then pin
        // the standard server (selecting it relaunches the browser against login.salesforce.com).
        if loginPage.isShowingBrowserLogin() {
            loginPage.returnToHostList(expectingBrowser: true)
        } else {
            loginPage.returnToHostList(expectingBrowser: false)
        }
        loginPage.configureLoginHost(host: "login.salesforce.com")
    }

    /// Performs login with the specified configuration.
    ///
    /// Configures the login options and performs authentication for the specified user.
    /// Must be called after `launch()`.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to log in with.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - forceAdvancedAuthentication: Overrides the SDK's process-global "force advanced
    ///     authentication" setting for this login. Leave `nil` to inherit the production default
    ///     (advanced auth forced on — the external browser is used for interactive login). Pass
    ///     `false` to exercise the legacy in-app WebView path, or `true` to force it explicitly.
    ///   - useWelcomeDiscovery: When true, configures simulated domain discovery. Defaults to `false`.
    ///   - loginForAdmin: When true, uses the "Login for Admin" flow (browser-based auth via the
    ///     in-app WebView's Settings menu). Requires advanced auth disabled so the WebView — and its
    ///     "Login for Admin" gear entry — is shown. Defaults to `false`.
    func login(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        useDPoP: Bool = false
    ) {
        let userConfig = getUser(loginHost: loginHost, user: user)
        let hostConfig = getLoginHost(loginHost: loginHost)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        let dynamicScopes = dynamicAppConfig == nil ? "" : testConfig.getScopesToRequest(for: dynamicAppConfig!, dynamicScopeSelection)

        // Advanced auth is forced on by default; only an explicit `false` disables it. When it is
        // on, interactive login happens in the external browser; when off, in the in-app WebView.
        let advancedAuthEnabled = forceAdvancedAuthentication != false
        // The surface used to enter credentials: the external browser under advanced auth (forced
        // on, or a host that itself requires it), otherwise the in-app WebView. Login for Admin is
        // special-cased below: it always finishes in the browser regardless of this value.
        let usesBrowser = advancedAuthEnabled || loginHost == .advancedAuth

        // A fresh login surface always starts under the process default (advanced auth on), so the
        // external browser is showing. Cancel it to reach the host list, where login options and
        // the login host are configured. (The flag re-defaults to on at every process launch.)
        loginPage.returnToHostList(expectingBrowser: true)

        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            discoveryLoginHost: useWelcomeDiscovery ? hostConfig.urlNoProtocol : "",
            discoveryUsername: useWelcomeDiscovery ? userConfig.username : "",
            useDPoP: useDPoP
        )

        // Closing login options restarts authentication, so the login surface reappears — the
        // browser when advanced auth is on, the in-app WebView when it was disabled. Return to the
        // host list to select the login host. Configuring the host last matches how a real user
        // arrives at the picker and keeps the login-options gear reachable until then.
        // When useWelcomeDiscovery is true, use welcome.salesforce.com/discovery as the login server.
        loginPage.returnToHostList(expectingBrowser: advancedAuthEnabled)
        let loginHostToUse = useWelcomeDiscovery ? "welcome.salesforce.com/discovery" : hostConfig.urlNoProtocol
        loginPage.configureLoginHost(host: loginHostToUse)

        // Invalid app config
        if (dynamicAppConfigName == .invalid || (dynamicAppConfigName == nil && staticAppConfigName == .invalid)) {
            XCTAssertTrue(loginPage.isShowingInvalidClientIdError(), "Login page should show invalid client id error")
            logoutAtTearDown = false
            return
        }

        // Login for Admin (browser-based auth via the in-app WebView's Settings menu)
        if (loginForAdmin) {
            loginPage.performLoginForAdmin(username: userConfig.username, password: userConfig.password)
        }
        // Welcome login: discovery always begins in the in-app WebView; once the My Domain is
        // resolved the SDK switches to the browser when advanced auth is on, so the password step
        // uses whichever surface `usesBrowser` indicates.
        else if (useWelcomeDiscovery) {
            XCTAssertTrue(loginPage.hasFilledUsernameField(username: userConfig.username), "Login page should have pre-filled username")
            loginPage.performWelcomeLogin(password: userConfig.password, advancedAuth: usesBrowser)
        }
        // Regular or advanced auth
        else {
            loginPage.performLogin(username: userConfig.username, password: userConfig.password, advancedAuth: usesBrowser)
        }

        // Invalid scope
        if (dynamicScopeSelection == .invalid || (dynamicAppConfig == nil && staticScopeSelection == .invalid)) {
            XCTAssertTrue(loginPage.isShowingUnexpectedOauthError(), "Screen should show OAuth Error")
            logoutAtTearDown = false
        }
    }
    
    /// Logs out the current user by tapping the logout button and confirming.
    ///
    /// Safe to call even if the app was never launched (no-op in that case).
    func logout() {
        // In case the app was never launched
        if (app != nil) {
            mainPage.performLogout()
        }
    }
    
    /// Switches to an already logged-in user and validates the credentials.
    ///
    /// Use this method when multiple users are logged in and you want to switch between them.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to switch to.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - userAppConfigName: The app configuration the user was logged in with.
    ///   - userScopeSelection: The scope selection the user was logged in with. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether web server OAuth flow was used. Defaults to `true`.
    ///   - useHybridFlow: Whether hybrid authentication flow was used. Defaults to `true`.
    ///   - isMultiUser: Whether multiple users are still logged in after the switch. Defaults to `false`.
    func switchToUserAndValidate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        isMultiUser: Bool = false
    ) {
        // Switch user
        mainPage.switchToUser(username: getUser(loginHost: loginHost, user: user).username)

        // Validate
        validate(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            isMultiUser: isMultiUser
        )
    }

    /// Switches to an already logged-in user and validates the user credentials.
    ///
    /// Use this method when multiple users are logged in and you want to switch between them.
    /// This method does not validate the oauth configuration.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to switch to.
    ///   - userAppConfigName: The app configuration the user was logged in with.
    ///   - userScopeSelection: The scope selection the user was logged in with. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether web server OAuth flow was used. Defaults to `true`.
    ///   - useHybridFlow: Whether hybrid authentication flow was used. Defaults to `true`.
    func switchToUserAndValidateUser(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        loginForAdmin: Bool = false,
        isMultiUser: Bool = false
    ) {
        // Switch user
        mainPage.switchToUser(username: getUser(loginHost: loginHost, user: user).username)

        // Validate user and feature flags
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: loginForAdmin || loginHost == .advancedAuth || (forceAdvancedAuthentication != false),
            isMultiUser: isMultiUser
        )
    }

    /// Launches the app and performs login.
    ///
    /// This is a convenience method that combines `launch()` and `login()` in one call.
    /// Use this for the initial login flow in tests.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to log in with.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    func launchAndLogin(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        loginForAdmin: Bool = false,
    ) {
        // Launch
        launch()

        // Login
        login(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            dynamicAppConfigName: dynamicAppConfigName,
            dynamicScopeSelection: dynamicScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            loginForAdmin: loginForAdmin,
        )
    }
    
    /// Launches the app, performs login, and validates the resulting credentials.
    ///
    /// This is a convenience method that combines `launch()`, `login()`, and validation in one call.
    /// Use this for the initial login flow in tests.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use. Defaults to `.regularAuth`.
    ///   - user: The user to log in with. Defaults to `.first`.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - useWelcomeDiscovery: When true, configures simulated domain discovery. Defaults to `false`.
    func launchLoginAndValidate(
        loginHost: KnownLoginHostConfig = .regularAuth,
        user: KnownUserConfig = .first,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        isMultiUser: Bool = false,
        useDPoP: Bool = false
    ) {
        let useStaticConfiguration = dynamicAppConfigName == nil
        let userAppConfigName = useStaticConfiguration ? staticAppConfigName : dynamicAppConfigName!
        let userScopeSelection = useStaticConfiguration ? staticScopeSelection : dynamicScopeSelection

        // Launch
        launch()

        // Login
        login(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            dynamicAppConfigName: dynamicAppConfigName,
            dynamicScopeSelection: dynamicScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            useWelcomeDiscovery: useWelcomeDiscovery,
            loginForAdmin: loginForAdmin,
            useDPoP: useDPoP
        )

        // Validate
        // Login for Admin always uses web server flow regardless of the useWebServerFlow setting
        let effectiveUseWebServerFlow = loginForAdmin || useWebServerFlow
        validate(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: effectiveUseWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            isMultiUser: isMultiUser,
            usesWelcomeDiscovery: useWelcomeDiscovery,
            loginForAdmin: loginForAdmin,
            useDPoP: useDPoP
        )
    }
    
    /// Logs in an additional user (multi-user scenario) WITHOUT performing credential validation.
    ///
    /// Use this method when you need to add a second user account but don't need full credential
    /// validation (e.g., when using advanced auth where identity data may not be immediately available).
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to log in with.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    func loginOtherUser(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
    ) {
        // Switch to add new user
        mainPage.performAddUser()

        // Login
        login(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
        )

        // Wait for main page to show (user is logged in)
        assertMainPageLoaded()
    }

    /// Logs in an additional user (multi-user scenario) and validates the credentials.
    ///
    /// Use this method after an initial user is already logged in to add another user account.
    /// Taps the "Add User" button before performing login.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - user: The user to log in with.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime). Is used when provided.
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - isMultiUser: Whether multiple users are logged in after this login. Defaults to `true`.
    func loginOtherUserAndValidate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        isMultiUser: Bool = true,
        useDPoP: Bool = false
    ) {
        let useStaticConfiguration = dynamicAppConfigName == nil
        let userAppConfigName = useStaticConfiguration ? staticAppConfigName : dynamicAppConfigName!
        let userScopeSelection = useStaticConfiguration ? staticScopeSelection : dynamicScopeSelection

        // Switch to add new user
        mainPage.performAddUser()

        // Login
        login(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            dynamicAppConfigName: dynamicAppConfigName,
            dynamicScopeSelection: dynamicScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            useDPoP: useDPoP
        )

        // Validate
        validate(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            isMultiUser: isMultiUser,
            useDPoP: useDPoP
        )
    }

    /// Restarts the app and validates that the user session persists.
    ///
    /// Terminates and relaunches the app, then validates that the user is still logged in
    /// with the expected credentials. Use this to test session persistence.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use. Defaults to `.regularAuth`.
    ///   - user: The user that should still be logged in after restart. Defaults to `.first`.
    ///   - userAppConfigName: The app configuration the user was logged in with.
    ///   - userScopeSelection: The scope selection the user was logged in with. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether web server OAuth flow was used. Defaults to `true`.
    ///   - useHybridFlow: Whether hybrid authentication flow was used. Defaults to `true`.
    ///   - loginForAdmin: When true, Login for Admin was used (browser-based auth), which sets the BW flag. Defaults to `false`.
    ///   - usesWelcomeDiscovery: When true, welcome discovery was used, which sets the WD flag. Defaults to `false`.
    func restartAndValidateUser(
        loginHost: KnownLoginHostConfig = .regularAuth,
        user: KnownUserConfig = .first,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        loginForAdmin: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        isMultiUser: Bool = false
    ) {
        // Restart
        app.terminate()
        app.launch()

        // Restore auth flow settings lost on restart
        mainPage.setAuthFlowTypes(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)

        // Validate user and feature flags
        // Not checking static app config since it will depend on the bootconfig of the target app
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: loginForAdmin || loginHost == .advancedAuth || (forceAdvancedAuthentication != false),
            usesWelcomeDiscovery: usesWelcomeDiscovery,
            isMultiUser: isMultiUser
        )
    }
    
    /// Migrates the refresh token to a new app configuration and validates the result.
    ///
    /// Performs a refresh token migration from the current app configuration to a new one,
    /// then validates that the credentials are updated correctly and the refresh token has changed.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - migrationAppConfigName: The app configuration to migrate to.
    ///   - migrationScopeSelection: The scope selection for the migration target. Defaults to `.empty`.
    ///   - migrationUseWebServerFlow: Whether to use web server OAuth flow for migration. Defaults to `true`.
    ///   - migrationUseHybridFlow: Whether to use hybrid authentication flow for migration. Defaults to `true`.
    func migrateAndValidate(
        loginHost: KnownLoginHostConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        migrationAppConfigName: KnownAppConfig,
        migrationScopeSelection: ScopeSelection = .empty,
        migrationUseWebServerFlow: Bool = true,
        migrationUseHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool? = nil,
        useDPoP: Bool = false
    ) {
        // Get original credentials before migration
        let originalUserCredentials = mainPage.getUserCredentials()

        // Get current user
        let user = getKnownUserConfig(loginHost: loginHost, byUsername: originalUserCredentials.username)


        // Migrate refresh token
        migrateRefreshToken(
            appConfigName: migrationAppConfigName,
            scopeSelection: migrationScopeSelection,
            useWebServerFlow: migrationUseWebServerFlow,
            useHybridFlow: migrationUseHybridFlow
        )

        // Validate after migration.
        //
        // NB on `useDPoP`: The SDK's Change Key sheet does not expose a DPoP toggle, so the
        // migration refresh exchange inherits `SalesforceManager.shared.usesDPoP` from the initial
        // login. We forward `useDPoP` here purely to strengthen the intermediate revoke/refresh
        // assertion inside `validate` — without it, a DPoP regression during the post-migration
        // refresh cycle would go undetected here.
        //
        // NB on `forceAdvancedAuthentication`: on iOS, the BW feature marker registered by
        // `SFOAuthCoordinator` at initial login does not appear in the migrated user's UA after
        // `migrateRefreshToken`. Migration tests pass `false` here so `expectAdvancedAuth`
        // matches the observed post-migration UA.
        let migratedUserCredentials = validate(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: migrationAppConfigName,
            userScopeSelection: migrationScopeSelection,
            useWebServerFlow: migrationUseWebServerFlow,
            useHybridFlow: migrationUseHybridFlow,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            useDPoP: useDPoP
        )

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            originalUserCredentials.refreshToken,
            migratedUserCredentials.refreshToken,
            "Refresh token should have been migrated"
        )
    }
    
    // MARK: - Protected Helpers for Subclasses

    /// Restarts the application.
    /// Use this for testing session persistence across app restarts.
    func restart() {
        app.terminate()
        app.launch()
    }

    /// Switches to a different user account.
    func switchToUser(loginHost: KnownLoginHostConfig, user: KnownUserConfig) {
        let userConfig = getUser(loginHost: loginHost, user: user)
        switchToUser(username: userConfig.username)
    }

    /// Switches to a different user account by username.
    private func switchToUser(username: String) {
        mainPage.switchToUser(username: username)
    }

    /// Gets the current user's credentials.
    func getUserCredentials() -> UserCredentialsData {
        return mainPage.getUserCredentials()
    }

    /// Validates the user agent string from already-fetched credentials.
    ///
    /// - Parameters:
    ///   - userCredentials: Credentials previously returned by `validateUser()`.
    ///   - loginHost: The login host used for the current user.
    ///   - expectAdvancedAuth: Whether advanced auth (browser-based) was used, which sets the BW flag. Defaults to `false`.
    ///   - usesWelcomeDiscovery: Whether welcome domain discovery was used. Defaults to `false`.
    ///   - isMultiUser: Whether multiple users are currently logged in. Defaults to `false`.
    ///   - isRtr: Whether Refresh Token Rotation is enabled, which sets the RT flag. Defaults to `false`.
    func validateUserAgent(userCredentials: UserCredentialsData, loginHost: KnownLoginHostConfig, expectAdvancedAuth: Bool = false, usesWelcomeDiscovery: Bool = false, isMultiUser: Bool = false, isRtr: Bool = false, expectDP: Bool = false) {
        validateUserAgent(ua: userCredentials.userAgent, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, usesWelcomeDiscovery: usesWelcomeDiscovery, isMultiUser: isMultiUser, isRtr: isRtr, expectDP: expectDP)
    }

    /// Validates a pre-fetched user agent string. Called from validate() which already has the UA.
    ///
    /// - Parameters:
    ///   - ua: A pre-fetched user agent string.
    ///   - loginHost: The login host used for the current user.
    ///   - expectAdvancedAuth: Whether advanced auth (browser-based) was used, which sets the BW flag. Defaults to `false`.
    ///   - usesWelcomeDiscovery: Whether welcome domain discovery was used. Defaults to `false`.
    ///   - isMultiUser: Whether multiple users are currently logged in. Defaults to `false`.
    ///   - isRtr: Whether Refresh Token Rotation is enabled, which sets the RT flag. Defaults to `false`.
    private func validateUserAgent(ua: String, loginHost: KnownLoginHostConfig, expectAdvancedAuth: Bool = false, usesWelcomeDiscovery: Bool = false, isMultiUser: Bool = false, isRtr: Bool = false, expectDP: Bool = false) {
        XCTAssertTrue(ua.contains("SalesforceMobileSDK/"), "User agent should contain 'SalesforceMobileSDK/' prefix; got: \(ua)")
        XCTAssertTrue(ua.contains("ftr_"), "User agent should contain 'ftr_' feature flag segment; got: \(ua)")

        // Extract the flag string after "ftr_" up to the next space
        let flagSet: Set<String>
        if let ftrRange = ua.range(of: "ftr_") {
            let afterFtr = String(ua[ftrRange.upperBound...])
            let flagString = afterFtr.components(separatedBy: " ").first ?? ""
            flagSet = Set(flagString.components(separatedBy: ".").filter { !$0.isEmpty })
        } else {
            flagSet = []
        }

        if expectAdvancedAuth {
            XCTAssertTrue(flagSet.contains("BW"), "User agent should contain 'BW' flag for advanced auth; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("BW"), "User agent should NOT contain 'BW' flag for non-advanced auth; flags: \(flagSet), ua: \(ua)")
        }

        if usesWelcomeDiscovery {
            XCTAssertTrue(flagSet.contains("WD"), "User agent should contain 'WD' flag when welcome discovery is used; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("WD"), "User agent should NOT contain 'WD' flag when welcome discovery is not used; flags: \(flagSet), ua: \(ua)")
        }

        if isMultiUser {
            XCTAssertTrue(flagSet.contains("MU"), "User agent should contain 'MU' flag when multiple users are logged in; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("MU"), "User agent should NOT contain 'MU' flag when only one user is logged in; flags: \(flagSet), ua: \(ua)")
        }

        if isRtr {
            XCTAssertTrue(flagSet.contains("RT"),
                          "User agent should contain 'RT' flag after Refresh Token Rotation; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("RT"),
                           "User agent should NOT contain 'RT' flag when Refresh Token Rotation has not occurred; flags: \(flagSet), ua: \(ua)")
        }

        if expectDP {
            XCTAssertTrue(flagSet.contains("DP"),
                          "User agent should contain 'DP' flag for DPoP-bound session; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("DP"),
                           "User agent should NOT contain 'DP' flag when DPoP is not enabled; flags: \(flagSet), ua: \(ua)")
        }
    }

    /// Revokes the current user's access token.
    @discardableResult
    func revokeAccessToken() -> Bool {
        return mainPage.revokeAccessToken()
    }

    /// Makes a REST API request with the current user's credentials.
    @discardableResult
    func makeRestRequest() -> Bool {
        return mainPage.makeRestRequest()
    }

    // MARK: - Force Advanced Auth Test Support
    //
    // Thin wrappers exposing the login-page / main-page primitives to `ForceAdvancedAuthTests`,
    // which asserts the login *modality* (external browser vs. in-app WebView) and the forced-
    // advanced-auth presentation chrome (back button / gear) rather than driving a full
    // `login()`/validate cycle. `app`, `loginPage`, and `mainPage` are private, so these give the
    // subclass just enough surface without widening the general API.

    /// Prevents `tearDown` from attempting a logout. Use in tests that intentionally stop on a
    /// login surface (external browser, in-app WebView, or a dev-menu modal) rather than the main
    /// page, where the logout button is not reachable. The next test's `launch()` self-heals any
    /// residual session (it logs out if the main page is showing on relaunch).
    func skipLogoutAtTearDown() {
        logoutAtTearDown = false
    }

    /// Returns to the login host list ("Change Server"). Pass `expectingBrowser: true` when the
    /// external browser is showing (forced advanced auth — cancel it to reach the list) and
    /// `false` when the in-app WebView is showing (reach the list via its Settings gear).
    func returnToLoginHostList(expectingBrowser: Bool) {
        loginPage.returnToHostList(expectingBrowser: expectingBrowser)
    }

    /// Selects (or adds) the given login host by its display string. Assumes the host list is
    /// already showing. For the built-in standard server pass its display name, e.g. "Production"
    /// (`login.salesforce.com`).
    func configureLoginHost(_ host: String) {
        loginPage.configureLoginHost(host: host)
    }

    /// Selects the login host for a known configuration (resolving its URL from `ui_test_config`).
    /// Assumes the host list is already showing.
    func configureLoginHost(_ loginHost: KnownLoginHostConfig) {
        loginPage.configureLoginHost(host: getLoginHost(loginHost: loginHost).urlNoProtocol)
    }

    /// Imports the `forceAdvancedAuthentication` flag (and a valid app config so the login form can
    /// load) via the login screen's Settings gear → Login Options → Auth Flow Types JSON import —
    /// the same hook `login()` uses. Assumes a screen with the Settings gear is showing (the host
    /// list under forced advanced auth, or the in-app WebView). Closing Login Options restarts
    /// authentication, so the login surface reappears in the modality the flag now selects.
    func setForceAdvancedAuthentication(
        _ value: Bool,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: nil,
            dynamicScopes: "",
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            forceAdvancedAuthentication: value,
            discoveryLoginHost: "",
            discoveryUsername: ""
        )
    }

    /// True when the external browser (`ASWebAuthenticationSession`) login surface is showing. Pass
    /// `UITestTimeouts.short` for the negative "no external browser" assertion.
    func isShowingBrowserLogin(timeout: TimeInterval = UITestTimeouts.long) -> Bool {
        return loginPage.isShowingBrowserLogin(timeout: timeout)
    }

    /// True when the legacy in-app WebView login form is showing. Pass `UITestTimeouts.short` for
    /// the negative "no in-app WebView" assertion.
    func isShowingInAppLoginForm(timeout: TimeInterval = UITestTimeouts.network) -> Bool {
        return loginPage.isShowingInAppLoginForm(timeout: timeout)
    }

    /// True when the Settings gear is present on the current login nav bar (host list under forced
    /// advanced auth, or the in-app WebView on the legacy path).
    func isShowingLoginSettingsGear() -> Bool {
        return loginPage.isShowingSettingsGear()
    }

    /// True when an accessible back control is present on the current login nav bar (see
    /// `LoginPageObject.isShowingBackButton()`).
    func isShowingLoginBackButton() -> Bool {
        return loginPage.isShowingBackButton()
    }

    /// Taps the login nav-bar back control, stopping the in-flight authentication and returning to
    /// the existing account list without completing login.
    func tapLoginBackButton() {
        loginPage.tapBackButton()
    }

    /// Opens Login Options from the Settings gear (gear → "Login Options").
    func openLoginOptions() {
        loginPage.openLoginOptions()
    }

    /// True when the Authentication Flow Types dev screen — the harness's own flag-driving surface —
    /// is showing.
    func isShowingAuthFlowTypesView() -> Bool {
        return loginPage.isShowingAuthFlowTypesView()
    }

    /// Triggers the add-new-account flow from the main page (Switch User → New User), which starts
    /// a fresh authentication for an additional user while preserving the current user. Under forced
    /// advanced auth the external browser launches; on the legacy path the in-app WebView is shown.
    func triggerAddUser() {
        mainPage.performAddUser()
    }

    /// Returns the user configuration for the specified login host and user.
    private func getUser(loginHost: KnownLoginHostConfig, user: KnownUserConfig) -> UserConfig {
        do {
            return try testConfig.getUser(loginHost, user)
        } catch {
            XCTFail("Failed to get user \(user) from login host \(loginHost): \(error)")
            fatalError("Failed to get user \(user) from login host \(loginHost): \(error)")
        }
    }

    /// Validates user credentials and feature flags.
    @discardableResult
    func validateUser(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection,
        useWebServerFlow: Bool,
        useHybridFlow: Bool,
        expectAdvancedAuth: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        isMultiUser: Bool = false
    ) -> UserCredentialsData {

        let userConfig = getUser(loginHost: loginHost, user: user)
        let userAppConfig = getAppConfig(named: userAppConfigName)
        let expectedGrantedScopes = testConfig.getExpectedScopesGranted(for: userAppConfig, userScopeSelection)
        let issuesJwt = userAppConfig.issuesJwt

        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()

        // Check the user credentials (consumer key should match the app config used)
        let userCredentials = checkUserCredentials(
            username: userConfig.username,
            userConsumerKey: userAppConfig.consumerKey,
            userRedirectUri: userAppConfig.redirectUri,
            grantedScopes: expectedGrantedScopes,
            issuesJwt: issuesJwt
        )

        // Check JWT if applicable
        checkJwtDetailsIfApplicable(
            appConfig: userAppConfig,
            scopes: expectedGrantedScopes,
            beaconChildConsumerKey: userCredentials.beaconChildConsumerKey
        )

        // Additional login-specific validations
        assertSIDs(userCredentialsData: userCredentials, useHybridFlow: useHybridFlow, useJwt: issuesJwt)
        assertURLs(userCredentialsData: userCredentials, useWebServerFlow: useWebServerFlow)

        // DPoP token binding: assert on any DPoP-app path (login, switch, restart, migration)
        if userAppConfig.isDPoP {
            assertDPoPCredentials(userCredentials)
        }

        // Validate feature flags using UA already present in the fetched credentials
        validateUserAgent(ua: userCredentials.userAgent, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, usesWelcomeDiscovery: usesWelcomeDiscovery, isMultiUser: isMultiUser, expectDP: userAppConfig.isDPoP)

        return userCredentials
    }
    
    // MARK: - Private Helpers
    
    /// Validates user credentials, do a revoke refesh cycle and validate oauth configuration
    @discardableResult
    private func validate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection,
        useWebServerFlow: Bool,
        useHybridFlow: Bool,
        forceAdvancedAuthentication: Bool? = nil,
        isMultiUser: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        useDPoP: Bool = false,
    ) -> UserCredentialsData {

        let staticAppConfig = getAppConfig(named: staticAppConfigName)

        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()

        let expectAdvancedAuth = loginForAdmin || loginHost == .advancedAuth || (forceAdvancedAuthentication != false)

        let userCredentials = validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: expectAdvancedAuth,
            usesWelcomeDiscovery: usesWelcomeDiscovery,
            isMultiUser: isMultiUser
        )

        // Revoke and refresh cycle
        let userAppConfig = getAppConfig(named: userAppConfigName)
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials, isRtr: userAppConfig.isRtr, isDPoP: useDPoP, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, isMultiUser: isMultiUser)

        // Check the oauth configuration
        _ = checkOauthConfiguration(
            staticConsumerKey: staticAppConfig.consumerKey,
            staticCallbackUrl: staticAppConfig.redirectUri,
            staticScopes: testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        )

        return userCredentials
    }

    private func migrateRefreshToken(
        appConfigName: KnownAppConfig,
        scopeSelection: ScopeSelection,
        useWebServerFlow: Bool,
        useHybridFlow: Bool
    ) {
        let appConfig = getAppConfig(named: appConfigName)
        let scopesToRequest = testConfig.getScopesToRequest(for: appConfig, scopeSelection)

        XCTAssert(mainPage.changeAppConfig(appConfig: appConfig, scopesToRequest: scopesToRequest, useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow), "Failed to migrate refresh token")
    }

    /// Asserts that the main page is loaded and showing.
    func assertMainPageLoaded() {
        XCTAssert(mainPage.isShowing(), "AuthFlowTester is not loaded")
    }
    
    private func checkUserCredentials(username: String, userConsumerKey: String, userRedirectUri: String, grantedScopes: String, issuesJwt: Bool) -> UserCredentialsData {
        let userCredentials = mainPage.getUserCredentials()
        XCTAssertEqual(userCredentials.username, username, "Username in credentials should match expected username")
        XCTAssertEqual(userCredentials.clientId, userConsumerKey, "Client ID in credentials should match expected consumer key")
        XCTAssertEqual(userCredentials.redirectUri, userRedirectUri, "Redirect URI in credentials should match expected redirect URI")
        XCTAssertEqual(userCredentials.credentialsScopes, grantedScopes, "Scopes in credentials should match expected granted scopes")
        XCTAssertEqual(userCredentials.tokenFormat, issuesJwt ? "jwt" : "", "Not the expected token format")
        return userCredentials
    }
    
    private func checkOauthConfiguration(staticConsumerKey: String, staticCallbackUrl: String, staticScopes: String) -> OAuthConfigurationData {
        let oauthConfiguration = mainPage.getOAuthConfiguration()
        XCTAssertEqual(oauthConfiguration.configuredConsumerKey, staticConsumerKey, "Configured consumer key should match expected value")
        XCTAssertEqual(oauthConfiguration.configuredCallbackUrl, staticCallbackUrl, "Configured callback URL should match expected value")
        XCTAssertEqual(oauthConfiguration.configuredScopes, staticScopes == "" ? "(none)" : staticScopes, "Configured scopes should match requested scopes")
        return oauthConfiguration
    }
    
    private func checkJwtDetails(clientId: String, scopes: String) -> JwtDetailsData? {
        guard let jwtDetails = mainPage.getJwtDetails() else {
            XCTFail("No JWT details found")
            return nil
        }
        XCTAssertEqual(jwtDetails.clientId, clientId, "JWT client ID should match expected consumer key")
        XCTAssertEqual(sortedScopes(jwtDetails.scopes), scopes, "JWT scopes should match expected scopes")
        return jwtDetails
    }
    
    private func assertSIDs(userCredentialsData: UserCredentialsData, useHybridFlow: Bool, useJwt: Bool) {
        let hasContentScope = userCredentialsData.credentialsScopes.contains("content")
        let hasLightningScope = userCredentialsData.credentialsScopes.contains("lightning")
        let hasVisualforceScope = userCredentialsData.credentialsScopes.contains("visualforce")
        
        assertNotEmpty(userCredentialsData.contentDomain, shouldNotBeEmpty: hasContentScope && useHybridFlow, "Content domain")
        assertNotEmpty(userCredentialsData.contentSid, shouldNotBeEmpty: hasContentScope && useHybridFlow, "Content SID")
        
        assertNotEmpty(userCredentialsData.lightningDomain, shouldNotBeEmpty: hasLightningScope && useHybridFlow, "Lightning domain")
        assertNotEmpty(userCredentialsData.lightningSid, shouldNotBeEmpty: hasLightningScope && useHybridFlow, "Lightning SID")
        
        assertNotEmpty(userCredentialsData.vfDomain, shouldNotBeEmpty: hasVisualforceScope && useHybridFlow, "VF domain")
        assertNotEmpty(userCredentialsData.vfSid, shouldNotBeEmpty: hasVisualforceScope && useHybridFlow, "VF SID")
        
        assertNotEmpty(userCredentialsData.parentSid, shouldNotBeEmpty: useJwt && useHybridFlow, "Parent SID")
    }
    
    private func assertURLs(userCredentialsData: UserCredentialsData, useWebServerFlow: Bool) {
        let hasApiScope = userCredentialsData.credentialsScopes.contains("api")
        let hasSfapApiScope = userCredentialsData.credentialsScopes.contains("sfap_api")
        
        assertNotEmpty(userCredentialsData.instanceUrl, shouldNotBeEmpty: true, "Instance URL")
        XCTAssertTrue(userCredentialsData.identityUrl.hasSuffix(userCredentialsData.organizationId + "/" + userCredentialsData.userId), "Identity URL should end with orgId/userId")
        assertNotEmpty(userCredentialsData.apiUrl, shouldNotBeEmpty: hasApiScope, "API URL")
        assertNotEmpty(userCredentialsData.apiInstanceUrl, shouldNotBeEmpty: hasSfapApiScope && useWebServerFlow /* not returned with user agent flow */, "API Instance URL")
    }
    
    private func assertNotEmpty(_ value: String, shouldNotBeEmpty: Bool, _ name: String) {
        if shouldNotBeEmpty {
            XCTAssertNotEqual(value, "", "\(name) should not be empty")
        } else {
            XCTAssertEqual(value, "", "\(name) should be empty")
        }
    }
    
    private func getAppConfig(named name: KnownAppConfig) -> AppConfig {
        do {
            return try testConfig.getApp(named: name)
        } catch {
            XCTFail("Failed to get app config for \(name): \(error)")
            fatalError("Failed to get app config for \(name): \(error)")
        }
    }
    
    private func getLoginHost(loginHost: KnownLoginHostConfig) -> LoginHostConfig {
        do {
            return try testConfig.getLoginHost(loginHost)
        } catch {
            XCTFail("Failed to get login host \(loginHost): \(error)")
            fatalError("Failed to get login host \(loginHost): \(error)")
        }
    }
    
    private func getKnownUserConfig(loginHost: KnownLoginHostConfig, byUsername username: String) -> KnownUserConfig {
        do {
            return try testConfig.getKnownUserConfig(loginHost, byUsername: username)
        } catch {
            XCTFail("Failed to get user \(username) from login host \(loginHost): \(error)")
            fatalError("Failed to get user \(username) from login host \(loginHost): \(error)")
        }
    }
    
    private func checkJwtDetailsIfApplicable(appConfig: AppConfig, scopes: String, beaconChildConsumerKey: String = "") {
        if appConfig.issuesJwt {
            _ = checkJwtDetails(
                clientId: beaconChildConsumerKey == "" ? appConfig.consumerKey : beaconChildConsumerKey,
                scopes: scopes
            )
        }
    }
    
    /// Captures current credentials then performs a revoke/refresh cycle and validates the result.
    ///
    /// `expectAdvancedAuth` defaults to `true` because interactive login defaults to advanced auth
    /// (external browser), which registers the BW feature marker on the UA.
    func assertRevokeAndRefreshWorks(isRtr: Bool, isDPoP: Bool = false, loginHost: KnownLoginHostConfig = .regularAuth, expectAdvancedAuth: Bool = true, isMultiUser: Bool = false) {
        assertRevokeAndRefreshWorks(previousCredentials: getUserCredentials(), isRtr: isRtr, isDPoP: isDPoP, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, isMultiUser: isMultiUser)
    }

    private func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData, isRtr: Bool, isDPoP: Bool = false, loginHost: KnownLoginHostConfig = .regularAuth, expectAdvancedAuth: Bool = true, isMultiUser: Bool = false) {
        // Revoke access token
        XCTAssert(mainPage.revokeAccessToken(), "Failed to revoke access token")

        // Make REST request (which should trigger token refresh)
        XCTAssert(mainPage.makeRestRequest(), "Failed to make REST request")

        let credentialsAfterRefresh = getUserCredentials()

        // Assert access token changed
        XCTAssertNotEqual(
            previousCredentials.accessToken,
            credentialsAfterRefresh.accessToken,
            "Access token should have been refreshed"
        )

        // Assert refresh token rotated (RTR) or stayed the same (non-RTR)
        if isRtr {
            XCTAssertNotEqual(
                previousCredentials.refreshToken,
                credentialsAfterRefresh.refreshToken,
                "Refresh token should have rotated (RTR app)"
            )
        } else {
            XCTAssertEqual(
                previousCredentials.refreshToken,
                credentialsAfterRefresh.refreshToken,
                "Refresh token should not have changed (non-RTR app)"
            )
        }

        // Assert DPoP token type and nonce presence if DPoP is enabled
        if isDPoP {
            assertDPoPCredentials(credentialsAfterRefresh, context: "after refresh")
        }

        validateUserAgent(userCredentials: credentialsAfterRefresh,
                          loginHost: loginHost,
                          expectAdvancedAuth: expectAdvancedAuth,
                          isMultiUser: isMultiUser,
                          isRtr: isRtr,
                          expectDP: isDPoP)
    }

    /// Asserts the DPoP token-type and nonce triad on a set of credentials.
    ///
    /// - Parameters:
    ///   - credentials: Credentials fetched from the main page after a DPoP-bound event.
    ///   - context: Optional context appended to failure messages (e.g. "after refresh",
    ///     "after migration"). Kept short — surfaces which flow step failed at a glance.
    private func assertDPoPCredentials(_ credentials: UserCredentialsData, context: String = "") {
        let ctx = context.isEmpty ? "" : " (\(context))"
        XCTAssertEqual(credentials.dpopTokenType, "DPoP", "Token type should be DPoP\(ctx)")
        XCTAssertNotNil(credentials.dpopNonce, "DPoP nonce should be present\(ctx)")
        XCTAssertFalse(credentials.dpopNonce?.isEmpty ?? true, "DPoP nonce should not be empty\(ctx)")
    }
    
    private func sortedScopes(_ value: String) -> String {
        let scopes = value
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
            .sorted()
        return scopes.joined(separator: " ")
    }
}
