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
    
    func setUsername(name: String) -> Void {
        sleep(3)
        hideKeyboard()
        let nameField = app.descendants(matching: .textField).element
        _ = nameField.waitForExistence(timeout: timeout * 12)
        nameField.tap()
        sleep(1)
        nameField.typeText(name)
    }
    
    func setPassword(password: String) -> Void {
        hideKeyboard()
        let passwordField = app.descendants(matching: .secureTextField).element
        _ = passwordField.waitForExistence(timeout: timeout)
        passwordField.tap()
        sleep(1)
        passwordField.typeText(password)
    }
    
    func tapLogin() -> Void {
        hideKeyboard()
        let loginButton = app.webViews.webViews.webViews.buttons["Log In"]
        _ = loginButton.waitForExistence(timeout: timeout)
        loginButton.tap()
    }
    
    func tapBack() -> Void {
        let backButton = app.navigationBars["Log In"].children(matching: .button).element(boundBy: 0)
        _ = backButton.waitForExistence(timeout: timeout)
        backButton.tap()
    }
    
    func hideKeyboard() -> Void {
        let continueButton = app.staticTexts["Continue"]
        if continueButton.exists {
            continueButton.tap()
        }
        
        let doneButton = app.toolbars.matching(identifier: "Toolbar").buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }
}

