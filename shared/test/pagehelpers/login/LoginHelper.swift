//
//  LoginHelper.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

class LoginHelper: SFLoginDelegate {
    
    func loginToSalesforce() {
        
        let loginPage = LoginPage()
        
        // Set user name
        // TODO get from login helper, maybe plist or arg
        loginPage.setUserName("eric@na1.mobile.ee.com")
        
        // Set password
        loginPage.setPassword("test1234")
        
        // Tap login
        let allowDenyPage = loginPage.tapLoginButton()
        
        // Tap allow
        allowDenyPage.tapAllowButton()
        
    }
}