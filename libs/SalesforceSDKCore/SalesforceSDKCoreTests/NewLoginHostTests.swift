import XCTest
@testable import SalesforceSDKCore

final class NewLoginHostTests: XCTestCase {
    let expectedHost = "login.salesforce.com"
    let expectedLabel = "Test Label"
    var view: NewLoginHostView!
    var savedHost: String?
    var savedLabel: String?
    
    override func setUp() {
        super.setUp()
        savedHost = nil
        savedLabel = nil
        view = NewLoginHostView(viewControllerConfig: nil) { host, label in
            self.savedHost = host
            self.savedLabel = label
        }
    }
    
    override func tearDown() {
        view = nil
        savedHost = nil
        savedLabel = nil
        super.tearDown()
    }
    
    func testSave() {
        view.save(host: expectedHost, hostLabel: expectedLabel)
        
        XCTAssertEqual(savedHost, expectedHost)
        XCTAssertEqual(savedLabel, expectedLabel)
    }
    
    func testSaveWithWhitespace() {
        view.save(host: "  login.salesforce.com  ", hostLabel: "  Test Label  ")
        
        XCTAssertEqual(savedHost, expectedHost)
        XCTAssertEqual(savedLabel, expectedLabel)
    }
    
    func testSaveWithHttpHost() {
        view.save(host: "http://login.salesforce.com", hostLabel: expectedLabel)
        
        XCTAssertEqual(savedHost, expectedHost)
        XCTAssertEqual(savedLabel, expectedLabel)
    }
    
    func testSaveWithHttpsHost() {
        view.save(host: "https://login.salesforce.com", hostLabel: expectedLabel)
        
        XCTAssertEqual(savedHost, expectedHost)
        XCTAssertEqual(savedLabel, expectedLabel)
    }
} 
