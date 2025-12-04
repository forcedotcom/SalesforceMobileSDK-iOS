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
    let testConfig = TestConfigUtils.shared
    let host: String = TestConfigUtils.shared.loginHostNoProtocol ?? ""
    var loginHostConfiguredAlready = false

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
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func login(
        userConfig: UserConfig,
        appConfig: AppConfig,
        scopesToRequest: String = "",
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true,
    ) {
        loginPage.configureLoginOptions(consumerKey: appConfig.consumerKey, redirectUri: appConfig.redirectUri, scopes: scopesToRequest)
        // To speed up things a bit - only configuring login host once (it never changes)
        if (!loginHostConfiguredAlready) {
            loginPage.configureLoginHost(host: host)
            loginHostConfiguredAlready = true
        }
        loginPage.performLogin(username: userConfig.username, password: userConfig.password)
    }
    
    func logout() {
        mainPage.performLogout()
    }
    
    func logoutIfNeeded() {
        if (mainPage.isShowing()) {
            mainPage.performLogout()
        }
    }
    
    func changeAppConfig(appConfig: AppConfig, scopesToRequest: String = "") {
        mainPage.changeAppConfig(appConfig: appConfig, scopesToRequest: scopesToRequest)
    }
    
    func getUserCredentials() -> UserCredentialsData {
        return mainPage.getUserCredentials()
    }
    
    func getOAuthConfiguration() -> OAuthConfigurationData {
        return mainPage.getOAuthConfiguration()
    }
    
    func assertMainPageLoaded() {
        XCTAssert(mainPage.isShowing(), "AuthFlowTester is not loaded")
    }
    
    func checkUserCredentials(username: String, userConsumerKey: String, userRedirectUri: String, grantedScopes: String) -> UserCredentialsData {
        let userCredentials = mainPage.getUserCredentials()
        XCTAssertEqual(userCredentials.username, username)
        XCTAssertEqual(userCredentials.clientId, maskedValue(userConsumerKey))
        XCTAssertEqual(userCredentials.redirectUri, userRedirectUri)
        XCTAssertEqual(userCredentials.credentialsScopes, grantedScopes)
        return userCredentials
    }
    
    func checkOauthConfiguration(configuredConsumerKey: String, configuredCallbackUrl: String, requestedScopes: String) -> OAuthConfigurationData {
        let oauthConfiguration = mainPage.getOAuthConfiguration()
        XCTAssertEqual(oauthConfiguration.configuredConsumerKey, maskedValue(configuredConsumerKey))
        XCTAssertEqual(oauthConfiguration.configuredCallbackUrl, configuredCallbackUrl)
        XCTAssertEqual(oauthConfiguration.configuredScopes, requestedScopes == "" ? "(none)" : requestedScopes)
        return oauthConfiguration
    }
    
    func checkJwtDetails(clientId:String, scopes: String) -> JwtDetailsData? {
        guard let jwtDetails = mainPage.getJwtDetails() else {
            XCTFail("No JWT details found")
            return nil
        }
        XCTAssertEqual(jwtDetails.clientId, maskedValue(clientId))
        XCTAssertEqual(sortedScopes(jwtDetails.scopes), scopes)
        return jwtDetails
    }
    
    func assertSIDs(userCredentialsData: UserCredentialsData, useHybridFlow: Bool) {
        if (useHybridFlow) {
            if (userCredentialsData.credentialsScopes.contains("content")) {
                XCTAssertNotEqual(userCredentialsData.contentDomain, "(empty)")
                XCTAssertNotEqual(userCredentialsData.contentSid, "(empty)")
            }
            if (userCredentialsData.credentialsScopes.contains("lightning")) {
                XCTAssertNotEqual(userCredentialsData.lightningDomain, "(empty)")
                XCTAssertNotEqual(userCredentialsData.lightningSid, "(empty)")
            }
            if (userCredentialsData.credentialsScopes.contains("visualforce")) {
                XCTAssertNotEqual(userCredentialsData.vfDomain, "(empty)")
                XCTAssertNotEqual(userCredentialsData.vfSid, "(empty)")
            }
            if (userCredentialsData.credentialsScopes.contains("web")) {
                XCTAssertNotEqual(userCredentialsData.parentSid, "(empty)")
            }
        } else {
            XCTAssertEqual(userCredentialsData.contentDomain, "(empty)")
            XCTAssertEqual(userCredentialsData.contentSid, "(empty)")
            XCTAssertEqual(userCredentialsData.lightningDomain, "(empty)")
            XCTAssertEqual(userCredentialsData.lightningSid, "(empty)")
            XCTAssertEqual(userCredentialsData.vfDomain, "(empty)")
            XCTAssertEqual(userCredentialsData.vfSid, "(empty)")
            XCTAssertEqual(userCredentialsData.parentSid, "(empty)")
        }
    }
    
    func assertURLs(userCredentialsData: UserCredentialsData) {
        XCTAssertNotEqual(userCredentialsData.instanceUrl, "(empty)")
        XCTAssertTrue(userCredentialsData.identityUrl.hasSuffix(userCredentialsData.organizationId + "/" + userCredentialsData.userId))
        
        if (userCredentialsData.credentialsScopes.contains("api")) {
            XCTAssertNotEqual(userCredentialsData.apiUrl, "(empty)")
        } else {
            XCTAssertEqual(userCredentialsData.apiUrl, "(empty)")
        }

        if (userCredentialsData.credentialsScopes.contains("sfap_api")) {
            XCTAssertNotEqual(userCredentialsData.apiInstanceUrl, "(empty)")
        } else {
            XCTAssertEqual(userCredentialsData.apiInstanceUrl, "(empty)")
        }
    }
    
    func assertRestRequestWorks() {
        XCTAssert(mainPage.makeRestRequest(), "Failed to make REST request")
    }
    
    func assertRevokeWorks() {
        XCTAssert(mainPage.revokeAccessToken(), "Failed to revoke access token")
    }
    
    // MARK: - Common Test Helpers
    
    /// Returns an AppConfig for the given KnownAppName
    func getAppConfig(named name: KnownAppName) -> AppConfig {
        do {
            return try testConfig.getApp(named: name)
        } catch {
            XCTFail("Failed to get app config for \(name): \(error)")
            fatalError("Failed to get app config for \(name): \(error)")
        }
    }
    
    /// Returns the primary user config
    func getPrimaryUser() -> UserConfig {
        do {
            return try testConfig.getPrimaryUser()
        } catch {
            XCTFail("Failed to get primary user: \(error)")
            fatalError("Failed to get primary user: \(error)")
        }
    }
    
    /// Computes the expected scopes granted based on requested scopes and app config
    func expectedScopesGranted(scopesToRequest: String, appConfig: AppConfig) -> String {
        return scopesToRequest == "" ? appConfig.scopes : scopesToRequest
    }
    
    /// Performs login and validates initial state (credentials and oauth configuration)
    func loginAndValidate(
        userConfig: UserConfig,
        appConfig: AppConfig,
        scopesToRequest: String,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) -> UserCredentialsData {
        let expectedScopes = expectedScopesGranted(scopesToRequest: scopesToRequest, appConfig: appConfig)
        
        // Perform login
        login(
            userConfig: userConfig,
            appConfig: appConfig,
            scopesToRequest: scopesToRequest,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        
        // Check that app loads and shows the expected user credentials etc
        assertMainPageLoaded()
        
        let userCredentials = checkUserCredentials(
            username: userConfig.username,
            userConsumerKey: appConfig.consumerKey,
            userRedirectUri: appConfig.redirectUri,
            grantedScopes: expectedScopes
        )
        
        _ = checkOauthConfiguration(
            configuredConsumerKey: appConfig.consumerKey,
            configuredCallbackUrl: appConfig.redirectUri,
            requestedScopes: scopesToRequest
        )
        
        return userCredentials
    }
    
    /// Checks JWT details if the app is configured to issue JWTs
    func checkJwtDetailsIfApplicable(appConfig: AppConfig, scopes: String) {
        if appConfig.issuesJwt {
            _ = checkJwtDetails(
                clientId: appConfig.consumerKey,
                scopes: scopes
            )
        }
    }
    
    /// Performs revoke and refresh cycle, asserting the access token changed
    func assertRevokeAndRefreshWorks(previousCredentials: UserCredentialsData) {
        // Revoke access token
        assertRevokeWorks()
        
        let credentialsAfterRevoke = getUserCredentials()
        
        // Make REST request (which should trigger token refresh)
        assertRestRequestWorks()
        
        // Assert access token changed
        XCTAssertNotEqual(
            previousCredentials.accessToken,
            credentialsAfterRevoke.accessToken,
            "Access token should have been refreshed"
        )
    }
    
    /// Performs login, validates state, checks JWT if applicable, validates SIDs and URLs, then performs revoke/refresh cycle.
    ///
    /// - Parameters:
    ///   - appConfigName: The app configuration to use for login.
    ///   - userConfig: The user credentials. If nil, uses the primary user from test config.
    ///   - scopesToRequest: Specific scopes to request (e.g., "api id refresh_token"). Ignored if `useAllScopes` is true.
    ///   - useAllScopes: If true, requests all scopes defined in the app config. Takes precedence over `scopesToRequest`.
    ///   - useWebServerFlow: Whether to use web server flow (true) or user agent flow (false).
    ///   - useHybridFlow: Whether to use hybrid authentication flow.
    ///
    /// Scope behavior:
    /// - If `useAllScopes` is true: Uses all scopes from the app config (ignores `scopesToRequest`).
    /// - If `useAllScopes` is false and `scopesToRequest` is empty: All scopes defined server-side for the app are granted.
    /// - If `useAllScopes` is false and `scopesToRequest` is set: Only the specified scopes are granted.
    func loginAndValidateAndRevokeAndRefresh(
        appConfigName: KnownAppName,
        userConfig: UserConfig? = nil,
        scopesToRequest: String = "",
        useAllScopes: Bool = false,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let appConfig = getAppConfig(named: appConfigName)
        let resolvedUserConfig = userConfig ?? getPrimaryUser()
        let actualScopesToRequest = useAllScopes ? appConfig.scopes : scopesToRequest
        let expectedScopes = expectedScopesGranted(scopesToRequest: actualScopesToRequest, appConfig: appConfig)
        
        // Login and validate initial state
        let userCredentials = loginAndValidate(
            userConfig: resolvedUserConfig,
            appConfig: appConfig,
            scopesToRequest: actualScopesToRequest,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        
        // Check JWT if applicable
        checkJwtDetailsIfApplicable(appConfig: appConfig, scopes: expectedScopes)
        
        // Additional login-specific validations
        assertSIDs(userCredentialsData: userCredentials, useHybridFlow: useHybridFlow)
        assertURLs(userCredentialsData: userCredentials)
        
        // Revoke and refresh cycle
        assertRevokeAndRefreshWorks(previousCredentials: userCredentials)
    }
    
    /// Performs login, migration, validates state, checks JWT if applicable, then performs revoke/refresh cycle
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
        let expectedMigratedScopes = expectedScopesGranted(scopesToRequest: migrationScopesToRequest, appConfig: migrationAppConfig)
        
        // Login and validate initial state
        let initialUserCredentials = loginAndValidate(
            userConfig: resolvedUserConfig,
            appConfig: initialAppConfig,
            scopesToRequest: initialScopesToRequest
        )
        
        // Migrate refresh token
        changeAppConfig(appConfig: migrationAppConfig, scopesToRequest: migrationScopesToRequest)

        // Check that app loads after migration
        assertMainPageLoaded()

        // Check the migrated user credentials
        let migratedUserCredentials = checkUserCredentials(
            username: resolvedUserConfig.username,
            userConsumerKey: migrationAppConfig.consumerKey,
            userRedirectUri: migrationAppConfig.redirectUri,
            grantedScopes: expectedMigratedScopes
        )
        
        // Check JWT if applicable
        checkJwtDetailsIfApplicable(appConfig: migrationAppConfig, scopes: expectedMigratedScopes)
        
        // The app auth config should NOT have changed (still using initial config)
        _ = checkOauthConfiguration(
            configuredConsumerKey: initialAppConfig.consumerKey,
            configuredCallbackUrl: initialAppConfig.redirectUri,
            requestedScopes: initialScopesToRequest
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
    
    private func maskedValue(_ value: String) -> String {
        let firstFive = value.prefix(5)
        let lastFive = value.suffix(5)
        return "\(firstFive)...\(lastFive)"
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

