/*
 DynamicConfigLoginTests.swift
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

/// Tests for login flows using dynamic (runtime-selected) app configuration.
/// Covers CA, ECA, and Beacon configs with dynamic config selection and restart validation.
class DynamicConfigLoginTests: BaseAuthFlowTester {

    // MARK: - CA Dynamic Configuration

    /// Login with CA JWT using default scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testCAJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .caOpaque,
            dynamicAppConfigName: .caJwt
        )
        restartAndValidate(
            userAppConfigName: .caJwt
        )
    }

    /// Login with CA JWT using subset of scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testCAJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .caOpaque,
            dynamicAppConfigName: .caJwt,
            dynamicScopeSelection: .subset)
        restartAndValidate(
            userAppConfigName: .caJwt,
            userScopeSelection: .subset
        )
    }

    // MARK: - ECA Dynamic Configuration

    /// Login with ECA JWT using default scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt
        )
        restartAndValidate(
            userAppConfigName: .ecaJwt
        )
    }

    /// Login with ECA JWT using subset of scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaOpaque,
            dynamicAppConfigName: .ecaJwt,
            dynamicScopeSelection: .subset)
        restartAndValidate(
            userAppConfigName: .ecaJwt,
            userScopeSelection: .subset
        )
    }

    // MARK: - Beacon Dynamic Configuration

    /// Login with Beacon JWT using default scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconOpaque,
            dynamicAppConfigName: .beaconJwt
        )
        restartAndValidate(
            loginHost: .regularAuth,
            userAppConfigName: .beaconJwt
        )
    }

    /// Login with Beacon JWT using subset of scopes and web server flow provided as dynamic configuration. Restart and validate.
    func testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart() throws {
        launchLoginAndValidate(
            loginHost: .regularAuth,
            staticAppConfigName: .beaconOpaque,
            dynamicAppConfigName: .beaconJwt,
            dynamicScopeSelection: .subset
        )
        restartAndValidate(
            loginHost: .regularAuth,
            userAppConfigName: .beaconJwt,
            userScopeSelection: .subset
        )
    }
}
