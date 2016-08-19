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
        loginPage.waitForPageLoaded()
    }
    
    override func tearDown() {
        loginPage.waitForPageLoaded()
        super.tearDown()
    }
    
    // MARK: Tests
    func FIXMEtestLoginSwitchBetweenAndLogoutUsers() {
        loginPage.scrollUp() //sanity test scrolling is enabled
        for login in loginAccounts {
            let user = login.valueForKey("username") as! String
            let password = login.valueForKey("password") as! String
            let host = login.valueForKey("host") as! String
            addAndSwitchToUser(user, password:password, host:host)
            sleep(1)
        }
        
        let total = loginAccounts.count
        for i in 0..<total {
            let user = loginAccounts[i].valueForKey("username") as! String
            switchToUser(user)
        }
        
        for j in 0..<total-1 {
            let user = loginAccounts[j].valueForKey("username") as! String
            switchToUser(user)
            searchScreen.logout()
            searchScreen.waitForPageLoaded()
        }
        searchScreen.logout()
        loginPage.waitForPageLoaded()
    }
    
    func switchToUser(username:String) {
        searchScreen.waitForPageLoaded()
        searchScreen.switchUser()
        userListScreen.switchToUser(username)
    }
    
    func addAndSwitchToUser(username:String, password:String, host:String) {
        if (!loginPage.isPresenting()) {
            searchScreen.waitForPageLoaded()
            searchScreen.switchUser()
            userListScreen.addUser()
        }
        loginPage.chooseConnection()
        hostPage.selectHost(host)
        loginHelper.loginToSalesforce(username, password: password)
    }
    
    
}