/*
LoginPage.swift

Created by Eric Engelking on 10/16/15.
Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

class LoginPage: PageObject, PageThatWaits {
    
    fileprivate var navigationBar: XCUIElement {
        get {
            return app.navigationBars["Log In"]
        }
    }
    
    fileprivate var chooseConnectionButton: XCUIElement {
        get {
            return navigationBar.buttons["Choose Connection"]
        }
    }
    
    fileprivate var webView: XCUIElement {
        get {
            return app.otherElements.element(matching: NSPredicate(format: "label BEGINSWITH[cd] 'Login |'"))
        }
    }
    
    fileprivate var userNameField: XCUIElement {
        get {
            return webView.children(matching: .textField).element
        }
    }
    
    fileprivate var passwordField: XCUIElement {
        get {
            return webView.children(matching: .secureTextField).element
        }
    }
    
    fileprivate var loginButton: XCUIElement {
        get {
            //TODO: Fix for Production, Mobile1, & Mobile2.  There is a bug that prevents us from using BEGINSWITH 'Log In'
            let buttonPredicate = NSPredicate(format: "label BEGINSWITH[cd] 'Log In'")
            return app.buttons.element(matching: buttonPredicate)

        }
    }
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(userNameField)
        
    }
    
    func waitForPageLoaded() {
        waitForElementExists(userNameField)
    }

    // MARK: Act on screen
    
    @discardableResult func setUserName(_ userName: String) -> LoginPage {
        userNameField.tap()
        sleep(1)
        userNameField.typeText(userName)
        return self
    }
    
    @discardableResult func setPassword(_ password: String) -> LoginPage {
        passwordField.tap()
        sleep(1)
        passwordField.typeText(password)
        return self
    }
    
    func login() -> AllowDenyPage {
        loginButton.tap()
        let allowDenyPage = AllowDenyPage()
        allowDenyPage.waitForPageLoaded()
        return allowDenyPage
        
    }
    
    @discardableResult func chooseConnection(_ host: Host?=nil) -> LoginPage {
        waitForElementEnabled(chooseConnectionButton)
        chooseConnectionButton.tap()
        if let wrappedHost = host {
            switch(wrappedHost) {
            case .production:
                app.tables.staticTexts["Production"].tap()
                break
            case .sandbox:
                app.tables.staticTexts["Sandbox"].tap()
                break
            }
        }
        return self;
    }
    
    func isPresenting() -> Bool {
        return navigationBar.exists
    }
    
    func scrollUp() {
        app.otherElements["Login | Salesforce"].swipeUp()
    }
    
}
