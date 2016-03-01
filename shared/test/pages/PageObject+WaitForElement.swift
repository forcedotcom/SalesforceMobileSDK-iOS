//
//  PageObject+WaitForElement.swift
//  Chatter
//
//  Created by Eric Engelking on 10/20/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

let exists = NSPredicate(format: "exists == true")
let enabled = NSPredicate(format: "enabled == true")
let doesNotExist = NSPredicate(format: "exists == false")
let waitTimeout: NSTimeInterval = 10

extension PageObject {
    
    func waitForElementExists(element: XCUIElement) {
        test.expectationForPredicate(exists, evaluatedWithObject: element, handler: nil)
        test.waitForExpectationsWithTimeout(waitTimeout, handler: nil)
    }
    
    func waitForElementEnabled(element: XCUIElement) {
        test.expectationForPredicate(enabled, evaluatedWithObject: element, handler: nil)
        test.waitForExpectationsWithTimeout(waitTimeout, handler: nil)
    }
    
    func waitForElementDoesNotExist(element: XCUIElement) {
        test.expectationForPredicate(doesNotExist, evaluatedWithObject: element, handler: nil)
        test.waitForExpectationsWithTimeout(waitTimeout, handler: nil)
    }
    
}