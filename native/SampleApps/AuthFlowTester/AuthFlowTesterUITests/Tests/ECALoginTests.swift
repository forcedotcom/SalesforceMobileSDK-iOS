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
class ECALoginTests: BaseAuthFlowTesterTest {
    
    // MARK: - ECA Opaque Tests
    
    /// Login with ECA advanced opaque using default scopes and web server flow.
    func testECAAdvancedOpaque_DefaultScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
    }
    
    /// Login with ECA advanced opaque using specific api/id/refresh scopes.
    func testECAAdvancedOpaque_SubsetScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedOpaque, scopesToRequest: "api id refresh_token")
    }
    
    /// Login with ECA advanced opaque using all scopes and web server flow.
    func testECAAdvancedOpaque_AllScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedOpaque, useAllScopes: true)
    }
    
    // MARK: - ECA JWT Tests
    
    /// Login with ECA advanced JWT using default scopes and web server flow.
    func testECAAdvancedJwt_DefaultScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedJwt)
    }
    
    /// Login with ECA advanced JWT using specific api/id/refresh scopes.
    func testECAAdvancedJwt_SubsetScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedJwt, scopesToRequest: "api id refresh_token")
    }
    
    /// Login with ECA advanced JWT using all scopes and web server flow.
    func testECAAdvancedJwt_AllScopes() throws {
        loginAndValidate(staticAppConfigName: .ecaAdvancedJwt, useAllScopes: true)
    }
}
