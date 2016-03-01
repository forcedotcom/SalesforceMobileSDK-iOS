/*
SmartSyncExplorerUITests.swift
SmartSyncExplorerUITests

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


import XCTest

class SmartSyncExplorerTest: SalesforceTestCase {
    
    // MARK: Setup
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        hitLogoutIfPossible()
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testCreateSaveSearchOpen() {
        let uids = createLocally(3)
        for uid in uids {
            searchAndOpen(uid);
        }
    }

    // MARK: Helper methods

    // Create n records and return their uid's
    func createLocally(n:Int) -> [Int] {
        var result : [Int] = []
        
        for (var i=0; i<n; i++) {
            let uid = self.uid()
            result.append(uid)
            
            hitAddInSearchScreen()
            fillDetailScreen(uid)
            hitButtonInDetailScreen("Save")
        }
        
        return result;
    }
    
    // Search for record uid and open detail screen
    func searchAndOpen(uid:Int) {
        searchFor(uid)
        checkSearchResultFor(uid)
        openDetailFor(uid)
        checkDetailScreen(uid)
        hitButtonInDetailScreen("Contacts")
    }
    
    func hitLogoutIfPossible() {
        let app = XCUIApplication()
        let contactsNavigationBar = app.navigationBars["Contacts"]
        if (contactsNavigationBar.exists) {
            contactsNavigationBar.buttons["Share"].tap()
            app.tables.staticTexts["Logout current user"].tap()
            app.sheets["Are you sure you want to log out?"].collectionViews.buttons["Confirm Logout"].tap()
        }
    }
    
    func searchFor(uid: Int) {
        let tablesQuery = XCUIApplication().tables
        let searchSearchField = tablesQuery.searchFields["Search"]
        searchSearchField.tap()
        if (searchSearchField.buttons["Clear text"].exists) {
            searchSearchField.buttons["Clear text"].tap()
        }
        searchSearchField.tap()
        searchSearchField.typeText("fn\(uid)")
    }
    
    func checkSearchResultFor(uid: Int) {
        let tablesQuery = XCUIApplication().tables
        XCTAssert(tablesQuery.cells.count == 1)
        XCTAssert(tablesQuery.staticTexts["fn\(uid) ln\(uid)"].exists)
        XCTAssert(tablesQuery.staticTexts["t\(uid)"].exists)
    }
    
    func openDetailFor(uid: Int) {
        let tablesQuery = XCUIApplication().tables
        tablesQuery.staticTexts["fn\(uid) ln\(uid)"].tap()
    }
    
    func hitAddInSearchScreen() {
        let contactsNavigationBar = XCUIApplication().navigationBars["Contacts"]
        contactsNavigationBar.buttons["add"].tap()
    }
    
    func hitButtonInDetailScreen(label: String) {
        let contactdetailviewNavigationBar = XCUIApplication().navigationBars["ContactDetailView"]
        contactdetailviewNavigationBar.buttons[label].tap()
        
    }
    
    func fillDetailScreen(uid:Int) {
        fillField(0, value:"fn\(uid)")
        fillField(1, value:"ln\(uid)")
        fillField(2, value:"t\(uid)");
    }

    func checkDetailScreen(uid:Int) {
        hitButtonInDetailScreen("Edit")
        checkField(0, value:"fn\(uid)")
        checkField(1, value:"ln\(uid)")
        checkField(2, value:"t\(uid)");
        hitButtonInDetailScreen("Cancel")
    }
    
    func fillField(index: UInt, value: String) {
        let tablesQuery = XCUIApplication().tables
        let field = tablesQuery.childrenMatchingType(.Cell).elementBoundByIndex(index).childrenMatchingType(.TextField).element
        field.tap()
        field.tap()
        field.typeText(value);
    }
    
    
    func checkField(index: UInt, value: String) {
        let tablesQuery = XCUIApplication().tables
        let field = tablesQuery.childrenMatchingType(.Cell).elementBoundByIndex(index).childrenMatchingType(.TextField).element
        XCTAssertEqual(field.value as! String, value)
    }
    
    func uid() -> Int {
        return Int(arc4random_uniform(9000) + 1000);
    }
}