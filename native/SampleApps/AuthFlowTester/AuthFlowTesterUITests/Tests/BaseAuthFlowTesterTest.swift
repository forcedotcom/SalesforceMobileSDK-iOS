/*
 BaseAuthFlowTesterTest.swift
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

import XCTest

class BaseAuthFlowTesterTest: XCTestCase {
    // App object
    var app: XCUIApplication!

    // App Pages
    var loginPage: LoginPageObject!
    var authPage: AuthorizationPageObject!
    var mainPage: AuthFlowTesterMainPageObject!

    // Login credentials
    var username: String = ""
    var password: String = ""
    
    // Default timeout
    var timeout: double_t = 10

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        // Get credentials from environment variables
//        let envUsername = ProcessInfo.processInfo.environment["USERNAME"] ?? ""
//        username = envUsername.isEmpty ? "circleci@mobilesdk.com" : envUsername
//        password = ProcessInfo.processInfo.environment["PASSWORD"] ?? ""
        
        // XXX do not check in
        username = "wmathurin@gs0.mobilesdk.com"
        password = "test123456"
        
        app = XCUIApplication()
        loginPage = LoginPageObject(testApp: app)
        authPage = AuthorizationPageObject(testApp: app)
        mainPage = AuthFlowTesterMainPageObject(testApp: app)
    }
    
    override func tearDown() {
        
        // TODO should we logout
        
        super.tearDown()
    }
    
    func performLogin() {

        app.launch()
        
        // Remove this check once we can get login to run without 2FA
        if (!mainPage.waitForMainScreen()) {            
            loginPage.setUsername(name: username)
            loginPage.setPassword(password: password)
            loginPage.tapLogin()
            
            authPage.tapAllowIfPresent()
        }
    }
    
    func assertAuthFlowTesterLoads(mainPage: AuthFlowTesterMainPageObject) {
        XCTAssert(mainPage.waitForMainScreen(), "AuthFlowTester did not load.")
    }
    
    func assertUserLoggedIn(mainPage: AuthFlowTesterMainPageObject, username: String) {
        // Expand the User Credentials section
        mainPage.expandUserCredentials()
        
        // Verify username appears in the UI
        XCTAssert(mainPage.waitForUsername(username: username), "Username '\(username)' not found in User Credentials")
    }
    
    func assertRestRequestWorks(mainPage: AuthFlowTesterMainPageObject) {
        // Tap the Make REST API Request button
        mainPage.tapMakeRestRequest()
        
        // Wait for request to complete and verify success
        XCTAssert(mainPage.isRestRequestSuccessful(), "REST API request did not succeed")
    }
}

