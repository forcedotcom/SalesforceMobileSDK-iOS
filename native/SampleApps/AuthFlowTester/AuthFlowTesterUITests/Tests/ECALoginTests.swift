/*
 ECALoginTests.swift
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

/// Tests for login flows using External Client App (ECA) configurations.
/// ECA apps are first-party Salesforce apps that use enhanced authentication flows.
///
/// NB: Tests use the first user from ui_test_config.json
///
class ECALoginTests: BaseAuthFlowTester {
    
    // MARK: - ECA Opaque Tests
    
    /// Login with ECA opaque using default scopes and web server flow.
    func testECAOpaque_DefaultScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaque)
    }
    
    /// Login with ECA opaque using subset of scopes and web server flow.
    func testECAOpaque_SubsetScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaque, staticScopeSelection: .subset)
    }
    
    /// Login with ECA opaque using all scopes and web server flow.
    func testECAOpaque_AllScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaque, staticScopeSelection: .all)
    }
    
    // MARK: - ECA JWT Tests
    
    /// Login with ECA JWT using default scopes and web server flow.
    func testECAJwt_DefaultScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwt)
    }
    
    /// Login with ECA JWT using subset of scopes and web server flow.
    func testECAJwt_SubsetScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwt, staticScopeSelection: .subset)
    }
    
    /// Login with ECA JWT using all scopes and web server flow.
    func testECAJwt_AllScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwt, staticScopeSelection: .all)
    }
    
    // MARK: - Negative testing
    
    /// Login with invalid client id in dynamic configuration
    func testDynamicConfigurationWithInvalidClientId() throws {
        // forceAdvancedAuthentication must be false: the invalid-client-id error is rendered by the
        // server inside the WKWebView; ASWebAuthenticationSession runs in a separate process that
        // XCTest cannot inspect, so the error is never visible under advanced auth.
        launchAndLogin(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaOpaque, dynamicAppConfigName: .invalid, forceAdvancedAuthentication: false)
    }
    
    /// Login with invalid scope in dynamic configuration
    func testDynamicConfigurationWithInvalidScope() throws {
        launchAndLogin(loginHost: .regularAuth, user: .first, staticAppConfigName: .ecaOpaque, dynamicAppConfigName: .ecaJwt, dynamicScopeSelection: .invalid)
    }

}
