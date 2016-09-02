/*
PasscodePage.swift

Created by Eric Engelking on 10/16/15.
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

import Foundation
import XCTest

enum PasscodeStatus {
    case Creating
    case Confirming
    case Verifying
    case Unknown
}

class PasscodePage: PageObject, PageThatWaits {
    
    private var createPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Create Passcode"]
        }
    }
    
    private var verifyPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Verify Passcode"]
        }
    }
    
    private var confirmPasscodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars["Confirm Passcode"]
        }
    }
    
    private var passcodeNavigationBar: XCUIElement {
        get {
            return app.navigationBars.elementMatchingPredicate(NSPredicate(format: "identifier CONTAINS[cd] 'Passcode'" ))
        }
    }
    
    
    private var nextButton: XCUIElement {
        get {
            return createPasscodeNavigationBar.buttons["Next"]
        }
    }

    private var passcodeSecureTextField: XCUIElement {
        get {
            return app.secureTextFields.allElementsBoundByAccessibilityElement[app.secureTextFields.allElementsBoundByAccessibilityElement.count-1]
        }
    }
  
    private var doneButton: XCUIElement {
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
    
    private var forgotPasscodeButton: XCUIElement {
        get {
            return app.buttons["Forgot Passcode?"]
        }
    }
    
    func verifyPasscode(passcode:String) {
        enterPasscode(passcode)
        done()
    }
    
    func enterPasscode(passcode:String) {
        passcodeSecureTextField.tap()
        passcodeSecureTextField.typeText(passcode)
    }
    
    func done() {
        doneButton.tap()
    }
    
    func createPasscode(passcode:String) -> Bool {
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
    
    func forgotPasscode(confirm:Bool) {
        forgotPasscodeButton.tap()
        let collectionViewsQuery = app.alerts["Forgot Passcode?"].collectionViews
        if (confirm) {
            collectionViewsQuery.buttons["Yes"].tap()
        }
        else {
            collectionViewsQuery.buttons["No"].tap()
        }
    }
    
    func isPresented() -> Bool {
        return (getStatus() != PasscodeStatus.Unknown)
    }
    
    func getStatus() -> PasscodeStatus {
        if verifyPasscodeNavigationBar.exists && verifyPasscodeNavigationBar.hittable {
            return PasscodeStatus.Verifying
        }
        else if createPasscodeNavigationBar.exists && createPasscodeNavigationBar.hittable {
            return PasscodeStatus.Creating
        }
        else if confirmPasscodeNavigationBar.exists && confirmPasscodeNavigationBar.hittable {
            return PasscodeStatus.Confirming
        }
        return PasscodeStatus.Unknown
    }
    
    func waitForPageLoaded() {
        waitForElementEnabled(passcodeNavigationBar)
    }
    
    
    func waitForPageInvalid() {
        waitForElementDoesNotExist(passcodeNavigationBar)
    }
    
}