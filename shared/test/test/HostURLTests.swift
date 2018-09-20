/*
HostURLTests.swift
HostURLTests

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

class HostURLTest: SalesforceNoSessionTestCase {
    
    var hostPage = HostPage()
    var loginPage = LoginPage()
    
    // MARK: Setup
    override func setUp() {
        super.setUp()
        loginPage.waitForPageLoaded()
        loginPage.chooseConnection()
        hostPage.waitForPageLoaded()
    }
    
    override func tearDown() {
        loginPage.waitForPageLoaded()
        super.tearDown()
    }
    
    // MARK: Tests
    func testAddAndDeleteURL() {
        hostPage.addAndChooseConnection("testAddURL", host: "cs1.salesforce.com")
        loginPage.chooseConnection()
        hostPage.deleteHost("testAddURL")
    }
    
    func testSwitchURL() {
        hostPage.addAndChooseConnection("testSwitchURL", host: "cs1.salesforce.com")
        loginPage.waitForPageLoaded()
        loginPage.chooseConnection(Host.production)
        loginPage.waitForPageLoaded()
        loginPage.chooseConnection(Host.sandbox)
        loginPage.waitForPageLoaded()
        loginPage.chooseConnection()
        hostPage.chooseConnection("testSwitchURL")
        //background
        XCUIDevice().press(XCUIDevice.Button.home)
        app.launch() //FIXME: seems this will actually terminate and relaunch the app, cannot find a better way to foreground the app yet than import some private headers
        loginPage.waitForPageLoaded()
        loginPage.chooseConnection()
        hostPage.deleteHost("testSwitchURL")
    }
    
    func testCancelAddURL() {
        hostPage.addAndCancel(true)
    }
    
    
}
