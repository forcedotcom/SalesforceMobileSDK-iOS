import XCTest
@testable import SalesforceSDKCore
import WebKit

// Mock WKWebView to simulate navigation and callback
class MockWKWebView: WKWebView {
    var simulatedCallbackURL: URL?
    override func load(_ request: URLRequest) -> WKNavigation? {
        if let callbackURL = simulatedCallbackURL,
           let delegate = self.navigationDelegate {
            let navAction = MockNavigationAction(url: callbackURL)
            delegate.webView?(self, decidePolicyFor: navAction, decisionHandler: { _ in })
        }
        return nil
    }
}

class MockNavigationAction: WKNavigationAction {
    private let _request: URLRequest
    override var request: URLRequest { _request }
    init(url: URL) {
        self._request = URLRequest(url: url)
        super.init()
    }
}

@MainActor
final class DomainDiscoveryCoordinatorTests: XCTestCase {

    func testCallbackSuccess() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let expectedDomain = "https://foo.my.salesforce.com"
        let expectedLoginHint = "testuser@example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(expectedDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL
        
        // When
        let results = try await coordinator.runMyDomainDiscovery(credentials: credentials!)
        
        // Then
        XCTAssertEqual(results.0, expectedDomain)
        XCTAssertEqual(results.1, expectedLoginHint)
    }

    func testMissingMyDomain() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let expectedLoginHint = "testuser@example.com"
        let callbackURLString = "sfdc://discocallback?login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL
        
        // When/Then
        do {
            _ = try await coordinator.runMyDomainDiscovery(credentials: credentials!)
            XCTFail("Expected error to be thrown, but got success")
        } catch {
            // Optionally, check error type or message here
        }
    }

    func testMissingLoginHint() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let expectedDomain = "https://foo.my.salesforce.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(expectedDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL

        // When/Then
        do {
            _ = try await coordinator.runMyDomainDiscovery(credentials: credentials!)
            XCTFail("Expected error to be thrown, but got success")
        } catch {
            // Optionally, check error type or message here
        }
    }

    func testMalformedCallbackURL() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let callbackURLString = "sfdc://discocallback?my_domain=&login_hint="
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL

        // When/Then
        do {
            _ = try await coordinator.runMyDomainDiscovery(credentials: credentials!)
            XCTFail("Expected error to be thrown, but got success")
        } catch {
            // Optionally, check error type or message here
        }
    }

    func testNonCallbackURL() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let nonCallbackURL = URL(string: "https://example.com")!
        mockWebView.simulatedCallbackURL = nonCallbackURL

        // When/Then
        let expectation = XCTestExpectation(description: "Should not complete for non-callback URL")
        expectation.isInverted = true // This means we expect it NOT to be fulfilled

        let task = Task {
            do {
                _ = try await coordinator.runMyDomainDiscovery(credentials: credentials!)
                XCTFail("Expected to hang or timeout, but got a result")
            } catch {
                // Optionally, check error type or message here
            }
            expectation.fulfill()
        }

        // Wait for a short period and then cancel
        await fulfillment(of: [expectation], timeout: 0.5)
        task.cancel()
    }

    func testSpecialCharactersInLoginHint() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let expectedDomain = "https://foo.my.salesforce.com"
        let expectedLoginHint = "user+test@example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(expectedDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        let results = try await coordinator.runMyDomainDiscovery(credentials: credentials!)

        // Then
        XCTAssertEqual(results.0, expectedDomain)
        XCTAssertEqual(results.1, expectedLoginHint)
    }

    func testExtraQueryParameters() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator(webView: mockWebView)
        let credentials = OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false)
        let expectedDomain = "https://foo.my.salesforce.com"
        let expectedLoginHint = "testuser@example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(expectedDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&extra=foo&another=bar"
        let callbackURL = URL(string: callbackURLString)!
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        let results = try await coordinator.runMyDomainDiscovery(credentials: credentials!)

        // Then
        XCTAssertEqual(results.0, expectedDomain)
        XCTAssertEqual(results.1, expectedLoginHint)
    }
} 
