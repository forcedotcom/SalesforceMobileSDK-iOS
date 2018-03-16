/*
 SalesforceSwiftSDKTests
 Created by Raj Rao on 11/27/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCore
import PromiseKit
@testable import SalesforceSwiftSDK

class SalesforceSwiftSDKTests: SalesforceSwiftSDKBaseTest {
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
     }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    override class func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
         super.tearDown()
    }

    func testConfiguration() {
        XCTAssertNotNil(SalesforceSwiftSDKTests.testConfig)
        XCTAssertNotNil(SalesforceSwiftSDKTests.testCredentials)
        SalesforceSwiftSDKManager.Builder.configure { (appconfig: SFSDKAppConfig) -> Void in
            appconfig.shouldAuthenticate = false
            appconfig.oauthScopes = ["web", "api"]
            appconfig.remoteAccessConsumerKey = (SalesforceSwiftSDKTests.testConfig?.testClientId)!
            appconfig.oauthRedirectURI = (SalesforceSwiftSDKTests.testConfig?.testRedirectUri)!
        }.done()

        XCTAssertNotNil(SalesforceSDKManager.shared().appConfig)
        XCTAssertTrue(!((SalesforceSDKManager.shared().appConfig?.shouldAuthenticate)!)
                      , "SalesforceSDKManager should have been configured to not authenticate")
        XCTAssertTrue(SalesforceSDKManager.shared().appConfig?.remoteAccessConsumerKey == SalesforceSwiftSDKTests.testConfig?.testClientId
                      , "SalesforceSDKManager should have been configured to use correct consumer key")
        XCTAssertTrue(SalesforceSDKManager.shared().appConfig?.oauthRedirectURI == SalesforceSwiftSDKTests.testConfig?.testRedirectUri
                      , "SalesforceSDKManager should have been configured to use correct redirect url")
    }
    
    func testPostLaunchBlock() {
        XCTAssertNotNil(SalesforceSwiftSDKTests.testConfig)
        XCTAssertNotNil(SalesforceSwiftSDKTests.testCredentials)
        let expectation = self.expectation(description: "launched")
        SalesforceSwiftSDKManager.Builder.postLaunch { action in
            expectation.fulfill()
        }.done()
        SalesforceSDKManager.shared().launch()
        wait(for: [expectation], timeout: 10)
    }
    
    func testSwitchUserBlock() {
        XCTAssertNotNil(SalesforceSwiftSDKTests.testConfig)
        XCTAssertNotNil(SalesforceSwiftSDKTests.testCredentials)
        let currentOrigUser = SFUserAccountManager.sharedInstance().currentUser
        let expectation = self.expectation(description: "switched")
        let newUser = self.createNewUser(indx: 1)
        SalesforceSwiftSDKManager.Builder.switchUser { from,to in
            expectation.fulfill()
        }.done()
        SFUserAccountManager.sharedInstance().switch(toUser: newUser)
        SFUserAccountManager.sharedInstance().currentUser = currentOrigUser
        wait(for: [expectation], timeout: 10)
    }
    
    func testAccessToken() {
        XCTAssertNotNil(SalesforceSwiftSDKTests.testCredentials?.accessToken)
        XCTAssertNotNil(SalesforceSwiftSDKTests.testCredentials?.instanceUrl)
    }
   
}
