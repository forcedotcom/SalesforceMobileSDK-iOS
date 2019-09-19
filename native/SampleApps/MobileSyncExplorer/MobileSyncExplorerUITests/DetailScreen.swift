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

class DetailScreen: PageObject {
    fileprivate var firstNameField : XCUIElement {
        get {
            let tablesQuery = XCUIApplication().tables
            return tablesQuery.children(matching: .cell).element(boundBy: 0).children(matching: .textField).element
        }
    }

    fileprivate var lastNameField : XCUIElement {
        get {
            let tablesQuery = XCUIApplication().tables
            return tablesQuery.children(matching: .cell).element(boundBy: 1).children(matching: .textField).element
        }
    }
    
    fileprivate var titleField : XCUIElement {
        get {
            let tablesQuery = XCUIApplication().tables
            return tablesQuery.children(matching: .cell).element(boundBy: 2).children(matching: .textField).element
        }
    }
    
    fileprivate var navigationBar : XCUIElement {
        get {
            return app.navigationBars["ContactDetailView"]
        }
    }
    
    fileprivate var saveButton : XCUIElement {
        get {
            return navigationBar.buttons["Save"]
        }
    }

    fileprivate var cancelButton : XCUIElement {
        get {
            return navigationBar.buttons["Cancel"]
        }
    }
    
    fileprivate var editButton : XCUIElement {
        get {
            return navigationBar.buttons["Edit"]
        }
    }
    
    fileprivate var contactsButton : XCUIElement {
        get {
            return navigationBar.buttons["Contacts"]
        }
    }

    // MARK - Check screen
    
    func hasFirstName(_ firstName : String) -> Bool {
        return firstNameField.value as! String == firstName
    }

    func hasLastName(_ lastName : String) -> Bool {
        return lastNameField.value as! String == lastName
    }

    func hasTitle(_ title : String) -> Bool {
        return titleField.value as! String == title
    }
    
    // MARK - Act on screen
    
    @discardableResult func typeFirstName(_ firstName: String) -> DetailScreen {
        firstNameField.tap()
        firstNameField.typeText(firstName)
        return self
    }

    @discardableResult func typeLastName(_ lastName: String) -> DetailScreen {
        lastNameField.tap()
        lastNameField.typeText(lastName)
        return self
    }

    @discardableResult func typeTitle(_ title: String) -> DetailScreen {
        titleField.tap()
        titleField.typeText(title)
        return self
    }
    
    @discardableResult func save() -> SearchScreen {
        saveButton.tap()
        return SearchScreen()
    }
    
    @discardableResult func edit() -> DetailScreen {
        editButton.tap()
        return self
    }
    
    @discardableResult func cancel() -> DetailScreen {
        cancelButton.tap()
        return self
    }
    
    @discardableResult func backToSearch() -> SearchScreen {
        contactsButton.tap()
        return SearchScreen()
    }
}
