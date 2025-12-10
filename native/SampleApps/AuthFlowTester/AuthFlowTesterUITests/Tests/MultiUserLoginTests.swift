/*
 MultiUserLoginTests.swift
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

/// Tests for multi-user login scenarios.
/// Tests login with two users using various configurations:
/// - Static vs dynamic app configuration
/// - Same or different app types (opaque vs JWT)
/// - Same or different scopes
class MultiUserLoginTests: BaseAuthFlowTesterTest {
    
    // MARK: - Both Users Static Config
    
    /// Both users use static config, same app type (opaque), same scopes (default).
    func testBothStatic_SameApp_SameScopes() throws {
        // First user
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Second user
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque)
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedOpaque)
        
        logout()
    }
    
    /// Both users use static config, different app types (opaque + jwt), same scopes (default).
    func testBothStatic_DifferentApps() throws {
        // First user with opaque
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Second user with jwt
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedJwt)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque)
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedJwt)
        
        logout()
    }
    
    /// Both users use static config, same app type, different scopes (first subset, second default).
    func testBothStatic_SameApp_DifferentScopes() throws {
        // First user with subset scopes
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque, scopesToRequest: "api id refresh_token")
        
        // Second user with default scopes
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque, requestedScopes: "api id refresh_token")
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedOpaque)
        
        logout()
    }
    
    // MARK: - Mixed Static/Dynamic Config
    
    /// First user static config, second user dynamic config, different apps, same scopes (default).
    func testFirstStatic_SecondDynamic_DifferentApps() throws {
        // First user with static config
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Second user with dynamic config
        loginOtherUserAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedJwt)
        
        // Restart to verify persistence
        restartAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque)
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedJwt, staticAppConfigName: .ecaBasicOpaque)
        
        logout()
    }
    
    /// First user dynamic config, second user static config, different apps, same scopes (default).
    func testFirstDynamic_SecondStatic_DifferentApps() throws {
        // First user with dynamic config
        launchLoginAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedOpaque)
        
        // Second user with static config
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedJwt)
        
        // Restart to verify persistence
        restartAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque, staticAppConfigName: .ecaBasicOpaque)
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedJwt)
        
        logout()
    }
    
    // MARK: - Both Users Dynamic Config
    
    /// Both users use dynamic config, different apps, same scopes (default).
    func testBothDynamic_DifferentApps() throws {
        // First user with dynamic config
        launchLoginAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedOpaque)
        
        // Second user with dynamic config
        loginOtherUserAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedJwt)
        
        // Restart to verify persistence
        restartAndValidate(staticAppConfigName: .ecaBasicOpaque, dynamicAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUser(.first)
        validate(appConfigName: .ecaAdvancedOpaque, staticAppConfigName: .ecaBasicOpaque)
        
        // Validate second user
        switchToUser(.second)
        validate(user: .second, appConfigName: .ecaAdvancedJwt, staticAppConfigName: .ecaBasicOpaque)
        
        logout()
    }
}
