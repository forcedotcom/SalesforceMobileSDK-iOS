/*
 AuthFlowTesterMainPageObject.swift
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

class AuthFlowTesterMainPageObject {
    let app: XCUIApplication
    let timeout: double_t = 60
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    // MARK: - UI Element Accessors
    
    func navigationTitle() -> XCUIElement {
        return app.navigationBars["AuthFlowTester"]
    }
    
    func revokeButton() -> XCUIElement {
        return app.buttons["Revoke Access Token"]
    }
    
    func makeRestRequestButton() -> XCUIElement {
        return app.buttons["Make REST API Request"]
    }
    
    func changeKeyButton() -> XCUIElement {
        return app.buttons["Change Key"]
    }
    
    func switchUserButton() -> XCUIElement {
        return app.buttons["Switch User"]
    }
    
    func logoutButton() -> XCUIElement {
        return app.buttons["Logout"]
    }
    
    func userCredentialsSection() -> XCUIElement {
        return app.buttons["User Credentials"]
    }
    
    func oauthConfigSection() -> XCUIElement {
        return app.buttons["OAuth Configuration"]
    }
    
    // MARK: - Actions
    
    func waitForMainScreen() -> Bool {
        return navigationTitle().waitForExistence(timeout: timeout)
    }
    
    func tapRevokeAccessToken() -> Void {
        let button = revokeButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func tapMakeRestRequest() -> Void {
        let button = makeRestRequestButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func tapChangeKey() -> Void {
        let button = changeKeyButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func tapSwitchUser() -> Void {
        let button = switchUserButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func tapLogout() -> Void {
        let button = logoutButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    func confirmLogout() -> Void {
        let logoutConfirmButton = app.buttons["Logout"]
        _ = logoutConfirmButton.waitForExistence(timeout: 5)
        logoutConfirmButton.tap()
    }
    
    func expandUserCredentials() -> Void {
        let section = userCredentialsSection()
        if section.waitForExistence(timeout: timeout) {
            section.tap()
            sleep(1)
        }
    }
    
    func expandOAuthConfig() -> Void {
        let section = oauthConfigSection()
        if section.waitForExistence(timeout: timeout) {
            section.tap()
            sleep(1)
        }
    }
    
    func waitForUsername(username: String) -> Bool {
        let usernameText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(username)'"))
        return usernameText.firstMatch.waitForExistence(timeout: timeout)
    }
    
    func isRestRequestSuccessful() -> Bool {
        let successIndicator = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '✓ Success:'")).firstMatch
        return successIndicator.waitForExistence(timeout: timeout)
    }
    
    func isAccessTokenRevoked() -> Bool {
        let alert = app.alerts["Access Token Revoked"]
        if alert.waitForExistence(timeout: 10) {
            alert.buttons["OK"].tap()
            return true
        }
        return false
    }
}

