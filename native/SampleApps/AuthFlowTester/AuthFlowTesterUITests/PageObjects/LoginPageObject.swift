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
import SalesforceSDKCore

/// Page object for interacting with the Salesforce login screen during UI tests.
/// Provides methods to configure login servers, login options and perform user authentication.
class LoginPageObject {
    let app: XCUIApplication

    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return loginNavigationBar().waitForExistence(timeout: UITestTimeouts.long)
    }
    
    func hasFilledUsernameField(username: String) -> Bool {
        return app.staticTexts[username].waitForExistence(timeout: UITestTimeouts.long)
    }
    
    func isShowingAdvancedAuth() -> Bool {
        return advancedAuthCloseButton().waitForExistence(timeout: UITestTimeouts.short)
    }
    
    func closeAdvancedAuth() -> Void {
        tap(advancedAuthCloseButton())
        tap(hostRow(host: "Production"))
    }
    
    func configureLoginHost(host: String) -> Void {
        tap(settingsButton())
        tap(changeServerButton())
        
        if (hasHost(host: host)) {
            // Select host if it exists already
            tap(hostRow(host: host))
        } else {
            // Add host if it does not exist
            tap(addConnectionButton())
            setTextField(hostInputField(), value: host)
            tap(doneOnAddConnectionButton())
        }
    }
    
    func performLogin(username: String, password: String) {
        setTextField(usernameField(), value: username)
        tap(toolbarDoneButton())
        setTextField(passwordField(), value: password)
        tap(toolbarDoneButton())
        tap(loginButton())
        tapIfPresent(allowButton())
    }

    func performAdvancedLogin(username: String, password: String) {
        setTextField(usernameField(), value: username)
        tap(passwordFieldLabel())
        setTextField(passwordField(), value: password)
        tap(usernameFieldLabel())
        tap(loginButton())
        tapIfPresent(allowButton())
    }
    
    func performWelcomeLogin(password: String) {
        setTextField(passwordField(), value: password)
        tap(usernameFieldLabel()) // click on label to hide keyboard
        tap(loginButton())
        tapIfPresent(allowButton())
    }
    
    func configureLoginOptions(
        staticAppConfig: AppConfig?,
        staticScopes: String,
        dynamicAppConfig: AppConfig?,
        dynamicScopes: String,
        useWebServerFlow: Bool,
        useHybridFlow: Bool,
        discoveryLoginHost: String,
        discoveryUsername: String,
    ) -> Void {
        tap(settingsButton())
        tap(loginOptionsButton())
        let loginOptionsPage = LoginOptionsPageObject(testApp: app)
        loginOptionsPage.configure(
            staticAppConfig: staticAppConfig,
            staticScopes: staticScopes,
            dynamicAppConfig: dynamicAppConfig,
            dynamicScopes: dynamicScopes,
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow,
            discoveryLoginHost: discoveryLoginHost,
            discoveryUsername: discoveryUsername
        )
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
    
    private func loginOptionsButton() -> XCUIElement {
        return app.buttons["Login Options"]
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
    
    private func toolbarDoneButton() -> XCUIElement {
        return app.toolbars["Toolbar"].buttons["Done"]
    }

    private func usernameFieldLabel() -> XCUIElement {
        return app.staticTexts["Username"]
    }
    
    private func usernameField() -> XCUIElement {
        return app.descendants(matching: .textField).element
    }
    
    private func passwordFieldLabel() -> XCUIElement {
        return app.staticTexts["Password"]
    }
    
    private func passwordField() -> XCUIElement {
        return app.descendants(matching: .secureTextField).element
    }
    
    private func loginButton() -> XCUIElement {
        return app.webViews.webViews.webViews.buttons["Log In"]
    }
    
    private func allowButton() -> XCUIElement {
        let buttons = app.webViews.webViews.webViews.buttons
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Allow'")
        return buttons.matching(predicate).firstMatch
    }

    private func advancedAuthCloseButton() -> XCUIElement {
        return app.otherElements["TopBrowserBar"].buttons["Close"]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: UITestTimeouts.long)
        element.tap()
    }
    
    private func tapIfPresent(_ element: XCUIElement) {
        if (element.waitForExistence(timeout: UITestTimeouts.long)) {
            element.tap()
        }
    }
    
    private func setTextField(_ textField: XCUIElement, value: String) {
        tap(textField)
        
        // Return if the value is already set
        if textField.value as? String == value {
            return
        }

        // Clear any existing text
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            tap(textField) // second tap should bring up menu
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: UITestTimeouts.short) {
                selectAll.tap()
                textField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
        
        textField.typeText(value)
    }
    
    // MARK: - Other
    
    private func hasHost(host: String) -> Bool {
        let row = hostRow(host: host)
        return row.waitForExistence(timeout: UITestTimeouts.long)
    }
}

