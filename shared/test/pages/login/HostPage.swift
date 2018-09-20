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

class HostPage: PageObject, PageThatWaits {

    fileprivate var ChooseConnectionButton: XCUIElement {
        get {
            return app.navigationBars["Log In"].buttons["Choose Connection"]
        }
    }
    
    fileprivate var AddConnectionButton: XCUIElement {
        get {
            return app.navigationBars["Choose Connection"].buttons["Add"]
        }
    }
    
    fileprivate var CancelConnectionButton: XCUIElement {
        get {
            return app.navigationBars["Choose Connection"].buttons["Cancel"]
        }
    }
    
    fileprivate var BackConnectionButton: XCUIElement {
        get {
            return app.navigationBars["Add Connection"].buttons["Back"]
        }
    }
    
    fileprivate var DoneAdd: XCUIElement {
        get {
            return app.navigationBars["Add Connection"].buttons["Done"]
        }
    }
    
    fileprivate var HostField: XCUIElement {
        get {
            return app.tables.textFields["Host (Example: login.salesforce.com)"]
        }
    }
    
    fileprivate var LabelField: XCUIElement {
        get {
            return app.tables.textFields["Label (Optional)"]
        }
    }
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(AddConnectionButton)
        
    }
    
    func waitForPageLoaded() {
        waitForElementExists(AddConnectionButton)
    }

    // MARK: Act on screen
    
    @discardableResult func chooseConnection(_ host: String) -> LoginPage {
        app.tables.staticTexts[host].tap()
        return LoginPage()
    }
    
    
    func setLabel(_ label: String) {
        LabelField.tap()
        LabelField.typeText(label)
    }
    
    func setHost(_ host: String) {
        HostField.tap()
        HostField.typeText(host)
    }
    
    
    @discardableResult  func addAndChooseConnection(_ label: String, host: String!) -> LoginPage {
        AddConnectionButton.tap()
        setLabel(label)
        setHost(host)
        DoneAdd.tap()
        let loginPage = LoginPage()
        loginPage.waitForPageLoaded()
        return loginPage
    }
    
    
    func addAndCancel(_ toLogin: Bool) {
        waitForElementEnabled(app.navigationBars["Choose Connection"].buttons["Add"])
        AddConnectionButton.tap()
        setHost("dummy")
        BackConnectionButton.tap()
        if (toLogin) {
            CancelConnectionButton.tap()
        }
    }

    @discardableResult func selectHost(_ host: String) -> LoginPage {
        if (!app.tables.staticTexts[host].exists) {
            addAndChooseConnection("", host: host)
        }
        else {
            app.tables.staticTexts[host].tap()
        }
        let loginPage = LoginPage()
        loginPage.waitForPageLoaded()
        return loginPage
    }
     
    func deleteHost(_ label: String!) {
        app.tables.staticTexts[label].swipeLeft()
        app.tables.buttons["Delete"].tap()
    }
    
}
