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
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedOpaque)
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedOpaque)
        
        // Logout second user
        logout()
    }
    
    /// Both users use static config, different app types (opaque + jwt), same scopes (default).
    func testBothStatic_DifferentApps() throws {
        // First user
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Second user
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedJwt)
        
        // Validate first user
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaAdvancedJwt, // static config overwritten
            userAppConfigName: .ecaAdvancedOpaque)
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaAdvancedJwt,
            userAppConfigName: .ecaAdvancedJwt)

        // Logout second user
        logout()
    }
    
    /// Both users use static config, same app type, different scopes (first subset, second default).
    func testBothStatic_SameApp_DifferentScopes() throws {
        // First user
        launchLoginAndValidate(
            staticAppConfigName: .ecaAdvancedOpaque,
            staticScopeSelection: .subset
        )
        
        // Second user
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaAdvancedOpaque,
            staticScopeSelection: .empty,
            userAppConfigName: .ecaAdvancedOpaque,
            userScopeSelection: .subset
        )
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaAdvancedOpaque,
            staticScopeSelection: .empty,
            userAppConfigName: .ecaAdvancedOpaque,
            userScopeSelection: .empty
        )

        // Logout second user
        logout()
    }
    
    // MARK: - Mixed Static/Dynamic Config
    
    /// First user static config, second user dynamic config, different apps, same scopes (default).
    func testFirstStatic_SecondDynamic_DifferentApps() throws {
        // First user
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Second user
        loginOtherUserAndValidate(
            staticAppConfigName: .ecaAdvancedOpaque,
            dynamicAppConfigName: .ecaAdvancedJwt
        )
        
        // Validate first user
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedOpaque
        )
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedJwt,
        )
        
        // Logout second user
        logout()
    }
    
    /// First user dynamic config, second user static config, different apps, same scopes (default).
    func testFirstDynamic_SecondStatic_DifferentApps() throws {
        // First user
        launchLoginAndValidate(
            staticAppConfigName: .ecaBasicOpaque,
            dynamicAppConfigName: .ecaAdvancedJwt
        )
        
        // Second user
        loginOtherUserAndValidate(staticAppConfigName: .ecaAdvancedOpaque)
        
        // Validate first user
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedJwt
        )
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaAdvancedOpaque,
            userAppConfigName: .ecaAdvancedOpaque,
        )
        
        // Logout second user
        logout()
    }
    
    // MARK: - Both Users Dynamic Config
    
    /// Both users use dynamic config, different apps, same scopes (default).
    func testBothDynamic_DifferentApps() throws {
        // First user
        launchLoginAndValidate(
            staticAppConfigName: .ecaBasicOpaque,
            dynamicAppConfigName: .ecaAdvancedOpaque
        )
        
        // Second user
        loginOtherUserAndValidate(
            staticAppConfigName: .ecaBasicOpaque,
            dynamicAppConfigName: .ecaAdvancedJwt
        )

        // Validate first user
        switchToUserAndValidate(
            user: .first,
            staticAppConfigName: .ecaBasicOpaque,
            userAppConfigName: .ecaAdvancedOpaque
        )
        
        // Validate second user
        switchToUserAndValidate(
            user: .second,
            staticAppConfigName: .ecaBasicOpaque,
            userAppConfigName: .ecaAdvancedJwt,
        )
        
        // Logout second user
        logout()
    }
}
