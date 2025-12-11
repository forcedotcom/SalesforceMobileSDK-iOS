/*
 BaseAuthFlowTesterTest.swift
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

class BaseAuthFlowTesterTest: XCTestCase {
    // App object
    private var app: XCUIApplication!

    // App Pages
    private var loginPage: LoginPageObject!
    private var mainPage: AuthFlowTesterMainPageObject!

    // Test configuration
    private let testConfig = TestConfigUtils.shared
    private let host: String = TestConfigUtils.shared.loginHostNoProtocol ?? ""
    private var loginHostConfiguredAlready = false

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        guard host != "" else {
            XCTFail("No login host configured")
            fatalError("No login host configured")
        }
    }
    
    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    // MARK: - Public API for Subclasses
    
    /// Launches the application and ensures it starts in a logged-out state.
    ///
    /// Initializes the app and page objects, launches the app, and logs out if a user is already logged in.
    func launch() {
        app = XCUIApplication()
        loginPage = LoginPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
        app.launch()
        
        // Start logged out
        if (!loginPage.isShowing()) {
            logout()
        }
    }
    
    /// Performs login with the specified configuration.
    ///
    /// Configures the login options and performs authentication for the specified user.
    /// Must be called after `launch()`.
    ///
    /// - Parameters:
    ///   - user: The user to log in with. Defaults to `.first`.
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useStaticConfiguration: Whether to use static or dynamic configuration. Defaults to `true`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - supportWelcomeDiscovery: Whether to support welcome/discovery screen. Defaults to `false`.
    func login(
        user: KnownUserConfig = .first,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useStaticConfiguration: Bool = true,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        supportWelcomeDiscovery: Bool = false
    ) {
        requireDynamicConfigIfNotUsingStatic(dynamicAppConfigName: dynamicAppConfigName, useStaticConfiguration: useStaticConfiguration)
        
        let userConfig = getUser(user)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let staticScopes = testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        let dynamicScopes = dynamicAppConfig == nil ? "" : testConfig.getScopesToRequest(for: dynamicAppConfig!, dynamicScopeSelection)
        
        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useStaticConfiguration: useStaticConfiguration,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            supportWelcomeDiscovery: supportWelcomeDiscovery
        )
        
        // To speed up things a bit - only configuring login host once (it never changes)
        if (!loginHostConfiguredAlready) {
            loginPage.configureLoginHost(host: host)
            loginHostConfiguredAlready = true
        }
        
        loginPage.performLogin(username: userConfig.username, password: userConfig.password)
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
    ///   - user: The user to switch to.
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - userAppConfigName: The app configuration the user was logged in with.
    ///   - userScopeSelection: The scope selection the user was logged in with. Defaults to `.empty`.
    ///   - useHybridFlow: Whether hybrid authentication flow was used. Defaults to `true`.
    func switchToUserAndValidate(
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useHybridFlow: Bool = true
    ) {
        // Switch user
        mainPage.switchToUser(username: getUser(user).username)
        
        // Validate
        validate(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useHybridFlow: useHybridFlow
        )
    }
    
    /// Launches the app, performs login, and validates the resulting credentials.
    ///
    /// This is a convenience method that combines `launch()`, `login()`, and validation in one call.
    /// Use this for the initial login flow in tests.
    ///
    /// - Parameters:
    ///   - user: The user to log in with. Defaults to `.first`.
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useStaticConfiguration: Whether to use static or dynamic configuration. Defaults to `true`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - supportWelcomeDiscovery: Whether to support welcome/discovery screen. Defaults to `false`.
    func launchLoginAndValidate(
        user: KnownUserConfig = .first,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useStaticConfiguration: Bool = true,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        supportWelcomeDiscovery: Bool = false
    ) {
        requireDynamicConfigIfNotUsingStatic(dynamicAppConfigName: dynamicAppConfigName, useStaticConfiguration: useStaticConfiguration)

        let userAppConfigName = useStaticConfiguration ? staticAppConfigName : dynamicAppConfigName!
        let userScopeSelection = useStaticConfiguration ? staticScopeSelection : dynamicScopeSelection
        
        // Launch
        launch()
        
        // Login
        login(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            dynamicAppConfigName: dynamicAppConfigName,
            dynamicScopeSelection: dynamicScopeSelection,
            useStaticConfiguration: useStaticConfiguration,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            supportWelcomeDiscovery: supportWelcomeDiscovery
        )
        
        // Validate
        validate(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useHybridFlow: useHybridFlow
        )
    }
    
    /// Logs in an additional user (multi-user scenario) and validates the credentials.
    ///
    /// Use this method after an initial user is already logged in to add another user account.
    /// Taps the "Add User" button before performing login.
    ///
    /// - Parameters:
    ///   - user: The user to log in with. Defaults to `.second`.
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - dynamicAppConfigName: Optional dynamic app configuration name (provided at runtime).
    ///   - dynamicScopeSelection: The scope selection for dynamic configuration. Defaults to `.empty`.
    ///   - useStaticConfiguration: Whether to use static or dynamic configuration. Defaults to `true`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    ///   - supportWelcomeDiscovery: Whether to support welcome/discovery screen. Defaults to `false`.
    func loginOtherUserAndValidate(
        user: KnownUserConfig = .second,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        dynamicAppConfigName: KnownAppConfig? = nil,
        dynamicScopeSelection: ScopeSelection = .empty,
        useStaticConfiguration: Bool = true,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
        supportWelcomeDiscovery: Bool = false
    ) {
        requireDynamicConfigIfNotUsingStatic(dynamicAppConfigName: dynamicAppConfigName, useStaticConfiguration: useStaticConfiguration)

        let userAppConfigName = useStaticConfiguration ? staticAppConfigName : dynamicAppConfigName!
        let userScopeSelection = useStaticConfiguration ? staticScopeSelection : dynamicScopeSelection
        
        // Switch to add new user
        mainPage.performAddUser()
        
        // Login
        login(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            dynamicAppConfigName: dynamicAppConfigName,
            dynamicScopeSelection: dynamicScopeSelection,
            useStaticConfiguration: useStaticConfiguration,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            supportWelcomeDiscovery: supportWelcomeDiscovery
        )
        
        // Validate
        validate(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useHybridFlow: useHybridFlow
        )
    }
    
    /// Restarts the app and validates that the user session persists.
    ///
    /// Terminates and relaunches the app, then validates that the user is still logged in
    /// with the expected credentials. Use this to test session persistence.
    ///
    /// - Parameters:
    ///   - user: The user that should still be logged in after restart.
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - userAppConfigName: The app configuration the user was logged in with.
    ///   - userScopeSelection: The scope selection the user was logged in with. Defaults to `.empty`.
    ///   - useHybridFlow: Whether hybrid authentication flow was used. Defaults to `true`.
    func restartAndValidate(
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection = .empty,
        useHybridFlow: Bool = true
    ) {
        // Restart
        app.terminate()
        app.launch()
        
        // Validate
        validate(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: userAppConfigName,
            userScopeSelection: userScopeSelection,
            useHybridFlow: useHybridFlow
        )
    }
    
    /// Migrates the refresh token to a new app configuration and validates the result.
    ///
    /// Performs a refresh token migration from the current app configuration to a new one,
    /// then validates that the credentials are updated correctly and the refresh token has changed.
    ///
    /// - Parameters:
    ///   - staticAppConfigName: The static app configuration name (compiled into the app).
    ///   - staticScopeSelection: The scope selection for static configuration. Defaults to `.empty`.
    ///   - migrationAppConfigName: The app configuration to migrate to.
    ///   - migrationScopeSelection: The scope selection for the migration target. Defaults to `.empty`.
    ///   - useWebServerFlow: Whether to use web server OAuth flow. Defaults to `true`.
    ///   - useHybridFlow: Whether to use hybrid authentication flow. Defaults to `true`.
    func migrateAndValidate(
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection = .empty,
        migrationAppConfigName: KnownAppConfig,
        migrationScopeSelection: ScopeSelection = .empty,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        // Get original credentials before migration
        let originalUserCredentials = mainPage.getUserCredentials()
        
        // Get current user
        let user = getKnownUserConfig(byUsername: originalUserCredentials.username)
        
        
        // Migrate refresh token
        migrateRefreshToken(
            appConfigName: migrationAppConfigName,
            scopeSelection: migrationScopeSelection
        )

        // Validate after migration
        let migratedUserCredentials = validate(
            user: user,
            staticAppConfigName: staticAppConfigName,
            staticScopeSelection: staticScopeSelection,
            userAppConfigName: migrationAppConfigName,
            userScopeSelection: migrationScopeSelection,
            useHybridFlow: useHybridFlow
        )

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            originalUserCredentials.refreshToken,
            migratedUserCredentials.refreshToken,
            "Refresh token should have been migrated"
        )
    }
    
    // MARK: - Private Helpers
    
    @discardableResult
    private func validate(
        user: KnownUserConfig,
        staticAppConfigName: KnownAppConfig,
        staticScopeSelection: ScopeSelection,
        userAppConfigName: KnownAppConfig,
        userScopeSelection: ScopeSelection,
        useHybridFlow: Bool = true
    ) -> UserCredentialsData {

        let userConfig = getUser(user)
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let userAppConfig = getAppConfig(named: userAppConfigName)
        let expectedGrantedScopes = testConfig.getExpectedScopesGranted(for: userAppConfig, userScopeSelection)
        
        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()
        
        // Check the user credentials (consumer key should match the app config used)
        let userCredentials = checkUserCredentials(
            username: userConfig.username,
            userConsumerKey: userAppConfig.consumerKey,
            userRedirectUri: userAppConfig.redirectUri,
            grantedScopes: expectedGrantedScopes
        )
        
        // Check the oauth configuration
        _ = checkOauthConfiguration(
            staticConsumerKey: staticAppConfig.consumerKey,
            staticCallbackUrl: staticAppConfig.redirectUri,
            staticScopes: testConfig.getScopesToRequest(for: staticAppConfig, staticScopeSelection)
        )
        
        // Check JWT if applicable
        checkJwtDetailsIfApplicable(appConfig: userAppConfig, scopes: expectedGrantedScopes)
        
        // Additional login-specific validations
        assertSIDs(userCredentialsData: userCredentials, useHybridFlow: useHybridFlow, useJwt: userAppConfig.issuesJwt)
        assertURLs(userCredentialsData: userCredentials)
        
        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials)
        
        return userCredentials
    }
    

    private func migrateRefreshToken(
        appConfigName: KnownAppConfig,
        scopeSelection: ScopeSelection
    ) {
        let appConfig = getAppConfig(named: appConfigName)
        let scopesToRequest = testConfig.getScopesToRequest(for: appConfig, scopeSelection)
        
        mainPage.changeAppConfig(appConfig: appConfig, scopesToRequest: scopesToRequest)
    }
    
    private func getUserCredentials() -> UserCredentialsData {
        return mainPage.getUserCredentials()
    }
    
    private func assertMainPageLoaded() {
        XCTAssert(mainPage.isShowing(), "AuthFlowTester is not loaded")
    }
    
    private func checkUserCredentials(username: String, userConsumerKey: String, userRedirectUri: String, grantedScopes: String) -> UserCredentialsData {
        let userCredentials = mainPage.getUserCredentials()
        XCTAssertEqual(userCredentials.username, username, "Username in credentials should match expected username")
        XCTAssertEqual(userCredentials.clientId, userConsumerKey, "Client ID in credentials should match expected consumer key")
        XCTAssertEqual(userCredentials.redirectUri, userRedirectUri, "Redirect URI in credentials should match expected redirect URI")
        XCTAssertEqual(userCredentials.credentialsScopes, grantedScopes, "Scopes in credentials should match expected granted scopes")
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
    
    private func assertURLs(userCredentialsData: UserCredentialsData) {
        let hasApiScope = userCredentialsData.credentialsScopes.contains("api")
        let hasSfapApiScope = userCredentialsData.credentialsScopes.contains("sfap_api")
        
        assertNotEmpty(userCredentialsData.instanceUrl, shouldNotBeEmpty: true, "Instance URL")
        XCTAssertTrue(userCredentialsData.identityUrl.hasSuffix(userCredentialsData.organizationId + "/" + userCredentialsData.userId), "Identity URL should end with orgId/userId")
        assertNotEmpty(userCredentialsData.apiUrl, shouldNotBeEmpty: hasApiScope, "API URL")
        assertNotEmpty(userCredentialsData.apiInstanceUrl, shouldNotBeEmpty: hasSfapApiScope, "API Instance URL")
    }
    
    private func assertNotEmpty(_ value: String, shouldNotBeEmpty: Bool, _ name: String) {
        if shouldNotBeEmpty {
            XCTAssertNotEqual(value, "", "\(name) should not be empty")
        } else {
            XCTAssertEqual(value, "", "\(name) should be empty")
        }
    }
    
    private func assertRestRequestWorks() {
            XCTAssert(mainPage.makeRestRequest(), "Failed to make REST request")
    }
    
    private func assertRevokeWorks() {
        XCTAssert(mainPage.revokeAccessToken(), "Failed to revoke access token")
    }
    
    private func getAppConfig(named name: KnownAppConfig) -> AppConfig {
        do {
            return try testConfig.getApp(named: name)
        } catch {
            XCTFail("Failed to get app config for \(name): \(error)")
            fatalError("Failed to get app config for \(name): \(error)")
        }
    }
    
    private func getUser(_ user: KnownUserConfig) -> UserConfig {
        do {
            return try testConfig.getUser(user)
        } catch {
            XCTFail("Failed to get user \(user): \(error)")
            fatalError("Failed to get user \(user): \(error)")
        }
    }
    
    private func getKnownUserConfig(byUsername username: String) -> KnownUserConfig {
        do {
            return try testConfig.getKnownUserConfig(byUsername: username)
        } catch {
            XCTFail("Failed to get user \(username): \(error)")
            fatalError("Failed to get user \(username): \(error)")
        }
    }
    
    private func checkJwtDetailsIfApplicable(appConfig: AppConfig, scopes: String) {
        if appConfig.issuesJwt {
            _ = checkJwtDetails(
                clientId: appConfig.consumerKey,
                scopes: scopes
            )
        }
    }
    
    private func requireDynamicConfigIfNotUsingStatic(dynamicAppConfigName: KnownAppConfig?, useStaticConfiguration: Bool) {
        guard dynamicAppConfigName != nil || useStaticConfiguration else {
            XCTFail("Cannot do login using dynamic config without a dynamic config")
            fatalError("Cannot do login using dynamic config without a dynamic config")
        }
    }
    
    private func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData) {
        //
        // FIXME
        //
        
//        // Revoke access token
//        assertRevokeWorks()
//        
//        // Make REST request (which should trigger token refresh)
//        assertRestRequestWorks()
//        
//        let credentialsAfterRefresh = getUserCredentials()
//        
//        // Assert access token changed
//        XCTAssertNotEqual(
//            previousCredentials.accessToken,
//            credentialsAfterRefresh.accessToken,
//            "Access token should have been refreshed"
//        )
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
