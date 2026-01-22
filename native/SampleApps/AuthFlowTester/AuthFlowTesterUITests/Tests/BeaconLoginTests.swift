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
///
/// NB: Tests use the first user from ui_test_config.json
///
class BeaconLoginTests: BaseAuthFlowTesterTest {
    
    // MARK: - Login Host Configuration
    
    /// Returns the login host configuration to use for tests.
    /// Subclasses can override this to use a different login host.
    func loginHostConfig() -> KnownLoginHostConfig {
        return .regularAuth
    }
    
    // MARK: - Beacon Opaque Tests
    
    /// Login with Beacon advanced opaque using default scopes and web server flow.
    func testBeaconAdvancedOpaque_DefaultScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedOpaque)
    }
    
    /// Login with Beacon advanced opaque using subset of scopes and web server flow.
    func testBeaconAdvancedOpaque_SubsetScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedOpaque, staticScopeSelection: .subset)
    }
        
    /// Login with Beacon advanced opaque using all scopes and web server flow.
    func testBeaconAdvancedOpaque_AllScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedOpaque, staticScopeSelection: .all)
    }
    
    // MARK: - Beacon JWT Tests
    
    /// Login with Beacon advanced JWT using default scopes and web server flow.
    func testBeaconAdvancedJwt_DefaultScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedJwt)
    }
    
    /// Login with Beacon advanced JWT using subset of scopes and web server flow.
    func testBeaconAdvancedJwt_SubsetScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedJwt, staticScopeSelection: .subset)
    }
    
    /// Login with Beacon advanced JWT using all scopes and web server flow.
    func testBeaconAdvancedJwt_AllScopes() throws {
        launchLoginAndValidate(loginHost: loginHostConfig(), staticAppConfigName: .beaconAdvancedJwt, staticScopeSelection: .all)
    }
    
    // MARK: - Using dynamic config
    
    /// Login with Beacon advanced JWT using default scopes and web server flow provided as dynamic configuration.
    /// Restart the application and validate it still works afterwards
    func testBeaconAdvancedJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: loginHostConfig(),
            staticAppConfigName: .beaconAdvancedOpaque,
            dynamicAppConfigName: .beaconAdvancedJwt
        )
        restartAndValidate(
            loginHost: loginHostConfig(),
            userAppConfigName: .beaconAdvancedJwt
        )
    }

    /// Login with Beacon advanced JWT using subset of scopes and web server flow provided as dynamic configuration.
    /// Restart the application and validate it still works afterwards
    func testBeaconAdvancedJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: loginHostConfig(),
            staticAppConfigName: .beaconAdvancedOpaque,
            dynamicAppConfigName: .beaconAdvancedJwt,
            dynamicScopeSelection: .subset
        )
        restartAndValidate(
            loginHost: loginHostConfig(),
            userAppConfigName: .beaconAdvancedJwt,
            userScopeSelection: .subset
        )
    }
}
