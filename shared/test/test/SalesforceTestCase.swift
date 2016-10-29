/*
SalesforceTestCase.swift

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

class SalesforceTestCase: XCTestCase {
    
    var loginDelegate = LoginHelper()
    var app = XCUIApplication()
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = true
        app.launch()
        loginThroughUI()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func loginThroughUI() {
        let loginInfo = TestSetupUtils.populateUILoginInfoFromConfigFile(for: type(of: self)) as! [NSDictionary]
        let swiftDict : NSMutableDictionary = NSMutableDictionary()
        for key : Any in (loginInfo[0].allKeys) {
            let stringKey = key as! String
            if let keyValue = loginInfo[0].value(forKey: stringKey){
                swiftDict[stringKey] = String(describing: keyValue)
            }
        }
        loginDelegate.loginToSalesforce(swiftDict["username"]! as! String, password:swiftDict["password"]! as! String, url:swiftDict["host"]! as! String)
    }

}
