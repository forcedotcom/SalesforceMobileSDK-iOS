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
/// NB: Tests use the first user from test_config.json
///
class ECALoginTests: BaseAuthFlowTesterTest {
    
    // MARK: - ECA Opaque Tests
    
    /// Login with ECA advanced opaque using default scopes and web server flow.
    func testECAAdvancedOpaque_DefaultScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
    }
    
    /// Login with ECA advanced opaque using subset of scopes and web server flow.
    func testECAAdvancedOpaque_SubsetScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque, staticScopeSelection: .subset)
    }
    
    /// Login with ECA advanced opaque using all scopes and web server flow.
    func testECAAdvancedOpaque_AllScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque, staticScopeSelection: .all)
    }
    
    // MARK: - ECA JWT Tests
    
    /// Login with ECA advanced JWT using default scopes and web server flow.
    func testECAAdvancedJwt_DefaultScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedJwt)
    }
    
    /// Login with ECA advanced JWT using subset of scopes and web server flow.
    func testECAAdvancedJwt_SubsetScopes_NotHybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedJwt, staticScopeSelection: .subset)
    }
    
    /// Login with ECA advanced JWT using all scopes and web server flow.
    func testECAAdvancedJwt_AllScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedJwt, staticScopeSelection: .all)
    }
    
    // MARK: - Using dynamic config
    
    /// Login with ECA advanced JWT using default scopes and web server flow provided as dynamic configuration.
    /// Restart the application and validate it still works afterwards
    func testECAAdvancedJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaAdvancedOpaque,
            dynamicAppConfigName: .ecaAdvancedJwt
        )
        restartAndValidate(
            userAppConfigName: .ecaAdvancedJwt
        )
    }

    /// Login with ECA advanced JWT using subset of scopes and web server flow provided as dynamic configuration.
    /// Restart the application and validate it still works afterwards
    func testECAAdvancedJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaAdvancedOpaque,
            dynamicAppConfigName: .ecaAdvancedJwt,
            dynamicScopeSelection: .subset)
        restartAndValidate(
            userAppConfigName: .ecaAdvancedJwt,
            userScopeSelection: .subset
        )
    }
}
