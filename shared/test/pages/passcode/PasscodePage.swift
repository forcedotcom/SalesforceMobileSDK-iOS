/*
PasscodePage.swift

Created by Eric Engelking on 10/16/15.
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

import Foundation
import XCTest

enum PasscodeStatus {
    case creating
    case confirming
    case verifying
    case unknown
}

class PasscodePage: PageObject, PageThatWaits {
    
    fileprivate var createPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Create Passcode"]
        }
    }
    
    fileprivate var verifyPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Verify Passcode"]
        }
    }
    
    fileprivate var confirmPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Confirm Passcode"]
        }
    }
    
    fileprivate var passcodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars.element(matching: NSPredicate(format: "identifier CONTAINS[cd] 'Passcode'" ))
        }
    }
    
    
    fileprivate var nextButton: XCUIElement {
        get {
            return createPasscodeNavigationBar.buttons["Next"]
        }
    }

    fileprivate var passcodeSecureTextField: XCUIElement {
        get {
            return app.secureTextFields.allElementsBoundByAccessibilityElement[app.secureTextFields.allElementsBoundByAccessibilityElement.count-1]
        }
    }
  
    fileprivate var doneButton: XCUIElement {
        get {
            if verifyPasscodeNavigationBar.exists {
                return verifyPasscodeNavigationBar.buttons["Done"]
            }
            if confirmPasscodeNavigationBar.exists {
                return confirmPasscodeNavigationBar.buttons["Done"]
            }
            return createPasscodeNavigationBar.buttons["Done"]
        }
    }
    
    fileprivate var forgotPasscodeButton: XCUIElement {
        get {
            return app.buttons["Forgot Passcode?"]
        }
    }
    
    func verifyPasscode(_ passcode:String) {
        enterPasscode(passcode)
        done()
    }
    
    func enterPasscode(_ passcode:String) {
        passcodeSecureTextField.tap()
        passcodeSecureTextField.typeText(passcode)
    }
    
    func done() {
        doneButton.tap()
    }
    
    @discardableResult func createPasscode(_ passcode:String) -> Bool {
        if (createPasscodeNavigationBar.exists) {
            passcodeSecureTextField.typeText(passcode)
            nextButton.tap()
            sleep(1) 
            passcodeSecureTextField.typeText(passcode)
            done()
            return true
        }
        return false
    }
    
    func forgotPasscode(_ confirm:Bool) {
        forgotPasscodeButton.tap()
        let alertQuery = app.alerts["Forgot Passcode?"]
        if (confirm) {
            alertQuery.buttons["Yes"].tap()
        }
        else {
            alertQuery.buttons["No"].tap()
        }
    }
    
    func isPresented() -> Bool {
        return !(app.navigationBars["Contacts"].exists && app.navigationBars["Contacts"].isHittable)
    }
    
    func getStatus() -> PasscodeStatus {
        if verifyPasscodeNavigationBar.exists && verifyPasscodeNavigationBar.isHittable {
            return PasscodeStatus.verifying
        }
        else if createPasscodeNavigationBar.exists && createPasscodeNavigationBar.isHittable {
            return PasscodeStatus.creating
        }
        else if confirmPasscodeNavigationBar.exists && confirmPasscodeNavigationBar.isHittable {
            return PasscodeStatus.confirming
        }
        return PasscodeStatus.unknown
    }
    
    func waitForPageLoaded() {
        waitForElementEnabled(passcodeNavigationBar)
    }
    
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(passcodeNavigationBar)
    }
    
}
