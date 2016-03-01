//
//  SalesforceTestCase.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

class SalesforceTestCase: XCTestCase {
    
    var loginDelegate: SFLoginDelegate = LoginHelper()
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = true // false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()
        
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        loginThroughUI()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func loginThroughUI() {
        
        loginDelegate.loginToSalesforce()
        
    }

}