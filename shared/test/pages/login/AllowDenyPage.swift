//
//  AllowDenyPage.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

class AllowDenyPage: PageObject,PageThatWaits {
    
    private var allowButton: XCUIElement {
        get {
            let buttonPredicate = NSPredicate(format: "label CONTAINS 'Allow'")
            return app.buttons.elementMatchingPredicate(buttonPredicate)
        }
    }
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(allowButton)
    }
    
    func waitForPageLoaded() {
        waitForElementExists(allowButton)
        
    }
    
    func tapAllowButton() {
        allowButton.tap()
    }
    
}