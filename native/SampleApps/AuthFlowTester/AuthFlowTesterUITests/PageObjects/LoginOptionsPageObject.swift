/*
 LoginOptionsPageObject.swift
 AuthFlowTesterUITests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/// Page object for interacting with the Login Options sheet (LoginOptionsViewController / LoginOptionsView) during UI tests.
/// Use after navigating to Login Options from the login screen (e.g. via Settings → Login Options).
class LoginOptionsPageObject {
    let app: XCUIApplication
    let authFlowTypesPageObject: AuthFlowTypesPageObject

    init(testApp: XCUIApplication) {
        app = testApp
        authFlowTypesPageObject = AuthFlowTypesPageObject(testApp: testApp)
    }

    /// Configures login options: flow switches, static/dynamic app config, and discovery result.
    /// Call when the Login Options sheet is already visible.
    func configure(
        staticAppConfig: AppConfig?,
        staticScopes: String,
        dynamicAppConfig: AppConfig?,
        dynamicScopes: String,
        useWebServerFlow: Bool,
        useHybridFlow: Bool,
        discoveryLoginHost: String,
        discoveryUsername: String,
    ) -> Void {
        // Set auth flow types using the dedicated page object
        authFlowTypesPageObject.setAuthFlowTypes(
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )

        if let staticAppConfig = staticAppConfig {
            let configJSON = buildConfigJSON(consumerKey: staticAppConfig.consumerKey, redirectUri: staticAppConfig.redirectUri, scopes: staticScopes)
            importConfig(configJSON, isStaticConfiguration: true)
        }

        if let dynamicAppConfig = dynamicAppConfig {
            let configJSON = buildConfigJSON(consumerKey: dynamicAppConfig.consumerKey, redirectUri: dynamicAppConfig.redirectUri, scopes: dynamicScopes)
            importConfig(configJSON, isStaticConfiguration: false)
        }

        let discoveryResultJSON = buildDiscoveryResultJSON(loginHost: discoveryLoginHost, username: discoveryUsername)
        importDiscoveryResult(discoveryResultJSON)

        tap(loginOptionsCloseButton())
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

    private func buildDiscoveryResultJSON(loginHost: String, username: String) -> String {
        let config: [String: String] = [
            "login_hint": username,
            "my_domain": loginHost
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func importConfig(_ jsonString: String, isStaticConfiguration: Bool = true) {
        // Tap import button to show alert
        tap(importConfigButton(useStaticConfiguration: isStaticConfiguration))

        // Wait for alert and enter JSON (text field is automatically focused)
        let alert = app.alerts["Import Configuration"]
        _ = alert.waitForExistence(timeout: UITestTimeouts.long)

        let textField = alert.textFields.firstMatch
        textField.typeText(jsonString)

        // Tap Import button in alert
        alert.buttons["Import"].tap()
    }

    private func importDiscoveryResult(_ jsonString: String) {
        // Tap import button to show alert
        tap(importDiscoveryResultButton())

        // Wait for alert and enter JSON (text field is automatically focused)
        let alert = app.alerts["Import Discovery Result"]
        _ = alert.waitForExistence(timeout: UITestTimeouts.long)

        let textField = alert.textFields.firstMatch
        textField.typeText(jsonString)

        // Tap Import button in alert
        alert.buttons["Import"].tap()
    }

    // MARK: - UI Element Accessors (LoginOptionsView)

    /// Returns the import button for either the static or dynamic configuration section.
    private func importConfigButton(useStaticConfiguration: Bool = true) -> XCUIElement {
        let buttons = app.buttons.matching(identifier: "importConfigButton")
        let index = useStaticConfiguration ? 0 : 1
        return buttons.element(boundBy: index)
    }

    private func importDiscoveryResultButton() -> XCUIElement {
        return app.buttons["importDiscoveryResultButton"]
    }

    private func loginOptionsCloseButton() -> XCUIElement {
        return app.buttons["loginOptionsCloseButton"]
    }

    // MARK: - Actions

    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: UITestTimeouts.long)
        element.tap()
    }
}
