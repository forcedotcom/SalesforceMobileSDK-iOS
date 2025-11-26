/*
 LoginPageObject.swift
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

class LoginPageObject {
    let app: XCUIApplication
    let timeout: double_t = 5
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return loginNavigationBar().waitForExistence(timeout: timeout)
    }
    
    func configureLoginHost(host: String) -> Void {
        tapSettings()
        tapChangeServer()
        
        if (hasHost(host: host)) {
            // Select host if it exists already
            tapHost(host: host)
        } else {
            // Add host if it does not exist
            tapAddConnectionButton()
            setConnectionHost(host: host)
            tapDoneOnAddConnection()
        }
    }
    
    func performLogin(username: String, password: String) {
        setUsername(name: username)
        setPassword(password: password)
        tapLogin()
        tapAllowIfPresent()
    }
    
    func configureAppConfig() -> Void {
        performShake()
        tapLoginOptionsButton()
    }
    
    // MARK: - UI Element Accessors
    
    private func loginNavigationBar() -> XCUIElement {
        return app.navigationBars["Log In"]
    }
    
    private func settingsButton() -> XCUIElement {
        return loginNavigationBar().buttons["Settings"]
    }
    
    private func changeServerButton() -> XCUIElement {
        return app.buttons["Change Server"]
    }
    
    private func changeServerNavigationBar() -> XCUIElement {
        return app.navigationBars["Change Server"]
    }
    
    private func addConnectionButton() -> XCUIElement {
        return changeServerNavigationBar().buttons["Add"]
    }
    
    private func addConnectionNavigationBar() -> XCUIElement {
        return app.navigationBars["Add Connection"]
    }
    
    private func hostInputField() -> XCUIElement {
        return app.textFields["addconn_hostInput"]
    }
    
    private func doneOnAddConnectionButton() -> XCUIElement {
        return addConnectionNavigationBar().buttons["Done"]
    }
    
    private func hostRow(host: String) -> XCUIElement {
        return app.staticTexts[host].firstMatch
    }
    
    private func usernameField() -> XCUIElement {
        return app.descendants(matching: .textField).element
    }
    
    private func passwordField() -> XCUIElement {
        return app.descendants(matching: .secureTextField).element
    }
    
    private func loginButton() -> XCUIElement {
        return app.webViews.webViews.webViews.buttons["Log In"]
    }
    
    private func allowButton() -> XCUIElement {
        return app.webViews.webViews.webViews.buttons[" Allow "]
    }
    
    private func toolbarDoneButton() -> XCUIElement {
        return app.toolbars.matching(identifier: "Toolbar").buttons["selected"]
    }
    
    private func loginOptionsAlert() -> XCUIElement {
        return app.alerts.firstMatch
    }
    
    private func loginOptionsButton() -> XCUIElement {
        return loginOptionsAlert().buttons["Login Options"]
    }
    
    private func loginOptionsActionSheet() -> XCUIElement {
        return app.sheets.firstMatch
    }
    
    // MARK: - Actions
    
    private func setUsername(name: String) -> Void {
        let nameField = usernameField()
        _ = nameField.waitForExistence(timeout: timeout)
        nameField.tap()
        sleep(1)
        nameField.typeText(name)
    }
    
    private func setPassword(password: String) -> Void {
        let field = passwordField()
        _ = field.waitForExistence(timeout: timeout)
        field.tap()
        sleep(1)
        field.typeText(password)
        hideToolbar()
    }
    
    private func tapLogin() -> Void {
        let button = loginButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    private func tapAllowIfPresent() {
        let button = allowButton()
        if (button.waitForExistence(timeout: timeout)) {
            button.tap()
        }
    }
    
    private func tapSettings() -> Void {
        let button = settingsButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    private func tapChangeServer() -> Void {
        let button = changeServerButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    private func tapAddConnectionButton() -> Void {
        let button = addConnectionButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    private func setConnectionHost(host: String) -> Void {
        let hostField = hostInputField()
        _ = hostField.waitForExistence(timeout: timeout)
        hostField.tap()
        sleep(1)
        hostField.typeText(host)
    }
    
    private func tapDoneOnAddConnection() -> Void {
        let button = doneOnAddConnectionButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    private func tapHost(host: String) {
        let row = hostRow(host: host)
        _ = row.waitForExistence(timeout: timeout)
        row.tap()
    }
    
    private func hideToolbar() -> Void {
        let button = toolbarDoneButton()
        if button.exists {
            button.tap()
        }
    }
    
    private func performShake() -> Void {
        // TODO is it possible with a UI test
    }
    
    private func tapLoginOptionsButton() -> Void {
        let button = loginOptionsButton()
        _ = button.waitForExistence(timeout: timeout)
        button.tap()
    }
    
    // MARK: - Other

    private func hasHost(host: String) -> Bool {
        let row = hostRow(host: host)
        return row.waitForExistence(timeout: timeout)
    }
    
}

