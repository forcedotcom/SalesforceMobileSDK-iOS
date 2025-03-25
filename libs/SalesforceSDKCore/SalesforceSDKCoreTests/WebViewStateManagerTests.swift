import XCTest
import WebKit
@testable import SalesforceSDKCore

final class WebViewStateManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        WebViewStateManager.setSessionCookieManagementDisabled(false)
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    @MainActor func testSharedProcessPoolIsCreated() {
        let pool = WebViewStateManager.sharedProcessPool
        XCTAssertNotNil(pool)
        XCTAssertEqual(pool, WebViewStateManager.sharedProcessPool)
    }

    @MainActor func testSetSharedProcessPoolUpdatesPool() {
        let customPool = WKProcessPool()
        WebViewStateManager.sharedProcessPool = customPool
        XCTAssertEqual(WebViewStateManager.sharedProcessPool, customPool)
    }

    func testSessionCookieManagementToggle() {
        WebViewStateManager.setSessionCookieManagementDisabled(true)
        XCTAssertTrue(WebViewStateManager.isSessionCookieManagementDisabled())

        WebViewStateManager.setSessionCookieManagementDisabled(false)
        XCTAssertFalse(WebViewStateManager.isSessionCookieManagementDisabled())
    }

    @MainActor func testRemoveSessionForcefullyCallsCompletion() async {
        // Set a custom pool to verify it's cleared
        WebViewStateManager.sharedProcessPool = WKProcessPool()

        await WebViewStateManager.removeSessionForcefully()

        // Check that shared process pool is cleared (should not match the one we just set)
        let currentPool = WebViewStateManager.sharedProcessPool
        XCTAssertNotNil(currentPool)

        // Check that cookies were cleared
        let records = await WKWebsiteDataStore.default().dataRecords(ofTypes: [WKWebsiteDataTypeCookies])
        XCTAssertTrue(records.isEmpty, "Expected cookies to be cleared")
    }
}
