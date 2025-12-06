/*
 BeaconLoginTests.swift
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

/// Tests for login flows using Beacon app configurations.
/// Beacon apps are lightweight authentication apps for specific use cases.
class BeaconLoginTests: BaseAuthFlowTesterTest {
    
    // MARK: - Beacon Basic Opaque Tests
    
    /// Login with Beacon basic opaque using default scopes and web server flow.
    func testBeaconBasicOpaque_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon basic opaque using default scopes and user agent flow.
    func testBeaconBasicOpaque_DefaultScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }

    /// Login with Beacon basic opaque using all scopes, web server flow, without hybrid auth.
    func testBeaconBasicOpaque_AllScopes_WebServerFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: false
        )
    }
    
    /// Login with Beacon basic opaque using all scopes, user agent flow, without hybrid auth.
    func testBeaconBasicOpaque_AllScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: false
        )
    }
    
    /// Login with Beacon basic opaque using all scopes and web server flow.
    func testBeaconBasicOpaque_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon basic opaque using all scopes and user agent flow.
    func testBeaconBasicOpaque_AllScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - Beacon Basic JWT Tests
    
    /// Login with Beacon basic JWT using default scopes and web server flow.
    func testBeaconBasicJwt_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon basic JWT using all scopes and web server flow.
    func testBeaconBasicJwt_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicJwt,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    // MARK: - Beacon Advanced Opaque Tests
    
    /// Login with Beacon advanced opaque using default scopes and web server flow.
    func testBeaconAdvancedOpaque_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon advanced opaque using default scopes and user agent flow.
    func testBeaconAdvancedOpaque_DefaultScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon advanced opaque using all scopes, web server flow, without hybrid auth.
    func testBeaconAdvancedOpaque_AllScopes_WebServerFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: false
        )
    }
    
    /// Login with Beacon advanced opaque using all scopes, user agent flow, without hybrid auth.
    func testBeaconAdvancedOpaque_AllScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: false
        )
    }
    
    /// Login with Beacon advanced opaque using all scopes and web server flow.
    func testBeaconAdvancedOpaque_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon advanced opaque using all scopes and user agent flow.
    func testBeaconAdvancedOpaque_AllScopes_UserAgentFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedOpaque,
            useAllScopes: true,
            useWebServerFlow: false,
            useHybridFlow: true
        )
    }
    
    // MARK: - Beacon Advanced JWT Tests
    
    /// Login with Beacon advanced JWT using default scopes and web server flow.
    func testBeaconAdvancedJwt_DefaultScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon advanced JWT using specific api/id/refresh scopes.
    func testBeaconAdvancedJwt_ApiIdRefreshScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedJwt,
            scopesToRequest: "api id refresh_token",
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    /// Login with Beacon advanced JWT using all scopes and web server flow.
    func testBeaconAdvancedJwt_AllScopes_WebServerFlow() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconAdvancedJwt,
            useAllScopes: true,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }
    
    // MARK: - Beacon Tests Using Dynamic App Configuration with an App Restart
    func testBeaconDynamicConfiguration_Restart() throws {
        loginAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicJwt,
            dynamicAppConfigName: .beaconAdvancedJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
        restartAndValidateAndRevokeAndRefresh(
            staticAppConfigName: .beaconBasicJwt,
            dynamicAppConfigName: .beaconAdvancedJwt,
            useWebServerFlow: true,
            useHybridFlow: true
        )
    }

}
