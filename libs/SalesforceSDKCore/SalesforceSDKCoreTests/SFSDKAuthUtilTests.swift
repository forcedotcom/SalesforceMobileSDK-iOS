/*
 SFSDKAuthUtilTests.swift
 SalesforceSDKCoreTests
 
 Created by Raj Rao on 7/25/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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
import Foundation
@testable import SalesforceSDKCore

class SFSDKAuthUtilTests: XCTestCase {
    
    var currentUser: UserAccount?
    
    override class func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        SFSDKLogoutBlocker.block()
        TestSetupUtils.populateAuthCredentialsFromConfigFile(for: SFSDKAuthUtilTests.self)
        TestSetupUtils.synchronousAuthRefresh()
    }
    
    override func setUp() {
        currentUser = UserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAccessToken() {
        let expectation = XCTestExpectation(description: "finished")
        XCTAssertNotNil(currentUser)
        let request = SFSDKOAuthTokenEndpointRequest()
        request.refreshToken = currentUser?.credentials.refreshToken ??  ""
        request.redirectURI = UserAccountManager.shared.oauthCompletionURL
        request.clientID = UserAccountManager.shared.oauthClientID
        
        if let url = URL(string: UserAccountManager.shared.loginHost) {
            request.serverURL = url
        }
        
        XCTAssertNotNil(request)
        let oauthClient = SFSDKOAuth2()
        var endpointResponse:SFSDKOAuthTokenEndpointResponse? =  nil
        oauthClient.accessToken(forRefresh: request) { (response) in
            print("Done!")
            endpointResponse = response
            expectation.fulfill()
        }
        
        self.wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(endpointResponse)
        XCTAssertFalse(endpointResponse!.hasError)
        XCTAssertNotNil(endpointResponse!.accessToken)
        XCTAssertNil(endpointResponse!.refreshToken)
        XCTAssertNotNil(endpointResponse!.scopes)
        XCTAssertNotNil(endpointResponse!.instanceUrl)
        XCTAssertNotNil(endpointResponse!.signature)
        XCTAssertNotNil(endpointResponse!.issuedAt)
    }
    
    func testAccessTokenInvalidClientIdError() {
        let expectation = XCTestExpectation(description: "finished")
        XCTAssertNotNil(currentUser)
        let request = SFSDKOAuthTokenEndpointRequest()
        request.refreshToken = currentUser?.credentials.refreshToken ??  ""
        request.redirectURI = UserAccountManager.shared.oauthCompletionURL
        request.clientID = "DUMMY_CLIENT_ID"
        
        if let url = URL(string: UserAccountManager.shared.loginHost) {
            request.serverURL = url
        }
        
        XCTAssertNotNil(request)
        let oauthClient = SFSDKOAuth2()
        
        var endpointResponse:SFSDKOAuthTokenEndpointResponse? =  nil
        oauthClient.accessToken(forRefresh: request) { (tokenResponse) in
            print("Done!")
            endpointResponse = tokenResponse
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
        XCTAssertNotNil(endpointResponse)
        let response = try! require(endpointResponse)
        XCTAssertTrue(response.hasError)
        let error = try! require(response.error)
        XCTAssertTrue((error.error as NSError).code == kSFOAuthErrorInvalidClientId)
    }
    
    func testAccessTokenInvalidGrant() {
        let expectation = XCTestExpectation(description: "finished")
        XCTAssertNotNil(currentUser)
        let request = SFSDKOAuthTokenEndpointRequest()
        request.refreshToken = "dummy_refresh_token"
        request.redirectURI = "bad://redirect"
        request.clientID = UserAccountManager.shared.oauthClientID
        
        if let url = URL(string: UserAccountManager.shared.loginHost) {
            request.serverURL = url
        }
        
        XCTAssertNotNil(request)
        let oauthClient = SFSDKOAuth2()
        
        var endpointResponse:SFSDKOAuthTokenEndpointResponse? =  nil
        oauthClient.accessToken(forRefresh: request) { (tokenResponse) in
            print("Done!")
            endpointResponse = tokenResponse
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
        XCTAssertNotNil(endpointResponse)
        let response = try! require(endpointResponse)
        let error = try! require(response.error)
        XCTAssertTrue((error.error as NSError).code == kSFOAuthErrorInvalidGrant)
    }
    
}
