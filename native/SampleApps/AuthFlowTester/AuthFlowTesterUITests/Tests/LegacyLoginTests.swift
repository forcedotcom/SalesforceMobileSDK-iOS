/*
 LegacyLoginTests.swift
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

/// Tests for legacy login flows including:
/// - Connected App (CA) configurations (traditional OAuth connected apps)
/// - User agent flow tests
/// - Non-hybrid flow tests
class LegacyLoginTests: BaseAuthFlowTesterTest {

    // MARK: - CA Web Server Flow Tests
    
    /// Login with CA advanced opaque using default scopes and web server flow.
    func testCAAdvancedOpaque_DefaultScopes_WebServerFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque)
    }
    
    /// Login with CA advanced opaque using specific api/id/refresh scopes and web server flow.
    func testCAAdvancedOpaque_SubsetScopes_WebServerFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, scopesToRequest: "api id refresh_token")
    }

    /// Login with CA advanced opaque using all scopes and web server flow.
    func testCAAdvancedOpaque_AllScopes_WebServerFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, useAllScopes: true)
    }
    
    // MARK: - CA User Agent Flow Tests
    
    /// Login with CA advanced opaque using default scopes and user agent  flow.
    func testCAAdvancedOpaque_DefaultScopes_UserAgentFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, useWebServerFlow: false)
    }
    
    /// Login with CA advanced opaque using specific api/id/refresh scopes and user agent flow.
    func testCAAdvancedOpaque_SubsetScopes_UserAgentFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, scopesToRequest: "api id refresh_token", useWebServerFlow: false)
    }

    /// Login with CA advanced opaque using all scopes and user agent flow.
    func testCAAdvancedOpaque_AllScopes_UserAgentFlow() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, useAllScopes: true, useWebServerFlow: false)
    }
    
    // MARK: - CA User Agent Flow Not Hybrid Tests
    
    /// Login with CA advanced opaque using default scopes and user agent  flow / not hybrid.
    func testCAAdvancedOpaque_DefaultScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, useWebServerFlow: false, useHybridFlow: false)
    }
    
    /// Login with CA advanced opaque using specific api/id/refresh scopes and user agent flow / not hybrid.
    func testCAAdvancedOpaque_SubsetScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, scopesToRequest: "api id refresh_token", useWebServerFlow: false, useHybridFlow: false)
    }

    /// Login with CA advanced opaque using all scopes and user agent flow / not hybrid.
    func testCAAdvancedOpaque_AllScopes_UserAgentFlow_NotHybrid() throws {
        loginAndValidate(staticAppConfigName: .caAdvancedOpaque, useAllScopes: true, useWebServerFlow: false, useHybridFlow: false)
    }
}

