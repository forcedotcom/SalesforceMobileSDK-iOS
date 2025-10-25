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
        XCTAssertTrue(app.buttons["Use default config"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Use dynamic config"].exists)
    }

    // MARK: - Default Configuration Test
    
    func testDefaultConfigSection() throws {
        let defaultConfigHeader = app.buttons["Default Configuration"]
        XCTAssertTrue(defaultConfigHeader.waitForExistence(timeout: 5))
        
        let useDefaultConfigButton = app.buttons["Use default config"]
        XCTAssertTrue(useDefaultConfigButton.waitForExistence(timeout: 5))
        XCTAssertTrue(useDefaultConfigButton.isEnabled)
        
        // Initially collapsed - fields should not be visible
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists)
        XCTAssertFalse(app.staticTexts["Callback URL:"].exists)
        XCTAssertFalse(app.staticTexts["Scopes:"].exists)

        // Tap to expand
        defaultConfigHeader.tap()
        
        // Fields should now be visible
        XCTAssertTrue(app.staticTexts["Consumer Key:"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", bootconfigConsumerKey)).count > 0)
        XCTAssertTrue(app.staticTexts["Callback URL:"].exists)
        let callbackPredicate = NSPredicate(format: "label CONTAINS %@", bootconfigRedirectURI)
        XCTAssertTrue(app.staticTexts.containing(callbackPredicate).count > 0)
        XCTAssertTrue(app.staticTexts["Scopes:"].exists)
        let scopesPredicate = NSPredicate(format: "label CONTAINS %@", bootconfigScopes)
        XCTAssertTrue(app.staticTexts.containing(scopesPredicate).count > 0)

        // Tap to collapse
        defaultConfigHeader.tap()
        
        // Fields should be hidden again
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists)
        XCTAssertFalse(app.staticTexts["Callback URL:"].exists)
        XCTAssertFalse(app.staticTexts["Scopes:"].exists)
    }
    
    
    // MARK: - Dynamic Configuration Test
    
    func testDynamicConfigSection() throws {
        let dynamicConfigHeader = app.buttons["Dynamic Configuration"]
        XCTAssertTrue(dynamicConfigHeader.waitForExistence(timeout: 5))
        
        let useDynamicConfigButton = app.buttons["Use dynamic config"]
        XCTAssertTrue(useDynamicConfigButton.waitForExistence(timeout: 5))
        XCTAssertTrue(useDynamicConfigButton.isEnabled)
        
        // Initially collapsed - fields should not be visible
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists)
        XCTAssertFalse(app.staticTexts["Callback URL:"].exists)
        XCTAssertFalse(app.staticTexts["Scopes (space-separated):"].exists)

        // Tap to expand
        dynamicConfigHeader.tap()
        
        // Fields should now be visible
        XCTAssertTrue(app.staticTexts["Consumer Key:"].exists)
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value CONTAINS %@", bootconfig2ConsumerKey)).count > 0)
        XCTAssertTrue(app.staticTexts["Callback URL:"].exists)
        let callbackPredicate = NSPredicate(format: "value CONTAINS %@", bootconfig2RedirectURI)
        XCTAssertTrue(app.textFields.containing(callbackPredicate).count > 0)
        XCTAssertTrue(app.staticTexts["Scopes (space-separated):"].exists)
        let scopesPredicate = NSPredicate(format: "value CONTAINS %@", bootconfig2Scopes)
        XCTAssertTrue(app.textFields.containing(scopesPredicate).count > 0)
        
        // Tap to collapse
        dynamicConfigHeader.tap()
        
        // Fields should be hidden again
        XCTAssertFalse(app.staticTexts["Consumer Key:"].exists)
        XCTAssertFalse(app.staticTexts["Callback URL:"].exists)
        XCTAssertFalse(app.staticTexts["Scopes (space-separated):"].exists)
    }
    
    // MARK: - Flow Types Test
    func testFlowTypes() throws {
        XCTAssertTrue(app.staticTexts["Authentication Flow Types"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use Web Server Flow")).count > 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use Hybrid Flow")).count > 0)
    }
}

