//
//  LoginPage.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

class LoginPage: PageObject,PageThatWaits {
    
    private var userNameField: XCUIElement {
        get {
            return app.otherElements["Login | Salesforce"].childrenMatchingType(.TextField).element
        }
    }
    
    private var passwordField: XCUIElement {
        get {
            return app.otherElements["Login | Salesforce"].childrenMatchingType(.SecureTextField).element
        }
    }
    
    private var loginButton: XCUIElement {
        get {
            //TODO: Fix for Production, Mobile1, & Mobile2.  There is a bug that prevents us from using BEGINSWITH 'Log In'
            let buttonPredicate = NSPredicate(format: "label BEGINSWITH[cd] 'Log In'")
            return app.buttons.elementMatchingPredicate(buttonPredicate)

        }
    }

    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(userNameField)
        
    }
    
    func waitForPageLoaded() {
        waitForElementExists(userNameField)
    }
    
    func setUserName(userName: String) -> LoginPage {
        userNameField.pressForDuration(2)
        userNameField.typeText(userName)
        return self
    }
    
    func setPassword(password: String) -> LoginPage {
        passwordField.tap()
        passwordField.typeText(password)
        return self
    }
    
    func tapLoginButton() -> AllowDenyPage {
        loginButton.tap()
        let allowDenyPage = AllowDenyPage()
        allowDenyPage.waitForPageLoaded()
        return allowDenyPage
        
    }
    
  
}