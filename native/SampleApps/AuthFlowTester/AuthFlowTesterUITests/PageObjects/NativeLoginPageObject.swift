/*
 NativeLoginPageObject.swift
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

/// Page object for the app-owned Native Login form and its Login Options sheet.
/// Identifiers mirror `NativeLoginView` / `the SDK Login Options screen` in the app target.
class NativeLoginPageObject {
    /// Launch argument that selects Native mode for a launch (Native Login cannot be turned off in-process).
    static let nativeModeArgument = "--authenticationMode=native"
    static let browserModeArgument = "--authenticationMode=browser"

    let app: XCUIApplication

    init(testApp: XCUIApplication) {
        app = testApp
    }

    // MARK: - State

    /// True when the native form is showing.
    func isShowingForm(timeout: TimeInterval = UITestTimeouts.network) -> Bool {
        return loginButton().waitForExistence(timeout: timeout)
    }

    func isShowingCancelButton() -> Bool {
        return cancelButton().waitForExistence(timeout: UITestTimeouts.short)
    }

    /// Result label text (success, invalidCredentials, ...), or nil if none appears in time.
    func result(timeout: TimeInterval = UITestTimeouts.network) -> String? {
        let label = resultLabel()
        guard label.waitForExistence(timeout: timeout) else { return nil }
        return label.label
    }

    /// Redacted diagnostics shown on the form (stage, dpop, nonce counts, status; never secrets).
    func diagnostics() -> String {
        let label = diagnosticsLabel()
        _ = label.waitForExistence(timeout: UITestTimeouts.short)
        return label.label
    }

    /// Failure detail (last diagnostics line), or empty when none is shown.
    func errorDetail() -> String {
        let label = errorDetailLabel()
        _ = label.waitForExistence(timeout: UITestTimeouts.short)
        return label.label
    }

    // MARK: - Actions

    func submit(username: String, password: String) {
        let user = usernameField()
        XCTAssertTrue(user.waitForExistence(timeout: UITestTimeouts.long), "Native username field did not appear")
        user.tap()
        user.typeText(username)
        let pass = passwordField()
        pass.tap()
        pass.typeText(password)
        loginButton().tap()
    }

    func tapCancel() {
        tap(cancelButton())
    }

    func tapBrowserFallback() {
        tap(browserFallbackButton())
    }

    /// Opens the options sheet, applies the Native client configuration through the JSON import
    /// (consumerKey, redirectUri, communityUrl, useDPoP, useHybridFlow), and closes the sheet.
    func configure(consumerKey: String, redirectUri: String, communityUrl: String, useDPoP: Bool, useHybridFlow: Bool) {
        tap(optionsButton())
        let json: [String: Any] = [
            "consumerKey": consumerKey,
            "redirectUri": redirectUri,
            "communityUrl": communityUrl,
            "useDPoP": useDPoP,
            "useHybridFlow": useHybridFlow
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []),
              let text = String(data: data, encoding: .utf8) else {
            XCTFail("Could not build native login config JSON")
            return
        }
        tap(importButton())
        let alert = app.alerts["Import Native Login Configuration"]
        XCTAssertTrue(alert.waitForExistence(timeout: UITestTimeouts.long), "Native config import alert did not appear")
        alert.textFields.firstMatch.typeText(text)
        alert.buttons["Import"].tap()
        tap(applyButton())
        // Applying may restart authentication, which replaces the form and its sheet; otherwise close the screen.
        if closeButton().waitForExistence(timeout: UITestTimeouts.short), closeButton().isHittable {
            closeButton().tap()
        }
        XCTAssertTrue(loginButton().waitForExistence(timeout: UITestTimeouts.long), "Native form did not return after closing options")
    }

    // MARK: - Accessors

    private func usernameField() -> XCUIElement { app.textFields["nativeUsernameField"] }
    private func passwordField() -> XCUIElement { app.secureTextFields["nativePasswordField"] }
    private func loginButton() -> XCUIElement { app.buttons["nativeLoginButton"] }
    private func cancelButton() -> XCUIElement { app.buttons["nativeCancelButton"] }
    private func optionsButton() -> XCUIElement { app.buttons["nativeLoginOptionsButton"] }
    private func browserFallbackButton() -> XCUIElement { app.buttons["nativeBrowserFallbackButton"] }
    private func importButton() -> XCUIElement { app.buttons["importNativeConfigButton"] }
    private func applyButton() -> XCUIElement { app.buttons["nativeApplyButton"] }
    private func closeButton() -> XCUIElement { app.buttons["loginOptionsCloseButton"] }
    private func resultLabel() -> XCUIElement { app.staticTexts["nativeResultLabel"] }
    private func errorDetailLabel() -> XCUIElement { app.staticTexts["nativeErrorDetail"] }
    private func diagnosticsLabel() -> XCUIElement { app.staticTexts["nativeDiagnosticsLabel"] }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = UITestTimeouts.long, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element \(element.debugDescription) did not appear within \(timeout)s", file: file, line: line)
        element.tap()
    }
}
