//
//  SFSDKAuthUtilTests.swift
//  SalesforceSDKCoreTests
//
//  Created by Raj Rao on 7/16/19.
//  Copyright © 2019 salesforce.com. All rights reserved.
//

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
