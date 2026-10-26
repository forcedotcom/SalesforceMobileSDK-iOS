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

/// Page object for the SDK's debug Native Login form and the Authentication Mode section of the
/// SDK Login Options screen. Identifiers mirror `DebugNativeLoginView` and `AuthenticationModeView`.
class NativeLoginPageObject {
    /// Launch argument prefix carrying a Native Login configuration (see `configJSON`).
    static let configArgumentPrefix = "--nativeLoginConfig="
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
        clear(user, placeholder: "Username")
        user.typeText(username)
        let pass = passwordField()
        pass.tap()
        clear(pass, placeholder: "Password")
        pass.typeText(password)
        loginButton().tap()
    }

    /// The form keeps its text after a failed attempt; remove it so a retry doesn't append to it.
    private func clear(_ field: XCUIElement, placeholder: String) {
        guard let text = field.value as? String, !text.isEmpty, text != placeholder else { return }
        // Put the caret at the end first; deleting from the middle would leave text behind.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }

    func tapCancel() {
        tap(cancelButton())
    }

    func tapBrowserFallback() {
        tap(browserFallbackButton())
    }

    /// Opens the SDK Login Options screen, imports the Native Login configuration (with Native mode
    /// selected) through the JSON import, and closes the screen, which restarts authentication.
    func configure(consumerKey: String, redirectUri: String, communityUrl: String, useDPoP: Bool, useHybridFlow: Bool) {
        guard let text = Self.configJSON(consumerKey: consumerKey, redirectUri: redirectUri, communityUrl: communityUrl,
                                         useDPoP: useDPoP, useHybridFlow: useHybridFlow) else {
            XCTFail("Could not build native login config JSON")
            return
        }
        tap(optionsButton())
        tap(importButton())
        let alert = app.alerts["Import Native Login Configuration"]
        XCTAssertTrue(alert.waitForExistence(timeout: UITestTimeouts.long), "Native config import alert did not appear")
        alert.textFields.firstMatch.typeText(text)
        // The alert action is exposed as more than one element; any of them applies the import.
        let importById = alert.buttons.matching(identifier: "importNativeConfigApplyButton").firstMatch
        (importById.exists ? importById : alert.buttons.matching(identifier: "Import").firstMatch).tap()
        XCTAssertFalse(configErrorLabel().waitForExistence(timeout: UITestTimeouts.short),
                       "Native config import failed: \(configErrorLabel().label)")
        tap(closeButton())
        XCTAssertTrue(loginButton().waitForExistence(timeout: UITestTimeouts.long), "Native form did not return after closing options")
    }

    /// The `--nativeLoginConfig` / import JSON, in the schema shared with Android.
    static func configJSON(consumerKey: String, redirectUri: String, communityUrl: String, useDPoP: Bool, useHybridFlow: Bool) -> String? {
        let json: [String: Any] = [
            "authenticationMode": "native",
            "consumerKey": consumerKey,
            "redirectUri": redirectUri,
            "communityUrl": communityUrl,
            "useDPoP": useDPoP,
            "useHybridFlow": useHybridFlow
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Accessors

    private func usernameField() -> XCUIElement { app.textFields["nativeUsernameField"] }
    private func passwordField() -> XCUIElement { app.secureTextFields["nativePasswordField"] }
    private func loginButton() -> XCUIElement { app.buttons["nativeLoginButton"] }
    private func cancelButton() -> XCUIElement { app.buttons["nativeCancelButton"] }
    private func optionsButton() -> XCUIElement { app.buttons["nativeLoginOptionsButton"] }
    private func browserFallbackButton() -> XCUIElement { app.buttons["nativeBrowserFallbackButton"] }
    private func importButton() -> XCUIElement { app.buttons["importNativeConfigButton"] }
    private func configErrorLabel() -> XCUIElement { app.staticTexts["nativeConfigError"] }
    private func closeButton() -> XCUIElement { app.buttons["loginOptionsCloseButton"] }
    private func resultLabel() -> XCUIElement { app.staticTexts["nativeResultLabel"] }
    private func errorDetailLabel() -> XCUIElement { app.staticTexts["nativeErrorDetail"] }
    private func diagnosticsLabel() -> XCUIElement { app.staticTexts["nativeDiagnosticsLabel"] }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = UITestTimeouts.long, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element \(element.debugDescription) did not appear within \(timeout)s", file: file, line: line)
        element.tap()
    }
}
