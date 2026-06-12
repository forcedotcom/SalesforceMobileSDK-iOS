import XCTest
@testable import SalesforceSDKCore

/// Tests for DomainDiscoveryCoordinator. We call `handle(callbackURL:)` directly with a URL
/// instead of building a MockNavigationAction, because subclassing WKNavigationAction and
/// calling super.init() can trigger an abort in WebKit on CI (signal abrt).
///
/// These tests exercise only synchronous URL-parsing logic, so they avoid @MainActor and async
/// to prevent main-actor contention with WebKit-using tests running in the same bundle.
final class DomainDiscoveryCoordinatorTests: XCTestCase {

    func testCallbackSuccess() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))

        // When
        let results = coordinator.handle(callbackURL: callbackURL)

        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testMissingMyDomain() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedLoginHint = "testuser@example.com"
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))

        // When
        let results = coordinator.handle(callbackURL: callbackURL)

        // Then
        XCTAssertNil(results)
    }

    func testMissingLoginHint() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        var components = URLComponents()
        components.scheme = "sfdc"
        components.host = "discocallback"
        components.queryItems = [URLQueryItem(name: "my_domain", value: "https://foo.my.salesforce.com")]
        let callbackURL = try XCTUnwrap(components.url)

        // When
        let results = coordinator.handle(callbackURL: callbackURL)

        // Then
        XCTAssertNil(results)
    }

    func testMalformedCallbackURL() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let callbackURLString = "sfdc://discocallback?my_domain=&login_hint="
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))

        // When
        let results = coordinator.handle(callbackURL: callbackURL)

        // Then
        XCTAssertEqual(results?.myDomain, "")
        XCTAssertEqual(results?.loginHint, "")
    }

    func testNonCallbackURL() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        let nonCallbackURL = try XCTUnwrap(components.url)

        // When
        let results = coordinator.handle(callbackURL: nonCallbackURL)

        // Then
        XCTAssertNil(results)
    }

    func testSpecialCharactersInLoginHint() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "user+test@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))

        // When
        let results = coordinator.handle(callbackURL: callbackURL)

        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testExtraQueryParameters() throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)&extra=foo&another=bar"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))

        // When
        let results = try XCTUnwrap(coordinator.handle(callbackURL: callbackURL))

        // Then
        XCTAssertEqual(results.myDomain, expectedDomain)
        XCTAssertEqual(results.loginHint, expectedLoginHint)
    }

}
