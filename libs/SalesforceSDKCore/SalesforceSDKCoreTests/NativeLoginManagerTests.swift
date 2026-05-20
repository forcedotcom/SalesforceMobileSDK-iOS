//
//  NativeLoginManagerTests.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 1/12/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore

final class NativeLoginManagerTests: XCTestCase {
    let nativeLoginManager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "c", callbackUrl: "r", communityUrl: "l", nativeLoginViewController: UIViewController(), scene: nil)
    
    override func setUpWithError() throws {
        _ = KeychainHelper.removeAll()
        BiometricAuthenticationManagerInternal.shared.locked = false
    }
    
    override func tearDownWithError() throws {
        UserAccountManager.shared.stopCurrentAuthentication()
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
    }
    
    func testUsernameValidation() async {
        var result = await nativeLoginManager.login(username: "", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow empty username.")
        result = await nativeLoginManager.login(username: "test@c", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow invalid username.")
        
        // success
        result = await nativeLoginManager.login(username: "test@c.co   ", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should allow username.")
    }
    
    func testUsernameValidationInSubmitOtpRequest() async {
        var result = await nativeLoginManager.submitOtpRequest(
            username: "",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            .invalidUsername,
            result.nativeLoginResult,
            "Should not allow empty username.")
        result = await nativeLoginManager.submitOtpRequest(
            username: "test@c",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            NativeLoginResult.invalidUsername,
            result.nativeLoginResult,
            "Should not allow invalid username.")
        
        // success
        result = await nativeLoginManager.submitOtpRequest(
            username: "test@c.co   ",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            NativeLoginResult.unknownError,
            result.nativeLoginResult,
            "Should allow username.")
    }
    
    func testPasswordValidation() async {
        var result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should not allow invalid password.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "test123")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password shorter than 8 chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "123456789")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any letter chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "abcdefghi")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any numbers.")
        
        // success
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "mypass12")
        XCTAssertEqual(.invalidCredentials, result, "Password should be acceptable.")
    }
    
    func testShouldShowBackButton() {
        let accountManager = UserAccountManager.shared
        XCTAssertNil(accountManager.currentUserAccount)
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button by default.")
        _ = createUser()
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user.")
        
        // Clear account
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when there are no other accounts.")
    }
    
    func testShouldShowBackButtonWithBioAuth() {
        let user = createUser()
        let bioAuthManager = BiometricAuthenticationManagerInternal.shared
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user (but not locked).")

        bioAuthManager.locked = true
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when bio auth is locked.")
        
        // Clear account
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        bioAuthManager.locked = false
    }
    
    func testNativeLoginPresentationHidesNavigationBar() {
        // Verify that when native login is enabled and the auth view is presented,
        // the wrapping SFSDKNavigationController has its navigation bar hidden.
        // This prevents an unwanted Salesforce-blue nav bar from appearing on top
        // of custom native login views (especially on re-presentation after
        // fallback-to-web-auth → back).
        let accountManager = UserAccountManager.shared

        // Native login is already configured via `nativeLoginManager` property.
        XCTAssertTrue(accountManager.nativeLoginEnabled, "Native login should be enabled.")
        accountManager.shouldFallbackToWebAuthentication = false

        let expectation = self.expectation(description: "Auth view presented")
        var presentedController: UIViewController?

        // Set up auth window with a mock VC that captures presentViewController: calls.
        // This lets the real presentLoginView: execute end-to-end.
        let mockPresenter = MockPresenterViewController()
        mockPresenter.onPresent = { controller in
            presentedController = controller
            expectation.fulfill()
        }
        SFSDKWindowManager.shared().authWindow(nil).viewController = mockPresenter

        // Directly invoke the default authViewHandler's display block with an
        // AuthViewHolder configured for the native login path (no loginController,
        // not advanced auth). This triggers presentLoginView: in production code.
        let viewHolder = AuthViewHolder()
        viewHolder.isAdvancedAuthFlow = false
        accountManager.authViewHandler.authViewDisplayBlock(viewHolder)

        waitForExpectations(timeout: 5)

        // Verify the navigation bar is hidden on the presented SFSDKNavigationController
        if let navController = presentedController as? UINavigationController {
            XCTAssertTrue(navController.isNavigationBarHidden, "Navigation bar should be hidden for native login presentation.")
        } else {
            XCTFail("Expected a UINavigationController to be presented for native login.")
        }
    }

    private func createUser() -> UserAccount {
        let credentials = OAuthCredentials(identifier: "identifier-0", clientId: "fakeClientIdForTesting", encrypted: true)!
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: [ "user_id": "0" ])
        do {
            try UserAccountManager.shared.upsert(user)
        } catch { }
        UserAccountManager.shared.currentUserAccount = user
        
        return user
    }
}

// MARK: - Test Helpers

private class MockPresenterViewController: UIViewController {
    var onPresent: ((UIViewController) -> Void)?

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        onPresent?(viewControllerToPresent)
        completion?()
    }
}
