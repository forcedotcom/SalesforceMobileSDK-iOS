import XCTest
import WebKit
@testable import SalesforceSDKCore

final class WebViewStateManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        SFSDKWebViewStateManager.sessionCookieManagementDisabled = false
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    @MainActor
    func testRemoveSessionForcefullyCallsCompletion() async {
        await SFSDKWebViewStateManager.removeSessionForcefully()

        // Check that cookies were cleared
        let records = await WKWebsiteDataStore.default().dataRecords(ofTypes: [WKWebsiteDataTypeCookies])
        XCTAssertTrue(records.isEmpty, "Expected cookies to be cleared")
    }
    
    func testSessionCookieManagementToggle() {
        SFSDKWebViewStateManager.sessionCookieManagementDisabled = true
        XCTAssertTrue(SFSDKWebViewStateManager.sessionCookieManagementDisabled)

        SFSDKWebViewStateManager.sessionCookieManagementDisabled = false
        XCTAssertFalse(SFSDKWebViewStateManager.sessionCookieManagementDisabled)
    }
}
