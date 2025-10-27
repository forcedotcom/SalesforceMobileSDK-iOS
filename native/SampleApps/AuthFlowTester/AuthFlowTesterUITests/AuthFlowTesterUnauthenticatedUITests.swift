/*
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

/// Tests for the unauthenticated state - Config Picker screen
final class AuthFlowTesterUnauthenticatedUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    // Expected values loaded from bootconfig.plist and bootconfig2.plist
    var bootconfigConsumerKey: String!
    var bootconfigRedirectURI: String!
    var bootconfigScopes: String!
    var bootconfig2ConsumerKey: String!
    var bootconfig2RedirectURI: String!
    var bootconfig2Scopes: String!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Load expected values from bootconfig files in the test bundle
        let bootconfig = try TestHelper.loadBootConfig(named: "bootconfig")
        let bootconfig2 = try TestHelper.loadBootConfig(named: "bootconfig2")
        bootconfigConsumerKey = bootconfig.consumerKey
        bootconfigRedirectURI = bootconfig.redirectURI
        bootconfigScopes = bootconfig.scopes
        bootconfig2ConsumerKey = bootconfig2.consumerKey
        bootconfig2RedirectURI = bootconfig2.redirectURI
        bootconfig2Scopes = bootconfig2.scopes
        
        TestHelper.launchWithoutCredentials(app)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Screen visible test
    func testConfigPickerScreenIsVisible() throws {
        // Navigation title
        XCTAssertTrue(app.navigationBars["AuthFlowTester"].waitForExistence(timeout: 5))
        // Primary actions
        XCTAssertTrue(app.buttons["Use static config"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Use dynamic config"].exists)
    }

    // MARK: - Static Configuration Test
    
    func testStaticConfigSection() throws {
        let staticConfigHeader = app.buttons["Static Configuration"]
        XCTAssertTrue(staticConfigHeader.waitForExistence(timeout: 5), "Static Configuration header should exist")
        
        let useStaticConfigButton = app.buttons["Use static config"]
        XCTAssertTrue(useStaticConfigButton.waitForExistence(timeout: 5), "Use static config button should exist")
        XCTAssertTrue(useStaticConfigButton.isEnabled, "Use static config button should be enabled")
        
        // Initially collapsed - fields should not be visible
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists, "Consumer Key label should not be visible when collapsed")
        
        // Tap to expand
        staticConfigHeader.tap()
        
        // Fields should now be visible - wait for animation
        XCTAssertTrue(app.staticTexts["Consumer Key:"].waitForExistence(timeout: 3), "Consumer Key label should appear when expanded")
        XCTAssertTrue(app.staticTexts["Callback URL:"].exists, "Callback URL label should exist")
        XCTAssertTrue(app.staticTexts["Scopes (space-separated):"].exists, "Scopes label should exist")
        
        // Check text fields exist and have correct values
        let consumerKeyField = app.textFields["consumerKeyTextField"]
        XCTAssertTrue(consumerKeyField.waitForExistence(timeout: 3), "Consumer key text field should exist")
        XCTAssertEqual(consumerKeyField.value as? String, bootconfigConsumerKey, "Consumer key should match boot config")
        
        let callbackUrlField = app.textFields["callbackUrlTextField"]
        XCTAssertTrue(callbackUrlField.exists, "Callback URL text field should exist")
        XCTAssertEqual(callbackUrlField.value as? String, bootconfigRedirectURI, "Callback URL should match boot config")
        
        let scopesField = app.textFields["scopesTextField"]
        XCTAssertTrue(scopesField.exists, "Scopes text field should exist")
        // Scopes text field will be empty if no scopes configured
        let scopesValue = scopesField.value as? String
        if bootconfigScopes == "(none)" {
            XCTAssert(scopesValue == "" || scopesValue == nil || scopesValue == "e.g. id api refresh_token", 
                     "Scopes should be empty or placeholder when not configured, got: '\(String(describing: scopesValue))'")
        } else {
            XCTAssertEqual(scopesValue, bootconfigScopes, "Scopes should match boot config")
        }

        // Tap to collapse
        staticConfigHeader.tap()
        
        // Fields should be hidden again
        XCTAssertFalse(app.staticTexts["Consumer Key:"].waitForExistence(timeout: 2), "Consumer Key label should be hidden when collapsed")
    }
    
    
    // MARK: - Dynamic Configuration Test
    
    func testDynamicConfigSection() throws {
        let dynamicConfigHeader = app.buttons["Dynamic Configuration"]
        XCTAssertTrue(dynamicConfigHeader.waitForExistence(timeout: 5), "Dynamic Configuration header should exist")
        
        let useDynamicConfigButton = app.buttons["Use dynamic config"]
        XCTAssertTrue(useDynamicConfigButton.waitForExistence(timeout: 5), "Use dynamic config button should exist")
        XCTAssertTrue(useDynamicConfigButton.isEnabled, "Use dynamic config button should be enabled")
        
        // Initially collapsed - fields should not be visible
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists, "Consumer Key label should not be visible when collapsed")

        // Tap to expand
        dynamicConfigHeader.tap()
        
        // Fields should now be visible - wait for animation
        XCTAssertTrue(app.staticTexts["Consumer Key:"].waitForExistence(timeout: 3), "Consumer Key label should appear when expanded")
        XCTAssertTrue(app.staticTexts["Callback URL:"].exists, "Callback URL label should exist")
        XCTAssertTrue(app.staticTexts["Scopes (space-separated):"].exists, "Scopes label should exist")
        
        // Check text fields exist and have correct values
        let consumerKeyField = app.textFields["consumerKeyTextField"]
        XCTAssertTrue(consumerKeyField.waitForExistence(timeout: 3), "Consumer key text field should exist")
        XCTAssertEqual(consumerKeyField.value as? String, bootconfig2ConsumerKey, "Consumer key should match bootconfig2")
        
        let callbackUrlField = app.textFields["callbackUrlTextField"]
        XCTAssertTrue(callbackUrlField.exists, "Callback URL text field should exist")
        XCTAssertEqual(callbackUrlField.value as? String, bootconfig2RedirectURI, "Callback URL should match bootconfig2")
        
        let scopesField = app.textFields["scopesTextField"]
        XCTAssertTrue(scopesField.exists, "Scopes text field should exist")
        // Scopes text field will be empty if no scopes configured
        let scopesValue = scopesField.value as? String
        if bootconfig2Scopes == "(none)" {
            XCTAssert(scopesValue == "" || scopesValue == nil || scopesValue == "e.g. id api refresh_token", 
                     "Scopes should be empty or placeholder when not configured, got: '\(String(describing: scopesValue))'")
        } else {
            XCTAssertEqual(scopesValue, bootconfig2Scopes, "Scopes should match bootconfig2")
        }
        
        // Tap to collapse
        dynamicConfigHeader.tap()
        
        // Fields should be hidden again
        XCTAssertFalse(app.staticTexts["Consumer Key:"].waitForExistence(timeout: 2), "Consumer Key label should be hidden when collapsed")
    }
    
    // MARK: - Flow Types Test
    func testFlowTypes() throws {
        XCTAssertTrue(app.staticTexts["Authentication Flow Types"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use Web Server Flow")).count > 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use Hybrid Flow")).count > 0)
    }
}

