/*
 MigrationTests.swift
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

/// Tests for migrating refresh tokens between different app configurations.
/// These tests verify that users can seamlessly transition between app types
/// (CA, ECA, Beacon) and token formats (opaque, JWT) without re-authentication.
class MigrationTests: BaseAuthFlowTesterTest {
    
    override func tearDown() {
        logout()
        super.tearDown()
    }
    
    // MARK: - ECA Migrations (within same app type)
    
    /// Migrate from ECA basic opaque to ECA basic JWT token format.
    func testMigrateECA_BasicOpaqueToBasicJwt() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaBasicOpaque)
        migrateAndValidate(
            staticAppConfigName: .ecaBasicOpaque,
            migrationAppConfigName: .ecaBasicJwt
        )
    }
    
    /// Migrate within same ECA advanced JWT app (scope upgrade).
    func testMigrateECA_AdvancedJwtToAdvancedJwt_WithMoreScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .ecaAdvancedJwt, staticScopeSelection: .subset)
        migrateAndValidate(
            staticAppConfigName: .ecaAdvancedJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .ecaAdvancedJwt
        )
    }

    // MARK: - Beacon Migrations (within same app type)
    
    /// Migrate from Beacon basic opaque to Beacon basic JWT token format.
    func testMigrateBeacon_BasicOpaqueToBasicJwt() throws {
        launchLoginAndValidate(staticAppConfigName: .beaconBasicOpaque)
        migrateAndValidate(
            staticAppConfigName: .beaconBasicOpaque,
            migrationAppConfigName: .beaconBasicJwt
        )
    }
    
    /// Migrate within same Beacon advanced JWT app (scope upgrade).
    func testMigrateBeacon_AdvancedJwtToAdvancedJwt_WithMoreScopes() throws {
        launchLoginAndValidate(staticAppConfigName: .beaconAdvancedJwt, staticScopeSelection: .subset)
        migrateAndValidate(
            staticAppConfigName: .beaconAdvancedJwt,
            staticScopeSelection: .subset,
            migrationAppConfigName: .beaconAdvancedJwt
        )
    }
    
    // MARK: - Cross-App Type Migrations
    
    /// Migrate from CA advanced opaque to ECA advanced opaque (app type change).
    func testMigrateCAToECA_AdvancedOpaqueToAdvancedOpaque() throws {
        launchLoginAndValidate(staticAppConfigName: .caAdvancedOpaque)
        migrateAndValidate(
            staticAppConfigName: .caAdvancedOpaque,
            migrationAppConfigName: .ecaAdvancedOpaque
        )
    }
    
    /// Migrate from CA advanced opaque to Beacon advanced opaque (app type change).
    func testMigrateCAToBeacon_AdvancedOpaqueToAdvancedOpaque() throws {
        launchLoginAndValidate(staticAppConfigName: .caAdvancedOpaque)
        migrateAndValidate(
            staticAppConfigName: .caAdvancedOpaque,
            migrationAppConfigName: .beaconAdvancedOpaque
        )
    }
}

