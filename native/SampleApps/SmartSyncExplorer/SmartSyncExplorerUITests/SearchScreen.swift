/*
SearchScreen.swift

Copyright (c) 2016, salesforce.com, inc. All rights reserved.

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
    
    private var searchField: XCUIElement {
        get {
            return app.tables.searchFields["Search"]
        }
    }
    
    private var clearSearchButton: XCUIElement {
        get {
            // Only available after search field is tapped
            return searchField.buttons["Clear text"];
        }
    }
    
    
    private var navigationBar : XCUIElement {
        get {
            return app.navigationBars["Contacts"]
        }
    }
    
    private var shareButton : XCUIElement {
        get {
            return navigationBar.buttons["Share"]
        }
    }

    private var addButton : XCUIElement {
        get {
            return navigationBar.buttons["add"]
        }
    }
    
    private var logoutButton : XCUIElement {
        get {
            // Only available after share button is tapped
            return app.tables.staticTexts["Logout current user"]
        }
    }
    
    private var switchUserButton : XCUIElement {
        get {
            // Only available after share button is tapped
            return app.tables.staticTexts["Switch user"]
        }
    }
    
    private var confirmLogoutButton : XCUIElement {
        get {
            // Only available after logout button is tapped
            return app.sheets["Are you sure you want to log out?"].collectionViews.buttons["Confirm Logout"]
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
        return app.tables.cells.count
    }
    
    func hasRecord(text : String) -> Bool {
        return app.tables.staticTexts[text].exists
    }
    
    
    // MARK - Act on screen
    
    func addRecord() -> DetailScreen {
        addButton.tap()
        return DetailScreen()
    }
    
    func clearSearch() -> SearchScreen {
        searchField.tap()
        if (clearSearchButton.exists) {
            clearSearchButton.tap()
        }
        return self
    }
    
    func typeSearch(query: String) -> SearchScreen {
        searchField.tap()
        searchField.typeText(query)
        return self
    }
    
    func logout() -> LoginPage? {
        if (navigationBar.exists) {
            shareButton.tap()
            logoutButton.tap()
            confirmLogoutButton.tap()
            return LoginPage()
        }
        return nil;
    }
    
    
    func switchUser() -> UserListScreen? {
        if (navigationBar.exists) {
            shareButton.tap()
            switchUserButton.tap()
            return UserListScreen()
        }
        return nil;
    }
    
    func openRecord(text :  String) -> DetailScreen {
        app.tables.staticTexts[text].tap()
        return DetailScreen()
    }
}