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

class DevInfoViewControllerTests: XCTestCase {
    
    func testMakeViewControllerHasSheetPresentationConfiguration() {
        let viewController = DevInfoViewController.makeViewController()
        
        #if !os(visionOS)
        XCTAssertNotNil(viewController.sheetPresentationController,
                       "ViewController should have sheet presentation controller")
        
        if let sheet = viewController.sheetPresentationController {
            XCTAssertTrue(sheet.detents.contains(.medium()) || sheet.detents.count > 0,
                         "Sheet should have detents configured")
            XCTAssertTrue(sheet.prefersGrabberVisible,
                         "Sheet should show grabber")
            XCTAssertEqual(sheet.preferredCornerRadius, 16,
                          "Sheet should have corner radius of 16")
        }
        #endif
    }
    
    func testViewInitializationWithEmptyData() {
        let view = DevInfoView(infoData: [], title: "Test Title")
        
        XCTAssertEqual(view.sections.count, 0, "Empty data should result in no sections")
        XCTAssertEqual(view.title, "Test Title", "Title should be preserved")
    }
    
    func testViewInitializationWithData() {
        let infoData = ["Key", "Value"]
        let view = DevInfoView(infoData: infoData, title: "My Title")
        
        XCTAssertEqual(view.sections.count, 1, "Should create one section")
        XCTAssertEqual(view.title, "My Title", "Title should be preserved")
    }
    
    func testViewInitializationWithMultipleSections() {
        let infoData = [
            "section:Section 1",
            "Key1", "Value1",
            "section:Section 2",
            "Key2", "Value2"
        ]
        let view = DevInfoView(infoData: infoData, title: "Test")
        
        XCTAssertEqual(view.sections.count, 2, "Should create two sections")
    }
       
    func testDevInfoRowHasUniqueIDs() {
        let row1 = DevInfoRow(headline: "Test", text: "Value")
        let row2 = DevInfoRow(headline: "Test", text: "Value")
        
        XCTAssertNotEqual(row1.id, row2.id,
                         "Each DevInfoRow should have a unique ID")
    }
    
    func testDevInfoRowStoresData() {
        let headline = "Test Headline"
        let text = "Test Text"
        let row = DevInfoRow(headline: headline, text: text)
        
        XCTAssertEqual(row.headline, headline, "Headline should be stored")
        XCTAssertEqual(row.text, text, "Text should be stored")
    }
    
    func testDevInfoSectionHasUniqueIDs() {
        let section1 = DevInfoSection(title: "Section", rows: [])
        let section2 = DevInfoSection(title: "Section", rows: [])
        
        XCTAssertNotEqual(section1.id, section2.id,
                         "Each DevInfoSection should have a unique ID")
    }
    
    func testDevInfoSectionWithTitle() {
        let title = "Test Section"
        let rows = [DevInfoRow(headline: "Key", text: "Value")]
        let section = DevInfoSection(title: title, rows: rows)
        
        XCTAssertEqual(section.title, title, "Title should be stored")
        XCTAssertEqual(section.rows.count, 1, "Rows should be stored")
        XCTAssertEqual(section.rows[0].headline, "Key")
    }
    
    func testDevInfoSectionWithoutTitle() {
        let rows = [DevInfoRow(headline: "Key", text: "Value")]
        let section = DevInfoSection(title: nil, rows: rows)
        
        XCTAssertNil(section.title, "Title should be nil")
        XCTAssertEqual(section.rows.count, 1, "Rows should be stored")
    }
    
    func testDevInfoSectionWithMultipleRows() {
        let rows = [
            DevInfoRow(headline: "Key1", text: "Value1"),
            DevInfoRow(headline: "Key2", text: "Value2"),
            DevInfoRow(headline: "Key3", text: "Value3")
        ]
        let section = DevInfoSection(title: "Test", rows: rows)
        
        XCTAssertEqual(section.rows.count, 3, "Should store all rows")
        XCTAssertEqual(section.rows[0].headline, "Key1")
        XCTAssertEqual(section.rows[1].headline, "Key2")
        XCTAssertEqual(section.rows[2].headline, "Key3")
    }
    
    func testDevInfoSectionWithEmptyRows() {
        let section = DevInfoSection(title: "Empty", rows: [])
        
        XCTAssertEqual(section.rows.count, 0, "Should handle empty rows array")
    }
    
