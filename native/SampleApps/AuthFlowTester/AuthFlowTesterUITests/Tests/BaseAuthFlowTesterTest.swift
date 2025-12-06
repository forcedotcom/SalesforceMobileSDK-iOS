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
            return
        }
                
        app = XCUIApplication()
        loginPage = LoginPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
        app.launch()
        
        // Start logged out
        if (mainPage.isShowing()) {
            logout()
        }
    }
    
    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    // MARK: - Public API for Subclasses
    
    /// Logs out the current user by tapping the logout button and confirming.
    func logout() {
        mainPage.performLogout()
    }
    
    /// Performs login, validates user credentials etc, then performs revoke/refresh cycle.
    ///
    /// - Parameters:
    ///   - staticAppConfigName: The app configuration to use as static configuration in login options.
    ///   - dynamicAppConfigName: The app configuration to use as dynamic configuration in login options (optional).
    ///   - userConfig: The user credentials. If nil, uses the primary user from test config.
    ///   - scopesToRequest: Specific scopes to request (e.g., "api id refresh_token"). Ignored if `useAllScopes` is true.
    ///   - useAllScopes: If true, requests all scopes defined in the app config. 
    ///   - useWebServerFlow: Whether to use web server flow (true) or user agent flow (false).
    ///   - useHybridFlow: Whether to use hybrid authentication flow.
    ///
    /// When a dynamicAppConfigName is specified, we will do the login using the dynamic configuration
    /// and scopesToRequest will be used in the dynamic configuration.
    ///
    /// When useAllScopes is used, we will request the scopes defined for the app in test_config.json.
    /// Otherwise we will use the value provided in the scopesToRequest parameter.
    func loginAndValidateAndRevokeAndRefresh(
        staticAppConfigName: KnownAppName,
        dynamicAppConfigName: KnownAppName? = nil,
        userConfig: UserConfig? = nil,
        scopesToRequest: String = "",
        useAllScopes: Bool = false,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let useStaticConfiguration = dynamicAppConfigName == nil
        
        // App configs
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let appConfig = dynamicAppConfig ?? staticAppConfig
        
        // Scopes
        let actualScopesToRequest = useAllScopes ? appConfig.scopes : scopesToRequest
        let staticScopes = useStaticConfiguration ? actualScopesToRequest : staticAppConfig.scopes
        let dynamicScopes = useStaticConfiguration ? "" : actualScopesToRequest
        let expectedScopes = expectedScopesGranted(scopesToRequest: actualScopesToRequest, appConfig: appConfig)

        // User
        let resolvedUserConfig = userConfig ?? getPrimaryUser()
        
        // Login
        login(
            userConfig: resolvedUserConfig,
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useStaticConfiguration: useStaticConfiguration,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        
        // Validate
        let userCredentials = validate(
            userConfig: resolvedUserConfig,
            appConfig: appConfig,
            expectedScopes: expectedScopes,
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            useHybridFlow: useHybridFlow
        )
        
        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials)
    }
    
    /// Restarts the app, validates user credentials etc, then performs revoke/refresh cycle.
    /// Use this after a prior login to verify the user session persists across app restarts.
    ///
    /// - Parameters:
    ///   - staticAppConfigName: The app configuration used as static configuration during initial login.
    ///   - dynamicAppConfigName: The app configuration used as dynamic configuration during initial login (optional).
    ///   - userConfig: The user credentials. If nil, uses the primary user from test config.
    ///   - scopesToRequest: The scopes that were requested during the initial login.
    ///   - useAllScopes: If true, uses all scopes defined in the app config.
    ///   - useWebServerFlow: Whether web server flow was used (true) or user agent flow (false).
    ///   - useHybridFlow: Whether hybrid authentication flow was used.
    func restartAndValidateAndRevokeAndRefresh(
        staticAppConfigName: KnownAppName,
        dynamicAppConfigName: KnownAppName? = nil,
        userConfig: UserConfig? = nil,
        scopesToRequest: String = "",
        useAllScopes: Bool = false,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let useStaticConfiguration = dynamicAppConfigName == nil
        
        // App configs
        let staticAppConfig = getAppConfig(named: staticAppConfigName)
        let dynamicAppConfig = dynamicAppConfigName == nil ? nil : getAppConfig(named: dynamicAppConfigName!)
        let appConfig = dynamicAppConfig ?? staticAppConfig
        
        // Scopes
        let actualScopesToRequest = useAllScopes ? appConfig.scopes : scopesToRequest
        let staticScopes = useStaticConfiguration ? actualScopesToRequest : staticAppConfig.scopes
        let dynamicScopes = useStaticConfiguration ? "" : actualScopesToRequest
        let expectedScopes = expectedScopesGranted(scopesToRequest: actualScopesToRequest, appConfig: appConfig)

        // User
        let resolvedUserConfig = userConfig ?? getPrimaryUser()
        
        // Restart
        app.terminate()
        app.launch()
        
        // Validate
        let userCredentials = validate(
            userConfig: resolvedUserConfig,
            appConfig: appConfig,
            expectedScopes: expectedScopes,
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            useHybridFlow: useHybridFlow
        )
        
        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials)
    }
    
    /// Performs login, migrates refresh token to a new app configuration, validates user credentials etc,
    /// then performs revoke/refresh cycle.
    /// Tests the refresh token migration flow where a user's session is transferred to a different connected app.
    ///
    /// - Parameters:
    ///   - initialAppConfigName: The app configuration to use for the initial login.
    ///   - migrationAppConfigName: The app configuration to migrate the refresh token to.
    ///   - userConfig: The user credentials. If nil, uses the primary user from test config.
    ///   - initialScopesToRequest: Scopes to request during the initial login.
    ///   - migrationScopesToRequest: Scopes to request during the migration.
    func loginAndMigrateAndValidateAndRevokeAndRefresh(
        initialAppConfigName: KnownAppName,
        migrationAppConfigName: KnownAppName,
        userConfig: UserConfig? = nil,
        initialScopesToRequest: String = "",
        migrationScopesToRequest: String = ""
    ) {
        let initialAppConfig = getAppConfig(named: initialAppConfigName)
        let migrationAppConfig = getAppConfig(named: migrationAppConfigName)
        let resolvedUserConfig = userConfig ?? getPrimaryUser()
        let expectedInitialScopes = expectedScopesGranted(scopesToRequest: initialScopesToRequest, appConfig: initialAppConfig)
        let expectedMigratedScopes = expectedScopesGranted(scopesToRequest: migrationScopesToRequest, appConfig: migrationAppConfig)
        
        // Login
        login(
            userConfig: resolvedUserConfig,
            staticAppConfig: initialAppConfig,
            staticScopes: initialScopesToRequest,
            dynamicAppConfig: nil,
            dynamicScopes: "",
            useStaticConfiguration: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
        
        // Validate initial state
        let initialUserCredentials = validate(
            userConfig: resolvedUserConfig,
            appConfig: initialAppConfig,
            expectedScopes: expectedInitialScopes,
            staticAppConfig: initialAppConfig,
            staticScopes: initialScopesToRequest,
            useHybridFlow: true
        )
        
        // Migrate refresh token
        changeAppConfig(appConfig: migrationAppConfig, scopesToRequest: migrationScopesToRequest)

        // Validate after migration (oauth config should still show initial config)
        let migratedUserCredentials = validate(
            userConfig: resolvedUserConfig,
            appConfig: migrationAppConfig,
            expectedScopes: expectedMigratedScopes,
            staticAppConfig: initialAppConfig,
            staticScopes: initialScopesToRequest,
            useHybridFlow: true
        )

        // Making sure the refresh token changed
        XCTAssertNotEqual(
            initialUserCredentials.refreshToken,
            migratedUserCredentials.refreshToken,
            "Refresh token should have been migrated"
        )
        
        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: migratedUserCredentials)
    }
    
    // MARK: - Private Helpers
    
    private func login(
        userConfig: UserConfig,
        staticAppConfig: AppConfig?,
        staticScopes: String = "",
        dynamicAppConfig: AppConfig?,
        dynamicScopes: String = "",
        useStaticConfiguration: Bool = true,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        loginPage.configureLoginOptions(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useStaticConfiguration: useStaticConfiguration,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        
        // To speed up things a bit - only configuring login host once (it never changes)
        if (!loginHostConfiguredAlready) {
            loginPage.configureLoginHost(host: host)
            loginHostConfiguredAlready = true
        }
        loginPage.performLogin(username: userConfig.username, password: userConfig.password)
    }
    
    private func changeAppConfig(appConfig: AppConfig, scopesToRequest: String = "") {
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
    
    private func checkOauthConfiguration(configuredConsumerKey: String, configuredCallbackUrl: String, requestedScopes: String) -> OAuthConfigurationData {
        let oauthConfiguration = mainPage.getOAuthConfiguration()
        XCTAssertEqual(oauthConfiguration.configuredConsumerKey, configuredConsumerKey, "Configured consumer key should match expected value")
        XCTAssertEqual(oauthConfiguration.configuredCallbackUrl, configuredCallbackUrl, "Configured callback URL should match expected value")
        XCTAssertEqual(oauthConfiguration.configuredScopes, requestedScopes == "" ? "(none)" : requestedScopes, "Configured scopes should match requested scopes")
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
    
    private func getAppConfig(named name: KnownAppName) -> AppConfig {
        do {
            return try testConfig.getApp(named: name)
        } catch {
            XCTFail("Failed to get app config for \(name): \(error)")
            fatalError("Failed to get app config for \(name): \(error)")
        }
    }
    
    private func getPrimaryUser() -> UserConfig {
        do {
            return try testConfig.getPrimaryUser()
        } catch {
            XCTFail("Failed to get primary user: \(error)")
            fatalError("Failed to get primary user: \(error)")
        }
    }
    
    private func expectedScopesGranted(scopesToRequest: String, appConfig: AppConfig) -> String {
        return scopesToRequest == "" ? appConfig.scopes : scopesToRequest
    }
    
    private func validate(
        userConfig: UserConfig,
        appConfig: AppConfig,
        expectedScopes: String,
        staticAppConfig: AppConfig,
        staticScopes: String,
        useHybridFlow: Bool
    ) -> UserCredentialsData {
        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()
        
        // Check the user credentials (consumer key should match the app config used)
        let userCredentials = checkUserCredentials(
            username: userConfig.username,
            userConsumerKey: appConfig.consumerKey,
            userRedirectUri: appConfig.redirectUri,
            grantedScopes: expectedScopes
        )
        
        // Check the oauth configuration
        // NB: Consumer key should match the static app config regardless of whether it was used or not
        _ = checkOauthConfiguration(
            configuredConsumerKey: staticAppConfig.consumerKey,
            configuredCallbackUrl: staticAppConfig.redirectUri,
            requestedScopes: staticScopes
        )
        
        // Check JWT if applicable
        checkJwtDetailsIfApplicable(appConfig: appConfig, scopes: expectedScopes)
        
        // Additional login-specific validations
        assertSIDs(userCredentialsData: userCredentials, useHybridFlow: useHybridFlow, useJwt: appConfig.issuesJwt)
        assertURLs(userCredentialsData: userCredentials)
        
        return userCredentials
    }
    
    private func checkJwtDetailsIfApplicable(appConfig: AppConfig, scopes: String) {
        if appConfig.issuesJwt {
            _ = checkJwtDetails(
                clientId: appConfig.consumerKey,
                scopes: scopes
            )
        }
    }
    
    private func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData) {
        // Revoke access token
        assertRevokeWorks()
                
        // Make REST request (which should trigger token refresh)
        assertRestRequestWorks()
        
        let credentialsAfterRefresh = getUserCredentials()
        
        // Assert access token changed
        XCTAssertNotEqual(
            previousCredentials.accessToken,
            credentialsAfterRefresh.accessToken,
            "Access token should have been refreshed"
        )
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
