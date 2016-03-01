//
//  PageObject.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import XCTest
import Foundation

class PageObject {
    
    // Reference to the test case that is currently running which exposes some APIs needed in the page object
    var test: XCTestCase {
        get {
            return TestCaseManager.currentTestCase
        }
    }
    
    // Reference to the root level app that can be used to access child elements
    var app: XCUIApplication {
        get{
            return XCUIApplication()
        }
    }
    
}