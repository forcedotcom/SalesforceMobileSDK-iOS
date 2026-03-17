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

class AuthFlowTypesViewTests: XCTestCase {
    
    var originalUseWebServerAuth: Bool!
    var originalUseHybridAuth: Bool!
    
    override func setUp() {
        super.setUp()
        
        // Save original state to restore in tearDown
        originalUseWebServerAuth = SalesforceManager.shared.useWebServerAuthentication
        originalUseHybridAuth = SalesforceManager.shared.useHybridAuthentication
    }
    
    override func tearDown() {
        // Restore original state
        SalesforceManager.shared.useWebServerAuthentication = originalUseWebServerAuth
        SalesforceManager.shared.useHybridAuthentication = originalUseHybridAuth
        
        super.tearDown()
    }
    
    func testAuthFlowTypesViewRendersSuccessfully() {
        let expectation = XCTestExpectation(description: "View renders without crashing")
        
        // Set specific toggle states before creating the view
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = false

        let view = AuthFlowTypesView()
        let hostingController = UIHostingController(rootView: view)
        
        // Create a window and add the view to trigger full rendering
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // Trigger view lifecycle (use appearance transition APIs to avoid callback misuse warning)
        hostingController.beginAppearanceTransition(true, animated: false)
        hostingController.endAppearanceTransition()
        
        // Give the view a moment to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(hostingController.view, "View should be rendered")
            
            // Verify the toggle states are still as set (view was initialized with these values)
            XCTAssertTrue(SalesforceManager.shared.useWebServerAuthentication, 
                         "Web server authentication should be enabled")
            XCTAssertFalse(SalesforceManager.shared.useHybridAuthentication, 
                          "Hybrid authentication should be disabled")
            
            // Clean up
            window.rootViewController = nil
            window.isHidden = true
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    func testImportAuthFlowTypesFromJSON() {
        // Set initial state
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = true

        // Create the view
        var view = AuthFlowTypesView()

        // Verify initial state
        XCTAssertTrue(SalesforceManager.shared.useWebServerAuthentication,
                     "Web server authentication should initially be true")
        XCTAssertTrue(SalesforceManager.shared.useHybridAuthentication,
                     "Hybrid authentication should initially be true")

        // Create JSON string
        let json: [String: Any] = [
            AuthFlowTypesJSONKeys.useWebServerFlow: false,
            AuthFlowTypesJSONKeys.useHybridFlow: false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            XCTFail("Failed to create JSON string")
            return
        }

        // Call the internal method to apply the JSON
        view.applyAuthFlowTypesFromJSON(jsonString)

        // Verify the values were updated
        XCTAssertFalse(SalesforceManager.shared.useWebServerAuthentication,
                      "Web server authentication should be false after import")
        XCTAssertFalse(SalesforceManager.shared.useHybridAuthentication,
                      "Hybrid authentication should be false after import")
    }

    func testImportAuthFlowTypesFromJSONPartialUpdate() {
        // Set initial state
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = true

        // Create the view
        let view = AuthFlowTypesView()

        // Test importing only one value
        let json: [String: Any] = [
            AuthFlowTypesJSONKeys.useWebServerFlow: false
            // Note: useHybridFlow is not included
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            XCTFail("Failed to create JSON string")
            return
        }

        // Call the internal method to apply the JSON
        view.applyAuthFlowTypesFromJSON(jsonString)

        // Verify only the specified value was updated
        XCTAssertFalse(SalesforceManager.shared.useWebServerAuthentication,
                      "Web server authentication should be false after import")
        XCTAssertTrue(SalesforceManager.shared.useHybridAuthentication,
                     "Hybrid authentication should remain true (not in JSON)")
    }

    func testAuthFlowTypesJSONKeys() {
        // Test that the JSON keys are correctly defined
        XCTAssertEqual(AuthFlowTypesJSONKeys.useWebServerFlow, "useWebServerFlow",
                      "useWebServerFlow key should match expected value")
        XCTAssertEqual(AuthFlowTypesJSONKeys.useHybridFlow, "useHybridFlow",
                      "useHybridFlow key should match expected value")
    }

    func testImportAuthFlowTypesFromInvalidJSON() {
        // Set initial state
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = true

        // Create the view
        let view = AuthFlowTypesView()

        // Test with invalid JSON
        let invalidJSON = "{ this is not valid JSON }"

        // Call the internal method with invalid JSON
        view.applyAuthFlowTypesFromJSON(invalidJSON)

        // Verify nothing changed (method should handle invalid JSON gracefully)
        XCTAssertTrue(SalesforceManager.shared.useWebServerAuthentication,
                     "Web server authentication should remain true after invalid JSON")
        XCTAssertTrue(SalesforceManager.shared.useHybridAuthentication,
                     "Hybrid authentication should remain true after invalid JSON")
    }

    func testImportAuthFlowTypesFromEmptyJSON() {
        // Set initial state
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = false

        // Create the view
        let view = AuthFlowTypesView()

        // Test with empty JSON object
        let emptyJSON = "{}"

        // Call the internal method with empty JSON
        view.applyAuthFlowTypesFromJSON(emptyJSON)

        // Verify nothing changed
        XCTAssertTrue(SalesforceManager.shared.useWebServerAuthentication,
                     "Web server authentication should remain unchanged after empty JSON")
        XCTAssertFalse(SalesforceManager.shared.useHybridAuthentication,
                      "Hybrid authentication should remain unchanged after empty JSON")
    }
}

