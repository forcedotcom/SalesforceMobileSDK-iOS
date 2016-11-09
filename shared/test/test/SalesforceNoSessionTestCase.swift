/*
SalesforceNoSessionTestCase.swift

Created by Eric Engelking on 10/16/15.
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
import SalesforceSDKCore

class SalesforceNoSessionTestCase: XCTestCase {
    var loginAccounts : [NSDictionary?] = []
    var accountWithPasscode : NSDictionary!
    var passcodeTimeout: UInt32?
    var passcodeLength: UInt32?
    var passcode: String = ""
    var app = XCUIApplication()
    var searchScreen = SearchScreen()
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = true
        app.launch()
        let loginInfo: [NSDictionary?] = TestSetupUtils.populateUILoginInfoFromConfigFile(for: type(of: self)) as! [NSDictionary]
        loginAccounts = loginInfo
        accountWithPasscode = loginAccounts[loginAccounts.count-1] as NSDictionary! //assuming last account has passcode enabled
        if (accountWithPasscode.value(forKey: "passcodeTimeout") != nil && accountWithPasscode.value(forKey: "passcodeLength") != nil) {
            passcodeTimeout = (accountWithPasscode.value(forKey: "passcodeTimeout")! as AnyObject).uint32Value!
            passcodeLength = (accountWithPasscode.value(forKey: "passcodeLength")! as AnyObject).uint32Value!
        
            for _ in 0..<passcodeLength! {
                passcode = randomPasscode()
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        searchScreen.logout()
    }
    
    func randomPasscode() -> String {
        srandom(UInt32(time(nil)))
        var randomPass = ""
        for _ in 0..<passcodeLength! {
            randomPass = randomPass.appendingFormat(String (format: "%d", arc4random()%10))
        }
        return randomPass
    }
}
