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
    let timeout: double_t = 5
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return loginNavigationBar().waitForExistence(timeout: timeout)
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
        setTextField(passwordField(), value: password)
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
        supportWelcomeDiscovery: Bool,
    ) -> Void {
        tap(settingsButton())
        tap(loginOptionsButton())
        setSwitchField(useWebServerFlowSwitch(), value: useWebServerFlow)
        setSwitchField(useHybridSwitch(), value: useHybridFlow)
        setSwitchField(supportWelcomeDiscoverySwitch(), value: supportWelcomeDiscovery)
        
        if let staticAppConfig = staticAppConfig {
            let configJSON = buildConfigJSON(consumerKey: staticAppConfig.consumerKey, redirectUri: staticAppConfig.redirectUri, scopes: staticScopes)
            importConfig(configJSON, isStaticConfiguration: true)
        }
        // In all cases - we want the static config to be set
        tap(useStaticConfigButton())

        // Setting dynamic config when provided
        if let dynamicAppConfig = dynamicAppConfig {
            tap(settingsButton())
            tap(loginOptionsButton())
            let configJSON = buildConfigJSON(consumerKey: dynamicAppConfig.consumerKey, redirectUri: dynamicAppConfig.redirectUri, scopes: dynamicScopes)
            importConfig(configJSON, isStaticConfiguration: false)
            tap(useDynamicConfigButton())
        }
    }
    
    private func buildConfigJSON(consumerKey: String, redirectUri: String, scopes: String) -> String {
        let config: [String: String] = [
            BootConfigJSONKeys.consumerKey: consumerKey,
            BootConfigJSONKeys.redirectUri: redirectUri,
            BootConfigJSONKeys.scopes: scopes
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
    
    private func importConfig(_ jsonString: String, isStaticConfiguration: Bool = true) {
        tap(importConfigButton(useStaticConfiguration: isStaticConfiguration))
        
        // Wait for alert to appear
        let alert = importConfigAlert()
        _ = alert.waitForExistence(timeout: timeout)
        
        // Type into the alert's text field
        let textField = importConfigTextField()
        textField.typeText(jsonString)
        
        tap(importAlertButton())
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
        let buttons = app.webViews.webViews.webViews.buttons
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Allow'")
        return buttons.matching(predicate).firstMatch
    }
    
    private func toolbarDoneButton() -> XCUIElement {
        return app.toolbars["Toolbar"].buttons["Done"]
    }
    
    private func useWebServerFlowSwitch() -> XCUIElement {
        return app.switches["Use Web Server Flow"]
    }

    private func useHybridSwitch() -> XCUIElement {
        return app.switches["Use Hybrid Flow"]
    }

    private func supportWelcomeDiscoverySwitch() -> XCUIElement {
        return app.switches["Support Welcome Discovery"]
    }

    private func staticConfigurationSection() -> XCUIElement {
        return app.buttons["Static Configuration"]
    }
    
    private func consumerKeyField() -> XCUIElement {
        return app.textFields["consumerKeyTextField"]
    }
    
    private func callbackUrlField() -> XCUIElement {
        return app.textFields["callbackUrlTextField"]
    }
    
    private func scopesField() -> XCUIElement {
        return app.textFields["scopesTextField"]
    }
    
    private func useStaticConfigButton() -> XCUIElement {
        return app.buttons["Use static config"]
    }

    private func useDynamicConfigButton() -> XCUIElement {
        return app.buttons["Use dynamic config"]
    }
    
    /// Returns the import button for either the static or dynamic configuration section.
    /// The BootConfigPickerView has two BootConfigEditor sections - the first for static config, the second for dynamic config.
    private func importConfigButton(useStaticConfiguration: Bool = true) -> XCUIElement {
        let buttons = app.buttons.matching(identifier: "importConfigButton")
        let index = useStaticConfiguration ? 0 : 1
        return buttons.element(boundBy: index)
    }
    
    private func importConfigAlert() -> XCUIElement {
        return app.alerts["Import Configuration"]
    }
    
    private func importConfigTextField() -> XCUIElement {
        // Access text field through the alert - SwiftUI alert TextFields are accessed this way
        return importConfigAlert().textFields.firstMatch
    }
    
    private func importAlertButton() -> XCUIElement {
        return importConfigAlert().buttons["Import"]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: timeout)
        element.tap()
    }
    
    private func tapIfPresent(_ element: XCUIElement) {
        if (element.waitForExistence(timeout: timeout)) {
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
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
                textField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
        
        textField.typeText(value)
        tapIfPresent(toolbarDoneButton())
    }
    
    private func setSwitchField(_ switchField: XCUIElement, value: Bool) {
        _ = switchField.waitForExistence(timeout: timeout)
        
        // Switch values are "0" (off) or "1" (on) in XCTest
        let currentValue = (switchField.value as? String) == "1"
        
        // Only tap if the current state differs from desired state
        if currentValue != value {
            tap(switchField)
        }
    }
    
    // MARK: - Other

    private func hasHost(host: String) -> Bool {
        let row = hostRow(host: host)
        return row.waitForExistence(timeout: timeout)
    }
    
}

