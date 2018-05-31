/*
 SalesforceSwiftSDKBaseTest
 Created by Raj Rao on 01/19/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
import SmartStore
@testable import SalesforceSwiftSDK

class SalesforceSwiftSDKBaseTest: XCTestCase {
    
    static var testCredentials: SFOAuthCredentials?
    static var testConfig: TestConfig?
    static var setupComplete = false
    
    override class func setUp() {
        super.setUp()
        SalesforceSwiftSDKManager.initSDK().shared().saveState()
        setupComplete = false
        _ = SalesforceSwiftSDKTests.readConfigFromFile(configFile: nil)
            .then { testJsonConfig -> Promise<SFUserAccount> in
                SalesforceSwiftSDKTests.testConfig = testJsonConfig
                SalesforceSwiftSDKTests.testCredentials?.accessToken = nil
                SalesforceSwiftSDKTests.testCredentials = SFOAuthCredentials(identifier: testJsonConfig.testClientId, clientId: testJsonConfig.testClientId, encrypted: true)
                SalesforceSwiftSDKTests.testCredentials?.refreshToken = SalesforceSwiftSDKTests.testConfig?.refreshToken
                SalesforceSwiftSDKTests.testCredentials?.redirectUri = SalesforceSwiftSDKTests.testConfig?.testRedirectUri
                SalesforceSwiftSDKTests.testCredentials?.domain = SalesforceSwiftSDKTests.testConfig?.testLoginDomain
                SalesforceSwiftSDKTests.testCredentials?.identityUrl = URL(string: (SalesforceSwiftSDKTests.testConfig?.identityUrl)!)
                SFUserAccountManager.sharedInstance().loginHost = SalesforceSwiftSDKTests.testConfig?.testLoginDomain
                return SalesforceSwiftSDKTests.refreshCredentials(credentials:(SalesforceSwiftSDKTests.testCredentials)!)
            }
            .then { userAccount -> Promise<Void> in
                SFUserAccountManager.sharedInstance().currentUser = userAccount
                return SFSmartStoreClient.removeAllGlobalStores()
            }
            .then { _  in
                return SFSmartStoreClient.removeAllSharedStores()
            }
            .done { userAccount in
                setupComplete = true
            }.catch { error  in
                setupComplete = true
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func setUp() {
        super.setUp()
        SalesforceSwiftSDKTests.waitForCompletion(maxWaitTime: 10) { () -> Bool in
            if (SalesforceSwiftSDKTests.setupComplete) {
                return true
            }
            return false
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    override class func tearDown() {
        SalesforceSwiftSDKManager.shared().restoreState()
        super.tearDown()
    }
    
}
