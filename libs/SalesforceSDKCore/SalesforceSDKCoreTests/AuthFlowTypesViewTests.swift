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
    var originalSupportsWelcomeDiscovery: Bool!
    
    override func setUp() {
        super.setUp()
        
        // Save original state to restore in tearDown
        originalUseWebServerAuth = SalesforceManager.shared.useWebServerAuthentication
        originalUseHybridAuth = SalesforceManager.shared.useHybridAuthentication
        originalSupportsWelcomeDiscovery = SalesforceManager.shared.supportsWelcomeDiscovery
    }
    
    override func tearDown() {
        // Restore original state
        SalesforceManager.shared.useWebServerAuthentication = originalUseWebServerAuth
        SalesforceManager.shared.useHybridAuthentication = originalUseHybridAuth
        SalesforceManager.shared.supportsWelcomeDiscovery = originalSupportsWelcomeDiscovery
        
        super.tearDown()
    }
    
    func testAuthFlowTypesViewRendersSuccessfully() {
        let expectation = XCTestExpectation(description: "View renders without crashing")
        
        // Set specific toggle states before creating the view
        SalesforceManager.shared.useWebServerAuthentication = true
        SalesforceManager.shared.useHybridAuthentication = false
        SalesforceManager.shared.supportsWelcomeDiscovery = true
        
        let view = AuthFlowTypesView()
        let hostingController = UIHostingController(rootView: view)
        
        // Create a window and add the view to trigger full rendering
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // Trigger view lifecycle
        hostingController.viewWillAppear(false)
        hostingController.viewDidAppear(false)
        
        // Give the view a moment to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(hostingController.view, "View should be rendered")
            
            // Verify the toggle states are still as set (view was initialized with these values)
            XCTAssertTrue(SalesforceManager.shared.useWebServerAuthentication, 
                         "Web server authentication should be enabled")
            XCTAssertFalse(SalesforceManager.shared.useHybridAuthentication, 
                          "Hybrid authentication should be disabled")
            XCTAssertTrue(SalesforceManager.shared.supportsWelcomeDiscovery, 
                         "Welcome discovery should be enabled")
            
            // Clean up
            window.rootViewController = nil
            window.isHidden = true
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

