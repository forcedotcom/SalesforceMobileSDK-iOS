/*
OAuthUITests.swift
OAuthUITests

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

class OAuthUITest: SalesforceNoSessionTestCase {
    
    let loginHelper = LoginHelper()
    
    // MARK: Setup
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: Tests
    func testLogin5Users() {
        // add uit1 user
        loginHelper.loginToSalesforce("uit1@cs1.mobilesdk.org", password:swiftDict["password"]!, host: Host.sandbox)
        //add uit2 user
        SearchScreen().logout()
        loginHelper.loginToSalesforce("uit2@cs1.mobilesdk.org", password:swiftDict["password"]!, host: Host.sandbox)
        
        let app = XCUIApplication()
        app.navigationBars["Log In"].buttons["Choose Connection"].tap()
        
        let tablesQuery = app.tables
        tablesQuery.staticTexts["Sandbox"].tap()
        
        let loginSalesforceElement = app.webViews.otherElements["Login | Salesforce"]
        loginSalesforceElement.childrenMatchingType(.TextField).element
        loginSalesforceElement.childrenMatchingType(.SecureTextField).element
        
        let shareButton = app.navigationBars["Contacts"].buttons["Share"]
        shareButton.tap()
        tablesQuery.staticTexts["Switch user"].tap()
        app.navigationBars["User List"].buttons["Cancel"].tap()
        shareButton.tap()
        
        let app = XCUIApplication()
        app.navigationBars["User List"].buttons["New User"].tap()
        app.navigationBars["Log In"].buttons["Choose Connection"].tap()
        app.navigationBars["Choose Connection"].buttons["Cancel"].tap()
        
        let loginSalesforceElement = app.webViews.otherElements["Login | Salesforce"]
        loginSalesforceElement.childrenMatchingType(.TextField).element
        loginSalesforceElement.childrenMatchingType(.SecureTextField).element
        app.navigationBars["Contacts"].buttons["Share"].tap()
        app.tables.staticTexts["Bring up user switching screen"].tap()
        
        let app = XCUIApplication()
        app.buttons["Switch to User"].tap()
        app.navigationBars["Contacts"].buttons["Share"].tap()
        
        
    }
    
    func testSwitchBetween5Users() {
        
    }
    
    func testLogout5Users() {
    }
    
    
    func testCommunityUserLogin() {
        
    }
    
    func testDifferentUserTypeLogin() {
        
    }
    
    func testRevoke() {
        
    }
    
    
    
}