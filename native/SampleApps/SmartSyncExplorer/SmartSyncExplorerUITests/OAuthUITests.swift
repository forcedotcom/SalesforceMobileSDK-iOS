/*
OAuthUITests.swift
OAuthUITests

Copyright (c) 2016, salesforce.com, inc. All rights reserved.

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

class OAuthUITest: SalesforceNoSessionTestCase {
    
    let loginHelper = LoginHelper()
    let loginPage = LoginPage()
    let hostPage = HostPage()
    let searchScreen = SearchScreen()
    let userListScreen = UserListScreen()
    
    // MARK: Setup
    override func setUp() {
        super.setUp()
        LoginPage().waitForPageLoaded()
    }
    
    override func tearDown() {
        LoginPage().waitForPageLoaded()
        super.tearDown()
    }
    
    // MARK: Tests
    func testLoginSwitchBetweenAndLogout5Users() {
        let password = swiftDict["password"]!
        loginPage.scrollUp() //sanity test scrolling is enabled
        // add 1st user on cs1
        loginHelper.loginToSalesforce("uit1@cs1.mobilesdk.org", password:password, host: Host.sandbox)
        //add 2nd user on cs1
        addAndSwitchToUser("uit2@cs1.mobilesdk.org", password:password, host:"Sandbox")
        //add 3rd user on production
        addAndSwitchToUser("su1@sf.mobilesdk.com", password:password, host: "Production")
        //add 4th user of chatter external
        addAndSwitchToUser("ce@sf.mobilesdk.com", password:password, host:"Production")
        //Todo: add 5th user on mydomain community - user to be setup
//        addAndSwitchToUser("uc1@sf.mobilesdk.community1.com", password:password, host:"mobilesdk-mhu-developer-edition.na30.force.com")
        
        switchToUser("su1@sf.mobilesdk.com")
        searchScreen.logout()
        userListScreen.switchToUser("ce@sf.mobilesdk.com")
        switchToUser("uit2@cs1.mobilesdk.org")
        searchScreen.logout()
        userListScreen.switchToUser("ce@sf.mobilesdk.com")
        searchScreen.logout()
        searchScreen.waitForPageLoaded()
        searchScreen.logout()
    }
    
    
    func testNativeBrowserFlow() {
    }
    
    func testLoginOptions () {
    }
    
    func testRevoke() {
        
    }
    
    func testRefreshToken() {
    }
    
    func switchToUser(username:String) {
        searchScreen.waitForPageLoaded()
        searchScreen.switchUser()
        userListScreen.switchToUser(username)
    }
    
    func addAndSwitchToUser(username:String, password:String, host:String) {
        searchScreen.waitForPageLoaded()
        searchScreen.switchUser()
        userListScreen.addUser()
        loginPage.chooseConnection()
        hostPage.selectHost(host)
        loginHelper.loginToSalesforce(username, password: password)
    }
    
    
}