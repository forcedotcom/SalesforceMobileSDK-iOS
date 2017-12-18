/*
PasscodeUITests.swift
PasscodeUITests

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


import XCTest

class PasscodeUITest: SalesforceNoSessionTestCase {
    
    let loginHelper = LoginHelper()
    let loginPage = LoginPage()
    let hostPage = HostPage()
    let userListScreen = UserListScreen()
    let passcodePage = PasscodePage()
    
    // MARK: Setup
    override func setUp() {
        super.setUp()
        XCTAssertNotNil(passcodeTimeout, "Expect passcode timeout defined")
        XCTAssertNotNil(passcodeLength, "Expect passcode length defined")
        print("Passcode:" + passcode)
        loginPage.waitForPageLoaded()
    }
    
    override func tearDown() {
        loginPage.waitForPageLoaded()
        super.tearDown()
    }
    
    // MARK: Tests
    func testPasscode() {
        let user = accountWithPasscode.value(forKey: "username") as! String
        let password = accountWithPasscode.value(forKey: "password") as! String
        let host = accountWithPasscode.value(forKey: "host") as! String
        loginHelper.loginToSalesforce(user, password: password, url: host, withPasscode: passcode)
        
        //verify activity timeout
        sleep(passcodeTimeout! - 10)
        XCTAssertFalse(passcodePage.isPresented()) //should not present passcode
        sleep(15)
        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying) //should present passcode
        
        //verify passcode enter
        passcodePage.verifyPasscode(getDifferentString())
        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying) //should
        passcodePage.verifyPasscode(getDifferentString())
        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying) //should
        
        passcodePage.enterPasscode(passcode)
        backspace(1) //backspace
        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying)
        passcodePage.enterPasscode(String(passcode[passcode.index(passcode.endIndex, offsetBy: -1)...]))
        passcodePage.done()
        XCTAssertFalse(passcodePage.isPresented()) //should not present passcode
        
        //TODO: verify background/foreground after timeout
//        XCUIDevice().press(XCUIDeviceButton.home)
//        sleep(passcodeTimeout! + 5)
//        app.resolve()
//        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying)
        
        //verify app resume after timeout
        app.launch()
        XCTAssertTrue(passcodePage.isPresented() && passcodePage.getStatus()==PasscodeStatus.verifying)
        
        //verify forgot passcode
        passcodePage.forgotPasscode(true)
        loginPage.waitForPageLoaded()
        XCTAssertTrue(loginPage.isPresenting())
 
    }
    
    func getDifferentString() -> String {
        var differentPass = "";
        while true {
            differentPass = randomPasscode()
            if (differentPass != passcode) {
                return differentPass
            }
        }
    }
    
    func backspace(_ number: UInt32) {
        for _ in 0..<number {
            app.keys["Delete"].tap()
        }
    }
}
