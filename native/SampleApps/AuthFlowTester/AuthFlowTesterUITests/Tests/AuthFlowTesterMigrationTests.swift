/*
 AuthFlowTesterMigrationTests.swift
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

class AuthFlowTesterMigrationTests: BaseAuthFlowTesterTest {
    
    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    private func loginAndMigrateAndValidateAndRevokeAndRefresh(
        userConfig: UserConfig,
        initialAppConfig: AppConfig,
        initialScopesToRequest: String,
        migrationAppConfig: AppConfig,
        migrationScopesToRequest: String
    ) {
        let expectedMigratedScopes = expectedScopesGranted(scopesToRequest: migrationScopesToRequest, appConfig: migrationAppConfig)
        
        // Login and validate initial state
        let initialUserCredentials = loginAndValidate(
            userConfig: userConfig,
            appConfig: initialAppConfig,
            scopesToRequest: initialScopesToRequest
        )
        
        // Migrate refresh token
        changeAppConfig(appConfig: migrationAppConfig, scopesToRequest: migrationScopesToRequest)

        // Check that app loads after migration
        assertMainPageLoaded()

        // Check the migrated user credentials
        let migratedUserCredentials = checkUserCredentials(
            username: userConfig.username,
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
    
    // MARK: - ECA Basic Opaque to ECA Basic JWT
    
    func testMigrateECABasicOpaqueToECABasicJwt_DefaultScopes() throws {
        let userConfig = try testConfig.getPrimaryUser()
        let initialAppConfig = try testConfig.getECABasicOpaque()
        let migrationAppConfig = try testConfig.getECABasicJwt()
        
        loginAndMigrateAndValidateAndRevokeAndRefresh(
            userConfig: userConfig,
            initialAppConfig: initialAppConfig,
            initialScopesToRequest: "api id refresh_token",
            migrationAppConfig: migrationAppConfig,
            migrationScopesToRequest: ""
        )
    }
    
    // MARK: - ECA Basic JWT to ECA Advanced JWT
    
    func testMigrateECABasicJwtToECAAdvancedJwt_DefaultScopes() throws {
        let userConfig = try testConfig.getPrimaryUser()
        let initialAppConfig = try testConfig.getECABasicJwt()
        let migrationAppConfig = try testConfig.getECAAdvancedJwt()
        
        loginAndMigrateAndValidateAndRevokeAndRefresh(
            userConfig: userConfig,
            initialAppConfig: initialAppConfig,
            initialScopesToRequest: "api id refresh_token",
            migrationAppConfig: migrationAppConfig,
            migrationScopesToRequest: ""
        )
    }
    
    // MARK: - ECA Advanced JWT to ECA Advanced JWT (same app, different scopes)

    func testMigrateECAAdvancedJwtToECAAdvancedJwt_SpecificScopes() throws {
        let userConfig = try testConfig.getPrimaryUser()
        let appConfig = try testConfig.getECAAdvancedJwt()
        
        loginAndMigrateAndValidateAndRevokeAndRefresh(
            userConfig: userConfig,
            initialAppConfig: appConfig,
            initialScopesToRequest: "api id refresh_token",
            migrationAppConfig: appConfig,
            migrationScopesToRequest: "api id refresh_token sfap_api"
        )
    }

    
    func testMigrateECAAdvancedJwtToECAAdvancedJwt_DefaultScopes() throws {
        let userConfig = try testConfig.getPrimaryUser()
        let appConfig = try testConfig.getECAAdvancedJwt()
        
        loginAndMigrateAndValidateAndRevokeAndRefresh(
            userConfig: userConfig,
            initialAppConfig: appConfig,
            initialScopesToRequest: "api id refresh_token",
            migrationAppConfig: appConfig,
            migrationScopesToRequest: ""
        )
    }
    
}
