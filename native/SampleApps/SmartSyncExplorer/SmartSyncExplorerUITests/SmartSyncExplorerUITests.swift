//
//  SmartSyncExplorerUITests.swift
//  SmartSyncExplorerUITests
//
//  Created by Wolfgang Mathurin on 2/29/16.
//  Copyright © 2016 salesforce.com. All rights reserved.
//

import XCTest

class SmartSyncExplorerTest: SalesforceTestCase {
    
    func testCreateSaveSearch() {
        for (var i=0; i<3; i++) {
            createSaveSearch()
        }
    }
    
    func createSaveSearch() {
        let uid = self.uid()
        let app = XCUIApplication()
        
        // Record should not exist initially
        XCTAssert(!app.tables.staticTexts["fn\(uid)"].exists)
        XCTAssert(!app.tables.staticTexts["ln\(uid)"].exists)
        XCTAssert(!app.tables.staticTexts["t\(uid)"].exists)
        
        // Creating new record
        let contactsNavigationBar = app.navigationBars["Contacts"]
        contactsNavigationBar.buttons["add"].tap()
        self.fillField(0, value:"fn\(uid)")
        self.fillField(1, value:"ln\(uid)")
        self.fillField(2, value:"t\(uid)");
        
        // Saving
        let contactdetailviewNavigationBar = app.navigationBars["ContactDetailView"]
        contactdetailviewNavigationBar.buttons["Save"].tap()
        
        // Searching
        let searchSearchField = app.tables.searchFields["Search"]
        searchSearchField.tap()
        if (searchSearchField.buttons["Clear text"].exists) {
            searchSearchField.buttons["Clear text"].tap()
        }
        searchSearchField.tap()
        searchSearchField.typeText("fn\(uid)")
        
        // Checking search results
        XCTAssert(app.tables.cells.count == 1)
        XCTAssert(app.tables.staticTexts["fn\(uid) ln\(uid)"].exists)
        XCTAssert(app.tables.staticTexts["t\(uid)"].exists)
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
        XCTAssert(field.staticTexts[value].exists)
    }
    
    func uid()->Int {
        return Int(arc4random_uniform(9000) + 1000);
    }
}