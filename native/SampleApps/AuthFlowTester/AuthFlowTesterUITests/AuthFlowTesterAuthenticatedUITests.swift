/*
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

/// Tests for the authenticated state - Session Detail screen
/// These tests require test_credentials.json to be properly configured
final class AuthFlowTesterAuthenticatedUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    // Expected values loaded from test_credentials.json
    var expectedUsername: String!
    var expectedInstanceUrl: String!
    var expectedConsumerKey: String!
    var expectedRedirectURI: String!
    var expectedDisplayName: String!
    var expectedScopes: String!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Load test credentials from test_credentials.json
        let credentials = try TestCredentials.loadFromBundle()
        expectedUsername = credentials.username
        expectedInstanceUrl = credentials.instanceUrl
        expectedConsumerKey = credentials.clientId
        expectedRedirectURI = credentials.redirectUri
        expectedDisplayName = credentials.displayName
        expectedScopes = credentials.scopes
        
        try TestHelper.launchWithCredentials(app)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Session Detail Screen Tests
    
//    func testSessionDetailScreenIsVisible() throws {
//        // Verify we're on the session detail screen (not config picker)
//        XCTAssertTrue(app.navigationBars["AuthFlowTester"].waitForExistence(timeout: 10))
//        
//        // Should see authenticated UI elements
//        XCTAssertTrue(app.buttons["Revoke Access Token"].waitForExistence(timeout: 5))
//        XCTAssertTrue(app.buttons["Make REST API Request"].waitForExistence(timeout: 5))
//
//    }
    
    //
    // TODO write more tests
    //
}


