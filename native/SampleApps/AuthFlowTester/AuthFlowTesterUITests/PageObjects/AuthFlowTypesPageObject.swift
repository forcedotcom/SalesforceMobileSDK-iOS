/*
 AuthFlowTypesPageObject.swift
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

/// Page object for interacting with the AuthFlowTypesView (auth flow switches) during UI tests.
/// Can be used from both LoginOptionsView and the refresh token migration sheet.
class AuthFlowTypesPageObject {
    let app: XCUIApplication

    init(testApp: XCUIApplication) {
        app = testApp
    }

    /// Sets the auth flow types (useWebServerFlow and useHybridFlow) using JSON import.
    func setAuthFlowTypes(useWebServerFlow: Bool, useHybridFlow: Bool) {
        // Wait for the import button to be ready
        _ = importAuthFlowTypesButton().waitForExistence(timeout: UITestTimeouts.long)

        // Build and import JSON
        let authFlowTypesJSON = buildAuthFlowTypesJSON(
            useWebServerFlow: useWebServerFlow,
            useHybridFlow: useHybridFlow
        )
        importAuthFlowTypes(authFlowTypesJSON)
    }

    // MARK: - Private Helpers

    private func buildAuthFlowTypesJSON(useWebServerFlow: Bool, useHybridFlow: Bool) -> String {
        let config: [String: Bool] = [
            AuthFlowTypesJSONKeys.useWebServerFlow: useWebServerFlow,
            AuthFlowTypesJSONKeys.useHybridFlow: useHybridFlow
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func importAuthFlowTypes(_ jsonString: String) {
        tap(importAuthFlowTypesButton())

        // Wait for alert to appear
        let alert = app.alerts["Import Auth Flow Types"]
        _ = alert.waitForExistence(timeout: UITestTimeouts.long)

        // Type into the alert's text field
        let textField = alert.textFields.firstMatch
        textField.typeText(jsonString)

        // Tap Import button
        alert.buttons["Import"].tap()
    }

    // MARK: - UI Element Accessors

    private func importAuthFlowTypesButton() -> XCUIElement {
        return app.buttons["importAuthFlowTypesButton"]
    }

    // MARK: - Actions

    private func tap(_ element: XCUIElement, timeout: TimeInterval = UITestTimeouts.long, file: StaticString = #file, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element.debugDescription) did not appear within \(timeout)s", file: file, line: line)
        element.tap()
    }
}
