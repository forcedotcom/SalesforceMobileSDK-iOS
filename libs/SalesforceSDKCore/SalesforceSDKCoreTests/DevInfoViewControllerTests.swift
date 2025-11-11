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
@testable import SalesforceSDKCore

class DevInfoViewControllerTests: XCTestCase {
    
    // MARK: - Test extractSections with no sections
    
    func testExtractSectionsWithNoSectionMarkers() {
        let infoData = [
            "Key1", "Value1",
            "Key2", "Value2",
            "Key3", "Value3"
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
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
    
    // MARK: - Test extractSections with section at start
    
    func testExtractSectionsWithSectionAtStart() {
        let infoData = [
            "section:First Section",
            "Key1", "Value1",
            "Key2", "Value2"
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertEqual(sections[0].title, "First Section", "Section should have correct title")
        XCTAssertEqual(sections[0].rows.count, 2, "Section should have 2 rows")
        
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")

        XCTAssertEqual(sections[0].rows[1].headline, "Key2")
        XCTAssertEqual(sections[0].rows[1].text, "Value2")

    }
    
    // MARK: - Test extractSections with section in middle
    
    func testExtractSectionsWithSectionInMiddle() {
        let infoData = [
            "Key1", "Value1",
            "section:Middle Section",
            "Key2", "Value2"
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
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
    
    // MARK: - Test extractSections with multiple sections
    
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
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
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
    
    // MARK: - Test extractSections with empty array
    
    func testExtractSectionsWithEmptyArray() {
        let infoData: [String] = []
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 0, "Should have no sections for empty array")
    }
    
    // MARK: - Test extractSections with odd number of items
    
    func testExtractSectionsWithOddNumberOfItems() {
        let infoData = [
            "Key1", "Value1",
            "Key2"  // Odd item, should be skipped
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertEqual(sections[0].rows.count, 1, "Should only have 1 complete row (odd item skipped)")
        XCTAssertEqual(sections[0].rows[0].headline, "Key1")
        XCTAssertEqual(sections[0].rows[0].text, "Value1")
    }
    
    // MARK: - Test extractSections with section but no rows
    
    func testExtractSectionsWithSectionButNoRows() {
        let infoData = [
            "Key1", "Value1",
            "section:Empty Section",
            "section:Another Section",
            "Key2", "Value2"
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 2, "Should have two sections (empty section should be skipped)")
        
        // First section (no title)
        XCTAssertNil(sections[0].title)
        XCTAssertEqual(sections[0].rows.count, 1)
        
        // Second section (Another Section) - Empty Section was skipped
        XCTAssertEqual(sections[1].title, "Another Section")
        XCTAssertEqual(sections[1].rows.count, 1)
    }
    
    // MARK: - Test extractSections with empty section title
    
    func testExtractSectionsWithEmptySectionTitle() {
        let infoData = [
            "section:",  // Empty section title
            "Key1", "Value1"
        ]
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
        XCTAssertEqual(sections.count, 1, "Should have exactly one section")
        XCTAssertNil(sections[0].title, "Empty section title should become nil")
        XCTAssertEqual(sections[0].rows.count, 1)
    }
    
    // MARK: - Test extractSections with complex real-world data
    
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
        
        let sections = SFSDKDevInfoView.testExtractSections(from: infoData)
        
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
}

// MARK: - Test Helper Extension

extension SFSDKDevInfoView {
    /// Public test-only method to expose extractSections for testing
    static func testExtractSections(from infoData: [String]) -> [DevInfoSection] {
        return SFSDKDevInfoView(infoData: infoData, title: "").sections
    }
}

