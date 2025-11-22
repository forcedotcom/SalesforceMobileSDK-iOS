/*
 ChangeKeyPageObject.swift
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


import Foundation
import XCTest

class ChangeKeyPageObject {
    let app: XCUIApplication
    let timeout: double_t = 10
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    // MARK: - UI Element Accessors
    
    func navigationTitle() -> XCUIElement {
        return app.navigationBars["Migrate to New App"]
    }
    
    func consumerKeyTextField() -> XCUIElement {
        return app.textFields["Consumer Key"]
    }
    
    func callbackUrlTextField() -> XCUIElement {
        return app.textFields["Callback URL"]
    }
    
    func scopesTextField() -> XCUIElement {
        return app.textFields["Scopes (space-separated)"]
    }
    
    func migrateButton() -> XCUIElement {
        return app.buttons["Migrate refresh token"]
    }
    
    func cancelButton() -> XCUIElement {
        return app.buttons["Cancel"]
    }
    
    // MARK: - Actions
    
    func waitForSheet() -> Bool {
        return navigationTitle().waitForExistence(timeout: timeout)
    }
    
    func setConsumerKey(key: String) -> Void {
        let textField = consumerKeyTextField()
        _ = textField.waitForExistence(timeout: timeout)
        textField.tap()
        textField.typeText(key)
    }
    
    func setCallbackUrl(url: String) -> Void {
        let textField = callbackUrlTextField()
        _ = textField.waitForExistence(timeout: timeout)
        textField.tap()
        textField.typeText(url)
    }
    
    func setScopes(scopes: String) -> Void {
        let textField = scopesTextField()
        _ = textField.waitForExistence(timeout: timeout)
        textField.tap()
        textField.typeText(scopes)
    }
    
    func tapMigrate() -> Void {
        let button = migrateButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func tapCancel() -> Void {
        let button = cancelButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
}

