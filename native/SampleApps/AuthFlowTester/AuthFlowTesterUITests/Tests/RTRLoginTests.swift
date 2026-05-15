/*
 RTRLoginTests.swift
 AuthFlowTesterUITests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/// Tests for login flows using External Client App (ECA) configurations with Refresh Token Rotation (RTR).
///
/// NB: Tests use the first user from ui_test_config.json
///
class RTRLoginTests: BaseAuthFlowTester {

    // MARK: - ECA JWT RTR Tests

    /// Login with ECA JWT RTR using hybrid flow.
    func testECAJwtRtr_Hybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
    }

    /// Login with ECA JWT RTR using hybrid flow, restart app, and verify session persists.
    func testECAJwtRtr_Hybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr)
        restartAndValidateUser(userAppConfigName: .ecaJwtRtr)
    }

    /// Login with ECA JWT RTR without hybrid flow.
    func testECAJwtRtr_NoHybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr, useHybridFlow: false)
    }

    /// Login with ECA JWT RTR without hybrid flow, restart app, and verify session persists.
    func testECAJwtRtr_NoHybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaJwtRtr, useHybridFlow: false)
        restartAndValidateUser(userAppConfigName: .ecaJwtRtr, useHybridFlow: false)
    }

    // MARK: - ECA Opaque RTR Tests

    /// Login with ECA Opaque RTR using hybrid flow.
    func testECAOpaqueRtr_Hybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr)
    }

    /// Login with ECA Opaque RTR using hybrid flow, restart app, and verify session persists.
    func testECAOpaqueRtr_Hybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr)
        restartAndValidateUser(userAppConfigName: .ecaOpaqueRtr)
    }

    /// Login with ECA Opaque RTR without hybrid flow.
    func testECAOpaqueRtr_NoHybrid() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
    }

    /// Login with ECA Opaque RTR without hybrid flow, restart app, and verify session persists.
    func testECAOpaqueRtr_NoHybrid_WithRestart() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
        restartAndValidateUser(userAppConfigName: .ecaOpaqueRtr, useHybridFlow: false)
    }
}
