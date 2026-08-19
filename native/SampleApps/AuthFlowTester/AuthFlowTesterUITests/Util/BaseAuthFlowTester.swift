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
        super.tearDown()
    }
    
    // MARK: - Public API for Subclasses
    
    /// Launches the application and ensures it starts in a logged-out state.
    ///
    /// Initializes the app and page objects, launches the app, and logs out if a user is already logged in.
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

        // Close advanced authentication is showing
        if (loginPage.isShowingAdvancedAuth()) {
            loginPage.closeAdvancedAuth()
        }

        // Pre-warm the WKWebView process pool by waiting for the initial login page
        // to fully load. On the first test in a class, the WebView process hasn't
        // been created yet — this absorbs the cold-start cost so subsequent
        // host-change navigations don't time out.
        loginPage.waitForWebViewReady()
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
    ///   - useWelcomeDiscovery: When true, configures simulated domain discovery. Defaults to `false`.
    ///   - loginForAdmin: When true, uses the "Login for Admin" flow (browser-based auth via Settings menu). Defaults to `false`.
    func login(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
    ) {
        let userConfig = getUser(loginHost: loginHost, user: user)
        let hostConfig = getLoginHost(loginHost: loginHost)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        let dynamicScopes = dynamicAppConfig == nil ? "" : testConfig.getScopesToRequest(for: dynamicAppConfig!, dynamicScopeSelection)
        
        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            discoveryLoginHost: useWelcomeDiscovery ? hostConfig.urlNoProtocol : "",
            discoveryUsername: useWelcomeDiscovery ? userConfig.username : "",
        )
        
        // Configuring login host last
        // When the configured login host requires advanced authentication
        // the login settings button is no longer available on the screen
        // When useWelcomeDiscovery is true, use welcome.salesforce.com/discovery as the login server
        let loginHostToUse = useWelcomeDiscovery ? "welcome.salesforce.com/discovery" : hostConfig.urlNoProtocol
        loginPage.configureLoginHost(host: loginHostToUse)
        
        // Invalid app config
        if (dynamicAppConfigName == .invalid || (dynamicAppConfigName == nil && staticAppConfigName == .invalid)) {
            XCTAssertTrue(loginPage.isShowingInvalidClientIdError(), "Login page should show invalid client id error")
            logoutAtTearDown = false
            return
        }
        
        // Login for Admin (browser-based auth via Settings menu)
        if (loginForAdmin) {
            loginPage.performLoginForAdmin(username: userConfig.username, password: userConfig.password)
        }
        // Welcome login
        else if (useWelcomeDiscovery) {
            XCTAssertTrue(loginPage.hasFilledUsernameField(username: userConfig.username), "Login page should have pre-filled username")
            loginPage.performWelcomeLogin(password: userConfig.password, advancedAuth: loginHost == .advancedAuth)
        }
        // Regular or advanced auth
        else {
            loginPage.performLogin(username: userConfig.username, password: userConfig.password, advancedAuth: loginHost == .advancedAuth)
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
    func switchToUserAndValidate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
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
            useHybridFlow: useHybridFlow
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
        useHybridFlow: Bool = true
    ) {
        // Switch user
        mainPage.switchToUser(username: getUser(loginHost: loginHost, user: user).username)
        
        // Validate
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
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
        useWelcomeDiscovery: Bool = false,
        loginForAdmin: Bool = false,
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
            useWelcomeDiscovery: useWelcomeDiscovery,
            loginForAdmin: loginForAdmin
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
            useHybridFlow: useHybridFlow
        )
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
    func loginOtherUserAndValidate(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
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
            useHybridFlow: useHybridFlow
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
    func restartAndValidateUser(
        loginHost: KnownLoginHostConfig = .regularAuth,
        user: KnownUserConfig = .first,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        // Restart
        app.terminate()
        app.launch()

        // Restore auth flow settings lost on restart
        mainPage.setAuthFlowTypes(useWebServerFlow: useWebServerFlow, useHybridFlow: useHybridFlow)

        // Validate user
        // Not checking static app config since it will depend on the bootconfig of the target app
        validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
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

        // Validate after migration
        let migratedUserCredentials = validate(
            loginHost: loginHost,
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: migrationAppConfigName,
            userScopeSelection: migrationScopeSelection,
            useWebServerFlow: migrationUseWebServerFlow,
            useHybridFlow: migrationUseHybridFlow
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

    /// Returns the user configuration for the specified login host and user.
    private func getUser(loginHost: KnownLoginHostConfig, user: KnownUserConfig) -> UserConfig {
        do {
            return try testConfig.getUser(loginHost, user)
        } catch {
            XCTFail("Failed to get user \(user) from login host \(loginHost): \(error)")
            fatalError("Failed to get user \(user) from login host \(loginHost): \(error)")
        }
    }

    /// Validates user credentials
    @discardableResult
    func validateUser(
        loginHost: KnownLoginHostConfig,
        user: KnownUserConfig,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection,
        useWebServerFlow: Bool,
        useHybridFlow: Bool
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
    ) -> UserCredentialsData {
        
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        
        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()

        let userCredentials = validateUser(
            loginHost: loginHost,
            user: user,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        
        // Revoke and refresh cycle
        let userAppConfig = getAppConfig(named: userAppConfigName)
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials, isRtr: userAppConfig.isRtr)

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
    func assertRevokeAndRefreshWorks(isRtr: Bool) {
        assertRevokeAndRefreshWorks(previousCredentials: getUserCredentials(), isRtr: isRtr)
    }

    private func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData, isRtr: Bool) {
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
