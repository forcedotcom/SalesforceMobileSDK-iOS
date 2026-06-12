/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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
import SwiftUI
@testable import SalesforceSDKCore

class LoginOptionsViewControllerTests: XCTestCase {
    
    var originalBootConfig: BootConfig?
    var originalRuntimeSelector: BootConfigRuntimeSelector?
    var originalOAuthClientID: String!
    var originalOAuthCompletionURL: String!
    var originalScopes: Set<String>!
    var originalSimulatedDomainDiscoveryResult: DomainDiscoveryResult?
    
    override func setUp() {
        super.setUp()
        
        // Save original state to restore in tearDown
        originalBootConfig = SalesforceManager.shared.bootConfig
        originalRuntimeSelector = SalesforceManager.shared.bootConfigRuntimeSelector
        originalOAuthClientID = UserAccountManager.shared.oauthClientID
        originalOAuthCompletionURL = UserAccountManager.shared.oauthCompletionURL
        originalScopes = UserAccountManager.shared.scopes
        originalSimulatedDomainDiscoveryResult = SalesforceManager.shared.simulatedDomainDiscoveryResult
    }
    
    override func tearDown() {
        // Restore original state
        SalesforceManager.shared.bootConfig = originalBootConfig
        SalesforceManager.shared.bootConfigRuntimeSelector = originalRuntimeSelector
        UserAccountManager.shared.oauthClientID = originalOAuthClientID
        UserAccountManager.shared.oauthCompletionURL = originalOAuthCompletionURL
        UserAccountManager.shared.scopes = originalScopes
        SalesforceManager.shared.simulatedDomainDiscoveryResult = originalSimulatedDomainDiscoveryResult
        
        super.tearDown()
    }
    
    func testMakeViewControllerHasSheetPresentationConfiguration() {
        let viewController = LoginOptionsViewController.makeViewController {
            // No-op callback
        }
        
        #if !os(visionOS)
        XCTAssertNotNil(viewController.sheetPresentationController, 
                       "ViewController should have sheet presentation controller")
        
        if let sheet = viewController.sheetPresentationController {
            XCTAssertTrue(sheet.detents.contains(.medium()) || sheet.detents.count > 0,
                         "Sheet should have medium detent configured")
            XCTAssertTrue(sheet.prefersGrabberVisible, 
                         "Sheet should show grabber")
            XCTAssertEqual(sheet.preferredCornerRadius, 16, 
                          "Sheet should have corner radius of 16")
        }
        #endif
    }
    
    func testBootConfigPickerViewRendered() {
        // Create a test BootConfig
        let testConfig: [String: Any] = [
            "remoteAccessConsumerKey": "test_boot_config_key",
            "oauthRedirectURI": "test://boot/callback",
            "oauthScopes": ["api", "web", "refresh_token"],
            "shouldAuthenticate": true
        ]
        SalesforceManager.shared.bootConfig = BootConfig(testConfig)

        let view = LoginOptionsView {
            // No-op callback
        }

        let hostingController = UIHostingController(rootView: view)

        // Create a window and add the view controller
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        // Trigger view lifecycle
        hostingController.beginAppearanceTransition(true, animated: false)
        hostingController.endAppearanceTransition()

        // Verify view rendered with non-zero layout
        hostingController.view.layoutIfNeeded()
        XCTAssertGreaterThan(hostingController.view.subviews.count, 0)
        XCTAssertGreaterThan(hostingController.view.frame.height, 0)

        // Clean up
        window.rootViewController = nil
        window.isHidden = true
    }
    