    func testExtractSectionsWithNoSectionMarkers() {
        let infoData = [
            "Key1", "Value1",
            "Key2", "Value2",
            "Key3", "Value3"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertNil(sections[0].title, "Section should have no title")
        XCTAssertEqual(sections[0].rows.count, 3, "Section should have 3 rows")
        
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")
        XCTAssertEqual(sections[0].rows[1].headline, "Key2")
        XCTAssertEqual(sections[0].rows[1].text, "Value2")
        XCTAssertEqual(sections[0].rows[2].headline, "Key3")
        XCTAssertEqual(sections[0].rows[2].text, "Value3")
    }
    
    func testExtractSectionsWithSectionAtStart() {
        let infoData = [
            "section:First Section",
            "Key1", "Value1",
            "Key2", "Value2"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertEqual(sections[0].title, "First Section", "Section should have correct title")
        XCTAssertEqual(sections[0].rows.count, 2, "Section should have 2 rows")
        
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")

        XCTAssertEqual(sections[0].rows[1].headline, "Key2")
        XCTAssertEqual(sections[0].rows[1].text, "Value2")

    }
    
    func testExtractSectionsWithSectionInMiddle() {
        let infoData = [
            "Key1", "Value1",
            "section:Middle Section",
            "Key2", "Value2"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 2, "Should have exactly two sections")
        
        // First section (no title)
        XCTAssertNil(sections[0].title, "First section should have no title")
        XCTAssertEqual(sections[0].rows.count, 1, "First section should have 1 row")
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")
        
        // Second section (with title)
        XCTAssertEqual(sections[1].title, "Middle Section", "Second section should have correct title")
        XCTAssertEqual(sections[1].rows.count, 1, "Second section should have 1 row")
        XCTAssertEqual(sections[1].rows[0].headline, "Key2")
        XCTAssertEqual(sections[1].rows[0].text, "Value2")
    }
    
    func testExtractSectionsWithMultipleSections() {
        let infoData = [
            "section:Section 1",
            "Key1", "Value1",
            "Key2", "Value2",
            "section:Section 2",
            "Key3", "Value3",
            "section:Section 3",
            "Key4", "Value4",
            "Key5", "Value5",
            "Key6", "Value6"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 3, "Should have exactly three sections")
        
        // Section 1
        XCTAssertEqual(sections[0].title, "Section 1")
        XCTAssertEqual(sections[0].rows.count, 2)
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")
        XCTAssertEqual(sections[0].rows[1].headline, "Key2")
        XCTAssertEqual(sections[0].rows[1].text, "Value2")

        // Section 2
        XCTAssertEqual(sections[1].title, "Section 2")
        XCTAssertEqual(sections[1].rows.count, 1)
        XCTAssertEqual(sections[1].rows[0].headline, "Key3")
        XCTAssertEqual(sections[1].rows[0].text, "Value3")

        // Section 3
        XCTAssertEqual(sections[2].title, "Section 3")
        XCTAssertEqual(sections[2].rows.count, 3)
        XCTAssertEqual(sections[2].rows[0].headline, "Key4")
        XCTAssertEqual(sections[2].rows[0].text, "Value4")
        XCTAssertEqual(sections[2].rows[1].headline, "Key5")
        XCTAssertEqual(sections[2].rows[1].text, "Value5")
        XCTAssertEqual(sections[2].rows[2].headline, "Key6")
        XCTAssertEqual(sections[2].rows[2].text, "Value6")
    }
    
    func testExtractSectionsWithEmptyArray() {
        let infoData: [String] = []
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 0, "Should have no sections for empty array")
    }
    
    func testExtractSectionsWithOddNumberOfItems() {
        let infoData = [
            "Key1", "Value1",
            "Key2"  // Odd item, should be skipped
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertEqual(sections[0].rows.count, 1, "Should only have 1 complete row (odd item skipped)")
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")
    }
    
    func testExtractSectionsWithSectionButNoRows() {
        let infoData = [
            "Key1", "Value1",
            "section:Empty Section",
            "section:Another Section",
            "Key2", "Value2"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 2, "Should have two sections (empty section should be skipped)")
        
        // First section (no title)
        XCTAssertNil(sections[0].title)
        XCTAssertEqual(sections[0].rows.count, 1)
        
        // Second section (Another Section) - Empty Section was skipped
        XCTAssertEqual(sections[1].title, "Another Section")
        XCTAssertEqual(sections[1].rows.count, 1)
    }
    
    func testExtractSectionsWithEmptySectionTitle() {
        let infoData = [
            "section:",  // Empty section title
            "Key1", "Value1"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertNil(sections[0].title, "Empty section title should become nil")
        XCTAssertEqual(sections[0].rows.count, 1)
    }
    
    func testExtractSectionsWithRealWorldData() {
        let infoData = [
            "SDK Version", "12.0.0",
            "App Type", "Native",
            "section:Auth Config",
            "Use Web Server Authentication", "YES",
            "Use Hybrid Authentication", "NO",
            "section:Current User",
            "Username", "test@example.com",
            "Consumer Key", "test_key",
            "Instance URL", "https://test.salesforce.com"
        ]
        
        let sections = DevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 3, "Should have three sections")
        
        // First section (no title)
        XCTAssertNil(sections[0].title)
        XCTAssertEqual(sections[0].rows.count, 2)
        XCTAssertEqual(sections[0].rows[0].headline, "SDK Version")
        XCTAssertEqual(sections[0].rows[1].headline, "App Type")
        
        // Auth Config section
        XCTAssertEqual(sections[1].title, "Auth Config")
        XCTAssertEqual(sections[1].rows.count, 2)
        XCTAssertEqual(sections[1].rows[0].headline, "Use Web Server Authentication")
        XCTAssertEqual(sections[1].rows[0].text, "YES")
        
        // Current User section
        XCTAssertEqual(sections[2].title, "Current User")
        XCTAssertEqual(sections[2].rows.count, 3)
        XCTAssertEqual(sections[2].rows[0].headline, "Username")
        XCTAssertEqual(sections[2].rows[0].text, "test@example.com")
    }
    
    func testDevInfoViewCreationWithSimpleData() {
        let infoData = ["Key", "Value"]
        let view = DevInfoView(infoData: infoData, title: "Test Title")
        
        // Verify view properties
        XCTAssertEqual(view.title, "Test Title")
        XCTAssertEqual(view.sections.count, 1)
        XCTAssertNil(view.sections[0].title)
        XCTAssertEqual(view.sections[0].rows.count, 1)
        XCTAssertEqual(view.sections[0].rows[0].headline, "Key")
        XCTAssertEqual(view.sections[0].rows[0].text, "Value")
    }
    
    func testDevInfoViewCreationWithMultipleRows() {
        let infoData = [
            "Key1", "Value1",
            "Key2", "Value2",
            "Key3", "Value3"
        ]
        let view = DevInfoView(infoData: infoData, title: "Multi Row Test")
        
        XCTAssertEqual(view.title, "Multi Row Test")
        XCTAssertEqual(view.sections.count, 1)
        XCTAssertEqual(view.sections[0].rows.count, 3)
        
        // Verify all rows
        XCTAssertEqual(view.sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(view.sections[0].rows[0].text, "Value1")
        XCTAssertEqual(view.sections[0].rows[1].headline, "Key2")
        XCTAssertEqual(view.sections[0].rows[1].text, "Value2")
        XCTAssertEqual(view.sections[0].rows[2].headline, "Key3")
        XCTAssertEqual(view.sections[0].rows[2].text, "Value3")
    }
    
    func testDevInfoViewCreationWithSections() {
        let infoData = [
            "section:Section 1",
            "Key1", "Value1",
            "section:Section 2",
            "Key2", "Value2"
        ]
        let view = DevInfoView(infoData: infoData, title: "Sectioned Data")
        
        XCTAssertEqual(view.title, "Sectioned Data")
        XCTAssertEqual(view.sections.count, 2)
        
        // Section 1
        XCTAssertEqual(view.sections[0].title, "Section 1")
        XCTAssertEqual(view.sections[0].rows.count, 1)
        XCTAssertEqual(view.sections[0].rows[0].headline, "Key1")
        
        // Section 2
        XCTAssertEqual(view.sections[1].title, "Section 2")
        XCTAssertEqual(view.sections[1].rows.count, 1)
        XCTAssertEqual(view.sections[1].rows[0].headline, "Key2")
    }
    
    func testDevInfoViewCreationWithEmptyData() {
        let view = DevInfoView(infoData: [], title: "Empty")
        
        XCTAssertEqual(view.title, "Empty")
        XCTAssertEqual(view.sections.count, 0)
    }
    
    func testDevInfoViewCreationWithMixedSections() {
        let infoData = [
            "Global1", "Value1",
            "Global2", "Value2",
            "section:Named Section",
            "Sectioned1", "SValue1",
            "Sectioned2", "SValue2",
            "section:Another Section",
            "Another1", "AValue1"
        ]
        let view = DevInfoView(infoData: infoData, title: "Mixed")
        
        XCTAssertEqual(view.sections.count, 3)
        
        // First section (no title)
        XCTAssertNil(view.sections[0].title)
        XCTAssertEqual(view.sections[0].rows.count, 2)
        
        // Named Section
        XCTAssertEqual(view.sections[1].title, "Named Section")
        XCTAssertEqual(view.sections[1].rows.count, 2)
        
        // Another Section
        XCTAssertEqual(view.sections[2].title, "Another Section")
        XCTAssertEqual(view.sections[2].rows.count, 1)
    }
    
    func testDevInfoViewWithRealWorldData() {
        let infoData = [
            "SDK Version", "13.0.0",
            "App Type", "Native iOS",
            "section:Current User",
            "Username", "test@salesforce.com",
            "User ID", "005xx000001X8Uz",
            "Org ID", "00Dxx0000001gPL",
            "Instance URL", "https://na1.salesforce.com",
            "section:OAuth Configuration",
            "Client ID", "3MVG9PhR6g6B7ps6aoQEJ8h_",
            "Redirect URI", "testapp://mobilesdk/detect/oauth/done",
            "Scopes", "api web refresh_token"
        ]
        let view = DevInfoView(infoData: infoData, title: "Dev Support")
        
        XCTAssertEqual(view.title, "Dev Support")
        XCTAssertEqual(view.sections.count, 3)
        
        // General info section (no title)
        XCTAssertNil(view.sections[0].title)
        XCTAssertEqual(view.sections[0].rows.count, 2)
        XCTAssertEqual(view.sections[0].rows[0].headline, "SDK Version")
        XCTAssertEqual(view.sections[0].rows[0].text, "13.0.0")
        
        // Current User section
        XCTAssertEqual(view.sections[1].title, "Current User")
        XCTAssertEqual(view.sections[1].rows.count, 4)
        XCTAssertEqual(view.sections[1].rows[0].headline, "Username")
        XCTAssertEqual(view.sections[1].rows[0].text, "test@salesforce.com")
        
        // OAuth Configuration section
        XCTAssertEqual(view.sections[2].title, "OAuth Configuration")
        XCTAssertEqual(view.sections[2].rows.count, 3)
        XCTAssertEqual(view.sections[2].rows[2].headline, "Scopes")
        XCTAssertEqual(view.sections[2].rows[2].text, "api web refresh_token")
    }
    
    func testDevInfoViewRendersRealWorldData() {
        let expectation = XCTestExpectation(description: "View renders real-world SDK data")
        
        let infoData = [
            "SDK Version", "13.0.0",
            "App Type", "Native iOS",
            "section:Current User",
            "Username", "test@salesforce.com",
            "User ID", "005xx000001X8Uz",
            "Org ID", "00Dxx0000001gPL",
            "Instance URL", "https://na1.salesforce.com",
            "section:OAuth Configuration",
            "Client ID", "3MVG9PhR6g6B7ps6aoQEJ8h_",
            "Redirect URI", "testapp://mobilesdk/detect/oauth/done",
            "Scopes", "api web refresh_token"
        ]
        let view = DevInfoView(infoData: infoData, title: "Dev Support")
        let hostingController = UIHostingController(rootView: view)
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        hostingController.viewWillAppear(false)
        hostingController.viewDidAppear(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Verify the complex real-world view renders successfully
            XCTAssertNotNil(hostingController.view)
            XCTAssertNotNil(hostingController.view.superview)
            
            // Clean up
            window.rootViewController = nil
            window.isHidden = true
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Test Helper Extension

extension DevInfoView {
    /// Public test-only method to expose extractSections for testing
    static func testExtractSections(from infoData: [String]) -> [DevInfoSection] {
        return DevInfoView(infoData: infoData, title: "").sections
    }
}

