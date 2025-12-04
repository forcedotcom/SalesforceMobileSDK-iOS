/*
 CALoginTests.swift
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

/// Tests for login flows using Connected App (CA) configurations.
/// CA apps are traditional OAuth connected apps created in Salesforce Setup.
class CALoginTests: BaseAuthFlowTesterTest {

    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }

    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    // MARK: - CA Basic Opaque Tests
    
    /// Login with CA basic opaque using default scopes and web server flow.
    func testCABasicOpaque_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA basic opaque using default scopes and user agent flow.
    func testCABasicOpaque_DefaultScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }

    /// Login with CA basic opaque using all scopes, web server flow, without hybrid auth.
    func testCABasicOpaque_AllScopes_WebServerFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: false
        )
    }
    
    /// Login with CA basic opaque using all scopes, user agent flow, without hybrid auth.
    func testCABasicOpaque_AllScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: false
        )
    }
    
    /// Login with CA basic opaque using all scopes and web server flow.
    func testCABasicOpaque_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA basic opaque using all scopes and user agent flow.
    func testCABasicOpaque_AllScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - CA Basic JWT Tests
    
    /// Login with CA basic JWT using default scopes and web server flow.
    func testCABasicJwt_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA basic JWT using all scopes and web server flow.
    func testCABasicJwt_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caBasicJwt,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    // MARK: - CA Advanced Opaque Tests
    
    /// Login with CA advanced opaque using default scopes and web server flow.
    func testCAAdvancedOpaque_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA advanced opaque using default scopes and user agent flow.
    func testCAAdvancedOpaque_DefaultScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    /// Login with CA advanced opaque using all scopes, web server flow, without hybrid auth.
    func testCAAdvancedOpaque_AllScopes_WebServerFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: false
        )
    }
    
    /// Login with CA advanced opaque using all scopes, user agent flow, without hybrid auth.
    func testCAAdvancedOpaque_AllScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: false
        )
    }
    
    /// Login with CA advanced opaque using all scopes and web server flow.
    func testCAAdvancedOpaque_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA advanced opaque using all scopes and user agent flow.
    func testCAAdvancedOpaque_AllScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - CA Advanced JWT Tests
    
    /// Login with CA advanced JWT using default scopes and web server flow.
    func testCAAdvancedJwt_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA advanced JWT using specific api/id/refresh scopes.
    func testCAAdvancedJwt_ApiIdRefreshScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedJwt,
            scopesToRequest: "api id refresh_token",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with CA advanced JWT using all scopes and web server flow.
    func testCAAdvancedJwt_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            appConfigName: .caAdvancedJwt,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }

}