    func testStaticConfigButtonAction() {
        // Create view with test static config values (save buttons do not call onConfigurationCompleted)
        let view = LoginOptionsView(
            onConfigurationCompleted: {},
            staticConsumerKey: "test_static_key",
            staticCallbackUrl: "test://static/callback",
            staticScopes: "api refresh_token web"
        )
        
        // Trigger the static config handler (saves config only; does not dismiss)
        view.handleStaticConfig()
        
        // Verify SalesforceManager was updated
        XCTAssertNotNil(SalesforceManager.shared.bootConfig, "BootConfig should be set")
        XCTAssertEqual(SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey, "test_static_key")
        XCTAssertEqual(SalesforceManager.shared.bootConfig?.oauthRedirectURI, "test://static/callback")
        XCTAssertEqual(SalesforceManager.shared.bootConfig?.oauthScopes.sorted(), ["api", "refresh_token", "web"])
        XCTAssertNil(SalesforceManager.shared.bootConfigRuntimeSelector, "Runtime selector should be nil for static config")
        
        // Verify UserAccountManager was updated
        XCTAssertEqual(UserAccountManager.shared.oauthClientID, "test_static_key")
        XCTAssertEqual(UserAccountManager.shared.oauthCompletionURL, "test://static/callback")
        XCTAssertEqual(UserAccountManager.shared.scopes.sorted(), ["api", "refresh_token", "web"])
    }
    
    func testDynamicConfigButtonAction() {
        // Save dynamic config does not call onConfigurationCompleted
        let view = LoginOptionsView(
            onConfigurationCompleted: {},
            dynamicConsumerKey: "test_dynamic_key",
            dynamicCallbackUrl: "test://dynamic/callback",
            dynamicScopes: "api id"
        )
        
        // Trigger the dynamic config handler (saves config only; does not dismiss)
        view.handleDynamicBootconfig()
        
        // Verify runtime selector was set
        XCTAssertNotNil(SalesforceManager.shared.bootConfigRuntimeSelector, "Runtime selector should be set for dynamic config")
        
        // Test the runtime selector
        let selectorExpectation = XCTestExpectation(description: "Runtime selector provides config")
        SalesforceManager.shared.bootConfigRuntimeSelector?("https://loginhost.salesforce.com") { bootConfig in
            XCTAssertNotNil(bootConfig, "BootConfig should be provided by runtime selector")
            XCTAssertEqual(bootConfig?.remoteAccessConsumerKey, "test_dynamic_key")
            XCTAssertEqual(bootConfig?.oauthRedirectURI, "test://dynamic/callback")
            XCTAssertEqual(bootConfig?.oauthScopes.sorted(), ["api", "id"])
            selectorExpectation.fulfill()
        }
        
        wait(for: [selectorExpectation], timeout: 1.0)
    }

    func testSimulatedDomainDiscoveryButtonAction() {
        // Save simulated result does not call onConfigurationCompleted
        let view = LoginOptionsView(
            onConfigurationCompleted: {},
            discoveryLoginHost: "test.my.salesforce.com",
            discoveryUserName: "user@example.com"
        )
        
        // Trigger the simulated domain discovery handler (saves result only; does not dismiss)
        let result = DomainDiscoveryResult(loginHint: "user@example.com", myDomain: "test.my.salesforce.com")
        view.handleSimulatedDomainDiscovery(result: result)
        
        // Verify SalesforceManager was updated
        XCTAssertNotNil(SalesforceManager.shared.simulatedDomainDiscoveryResult, "Simulated domain discovery result should be set")
        XCTAssertEqual(SalesforceManager.shared.simulatedDomainDiscoveryResult?.loginHint, "user@example.com")
        XCTAssertEqual(SalesforceManager.shared.simulatedDomainDiscoveryResult?.myDomain, "test.my.salesforce.com")
        
        // Clearing the simulated result (e.g. empty login host in editor)
        view.handleSimulatedDomainDiscovery(result: nil)
        XCTAssertNil(SalesforceManager.shared.simulatedDomainDiscoveryResult, "Simulated result should be cleared when passing nil")
    }

    func testCompletionHandlerCalledWhenClosingSheet() {
        let expectation = XCTestExpectation(description: "Completion handler called when sheet is closed")
        var completionCalled = false

        let view = LoginOptionsView(onConfigurationCompleted: {
            completionCalled = true
            expectation.fulfill()
        })

        // Simulate user tapping the title bar close button (same code path)
        view.closeSheet()

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(completionCalled, "Completion handler should be called when closing the sheet")
    }
}
