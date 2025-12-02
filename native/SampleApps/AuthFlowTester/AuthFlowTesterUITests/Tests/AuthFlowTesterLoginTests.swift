/*
 AuthFlowTesterLoginTests.swift
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

class AuthFlowTesterLoginTests: BaseAuthFlowTesterTest {
    
    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    private func loginValidateAndRevokeAndRefresh(
        userConfig: UserConfig,
        appConfig: AppConfig,
        scopesToRequest: String,
        useWebServerFlow: Bool = true,
        useHybridFlow: Bool = true
    ) {
        let expectedScopesGranted = scopesToRequest == "" ? appConfig.scopes : scopesToRequest
        
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
        
        assertUserCredentials(
            username: userConfig.username,
            userConsumerKey: appConfig.consumerKey,
            userRedirectUri: appConfig.consumerKey,
            grantedScopes: expectedScopesGranted
        )
        
        assertOauthConfiguration(
            configuredConsumerKey: appConfig.consumerKey,
            configuredCallbackUrl: appConfig.redirectUri,
            requestedScopes: scopesToRequest
        )
        
        if (appConfig.issuesJwt) {
            assertJwtDetails(
                clientId: appConfig.consumerKey,
                scopes: expectedScopesGranted
            )
        }
        
        // Attempting revoke / refresh
//        let accessTokenBeforeRevoke = mainPage.getUserCredentials().accessToken
        
        assertRevokeWorks()
        
//        let accessTokenAfterRevoke = mainPage.getUserCredentials().accessToken
        
//        XCTAssertNotEqual(accessTokenBeforeRevoke, accessTokenAfterRevoke, "Access token should have been refreshed")
        
        assertRestRequestWorks()
    }
    
    // MARK: - ECA Basic Opaque Tests
    
    func testECABasicOpaque_EmptyScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicOpaque()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECABasicOpaque_EmptyScopes_UserAgentFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicOpaque()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "",
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    func testECABasicOpaque_AllScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicOpaque()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: app.scopes,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECABasicOpaque_AllScopes_UserAgentFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicOpaque()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: app.scopes,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - ECA Basic JWT Tests
    
    func testECABasicJwt_EmptyScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECABasicJwt_EmptyScopes_UserAgentFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "",
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    func testECABasicJwt_AllScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: app.scopes,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECABasicJwt_AllScopes_UserAgentFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECABasicJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: app.scopes,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - ECA Advanced JWT Tests
    
    func testECAAdvancedJwt_EmptyScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECAAdvancedJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECAAdvancedJwt_ApiIdRefreshScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECAAdvancedJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: "api id refresh_token",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    func testECAAdvancedJwt_AllScopes_WebServerFlow() throws {
        let user = try testConfig.getPrimaryUser()
        let app = try testConfig.getECAAdvancedJwt()
        
        loginValidateAndRevokeAndRefresh(
            userConfig: user,
            appConfig: app,
            scopesToRequest: app.scopes,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }

}

