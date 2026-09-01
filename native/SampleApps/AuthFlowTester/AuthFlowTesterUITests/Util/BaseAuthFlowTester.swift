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

// B-marker codes (why browser login was used)
let kBrowserLoginServerAuthConfig = "B1"
let kBrowserLoginForAdmin         = "B3"
let kBrowserLoginForceFlag        = "B4"
private let kAllBMarkers          = ["B1", "B2", "B3", "B4"]

// L-marker codes (which login server type)
let kLoginServerProduction        = "L1"
let kLoginServerWelcomeDiscovery  = "L3"
let kLoginServerMyDomain          = "L4"
private let kAllLMarkers          = ["L1", "L2", "L3", "L4", "L5"]

// A-marker codes (which auth type was used)
let kAuthTypeWebServerNonHybrid   = "A1"
let kAuthTypeWebServerHybrid      = "A2"
let kAuthTypeUserAgentNonHybrid   = "A3"
let kAuthTypeUserAgentHybrid      = "A4"
let kAuthTypeNative               = "A5"
private let kAllAMarkers          = ["A1", "A2", "A3", "A4", "A5"]

private let kRegularAuthLoginHostName = "UITests"
private let kAdvancedAuthLoginHostName = "UITests Adv Auth"
private let kLoginPoolHostName = "UITests Login Pool"
private let kWelcomeDiscoveryLoginHostName = "Welcome Discovery"

class BaseAuthFlowTester: XCTestCase {
    // App object
    private var app: XCUIApplication!

    // App Pages
    private var loginPage: LoginPageObject!
    private var mainPage: AuthFlowTesterMainPageObject!

    // Test configuration
    private let testConfig = UITestConfigUtils.shared

