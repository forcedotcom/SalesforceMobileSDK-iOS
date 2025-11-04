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
    func testProcessPoolIsNil() {
        // TODO remove this test in 14.0 when we remove sharedProcessPool from SFSDKWebViewStateManager
        XCTAssertNil(SFSDKWebViewStateManager.sharedProcessPool)
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
    
    @MainActor
    func testClearCache() async throws {
        // Add some test data
        let webView = WKWebView()
        let html = """
        <html>
        <head><script>localStorage.setItem('test', 'value');</script></head>
        <body>Test Content</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://example.com"))
        try await Task.sleep(for: .seconds(1))
        
        // Verify data exists before clearing
        let dataTypes: Set<String> = [WKWebsiteDataTypeDiskCache,
                                      WKWebsiteDataTypeMemoryCache,
                                      WKWebsiteDataTypeFetchCache,
                                      WKWebsiteDataTypeLocalStorage,
                                      WKWebsiteDataTypeSessionStorage,
                                      WKWebsiteDataTypeIndexedDBDatabases,
                                      WKWebsiteDataTypeWebSQLDatabases,
                                      WKWebsiteDataTypeOfflineWebApplicationCache,
                                      WKWebsiteDataTypeServiceWorkerRegistrations]
        let dataStore = WKWebsiteDataStore.default()
        let initialRecords = await dataStore.dataRecords(ofTypes: dataTypes)
        XCTAssertFalse(initialRecords.isEmpty, "Expected data to exist before clearing")
        
        // Clear the cache
        await SFSDKWebViewStateManager.clearCache()
        
        // Verify data was cleared
        let records = await dataStore.dataRecords(ofTypes: dataTypes)
        XCTAssertTrue(records.isEmpty, "Expected data to be cleared")
    }
}
