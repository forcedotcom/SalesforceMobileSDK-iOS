/*
SearchScreen.swift

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

class SearchScreen: PageObject {
    
    fileprivate var searchField: XCUIElement {
        get {
            return app.tables.searchFields["Search"]
        }
    }
    
    fileprivate var clearSearchButton: XCUIElement {
        get {
            // Only available after search field is tapped
            return searchField.buttons["Clear text"];
        }
    }
    
    
    fileprivate var navigationBar : XCUIElement {
        get {
            return app.navigationBars["Contacts"]
        }
    }
    
    fileprivate var syncButton: XCUIElement {
        get {
            return app.navigationBars["Contacts"].buttons["sync"]
        }
    }
    
    fileprivate var shareButton : XCUIElement {
        get {
            return navigationBar.buttons["Share"]
        }
    }

    fileprivate var addButton : XCUIElement {
        get {
            return navigationBar.buttons["add"]
        }
    }
    
    fileprivate var logoutButton : XCUIElement {
        get {
            // Only available after share button is tapped
            return app.tables.staticTexts["Logout current user"]
        }
    }
    
    fileprivate var switchUserButton : XCUIElement {
        get {
            // Only available after share button is tapped
            return app.tables.staticTexts["Switch user"]
        }
    }
    
    fileprivate var confirmLogoutButton : XCUIElement {
        get {
            // Only available after logout button is tapped
            return app.sheets["Are you sure you want to log out?"].buttons["Confirm Logout"]
        }
    }
    
    func isPresenting() -> Bool {
        return navigationBar.exists
    }
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(navigationBar)
        
    }
    
    func waitForPageLoaded() {
        waitForElementExists(navigationBar)
    }

    // MARK - Check screen
    
    func countRecords() -> UInt {
        return UInt(app.tables.cells.count)
    }
    
    func hasRecord(_ text : String) -> Bool {
        return app.tables.staticTexts[text].exists
    }
    
    // MARK - Act on screen
    
    func sync() {
        syncButton.tap()
    }
    
    func addRecord() -> DetailScreen {
        addButton.tap()
        return DetailScreen()
    }
    
    @discardableResult func clearSearch() -> SearchScreen {
        searchField.tap()
        if (clearSearchButton.exists) {
            clearSearchButton.tap()
        }
        return self
    }
    
    @discardableResult func typeSearch(_ query: String) -> SearchScreen {
        searchField.tap()
        searchField.typeText(query)
        return self
    }
    
    @discardableResult  func logout() -> LoginPage? {
        if (navigationBar.exists) {
            shareButton.tap()
            logoutButton.tap()
            return LoginPage()
        }
        return nil;
    }
    
    
    @discardableResult  func switchUser() -> UserListScreen? {
        if (navigationBar.exists) {
            shareButton.tap()
            switchUserButton.tap()
            return UserListScreen()
        }
        return nil;
    }
    
    func openRecord(_ text :  String) -> DetailScreen {
        app.tables.staticTexts[text].tap()
        return DetailScreen()
    }
    
    
    func openRecord(_ cell :  UInt) {
        app.tables.cells.element.tap()
    }
}
