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
    let timeout: double_t = 5
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return navigationTitle().waitForExistence(timeout: timeout)
    }
    
    func performLogout() {
        tap(bottomBarLogoutButton())
        tap(alertLogoutButton())
    }
    
    func hasUser(username: String) -> Bool {
        tap(userCredentialsSection())
        tap(userIdentitySection())
        let hasUser = hasStaticText(username)
        tap(userIdentitySection())
        tap(userCredentialsSection())
        return hasUser
    }
    
    func makeRestRequest() -> Bool {
        tap(makeRestRequestButton())
        let alert = app.alerts["Request Successful"]
        if (alert.waitForExistence(timeout: timeout)) {
            alert.buttons["OK"].tap()
            return true
        }
        return false
    }
    
    func reokveAccessToken() -> Bool {
        tap(revokeButton())
        let alert = app.alerts["Access Token Revoked"]
        if (alert.waitForExistence(timeout: timeout)) {
            alert.buttons["OK"].tap()
            return true
        }
        return false
    }
    
    // MARK: - UI Element Accessors
    
    private func navigationTitle() -> XCUIElement {
        return app.navigationBars["AuthFlowTester"]
    }
    
    private func revokeButton() -> XCUIElement {
        return app.buttons["Revoke Access Token"]
    }
    
    private func makeRestRequestButton() -> XCUIElement {
        return app.buttons["Make REST API Request"]
    }
    
    private func bottomBarChangeKeyButton() -> XCUIElement {
        return app.buttons["Change Key"]
    }
    
    private func bottomBarSwitchUserButton() -> XCUIElement {
        return app.buttons["Switch User"]
    }
    
    private func bottomBarLogoutButton() -> XCUIElement {
        return app.buttons["Logout"]
    }
    
    private func alertLogoutButton() -> XCUIElement {
        return app.alerts["Logout"].buttons["Logout"]
    }
    
    private func userCredentialsSection() -> XCUIElement {
        return app.buttons["User Credentials"]
    }
    
    private func userIdentitySection() -> XCUIElement {
        return app.buttons["User Identity"]
    }
    
    private func oauthConfigSection() -> XCUIElement {
        return app.buttons["OAuth Configuration"]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: timeout)
        element.tap()
    }
    
    // MARK: - Other
    
    private func hasStaticText(_ text: String) -> Bool {
        let staticText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(text)'"))
        return staticText.firstMatch.waitForExistence(timeout: timeout)
    }
}