    // RT is a per-user, sticky SDK marker. It starts absent after login and is set only when a
    // normal refresh observes a changed refresh token. Keep the expected state independently of
    // whether the current app configuration is capable of refresh-token rotation.
    private var expectedRTRFeatureMarkerByUsername: [String: Bool] = [:]

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
        super.tearDown()
    }
    
    // MARK: - Public API for Subclasses
    
    /// Launches the application and ensures it starts in a logged-out state on a known login server.
    ///
    /// Initializes the app and page objects on the regular UI-test login server. Fresh launches
    /// reset all auth state, seed the fixed test servers, and select regular auth by default.
    func launch() {
        // launch() requests --resetSDKForUITesting, which clears the SDK's per-user markers.
        expectedRTRFeatureMarkerByUsername.removeAll()
        app = XCUIApplication()

        // Set environment variable to indicate we're running UI tests
        // This is used to show/hide certain UI elements like DiscoveryResultEditor
        app.launchEnvironment["IS_UI_TESTING"] = "1"

        // Instruct the app to reset all SDK auth state and select the first static test server
        // in-process at startup, before loginIfRequired fires.
        app.launchArguments = ["--resetSDKForUITesting"]

        loginPage = LoginPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
        app.launch()

        // Tap the app to trigger any pending system alert interruption handlers.
        // On CI, system alerts (tracking permission, paste confirmation) can block
        // the UI if not dismissed before interacting with app elements.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
    ///   - forceAdvancedAuthentication: Whether to use the external browser for login (advanced
    ///     auth). Defaults to `true`, matching the SDK's own default. Pass `false` to exercise
    ///     the legacy in-app WebView path.
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
        forceAdvancedAuthentication: Bool = true,
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        useDPoP: Bool = false,
        useLoginPoolHost: Bool = false
    ) {
        let userConfig = getUser(loginHost: loginHost, user: user)
        let hostConfig = getLoginHost(loginHost: loginHost)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        let dynamicScopes = dynamicAppConfig == nil ? "" : testConfig.getScopesToRequest(for: dynamicAppConfig!, dynamicScopeSelection)

        let advancedAuthEnabled = forceAdvancedAuthentication
        // The surface used to enter credentials: the external browser under advanced auth (forced
        // true, or a host that itself requires it), otherwise the in-app WebView. Login for Admin
        // is special-cased below: it always finishes in the browser regardless of this value.
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

        // Closing Login Options restarts authentication on the selected server. A fresh launch
        // already selected regular auth, so avoid cancelling and re-selecting it for the common
        // case. Special paths still choose their required server explicitly.
        if useWelcomeDiscovery || useLoginPoolHost || loginHost != .regularAuth {
            loginPage.returnToHostList(expectingBrowser: advancedAuthEnabled)
            let loginHostToUse: String
            if useWelcomeDiscovery {
                loginHostToUse = "welcome.salesforce.com/discovery"
            } else if useLoginPoolHost {
                do {
                    let poolHost = try UITestConfigUtils.shared.getLoginPoolHost()
                    loginHostToUse = poolHost
                        .replacingOccurrences(of: "https://", with: "")
                        .replacingOccurrences(of: "http://", with: "")
                } catch {
                    XCTFail("useLoginPoolHost is true but getLoginPoolHost() failed: \(error)")
                    return
                }
            } else {
                loginHostToUse = hostConfig.urlNoProtocol
            }
            let loginHostDisplayName: String
            if useWelcomeDiscovery {
                loginHostDisplayName = kWelcomeDiscoveryLoginHostName
            } else if useLoginPoolHost {
                loginHostDisplayName = kLoginPoolHostName
            } else if loginHost == .advancedAuth {
                loginHostDisplayName = kAdvancedAuthLoginHostName
            } else {
                loginHostDisplayName = kRegularAuthLoginHostName
            }
            loginPage.configureLoginHost(host: loginHostToUse, displayName: loginHostDisplayName)
        }

        // Invalid app config
        if (dynamicAppConfigName == .invalid || (dynamicAppConfigName == nil && staticAppConfigName == .invalid)) {
            XCTAssertTrue(loginPage.isShowingInvalidClientIdError(), "Login page should show invalid client id error")
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

        // An authorization-code login does not use SFOAuthSessionRefresher, so it cannot set RT.
        // Record this explicitly: later migration/restart checks must preserve this value until a
        // test-triggered normal refresh observes token rotation.
        expectedRTRFeatureMarkerByUsername[userConfig.username] = false

        // Invalid scope
        if (dynamicScopeSelection == .invalid || (dynamicAppConfig == nil && staticScopeSelection == .invalid)) {
            XCTAssertTrue(loginPage.isShowingUnexpectedOauthError(), "Screen should show OAuth Error")
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
    ///   - wasMigrated: Whether the user underwent a token migration. Defaults to `false`.
    func switchToUserAndValidate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        isMultiUser: Bool = false,
        wasMigrated: Bool = false
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
            isMultiUser: isMultiUser,
            wasMigrated: wasMigrated
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
        forceAdvancedAuthentication: Bool = true,
        loginForAdmin: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        isMultiUser: Bool = false,
        wasMigrated: Bool = false
    ) {
        // Switch user
        mainPage.switchToUser(username: getUser(loginHost: loginHost, user: user).username)

        let expectAdvancedAuth = loginForAdmin || loginHost == .advancedAuth || forceAdvancedAuthentication

        let expectedBMarker: String? = expectAdvancedAuth ? (
            loginForAdmin ? kBrowserLoginForAdmin :
            forceAdvancedAuthentication ? kBrowserLoginForceFlag :
            kBrowserLoginServerAuthConfig
        ) : nil
        let expectedLMarker: String? = usesWelcomeDiscovery ? kLoginServerWelcomeDiscovery : kLoginServerMyDomain
        let aMarker = aMarkerFor(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)

        // Validate user and feature flags
        let userAppConfig = getAppConfig(named: userAppConfigName)
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: expectAdvancedAuth,
            usesWelcomeDiscovery: usesWelcomeDiscovery,
            isMultiUser: isMultiUser,
            expectedBMarker: expectedBMarker,
            expectedLMarker: expectedLMarker,
            expectedAMarker: aMarker,
            wasMigrated: wasMigrated,
            isBeacon: userAppConfig.isBeacon
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
    ///   - useDPoP: Whether to enable DPoP for this login. Defaults to `false`.
    func launchAndLogin(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool = true,
        loginForAdmin: Bool = false,
        useDPoP: Bool = false
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
            useDPoP: useDPoP
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
        forceAdvancedAuthentication: Bool = true,
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        isMultiUser: Bool = false,
        useDPoP: Bool = false,
        useLoginPoolHost: Bool = false
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
            useDPoP: useDPoP,
            useLoginPoolHost: useLoginPoolHost
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
            useDPoP: useDPoP,
            useLoginPoolHost: useLoginPoolHost
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
    ///   - useDPoP: Whether to enable DPoP for this login. Defaults to `false`.
    func loginOtherUser(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        useDPoP: Bool = false
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
            useDPoP: useDPoP
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
        forceAdvancedAuthentication: Bool = true,
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
        forceAdvancedAuthentication: Bool = true,
        loginForAdmin: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        isMultiUser: Bool = false,
        wasMigrated: Bool = false
    ) {
        // Restart without --resetSDKForUITesting so the session persists across the restart
        restart()

        // Restore auth flow settings lost on restart
        mainPage.setAuthFlowTypes(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)

        let expectAdvancedAuth = loginForAdmin || loginHost == .advancedAuth || forceAdvancedAuthentication

        let expectedBMarker: String? = expectAdvancedAuth ? (
            loginForAdmin ? kBrowserLoginForAdmin :
            forceAdvancedAuthentication ? kBrowserLoginForceFlag :
            kBrowserLoginServerAuthConfig
        ) : nil

        let expectedLMarker: String? = usesWelcomeDiscovery
            ? kLoginServerWelcomeDiscovery
            : kLoginServerMyDomain

        let aMarker = aMarkerFor(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)

        // Validate user and feature flags
        // Not checking static app config since it will depend on the bootconfig of the target app
        let userAppConfig = getAppConfig(named: userAppConfigName)
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: expectAdvancedAuth,
            usesWelcomeDiscovery: usesWelcomeDiscovery,
            isMultiUser: isMultiUser,
            expectedBMarker: expectedBMarker,
            expectedLMarker: expectedLMarker,
            expectedAMarker: aMarker,
            wasMigrated: wasMigrated,
            isBeacon: userAppConfig.isBeacon
        )
    }

    /// Migrates the refresh token to a new app configuration and validates the result.
    ///
    /// Performs a refresh token migration from the current app configuration to a new one,
    /// then validates that the credentials are updated correctly and the refresh token has changed.
    ///
    /// The SDK preserves the BW feature marker through migration (migration is a silent token
    /// exchange that does not change how the user originally authenticated), so
    /// `forceAdvancedAuthentication` mirrors the value used at initial login. Tests that logged
    /// in with `forceAdvancedAuthentication: false` (e.g. user-agent flow) should pass `false`
    /// here as well.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - migrationAppConfigName: The app configuration to migrate to.
    ///   - migrationScopeSelection: The scope selection for the migration target. Defaults to `.empty`.
    ///   - migrationUseWebServerFlow: Whether to use web server OAuth flow for migration. Defaults to `true`.
    ///   - migrationUseHybridFlow: Whether to use hybrid authentication flow for migration. Defaults to `true`.
    ///   - forceAdvancedAuthentication: Whether BW is expected in the post-migration UA. Defaults to `true`.
    ///   - useDPoP: Whether DPoP was enabled for this session. Defaults to `false`.
    ///   - isMultiUser: Whether multiple users are logged in. Defaults to `false`.
    func migrateAndValidate(
        loginHost: KnownLoginHostConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        migrationAppConfigName: KnownAppConfig,
        migrationScopeSelection: ScopeSelection = .empty,
        migrationUseWebServerFlow: Bool = true,
        migrationUseHybridFlow: Bool = true,
        forceAdvancedAuthentication: Bool = true,
        useDPoP: Bool = false,
        isMultiUser: Bool = false
    ) {
        let originalUserCredentials = mainPage.getUserCredentials()
        let user = getKnownUserConfig(loginHost: loginHost, byUsername: originalUserCredentials.username)
        // Capture the A-marker before migration — migration preserves it unchanged (per spec).
        let preMigrationAMarker = extractAMarkerFromUA(originalUserCredentials.userAgent)

        migrateRefreshToken(
            appConfigName: migrationAppConfigName,
            scopeSelection: migrationScopeSelection,
            useWebServerFlow: migrationUseWebServerFlow,
            useHybridFlow: migrationUseHybridFlow
        )

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
            isMultiUser: isMultiUser,
            useDPoP: useDPoP,
            wasMigrated: true,
            expectedAMarkerOverride: preMigrationAMarker
        )

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            originalUserCredentials.refreshToken,
            migratedUserCredentials.refreshToken,
            "Refresh token should have been migrated"
        )
    }

    /// Upgrades the current session to DPoP in place (same connected app, via
    /// `UserAccountManager.upgradeToDPoP`) and validates the result: DPoP-bound credentials,
    /// an unchanged consumer key, and a working revoke/refresh cycle.
    ///
    /// Unlike `migrateAndValidate`, this does not change the connected app — it re-authenticates
    /// against the same client id/redirect URI/scopes, so the consumer key is expected to stay
    /// the same while the refresh token is rotated.
    ///
    /// - Parameter isJwt: Whether the connected app issues JWT-format access tokens (drives the
    ///   "JT"/"OT" UA marker assertion). Defaults to `true` since the upgrade test uses `.ecaJwt`.
    func upgradeToDPoPAndValidate(isJwt: Bool = true) {
        let originalUserCredentials = getUserCredentials()

        XCTAssert(mainPage.upgradeToDPoP(), "Failed to upgrade to DPoP")

        let upgradedUserCredentials = getUserCredentials()

        // The upgrade re-authenticates with the same connected app: consumer key is unchanged.
        XCTAssertEqual(
            originalUserCredentials.clientId,
            upgradedUserCredentials.clientId,
            "Consumer key should be unchanged after upgrading to DPoP"
        )

        assertDPoPCredentials(upgradedUserCredentials, context: "after upgrade")

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            originalUserCredentials.refreshToken,
            upgradedUserCredentials.refreshToken,
            "Refresh token should have been rotated by the DPoP upgrade"
        )

        // `upgradeToDPoP` delegates to the refresh-token migration path, so the "TM"
        // (token-migration) UA feature flag is legitimately registered — the marker tracks the
        // migration mechanism, not whether the connected app changed. Assert its presence.
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: true, wasMigrated: true, isJwt: isJwt)
    }

    /// Downgrades the current DPoP-bound session back to Bearer in place (same connected app, via
    /// `UserAccountManager.downgradeFromDPoP`) and validates the result: Bearer credentials, an
    /// unchanged consumer key, and a working revoke/refresh cycle.
    ///
    /// Mirrors `upgradeToDPoPAndValidate` in the opposite direction — it re-authenticates against
    /// the same client id/redirect URI/scopes with `useDPoP: false`, so the consumer key is
    /// expected to stay the same while the refresh token is rotated and the session unbinds from
    /// DPoP.
    ///
    /// - Parameter isJwt: Whether the connected app issues JWT-format access tokens (drives the
    ///   "JT"/"OT" UA marker assertion). Defaults to `true` since the downgrade test uses `.ecaJwt`.
    func downgradeFromDPoPAndValidate(isJwt: Bool = true) {
        let originalUserCredentials = getUserCredentials()

        XCTAssert(mainPage.downgradeFromDPoP(), "Failed to downgrade from DPoP")

        let downgradedUserCredentials = getUserCredentials()

        // The downgrade re-authenticates with the same connected app: consumer key is unchanged.
        XCTAssertEqual(
            originalUserCredentials.clientId,
            downgradedUserCredentials.clientId,
            "Consumer key should be unchanged after downgrading from DPoP"
        )

        XCTAssertNotEqual(downgradedUserCredentials.dpopTokenType, "DPoP", "Token type should no longer be DPoP after downgrade")

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            originalUserCredentials.refreshToken,
            downgradedUserCredentials.refreshToken,
            "Refresh token should have been rotated by the DPoP downgrade"
        )

        // `downgradeFromDPoP` delegates to the refresh-token migration path, so the "TM"
        // (token-migration) UA feature flag is legitimately registered — the marker tracks the
        // migration mechanism, not whether the connected app changed. Assert its presence, and
        // that "DP" is absent now that the session is Bearer-bound.
        assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: false, isDPoP: false, wasMigrated: true, isJwt: isJwt)
    }

    /// Launches the app and attempts a login expected to fail before any credentials are entered.
    ///
    /// Replays the same host-list / login-options / login-host prefix as `login()` (selecting the
    /// login host is what triggers `/authorize`), then stops — it never calls `performLogin`.
    /// Use this for enforced-server rejections that fire at `/authorize` before a login form ever
    /// renders (e.g. a DPoP-enforced ECA rejecting an unbound login with `useDPoP: false`); calling
    /// `performLogin` in that case would hang waiting on form fields that never appear.
    ///
    /// - Parameters:
    ///   - loginHost: The login host configuration to use.
    ///   - staticAppConfigName: The static app configuration name.
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - forceAdvancedAuthentication: Whether to use the external browser for login. Defaults to `true`.
    ///   - useDPoP: Whether to enable the "Use DPoP" login option. Defaults to `false`.
    func launchAndAttemptLoginExpectingFailure(
        loginHost: KnownLoginHostConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        forceAdvancedAuthentication: Bool = true,
        useDPoP: Bool = false
    ) {
        launch()

        let hostConfig = getLoginHost(loginHost: loginHost)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)

        let advancedAuthEnabled = forceAdvancedAuthentication

        // A fresh login surface always starts under the process default (advanced auth on), so the
        // external browser is showing. Cancel it to reach the host list, where login options and
        // the login host are configured. (Mirrors login()'s own prefix.)
        loginPage.returnToHostList(expectingBrowser: true)

        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: nil,
            dynamicScopes: "",
            useWebServerFlow: true,
            useHybridFlow: true,
            forceAdvancedAuthentication: forceAdvancedAuthentication,
            discoveryLoginHost: "",
            discoveryUsername: "",
            useDPoP: useDPoP
        )

        // Closing Login Options already triggers /authorize on the reset default regular server.
        // Other hosts still require explicit selection.
        if loginHost != .regularAuth {
            loginPage.returnToHostList(expectingBrowser: advancedAuthEnabled)
            loginPage.configureLoginHost(host: hostConfig.urlNoProtocol)
        }

        // We assert on absence-of-main-page rather than on error text because there is no error
        // surface to read here. This path uses advanced auth (ASWebAuthenticationSession), and the
        // enforced ECA rejects the unbound /authorize with a short non-HTML body. The system browser
        // can't render it and falls back to a QuickLook document preview (a generic file icon
        // labeled "authorize" / "data - N bytes" / "Open in…") — there is no error= / error_description
        // string on screen. This differs from the in-app WebView negative tests (invalid client id,
        // invalid scope), which render an HTML error page whose text is assertable. The only elements
        // available here are iOS's file-preview chrome, which is not a stable SDK/server contract, so
        // "the app never reaches the authenticated view" is the strongest reliable signal.
        assertMainPageNotLoaded()
    }

    // MARK: - Protected Helpers for Subclasses

    /// Restarts the application.
    /// Use this for testing session persistence across app restarts.
    /// A fresh XCUIApplication is created without --resetSDKForUITesting so the
    /// existing user session is preserved across the restart.
    func restart() {
        restart(withLaunchArguments: [])
    }

    /// Restarts the application with the given launch arguments.
    ///
    /// Session state persists (no `--resetSDKForUITesting`). Use for tests that need to relaunch
    /// while injecting a test-only launch flag (e.g. `--disableDPoPAtStart`) recognized by the app.
    func restart(withLaunchArguments launchArguments: [String]) {
        app.terminate()
        app = XCUIApplication()
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchArguments = launchArguments
        loginPage = LoginPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
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
    ///   - expectedRTRFeatureMarker: Whether the SDK should already have registered RT for this user.
    ///   - expectedBMarker: The single B-marker code expected in the UA (e.g. "B3", "B4"). Pass `nil` when no browser login occurred.
    ///   - expectedLMarker: The single L-marker code expected in the UA (e.g. "L3", "L4"). Pass `nil` to assert no L-markers are present.
    ///   - expectedAMarker: The single A-marker code expected in the UA (e.g. "A1", "A5"). Pass `nil` to assert no A-markers are present.
    ///   - wasMigrated: Whether a refresh token migration occurred (TM flag). Defaults to `false`.
    ///   - isJwt: Whether the session uses JWT token format (JT flag). Defaults to `false`, asserting OT instead.
    ///   - isBeacon: Whether this is a beacon child app (BN flag). Defaults to `false`.
    func validateUserAgent(userCredentials: UserCredentialsData, loginHost: KnownLoginHostConfig, expectAdvancedAuth: Bool = false, usesWelcomeDiscovery: Bool = false, isMultiUser: Bool = false, expectDP: Bool = false, expectedBMarker: String? = nil, expectedLMarker: String? = nil, expectedAMarker: String? = nil, wasMigrated: Bool = false, isJwt: Bool = false, isBeacon: Bool = false) {
        validateUserAgent(ua: userCredentials.userAgent, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, usesWelcomeDiscovery: usesWelcomeDiscovery, isMultiUser: isMultiUser, expectedRTRFeatureMarker: expectedRTRFeatureMarker(for: userCredentials.username), expectDP: expectDP, expectedBMarker: expectedBMarker, expectedLMarker: expectedLMarker, expectedAMarker: expectedAMarker, wasMigrated: wasMigrated, isJwt: isJwt, isBeacon: isBeacon)
    }

    /// Validates a pre-fetched user agent string. Called from validate() which already has the UA.
    ///
    /// - Parameters:
    ///   - ua: A pre-fetched user agent string.
    ///   - loginHost: The login host used for the current user.
    ///   - expectAdvancedAuth: Whether advanced auth (browser-based) was used, which sets the BW flag. Defaults to `false`.
    ///   - usesWelcomeDiscovery: Whether welcome domain discovery was used. Defaults to `false`.
    ///   - isMultiUser: Whether multiple users are currently logged in. Defaults to `false`.
    ///   - expectedRTRFeatureMarker: Whether the SDK should already have registered RT for this user.
    ///   - expectedBMarker: The single B-marker code expected in the UA (e.g. "B3", "B4"). Pass `nil` when no browser login occurred.
    ///   - expectedLMarker: The single L-marker code expected in the UA (e.g. "L3", "L4"). Pass `nil` to skip the assertion.
    ///   - expectedAMarker: The single A-marker code expected in the UA (e.g. "A1", "A5"). Pass `nil` to assert no A-markers are present.
    ///   - wasMigrated: Whether a refresh token migration occurred (TM flag). Defaults to `false`.
    ///   - isJwt: Whether the session uses JWT token format (JT flag). Defaults to `false`.
    ///   - isBeacon: Whether this is a beacon child app (BN flag). Defaults to `false`.
    private func validateUserAgent(ua: String, loginHost: KnownLoginHostConfig, expectAdvancedAuth: Bool = false, usesWelcomeDiscovery: Bool = false, isMultiUser: Bool = false, expectedRTRFeatureMarker: Bool, expectDP: Bool = false, expectedBMarker: String? = nil, expectedLMarker: String? = nil, expectedAMarker: String? = nil, wasMigrated: Bool = false, isJwt: Bool = false, isBeacon: Bool = false) {
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

        if expectedRTRFeatureMarker {
            XCTAssertTrue(flagSet.contains("RT"),
                          "User agent should contain 'RT' after the SDK observed Refresh Token Rotation; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("RT"),
                           "User agent should NOT contain 'RT' before the SDK observes Refresh Token Rotation; flags: \(flagSet), ua: \(ua)")
        }

        if expectDP {
            XCTAssertTrue(flagSet.contains("DP"),
                          "User agent should contain 'DP' flag for DPoP-bound session; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("DP"),
                           "User agent should NOT contain 'DP' flag when DPoP is not enabled; flags: \(flagSet), ua: \(ua)")
        }

        // B-markers
        if let bMarker = expectedBMarker {
            XCTAssertTrue(flagSet.contains(bMarker), "Expected B-marker '\(bMarker)' in UA; flags: \(flagSet), ua: \(ua)")
            for other in kAllBMarkers where other != bMarker {
                XCTAssertFalse(flagSet.contains(other), "Unexpected B-marker '\(other)' in UA; flags: \(flagSet), ua: \(ua)")
            }
        } else {
            for marker in kAllBMarkers {
                XCTAssertFalse(flagSet.contains(marker), "Unexpected B-marker '\(marker)' when no browser login expected; flags: \(flagSet), ua: \(ua)")
            }
        }

        // L-markers
        if let lMarker = expectedLMarker {
            XCTAssertTrue(flagSet.contains(lMarker), "Expected L-marker '\(lMarker)' in UA; flags: \(flagSet), ua: \(ua)")
            for other in kAllLMarkers where other != lMarker {
                XCTAssertFalse(flagSet.contains(other), "Unexpected L-marker '\(other)' in UA; flags: \(flagSet), ua: \(ua)")
            }
        } else {
            for marker in kAllLMarkers {
                XCTAssertFalse(flagSet.contains(marker), "Unexpected L-marker '\(marker)' when no login server marker expected; flags: \(flagSet), ua: \(ua)")
            }
        }

        // A-markers
        if let aMarker = expectedAMarker {
            XCTAssertTrue(flagSet.contains(aMarker), "Expected A-marker '\(aMarker)' in UA; flags: \(flagSet), ua: \(ua)")
            for other in kAllAMarkers where other != aMarker {
                XCTAssertFalse(flagSet.contains(other), "Unexpected A-marker '\(other)' in UA; flags: \(flagSet), ua: \(ua)")
            }
        } else {
            for marker in kAllAMarkers {
                XCTAssertFalse(flagSet.contains(marker), "Unexpected A-marker '\(marker)' when no auth-type marker expected; flags: \(flagSet), ua: \(ua)")
            }
        }

        // TM: token migration
        if wasMigrated {
            XCTAssertTrue(flagSet.contains("TM"), "User agent should contain 'TM' flag after token migration; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("TM"), "User agent should NOT contain 'TM' flag when no migration occurred; flags: \(flagSet), ua: \(ua)")
        }

        // JT/OT: token format
        if isJwt {
            XCTAssertTrue(flagSet.contains("JT"), "User agent should contain 'JT' flag for JWT token format; flags: \(flagSet), ua: \(ua)")
            XCTAssertFalse(flagSet.contains("OT"), "User agent should NOT contain 'OT' flag when token format is JWT; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("JT"), "User agent should NOT contain 'JT' flag for non-JWT token format; flags: \(flagSet), ua: \(ua)")
            XCTAssertTrue(flagSet.contains("OT"), "User agent should contain 'OT' flag for opaque token format; flags: \(flagSet), ua: \(ua)")
        }

        // BN: beacon child app
        if isBeacon {
            XCTAssertTrue(flagSet.contains("BN"), "User agent should contain 'BN' flag for beacon child app; flags: \(flagSet), ua: \(ua)")
        } else {
            XCTAssertFalse(flagSet.contains("BN"), "User agent should NOT contain 'BN' flag for non-beacon app; flags: \(flagSet), ua: \(ua)")
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

    /// Imports the `forceAdvancedAuthentication` flag via the login screen's Settings gear →
    /// Login Options → Auth Flow Types JSON import — the same hook `login()` uses. Assumes a
    /// screen with the Settings gear is showing (the host list under forced advanced auth, or the
    /// in-app WebView). Closing Login Options restarts authentication, so the login surface
    /// reappears in the modality the flag now selects.
    ///
    /// - Parameter staticAppConfigName: When non-nil, imports the given app config so the WebView
    ///   can load a real login page. Pass `nil` (the default) when testing against
    ///   `login.salesforce.com` — the app's default `bootconfig.plist` consumer key is valid there
    ///   and overriding it with a My-Domain-specific ECA config (e.g. `ecaOpaque`) would cause
    ///   `invalid_client_id` on the standard server and prevent the login form from loading.
    func setForceAdvancedAuthentication(
        _ value: Bool,
        staticAppConfigName: KnownAppConfig? = nil,
        staticScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let staticAppConfig = staticAppConfigName.map { getAppConfig(named: $0) }
        let staticScopes = staticAppConfig.map { testConfig.getScopesToRequest(for: $0, staticScopeSelection) } ?? ""
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

    /// True when the in-app login view controller (`SFLoginViewController`) is showing, detected
    /// by its "Log In" nav bar. Appears as soon as the view controller is presented — before the
    /// WKWebView has loaded the login page — so it is faster and more reliable than
    /// `isShowingInAppLoginForm()` for modality checks. Use when you need to confirm the SDK chose
    /// the in-app WebView path rather than the external browser, without waiting for a real page load.
    func isShowingLoginViewController(timeout: TimeInterval = UITestTimeouts.long) -> Bool {
        return loginPage.isShowingLoginViewController(timeout: timeout)
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
        isMultiUser: Bool = false,
        expectedBMarker: String? = nil,
        expectedLMarker: String? = nil,
        expectedAMarker: String? = nil,
        wasMigrated: Bool = false,
        isBeacon: Bool = false,
        expectDP: Bool? = nil
    ) -> UserCredentialsData {

        let userConfig = getUser(loginHost: loginHost, user: user)
        let userAppConfig = getAppConfig(named: userAppConfigName)
        let expectedGrantedScopes = testConfig.getExpectedScopesGranted(for: userAppConfig, userScopeSelection)
        let issuesJwt = userAppConfig.issuesJwt
        let effectiveExpectDP = expectDP ?? userAppConfig.isDPoP

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
        assertSIDs(userCredentialsData: userCredentials, useHybridFlow: useHybridFlow, useJwt: issuesJwt, isDPoP: effectiveExpectDP)
        assertURLs(userCredentialsData: userCredentials, useWebServerFlow: useWebServerFlow)

        // DPoP token binding: assert on any DPoP-app path (login, switch, restart, migration)
        if effectiveExpectDP {
            assertDPoPCredentials(userCredentials)
        }

        // Validate feature flags using UA already present in the fetched credentials
        validateUserAgent(ua: userCredentials.userAgent, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, usesWelcomeDiscovery: usesWelcomeDiscovery, isMultiUser: isMultiUser, expectedRTRFeatureMarker: expectedRTRFeatureMarker(for: userConfig.username), expectDP: effectiveExpectDP, expectedBMarker: expectedBMarker, expectedLMarker: expectedLMarker, expectedAMarker: expectedAMarker, wasMigrated: wasMigrated, isJwt: issuesJwt, isBeacon: isBeacon)

        return userCredentials
    }
    
    // MARK: - Private Helpers

    private func aMarkerFor(useWebServerFlow: Bool, useHybridFlow: Bool) -> String {
        if useWebServerFlow {
            return useHybridFlow ? kAuthTypeWebServerHybrid : kAuthTypeWebServerNonHybrid
        } else {
            return useHybridFlow ? kAuthTypeUserAgentHybrid : kAuthTypeUserAgentNonHybrid
        }
    }

    /// Extracts the current A-marker from a UA string, returning nil if none is present.
    private func extractAMarkerFromUA(_ ua: String) -> String? {
        guard let ftrRange = ua.range(of: "ftr_") else { return nil }
        let flags = String(ua[ftrRange.upperBound...])
            .components(separatedBy: " ").first ?? ""
        let flagSet = Set(flags.components(separatedBy: ".").filter { !$0.isEmpty })
        return kAllAMarkers.first { flagSet.contains($0) }
    }

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
        forceAdvancedAuthentication: Bool = true,
        isMultiUser: Bool = false,
        usesWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
        useDPoP: Bool = false,
        wasMigrated: Bool = false,
        useLoginPoolHost: Bool = false,
        expectedAMarkerOverride: String? = nil
    ) -> UserCredentialsData {

        let staticAppConfig = getAppConfig(named: staticAppConfigName)

        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()

        let expectAdvancedAuth = loginForAdmin || loginHost == .advancedAuth || forceAdvancedAuthentication

        let expectedBMarker: String? = expectAdvancedAuth ? (
            loginForAdmin ? kBrowserLoginForAdmin :
            forceAdvancedAuthentication ? kBrowserLoginForceFlag :
            kBrowserLoginServerAuthConfig
        ) : nil

        let expectedLMarker: String?
        if usesWelcomeDiscovery {
            expectedLMarker = kLoginServerWelcomeDiscovery
        } else if useLoginPoolHost {
            // Pool server (login.salesforce.com, login.*.salesforce.com) registers L1, not L4.
            expectedLMarker = kLoginServerProduction
        } else {
            expectedLMarker = kLoginServerMyDomain
        }

        // For migrations, use the pre-migration A-marker (preserved per spec). For fresh logins,
        // derive it from the flow parameters. Login for Admin always uses SFOAuthTypeAdvancedBrowser
        // which issues a web-server (auth-code) grant regardless of the app's configured flow.
        let effectiveWebServerFlow = loginForAdmin ? true : useWebServerFlow
        let aMarker = expectedAMarkerOverride ?? aMarkerFor(useWebServerFlow: effectiveWebServerFlow, useHybridFlow: useHybridFlow)
        let userAppConfig = getAppConfig(named: userAppConfigName)

        let effectiveExpectDP = useDPoP || userAppConfig.isDPoP
        let userCredentials = validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            expectAdvancedAuth: expectAdvancedAuth,
            usesWelcomeDiscovery: usesWelcomeDiscovery,
            isMultiUser: isMultiUser,
            expectedBMarker: expectedBMarker,
            expectedLMarker: expectedLMarker,
            expectedAMarker: aMarker,
            wasMigrated: wasMigrated,
            isBeacon: userAppConfig.isBeacon,
            expectDP: effectiveExpectDP
        )

        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials, expectsRefreshTokenRotation: userAppConfig.expectsRefreshTokenRotation, isDPoP: effectiveExpectDP, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, usesWelcomeDiscovery: usesWelcomeDiscovery, isMultiUser: isMultiUser, expectedBMarker: expectedBMarker, expectedLMarker: expectedLMarker, expectedAMarker: aMarker, wasMigrated: wasMigrated, isJwt: userAppConfig.issuesJwt, isBeacon: userAppConfig.isBeacon)

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

    /// Asserts that the main page never loads, i.e. the app never reaches the post-login
    /// credentials view. Use this after a login attempt expected to be rejected before any
    /// authenticated user is added (e.g. an enforced-server `/authorize` rejection). Waits out
    /// `mainPage.isShowing()`'s own network timeout to give a rejected login enough time to settle
    /// back on the host picker before asserting absence.
    func assertMainPageNotLoaded() {
        XCTAssertFalse(mainPage.isShowing(), "AuthFlowTester should not have loaded")
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
    
    private func assertSIDs(userCredentialsData: UserCredentialsData, useHybridFlow: Bool, useJwt: Bool, isDPoP: Bool) {
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

        assertNotEmpty(userCredentialsData.uiSid, shouldNotBeEmpty: isDPoP, "UI SID")

        if useHybridFlow {
            if isDPoP {
                XCTAssertEqual(userCredentialsData.mainSid, userCredentialsData.uiSid, "Main SID should equal UI SID in DPoP hybrid flow")
            } else if useJwt {
                XCTAssertEqual(userCredentialsData.mainSid, userCredentialsData.parentSid, "Main SID should equal Parent SID in JWT hybrid flow")
            } else {
                XCTAssertEqual(userCredentialsData.mainSid, userCredentialsData.accessToken, "Main SID should equal Access Token in opaque hybrid flow")
            }
        }
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
    /// `expectAdvancedAuth` defaults to `true`, matching the `forceAdvancedAuthentication` default.
    /// Pass `false` for tests that logged in with the in-app WebView or post-migration validations
    /// where BW is not re-registered.
    func assertRevokeAndRefreshWorks(expectsRefreshTokenRotation: Bool, isDPoP: Bool = false, loginHost: KnownLoginHostConfig = .regularAuth, expectAdvancedAuth: Bool = true, isMultiUser: Bool = false, useWebServerFlow: Bool = true, useHybridFlow: Bool = true, wasMigrated: Bool = false, isJwt: Bool = false, isBeacon: Bool = false, useLoginPoolHost: Bool = false) {
        let expectedBMarker: String? = expectAdvancedAuth ? kBrowserLoginForceFlag : nil
        let expectedLMarker: String? = useLoginPoolHost ? kLoginServerProduction : kLoginServerMyDomain
        let aMarker = aMarkerFor(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)
        assertRevokeAndRefreshWorks(previousCredentials: getUserCredentials(), expectsRefreshTokenRotation: expectsRefreshTokenRotation, isDPoP: isDPoP, loginHost: loginHost, expectAdvancedAuth: expectAdvancedAuth, isMultiUser: isMultiUser, expectedBMarker: expectedBMarker, expectedLMarker: expectedLMarker, expectedAMarker: aMarker, wasMigrated: wasMigrated, isJwt: isJwt, isBeacon: isBeacon)
    }

    private func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData, expectsRefreshTokenRotation: Bool, isDPoP: Bool = false, loginHost: KnownLoginHostConfig = .regularAuth, expectAdvancedAuth: Bool = true, usesWelcomeDiscovery: Bool = false, isMultiUser: Bool = false, expectedBMarker: String? = nil, expectedLMarker: String? = nil, expectedAMarker: String? = nil, wasMigrated: Bool = false, isJwt: Bool = false, isBeacon: Bool = false) {
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

        // Assert refresh token rotated (RTR) or stayed the same (non-RTR).
        let refreshTokenRotated = previousCredentials.refreshToken != credentialsAfterRefresh.refreshToken
        if expectsRefreshTokenRotation {
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

        // RT is sticky per user and is registered only by a normal refresh that observes a
        // changed refresh token. Migration and login never advance this state.
        let expectedRTRFeatureMarkerAfterRefresh = expectedRTRFeatureMarker(for: previousCredentials.username) || refreshTokenRotated
        expectedRTRFeatureMarkerByUsername[previousCredentials.username] = expectedRTRFeatureMarkerAfterRefresh

        // Assert DPoP token type and nonce presence if DPoP is enabled
        if isDPoP {
            assertDPoPCredentials(credentialsAfterRefresh, context: "after refresh")
        }

        validateUserAgent(userCredentials: credentialsAfterRefresh,
                          loginHost: loginHost,
                          expectAdvancedAuth: expectAdvancedAuth,
                          usesWelcomeDiscovery: usesWelcomeDiscovery,
                          isMultiUser: isMultiUser,
                          expectDP: isDPoP,
                          expectedBMarker: expectedBMarker,
                          expectedLMarker: expectedLMarker,
                          expectedAMarker: expectedAMarker,
                          wasMigrated: wasMigrated,
                          isJwt: isJwt,
                          isBeacon: isBeacon)
    }

    private func expectedRTRFeatureMarker(for username: String) -> Bool {
        guard let expectedRTRFeatureMarker = expectedRTRFeatureMarkerByUsername[username] else {
            XCTFail("No RT feature-marker state recorded for user \(username)")
            return false
        }
        return expectedRTRFeatureMarker
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
