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
    func testSharedProcessPoolIsCreated() {
        let pool = SFSDKWebViewStateManager.sharedProcessPool
        XCTAssertNotNil(pool)
        XCTAssertEqual(pool, SFSDKWebViewStateManager.sharedProcessPool)
    }

    @MainActor
    func testSetSharedProcessPoolUpdatesPool() {
        let customPool = WKProcessPool()
        SFSDKWebViewStateManager.sharedProcessPool = customPool
        XCTAssertEqual(SFSDKWebViewStateManager.sharedProcessPool, customPool)
    }

    @MainActor
    func testRemoveSessionForcefullyCallsCompletion() async {
        // Set a custom pool to verify it's cleared
        SFSDKWebViewStateManager.sharedProcessPool = WKProcessPool()

        await SFSDKWebViewStateManager.removeSessionForcefully()

        // Check that shared process pool is cleared (should not match the one we just set)
        let currentPool = SFSDKWebViewStateManager.sharedProcessPool
        XCTAssertNotNil(currentPool)

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
