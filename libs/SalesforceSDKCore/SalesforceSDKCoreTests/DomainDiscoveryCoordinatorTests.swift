import XCTest
@testable import SalesforceSDKCore
import WebKit

// Mock WKWebView to simulate navigation and callback
class MockWKWebView: WKWebView {
    var simulatedCallbackURL: URL?
    var mockAction: WKNavigationAction?
    override func load(_ request: URLRequest) -> WKNavigation? {
        if let callbackURL = simulatedCallbackURL {
            mockAction = MockNavigationAction(url: callbackURL) as WKNavigationAction
        }
        
        if let delegate = self.navigationDelegate, let action = mockAction {
            delegate.webView?(self, decidePolicyFor: action, decisionHandler: { _ in })
        }
        return nil
    }
}

@MainActor
final class DomainDiscoveryCoordinatorTests: XCTestCase {

    func testCallbackSuccess() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL
        
        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
        
        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testMissingMyDomain() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let expectedLoginHint = "testuser@example.com"
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL
        
        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
        
        // Then
        XCTAssertNil(results)
    }

    func testMissingLoginHint() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
        
        // Then
        XCTAssertNil(results)
    }

    func testMalformedCallbackURL() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let callbackURLString = "sfdc://discocallback?my_domain=&login_hint="
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
        
        // Then
        XCTAssertEqual(results?.myDomain, "")
        XCTAssertEqual(results?.loginHint, "")
    }

    func testNonCallbackURL() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let nonCallbackURL = try XCTUnwrap(URL(string: "https://example.com"))
        mockWebView.simulatedCallbackURL = nonCallbackURL

        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
        
        // Then
        XCTAssertNil(results)
    }

    func testSpecialCharactersInLoginHint() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "user+test@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
        let mockAction = try XCTUnwrap(mockWebView.mockAction)
        let results = coordinator.handle(action: mockAction)
    
        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testExtraQueryParameters() async throws {
        // Given
        let mockWebView = MockWKWebView()
        let coordinator = DomainDiscoveryCoordinator()
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "test", clientId: "client123", encrypted: false))
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)&extra=foo&another=bar"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        mockWebView.simulatedCallbackURL = callbackURL

        // When
        coordinator.runMyDomainsDiscovery(on: mockWebView, with: credentials)
    
        let populatedAction = try XCTUnwrap(mockWebView.mockAction)
        let results = try XCTUnwrap(coordinator.handle(action: populatedAction))
    
        // Then
        XCTAssertEqual(results.myDomain, expectedDomain)
        XCTAssertEqual(results.loginHint, expectedLoginHint)
    }
}
